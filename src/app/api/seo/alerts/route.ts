/**
 * GET /api/seo/alerts — SIL-9 Option A: Compute-on-Read Alert Surface (MVP T1–T3)
 *
 * SIL-9.1: alert filtering + deterministic keyset pagination.
 * SIL-9.2: deterministic suppression rules (spam control, pre-pagination).
 *
 * Returns deterministic alert records derived from snapshot history.
 * No writes. No EventLog. No schema changes. No background jobs.
 * All trigger conditions are functions of included snapshot rows only.
 *
 * Trigger types:
 *   T1 — Volatility Regime Transition
 *   T2 — Spike Threshold Exceedance
 *   T3 — Risk Concentration Exceedance
 *
 * Query params:
 *   windowDays             required  integer 1–30
 *   spikeThreshold         optional  float 0–100,  default 75.00
 *   concentrationThreshold optional  float 0–1,    default 0.80
 *   limit                  optional  integer 1–200, default 100
 *   cursor                 optional  opaque base64url string (keyset pagination)
 *
 * SIL-9.1 filter params (optional, validated before any DB work):
 *   triggerTypes           comma-separated subset of T1,T2,T3
 *   keywordTargetId        UUID — filters to single keyword; excludes T3
 *   minSeverityRank        integer 0–999
 *   minPairVolatilityScore float 0–100 (T2 only)
 *
 * SIL-9.2 suppression params (optional, validated before any DB work):
 *   suppressionMode        "none" | "default"         default: "default"
 *   t2Mode                 "all" | "maxPerKeyword"     default: "maxPerKeyword" when suppressionMode=default
 *   t1Mode                 "all" | "latestPerKeyword" | "upwardOnlyLatest"  default: "latestPerKeyword"
 *   t3Mode                 "all" | "deltaOnly"         default: "all"
 *
 * Suppression runs after filter+sort, before cursor. Pure function; no DB calls inside.
 *
 * Deterministic ordering (unchanged from SIL-9):
 *   1. severityRank DESC
 *   2. toCapturedAt DESC
 *   3. triggerType ASC
 *   4. keywordTargetId ASC (nulls last)
 *   5. toSnapshotId DESC  (nulls last)
 *
 * Isolation: resolveProjectId(request) — headers only.
 */

import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeVolatility,
  classifyRegime,
  VolatilityRegime,
  SnapshotForVolatility,
} from "@/lib/seo/volatility-service";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================

const WINDOW_DAYS_MIN = 1;
const WINDOW_DAYS_MAX = 30;

const SPIKE_THRESHOLD_DEFAULT         = 75.00;
const SPIKE_THRESHOLD_MIN             = 0;
const SPIKE_THRESHOLD_MAX             = 100;

const CONCENTRATION_THRESHOLD_DEFAULT = 0.80;
const CONCENTRATION_THRESHOLD_MIN     = 0;
const CONCENTRATION_THRESHOLD_MAX     = 1;

const LIMIT_DEFAULT = 100;
const LIMIT_MIN     = 1;
const LIMIT_MAX     = 200;

const MIN_SEVERITY_RANK_MIN = 0;
const MIN_SEVERITY_RANK_MAX = 999;

// T3 deltaOnly: minimum ratio increase required to fire
const T3_DELTA_ONLY_MIN_DELTA = 0.05;


const VALID_TRIGGER_TYPES = new Set(["T1", "T2", "T3", "T4"] as const);
type TriggerTypeToken = "T1" | "T2" | "T3" | "T4";

// T4 — AI Churn Cluster constants
const AI_CHURN_MIN_FLIPS_MIN     = 2;
const AI_CHURN_MIN_FLIPS_MAX     = 20;
const AI_CHURN_MAX_GAP_DAYS_DEFAULT = 7;
const AI_CHURN_MAX_GAP_DAYS_MIN  = 1;
const AI_CHURN_MAX_GAP_DAYS_MAX  = 30;
// aiChurnWindowDays defaults to windowDays; same min/max as windowDays
const MS_PER_DAY = 86_400_000;

// =============================================================================
// Suppression param types
// =============================================================================

type SuppressionMode  = "none" | "default";
type T1Mode           = "all" | "latestPerKeyword" | "upwardOnlyLatest";
type T2Mode           = "all" | "maxPerKeyword";
type T3Mode           = "all" | "deltaOnly";

interface SuppressionOpts {
  suppressionMode: SuppressionMode;
  t1Mode:          T1Mode;
  t2Mode:          T2Mode;
  t3Mode:          T3Mode;
}

// =============================================================================
// Severity scoring — SIL-9.3 magnitude-aware, integer [0, 100]
// =============================================================================

const REGIME_TO_INT: Record<VolatilityRegime, number> = {
  calm:     0,
  shifting: 1,
  unstable: 2,
  chaotic:  3,
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/**
 * T1 severity — regime-direction base + pair-score magnitude.
 *
 * direction = toOrder - fromOrder  (negative = recovery)
 * base      = 50 + direction * 20
 * magnitude = clamp(round(|lastPairScore - previousPairScore|), 0, 50)
 * result    = clamp(base + magnitude, 0, 100)
 */
function computeT1SeverityRank(
  fromRegime:        VolatilityRegime,
  toRegime:          VolatilityRegime,
  lastPairScore:     number,
  previousPairScore: number | null,
): number {
  const direction = REGIME_TO_INT[toRegime] - REGIME_TO_INT[fromRegime];
  const base      = 50 + direction * 20;
  const magnitude = previousPairScore !== null
    ? clamp(Math.round(Math.abs(lastPairScore - previousPairScore)), 0, 50)
    : 0;
  return clamp(base + magnitude, 0, 100);
}

/**
 * T2 severity — exceedance above spike threshold.
 *
 * exceed = pairVolatilityScore - spikeThreshold
 * result = clamp(round(60 + exceed * 2), 0, 100)
 */
function computeT2SeverityRank(
  pairVolatilityScore: number,
  spikeThreshold:      number,
): number {
  const exceed = pairVolatilityScore - spikeThreshold;
  return clamp(Math.round(60 + exceed * 2), 0, 100);
}

/**
 * T3 severity — concentration ratio exceedance.
 *
 * exceed = ratio - threshold
 * result = clamp(round(70 + exceed * 200), 0, 100)
 */
function computeT3SeverityRank(
  volatilityConcentrationRatio: number,
  concentrationThreshold:       number,
): number {
  const exceed = volatilityConcentrationRatio - concentrationThreshold;
  return clamp(Math.round(70 + exceed * 200), 0, 100);
}

/**
 * T4 severity — AI churn cluster density.
 *
 * excessFlips = flipCount - aiChurnMinFlips  (>= 0)
 * tightness   = 1 - (clusterDurationMs / (aiChurnMaxGapDays * MS_PER_DAY)), clamped [0, 1]
 * result      = clamp(round(65 + excessFlips * 5 + tightness * 20), 0, 100)
 */
function computeT4SeverityRank(
  flipCount:          number,
  aiChurnMinFlips:    number,
  clusterDurationMs:  number,
  aiChurnMaxGapDays:  number,
): number {
  const excessFlips = flipCount - aiChurnMinFlips;
  const tightness   = clamp(1 - clusterDurationMs / (aiChurnMaxGapDays * MS_PER_DAY), 0, 1);
  return clamp(Math.round(65 + excessFlips * 5 + tightness * 20), 0, 100);
}

// =============================================================================
// Alert union types
// =============================================================================

interface T1Alert {
  triggerType:         "T1";
  keywordTargetId:     string;
  query:               string;
  fromRegime:          VolatilityRegime;
  toRegime:            VolatilityRegime;
  fromSnapshotId:      string;
  toSnapshotId:        string;
  fromCapturedAt:      string;
  toCapturedAt:        string;
  pairVolatilityScore: number;
  _severityRank:       number;
  _toCapturedAtMs:     number;
  _toSnapshotId:       string;
  _keywordTargetId:    string;
}

interface T2Alert {
  triggerType:         "T2";
  keywordTargetId:     string;
  query:               string;
  fromSnapshotId:      string;
  toSnapshotId:        string;
  fromCapturedAt:      string;
  toCapturedAt:        string;
  pairVolatilityScore: number;
  threshold:           number;
  exceedanceMargin:    number;
  _severityRank:       number;
  _toCapturedAtMs:     number;
  _toSnapshotId:       string;
  _keywordTargetId:    string;
}

interface T3Alert {
  triggerType:                  "T3";
  projectId:                    string;
  volatilityConcentrationRatio: number;
  threshold:                    number;
  top3RiskKeywords:             Array<{
    keywordTargetId:  string;
    query:            string;
    volatilityScore:  number;
    volatilityRegime: VolatilityRegime;
  }>;
  activeKeywordCount:  number;
  _severityRank:       number;
  _toCapturedAtMs:     number;
  _toSnapshotId:       null;
  _keywordTargetId:    null;
}

interface T4Alert {
  triggerType:           "T4";
  keywordTargetId:       string;
  query:                 string;
  flipCount:             number;
  clusterFirstFlipAt:    string; // ISO
  clusterLastFlipAt:     string; // ISO
  clusterDurationDays:   number; // rounded 2 decimals
  aiChurnMinFlips:       number;
  aiChurnMaxGapDays:     number;
  aiChurnWindowDays:     number;
  // sort-assist
  _severityRank:         number;
  _toCapturedAtMs:       number;
  _toSnapshotId:         string;
  _keywordTargetId:      string;
}

type AnyAlert = T1Alert | T2Alert | T3Alert | T4Alert;

type T1Emitted    = Omit<T1Alert, "_severityRank" | "_toCapturedAtMs" | "_toSnapshotId" | "_keywordTargetId">;
type T2Emitted    = Omit<T2Alert, "_severityRank" | "_toCapturedAtMs" | "_toSnapshotId" | "_keywordTargetId">;
type T3Emitted    = Omit<T3Alert, "_severityRank" | "_toCapturedAtMs" | "_toSnapshotId" | "_keywordTargetId">;
type T4Emitted    = Omit<T4Alert, "_severityRank" | "_toCapturedAtMs" | "_toSnapshotId" | "_keywordTargetId">;
type AlertEmitted = T1Emitted | T2Emitted | T3Emitted | T4Emitted;

// =============================================================================
// Cursor
// =============================================================================

interface CursorPayload {
  s:  number;
  t:  number;
  tt: TriggerTypeToken;
  k:  string | null;
  sn: string | null;
}

function encodeCursor(alert: AnyAlert): string {
  const payload: CursorPayload = {
    s:  alert._severityRank,
    t:  alert._toCapturedAtMs,
    tt: alert.triggerType,
    k:  alert._keywordTargetId,
    sn: alert._toSnapshotId,
  };
  return Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
}

function decodeCursor(raw: string): { payload: CursorPayload } | { error: string } {
  try {
    const json = Buffer.from(raw, "base64url").toString("utf8");
    const p = JSON.parse(json) as Record<string, unknown>;
    if (
      typeof p.s  !== "number" ||
      typeof p.t  !== "number" ||
      typeof p.tt !== "string" ||
      !VALID_TRIGGER_TYPES.has(p.tt as TriggerTypeToken) ||
      (p.k  !== null && typeof p.k  !== "string") ||
      (p.sn !== null && typeof p.sn !== "string")
    ) {
      return { error: "cursor is invalid: missing or malformed fields" };
    }
    return {
      payload: {
        s:  p.s  as number,
        t:  p.t  as number,
        tt: p.tt as TriggerTypeToken,
        k:  p.k  as string | null,
        sn: p.sn as string | null,
      },
    };
  } catch {
    return { error: "cursor is invalid: not valid base64url JSON" };
  }
}

// =============================================================================
// Deterministic sort comparator (unchanged from SIL-9)
// =============================================================================

function compareAlerts(a: AnyAlert, b: AnyAlert): number {
  if (b._severityRank !== a._severityRank) return b._severityRank - a._severityRank;
  if (b._toCapturedAtMs !== a._toCapturedAtMs) return b._toCapturedAtMs - a._toCapturedAtMs;
  if (a.triggerType < b.triggerType) return -1;
  if (a.triggerType > b.triggerType) return 1;
  const aKtId = a._keywordTargetId;
  const bKtId = b._keywordTargetId;
  if (aKtId === null && bKtId === null) {
    // fall through
  } else if (aKtId === null) {
    return 1;
  } else if (bKtId === null) {
    return -1;
  } else {
    const cmp = aKtId.localeCompare(bKtId);
    if (cmp !== 0) return cmp;
  }
  const aSnId = a._toSnapshotId;
  const bSnId = b._toSnapshotId;
  if (aSnId === null && bSnId === null) return 0;
  if (aSnId === null) return 1;
  if (bSnId === null) return -1;
  if (bSnId > aSnId) return 1;
  if (bSnId < aSnId) return -1;
  return 0;
}

// =============================================================================
// isAfterCursor (unchanged from SIL-9.1)
// =============================================================================

function isAfterCursor(alert: AnyAlert, cur: CursorPayload): boolean {
  if (alert._severityRank !== cur.s) return alert._severityRank < cur.s;
  if (alert._toCapturedAtMs !== cur.t) return alert._toCapturedAtMs < cur.t;
  if (alert.triggerType !== cur.tt) return alert.triggerType > cur.tt;
  const ak = alert._keywordTargetId;
  const ck = cur.k;
  if (ak !== ck) {
    if (ak === null) return true;
    if (ck === null) return false;
    return ak.localeCompare(ck) > 0;
  }
  const asn = alert._toSnapshotId;
  const csn = cur.sn;
  if (asn !== csn) {
    if (asn === null) return true;
    if (csn === null) return false;
    return asn < csn;
  }
  return false;
}

// =============================================================================
// Strip sort-assist fields
// =============================================================================

function stripSortFields(alert: AnyAlert): AlertEmitted {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { _severityRank, _toCapturedAtMs, _toSnapshotId, _keywordTargetId, ...emitted } = alert;
  return emitted as AlertEmitted;
}

// =============================================================================
// suppressAlerts — pure function, no DB calls.
//
// Pipeline:
//   T2 suppression → T1 suppression → T3 suppression (per-type, order irrelevant)
//
// Suppression is a subset operation: survivors retain their relative sort order
// from the input array (which is already sorted by compareAlerts).
// No re-sort required — the filtered output is still correctly ordered.
//
// T3 deltaOnly suppression uses priorWindowConcentrationRatio passed in from
// the route's data-loading phase. If null, deltaOnly suppresses T3 (no prior
// window data → cannot confirm delta ≥ threshold).
// =============================================================================

interface SuppressionContext {
  opts:                         SuppressionOpts;
  // For t3Mode=deltaOnly: ratio from the prior window (null if unavailable)
  priorWindowConcentrationRatio: number | null;
}

function suppressAlerts(alerts: AnyAlert[], ctx: SuppressionContext): AnyAlert[] {
  const { opts, priorWindowConcentrationRatio } = ctx;

  // suppressionMode=none: bypass all suppression
  if (opts.suppressionMode === "none") return alerts;

  let result = alerts;

  // ── T2 suppression ──────────────────────────────────────────────────────────
  if (opts.t2Mode === "maxPerKeyword") {
    // For each keywordTargetId, keep only the T2 alert with the highest
    // pairVolatilityScore. Tie-break: toCapturedAt DESC, toSnapshotId DESC.
    // Non-T2 alerts pass through untouched.
    const t2Best = new Map<string, T2Alert>();

    for (const alert of result) {
      if (alert.triggerType !== "T2") continue;
      const a   = alert as T2Alert;
      const key = a._keywordTargetId;
      const existing = t2Best.get(key);
      if (!existing) {
        t2Best.set(key, a);
        continue;
      }
      // Compare: prefer higher pairVolatilityScore
      if (a.pairVolatilityScore > existing.pairVolatilityScore) {
        t2Best.set(key, a);
      } else if (a.pairVolatilityScore === existing.pairVolatilityScore) {
        // tie-break: toCapturedAt DESC (higher ms wins)
        if (a._toCapturedAtMs > existing._toCapturedAtMs) {
          t2Best.set(key, a);
        } else if (a._toCapturedAtMs === existing._toCapturedAtMs) {
          // final tie-break: toSnapshotId DESC (lexicographically larger wins)
          if (a._toSnapshotId > existing._toSnapshotId) {
            t2Best.set(key, a);
          }
        }
      }
    }

    // Rebuild result: keep non-T2 alerts and the best T2 per keyword.
    // Preserve relative order of the input (stable — iterate in input order).
    const t2BestSet = new Set(t2Best.values());
    result = result.filter(
      (alert) => alert.triggerType !== "T2" || t2BestSet.has(alert as T2Alert)
    );
  }

  // ── T1 suppression ──────────────────────────────────────────────────────────
  if (opts.t1Mode === "latestPerKeyword" || opts.t1Mode === "upwardOnlyLatest") {
    // Step 1 (upwardOnlyLatest only): filter T1 to upward transitions.
    // Upward = REGIME_TO_INT[toRegime] > REGIME_TO_INT[fromRegime].
    let t1Candidates = result.filter((a) => a.triggerType === "T1") as T1Alert[];

    if (opts.t1Mode === "upwardOnlyLatest") {
      t1Candidates = t1Candidates.filter(
        (a) => REGIME_TO_INT[a.toRegime] > REGIME_TO_INT[a.fromRegime]
      );
    }

    // Step 2: for each keywordTargetId, keep the T1 with latest toCapturedAt.
    // Tie-break: toSnapshotId DESC.
    const t1Best = new Map<string, T1Alert>();
    for (const a of t1Candidates) {
      const key      = a._keywordTargetId;
      const existing = t1Best.get(key);
      if (!existing) {
        t1Best.set(key, a);
        continue;
      }
      if (a._toCapturedAtMs > existing._toCapturedAtMs) {
        t1Best.set(key, a);
      } else if (a._toCapturedAtMs === existing._toCapturedAtMs) {
        if (a._toSnapshotId > existing._toSnapshotId) {
          t1Best.set(key, a);
        }
      }
    }

    const t1BestSet = new Set(t1Best.values());
    result = result.filter(
      (alert) => alert.triggerType !== "T1" || t1BestSet.has(alert as T1Alert)
    );
  }

  // ── T3 suppression ──────────────────────────────────────────────────────────
  if (opts.t3Mode === "deltaOnly") {
    // Keep T3 only if currentRatio - priorRatio >= T3_DELTA_ONLY_MIN_DELTA.
    // If priorWindowConcentrationRatio is null (no prior window data), suppress T3.
    result = result.filter((alert) => {
      if (alert.triggerType !== "T3") return true;
      const t3 = alert as T3Alert;
      if (priorWindowConcentrationRatio === null) return false;
      const delta = t3.volatilityConcentrationRatio - priorWindowConcentrationRatio;
      return delta >= T3_DELTA_ONLY_MIN_DELTA;
    });
  }

  return result;
}

// =============================================================================
// Param parsers
// =============================================================================

function parseWindowDays(
  sp: URLSearchParams
): { windowDays: number } | { error: string } {
  const raw = sp.get("windowDays");
  if (raw === null) return { error: "windowDays is required" };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_DAYS_MIN) return { error: `windowDays must be >= ${WINDOW_DAYS_MIN}` };
  if (n > WINDOW_DAYS_MAX) return { error: `windowDays must be <= ${WINDOW_DAYS_MAX}` };
  return { windowDays: n };
}

function parseSpikeThreshold(
  sp: URLSearchParams
): { spikeThreshold: number } | { error: string } {
  const raw = sp.get("spikeThreshold");
  if (raw === null) return { spikeThreshold: SPIKE_THRESHOLD_DEFAULT };
  const n = parseFloat(raw);
  if (isNaN(n)) return { error: "spikeThreshold must be a number" };
  if (n < SPIKE_THRESHOLD_MIN) return { error: `spikeThreshold must be >= ${SPIKE_THRESHOLD_MIN}` };
  if (n > SPIKE_THRESHOLD_MAX) return { error: `spikeThreshold must be <= ${SPIKE_THRESHOLD_MAX}` };
  return { spikeThreshold: n };
}

function parseConcentrationThreshold(
  sp: URLSearchParams
): { concentrationThreshold: number } | { error: string } {
  const raw = sp.get("concentrationThreshold");
  if (raw === null) return { concentrationThreshold: CONCENTRATION_THRESHOLD_DEFAULT };
  const n = parseFloat(raw);
  if (isNaN(n)) return { error: "concentrationThreshold must be a number" };
  if (n < CONCENTRATION_THRESHOLD_MIN) return { error: `concentrationThreshold must be >= ${CONCENTRATION_THRESHOLD_MIN}` };
  if (n > CONCENTRATION_THRESHOLD_MAX) return { error: `concentrationThreshold must be <= ${CONCENTRATION_THRESHOLD_MAX}` };
  return { concentrationThreshold: n };
}

function parseLimit(
  sp: URLSearchParams
): { limit: number } | { error: string } {
  const raw = sp.get("limit");
  if (raw === null) return { limit: LIMIT_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "limit must be an integer" };
  const n = parseInt(raw, 10);
  if (n < LIMIT_MIN) return { error: `limit must be >= ${LIMIT_MIN}` };
  if (n > LIMIT_MAX) return { error: `limit must be <= ${LIMIT_MAX}` };
  return { limit: n };
}

function parseTriggerTypes(
  sp: URLSearchParams
): { triggerTypes: Set<TriggerTypeToken> | null } | { error: string } {
  const raw = sp.get("triggerTypes");
  if (raw === null) return { triggerTypes: null };
  const tokens = raw.split(",").map((t) => t.trim());
  if (tokens.length === 0 || (tokens.length === 1 && tokens[0] === "")) {
    return { error: "triggerTypes must not be empty" };
  }
  const set = new Set<TriggerTypeToken>();
  for (const token of tokens) {
    if (!VALID_TRIGGER_TYPES.has(token as TriggerTypeToken)) {
      return { error: `triggerTypes contains invalid token: "${token}". Valid values: T1, T2, T3, T4` };
    }
    set.add(token as TriggerTypeToken);
  }
  return { triggerTypes: set };
}

function parseKeywordTargetId(
  sp: URLSearchParams
): { keywordTargetId: string | null } | { error: string } {
  const raw = sp.get("keywordTargetId");
  if (raw === null) return { keywordTargetId: null };
  if (!UUID_RE.test(raw)) return { error: "keywordTargetId must be a valid UUID" };
  return { keywordTargetId: raw };
}

function parseMinSeverityRank(
  sp: URLSearchParams
): { minSeverityRank: number | null } | { error: string } {
  const raw = sp.get("minSeverityRank");
  if (raw === null) return { minSeverityRank: null };
  if (!/^\d+$/.test(raw)) return { error: "minSeverityRank must be an integer" };
  const n = parseInt(raw, 10);
  if (n < MIN_SEVERITY_RANK_MIN) return { error: `minSeverityRank must be >= ${MIN_SEVERITY_RANK_MIN}` };
  if (n > MIN_SEVERITY_RANK_MAX) return { error: `minSeverityRank must be <= ${MIN_SEVERITY_RANK_MAX}` };
  return { minSeverityRank: n };
}

function parseMinPairVolatilityScore(
  sp: URLSearchParams
): { minPairVolatilityScore: number | null } | { error: string } {
  const raw = sp.get("minPairVolatilityScore");
  if (raw === null) return { minPairVolatilityScore: null };
  const n = parseFloat(raw);
  if (isNaN(n)) return { error: "minPairVolatilityScore must be a number" };
  if (n < 0)   return { error: "minPairVolatilityScore must be >= 0" };
  if (n > 100) return { error: "minPairVolatilityScore must be <= 100" };
  return { minPairVolatilityScore: n };
}

function parseCursor(
  sp: URLSearchParams
): { cursor: CursorPayload | null } | { error: string } {
  const raw = sp.get("cursor");
  if (raw === null) return { cursor: null };
  const result = decodeCursor(raw);
  if ("error" in result) return { error: result.error };
  return { cursor: result.payload };
}

function parseSuppressionMode(
  sp: URLSearchParams
): { suppressionMode: SuppressionMode } | { error: string } {
  const raw = sp.get("suppressionMode");
  if (raw === null) return { suppressionMode: "default" };
  if (raw !== "none" && raw !== "default") {
    return { error: `suppressionMode must be "none" or "default"` };
  }
  return { suppressionMode: raw };
}

function parseT1Mode(
  sp: URLSearchParams,
  suppressionMode: SuppressionMode
): { t1Mode: T1Mode } | { error: string } {
  const raw = sp.get("t1Mode");
  if (raw === null) {
    return { t1Mode: suppressionMode === "default" ? "latestPerKeyword" : "all" };
  }
  if (raw !== "all" && raw !== "latestPerKeyword" && raw !== "upwardOnlyLatest") {
    return { error: `t1Mode must be "all", "latestPerKeyword", or "upwardOnlyLatest"` };
  }
  return { t1Mode: raw };
}

function parseT2Mode(
  sp: URLSearchParams,
  suppressionMode: SuppressionMode
): { t2Mode: T2Mode } | { error: string } {
  const raw = sp.get("t2Mode");
  if (raw === null) {
    return { t2Mode: suppressionMode === "default" ? "maxPerKeyword" : "all" };
  }
  if (raw !== "all" && raw !== "maxPerKeyword") {
    return { error: `t2Mode must be "all" or "maxPerKeyword"` };
  }
  return { t2Mode: raw };
}

function parseT3Mode(
  sp: URLSearchParams
): { t3Mode: T3Mode } | { error: string } {
  const raw = sp.get("t3Mode");
  if (raw === null) return { t3Mode: "all" };
  if (raw !== "all" && raw !== "deltaOnly") {
    return { error: `t3Mode must be "all" or "deltaOnly"` };
  }
  return { t3Mode: raw };
}

// =============================================================================
// T4 param parsers
// =============================================================================

interface T4Params {
  active:            boolean; // false when T4 not in triggerTypes
  aiChurnMinFlips:   number;
  aiChurnMaxGapDays: number;
  aiChurnWindowDays: number; // resolved (defaults to windowDays)
}

function parseT4Params(
  sp: URLSearchParams,
  triggerTypesFilter: Set<TriggerTypeToken> | null,
  windowDays: number,
): { t4: T4Params } | { error: string } {
  const t4Active = triggerTypesFilter === null
    ? false // T4 is opt-in; only active when explicitly requested
    : triggerTypesFilter.has("T4");

  if (!t4Active) {
    // T4 not requested — parse nothing, return inactive sentinel
    return {
      t4: {
        active:            false,
        aiChurnMinFlips:   0,
        aiChurnMaxGapDays: AI_CHURN_MAX_GAP_DAYS_DEFAULT,
        aiChurnWindowDays: windowDays,
      },
    };
  }

  // T4 is active — aiChurnMinFlips is required
  const rawMinFlips = sp.get("aiChurnMinFlips");
  if (rawMinFlips === null) {
    return { error: "aiChurnMinFlips is required when triggerTypes includes T4" };
  }
  if (!/^\d+$/.test(rawMinFlips)) {
    return { error: "aiChurnMinFlips must be an integer" };
  }
  const minFlips = parseInt(rawMinFlips, 10);
  if (minFlips < AI_CHURN_MIN_FLIPS_MIN) {
    return { error: `aiChurnMinFlips must be >= ${AI_CHURN_MIN_FLIPS_MIN}` };
  }
  if (minFlips > AI_CHURN_MIN_FLIPS_MAX) {
    return { error: `aiChurnMinFlips must be <= ${AI_CHURN_MIN_FLIPS_MAX}` };
  }

  const rawMaxGap = sp.get("aiChurnMaxGapDays");
  let maxGapDays = AI_CHURN_MAX_GAP_DAYS_DEFAULT;
  if (rawMaxGap !== null) {
    if (!/^\d+$/.test(rawMaxGap)) return { error: "aiChurnMaxGapDays must be an integer" };
    maxGapDays = parseInt(rawMaxGap, 10);
    if (maxGapDays < AI_CHURN_MAX_GAP_DAYS_MIN) return { error: `aiChurnMaxGapDays must be >= ${AI_CHURN_MAX_GAP_DAYS_MIN}` };
    if (maxGapDays > AI_CHURN_MAX_GAP_DAYS_MAX) return { error: `aiChurnMaxGapDays must be <= ${AI_CHURN_MAX_GAP_DAYS_MAX}` };
  }

  const rawChurnWin = sp.get("aiChurnWindowDays");
  let churnWindowDays = windowDays; // default = outer windowDays
  if (rawChurnWin !== null) {
    if (!/^\d+$/.test(rawChurnWin)) return { error: "aiChurnWindowDays must be an integer" };
    churnWindowDays = parseInt(rawChurnWin, 10);
    if (churnWindowDays < WINDOW_DAYS_MIN) return { error: `aiChurnWindowDays must be >= ${WINDOW_DAYS_MIN}` };
    if (churnWindowDays > WINDOW_DAYS_MAX) return { error: `aiChurnWindowDays must be <= ${WINDOW_DAYS_MAX}` };
  }

  return {
    t4: {
      active:            true,
      aiChurnMinFlips:   minFlips,
      aiChurnMaxGapDays: maxGapDays,
      aiChurnWindowDays: churnWindowDays,
    },
  };
}

// =============================================================================
// T4 cluster detection — pure function, no DB calls.
//
// Iterates snaps (already sorted capturedAt ASC, id ASC) within aiChurnStart.
// Collects flip events, then finds the tightest qualifying cluster using a
// sliding window of aiChurnMinFlips flips.
//
// Cluster selection: among all qualifying windows (length >= minFlips, span <=
// maxGapMs), prefer the sequence ending latest; tie-break: shortest duration.
// Returns null when no qualifying cluster exists.
// =============================================================================

interface T4ClusterResult {
  flipCount:          number;
  clusterFirstFlipMs: number;
  clusterLastFlipMs:  number;
  clusterDurationMs:  number;
  lastFlipToSnapshotId: string;
}

function detectT4Cluster(
  snaps:          Array<{ id: string; capturedAt: Date; aiOverviewStatus: string | null }>,
  aiChurnStartMs: number,
  minFlips:       number,
  maxGapMs:       number,
): T4ClusterResult | null {
  // Collect flip events within churn window (pairs where toCapturedAt >= aiChurnStartMs)
  interface FlipEvent {
    toCapturedAtMs: number;
    toSnapshotId:   string;
  }
  const flips: FlipEvent[] = [];

  for (let i = 0; i < snaps.length - 1; i++) {
    const A = snaps[i];
    const B = snaps[i + 1];
    const toMs = B.capturedAt.getTime();
    if (toMs < aiChurnStartMs) continue; // pair outside churn window
    if (A.aiOverviewStatus !== B.aiOverviewStatus) {
      flips.push({ toCapturedAtMs: toMs, toSnapshotId: B.id });
    }
  }

  if (flips.length < minFlips) return null;

  // Sliding window: find all qualifying sub-sequences of length >= minFlips
  // within maxGapMs. For determinism, choose:
  //   1. Latest clusterLastFlipMs
  //   2. Tie: shortest duration
  // We check every window of exactly minFlips consecutive flips, then
  // expand rightward to include additional flips still within maxGapMs.

  let bestResult: T4ClusterResult | null = null;

  for (let i = 0; i <= flips.length - minFlips; i++) {
    const windowStart = flips[i].toCapturedAtMs;
    // Find rightmost flip within maxGapMs from windowStart
    let j = i + minFlips - 1; // minimum right index
    // Expand right while next flip is still within maxGapMs
    while (j + 1 < flips.length && flips[j + 1].toCapturedAtMs - windowStart <= maxGapMs) {
      j++;
    }
    const span = flips[j].toCapturedAtMs - windowStart;
    if (span > maxGapMs) continue; // minimum window itself exceeds gap (shouldn't happen but guard)

    const candidate: T4ClusterResult = {
      flipCount:            j - i + 1,
      clusterFirstFlipMs:   windowStart,
      clusterLastFlipMs:    flips[j].toCapturedAtMs,
      clusterDurationMs:    span,
      lastFlipToSnapshotId: flips[j].toSnapshotId,
    };

    if (bestResult === null) {
      bestResult = candidate;
    } else {
      // Prefer later last flip
      if (candidate.clusterLastFlipMs > bestResult.clusterLastFlipMs) {
        bestResult = candidate;
      } else if (candidate.clusterLastFlipMs === bestResult.clusterLastFlipMs) {
        // Tie: prefer shorter duration
        if (candidate.clusterDurationMs < bestResult.clusterDurationMs) {
          bestResult = candidate;
        }
      }
    }
  }

  return bestResult;
}

// =============================================================================
// B2 concentration ratio helper — reused for both current and prior windows
// =============================================================================

function computeConcentrationRatio(
  snapshots: Array<SnapshotForVolatility & { capturedAt: Date; query: string; locale: string; device: string }>,
  targets: Array<{ id: string; query: string; locale: string; device: string }>
): number | null {
  // Group snapshots by natural key
  const map = new Map<string, Array<SnapshotForVolatility & { capturedAt: Date }>>();
  for (const snap of snapshots) {
    const key = `${snap.query}\0${snap.locale}\0${snap.device}`;
    let bucket = map.get(key);
    if (!bucket) { bucket = []; map.set(key, bucket); }
    bucket.push(snap);
  }

  let totalVolatilitySum = 0;
  const activeRecords: Array<{ keywordTargetId: string; query: string; volatilityScore: number }> = [];

  for (const target of targets) {
    const key   = `${target.query}\0${target.locale}\0${target.device}`;
    const snaps = map.get(key) ?? [];
    const profile = computeVolatility(snaps);
    if (profile.sampleSize >= 1) {
      totalVolatilitySum += profile.volatilityScore;
      activeRecords.push({
        keywordTargetId: target.id,
        query:           target.query,
        volatilityScore: profile.volatilityScore,
      });
    }
  }

  if (totalVolatilitySum === 0) return null;

  activeRecords.sort((a, b) => {
    if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
    const qCmp = a.query.localeCompare(b.query);
    if (qCmp !== 0) return qCmp;
    return a.keywordTargetId.localeCompare(b.keywordTargetId);
  });

  const top3    = activeRecords.slice(0, 3);
  const top3Sum = top3.reduce((acc, r) => acc + r.volatilityScore, 0);
  return Math.round((top3Sum / totalVolatilitySum) * 10000) / 10000;
}

// =============================================================================
// GET /api/seo/alerts
// =============================================================================

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const sp = new URL(request.url).searchParams;

    // -- Parse all params before any DB work ----------------------------------
    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    const spikeResult = parseSpikeThreshold(sp);
    if ("error" in spikeResult) return badRequest(spikeResult.error);
    const spikeThreshold = spikeResult.spikeThreshold;

    const concResult = parseConcentrationThreshold(sp);
    if ("error" in concResult) return badRequest(concResult.error);
    const concentrationThreshold = concResult.concentrationThreshold;

    const limitResult = parseLimit(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limit = limitResult.limit;

    const ttResult = parseTriggerTypes(sp);
    if ("error" in ttResult) return badRequest(ttResult.error);
    const triggerTypesFilter = ttResult.triggerTypes;

    const ktIdResult = parseKeywordTargetId(sp);
    if ("error" in ktIdResult) return badRequest(ktIdResult.error);
    const keywordTargetIdFilter = ktIdResult.keywordTargetId;

    const minSevResult = parseMinSeverityRank(sp);
    if ("error" in minSevResult) return badRequest(minSevResult.error);
    const minSeverityRank = minSevResult.minSeverityRank;

    const minPvsResult = parseMinPairVolatilityScore(sp);
    if ("error" in minPvsResult) return badRequest(minPvsResult.error);
    const minPairVolatilityScore = minPvsResult.minPairVolatilityScore;

    const cursorResult = parseCursor(sp);
    if ("error" in cursorResult) return badRequest(cursorResult.error);
    const cursorPayload = cursorResult.cursor;

    // Suppression params (suppressionMode must be parsed first — others depend on it)
    const supModeResult = parseSuppressionMode(sp);
    if ("error" in supModeResult) return badRequest(supModeResult.error);
    const suppressionMode = supModeResult.suppressionMode;

    const t1Result = parseT1Mode(sp, suppressionMode);
    if ("error" in t1Result) return badRequest(t1Result.error);
    const t1Mode = t1Result.t1Mode;

    const t2Result = parseT2Mode(sp, suppressionMode);
    if ("error" in t2Result) return badRequest(t2Result.error);
    const t2Mode = t2Result.t2Mode;

    const t3Result = parseT3Mode(sp);
    if ("error" in t3Result) return badRequest(t3Result.error);
    const t3Mode = t3Result.t3Mode;

    const suppressionOpts: SuppressionOpts = { suppressionMode, t1Mode, t2Mode, t3Mode };

    // T4 params — parsed after triggerTypes + windowDays are resolved
    const t4Result = parseT4Params(sp, triggerTypesFilter, windowDays);
    if ("error" in t4Result) return badRequest(t4Result.error);
    const t4Params = t4Result.t4;

    // Single requestTime anchor — all window boundaries derived here.
    const requestTime  = new Date();
    const windowStart  = new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000);
    // Prior window for t3Mode=deltaOnly (same length, immediately preceding current window)
    const priorWindowStart = new Date(windowStart.getTime() - windowDays * 24 * 60 * 60 * 1000);

    // ── Query 1: KeywordTargets ───────────────────────────────────────────────
    const targets = await prisma.keywordTarget.findMany({
      where:   { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select:  { id: true, query: true, locale: true, device: true },
    });

    // ── Query 2: SERPSnapshots ────────────────────────────────────────────────
    // When t3Mode=deltaOnly, we need prior-window snapshots for the delta check.
    // Expand the query to cover priorWindowStart so we can partition in-memory.
    // This adds no extra DB queries — one query, one partition.
    const snapshotQueryStart = t3Mode === "deltaOnly" ? priorWindowStart : windowStart;

    const allSnapshotsRaw = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        capturedAt: { gte: snapshotQueryStart },
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id:               true,
        query:            true,
        locale:           true,
        device:           true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    // Partition: current window vs prior window (for deltaOnly)
    type SnapRowFull = SnapshotForVolatility & { capturedAt: Date; query: string; locale: string; device: string };

    const currentWindowSnaps: SnapRowFull[] = [];
    const priorWindowSnaps:   SnapRowFull[] = [];

    for (const snap of allSnapshotsRaw) {
      const row: SnapRowFull = {
        id:               snap.id,
        capturedAt:       snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload:       snap.rawPayload,
        query:            snap.query,
        locale:           snap.locale,
        device:           snap.device,
      };
      const ms = snap.capturedAt.getTime();
      if (ms >= windowStart.getTime()) {
        currentWindowSnaps.push(row);
      } else if (t3Mode === "deltaOnly" && ms >= priorWindowStart.getTime()) {
        priorWindowSnaps.push(row);
      }
    }

    // Group current-window snapshots by natural key (for alert generation)
    type SnapRow = SnapshotForVolatility & { capturedAt: Date };
    const snapshotMap = new Map<string, SnapRow[]>();
    let latestCapturedAtMs = 0;

    for (const snap of currentWindowSnaps) {
      const key = `${snap.query}\0${snap.locale}\0${snap.device}`;
      let bucket = snapshotMap.get(key);
      if (!bucket) { bucket = []; snapshotMap.set(key, bucket); }
      bucket.push({
        id:               snap.id,
        capturedAt:       snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload:       snap.rawPayload,
      });
      const ms = snap.capturedAt.getTime();
      if (ms > latestCapturedAtMs) latestCapturedAtMs = ms;
    }

    // ── Collect all candidate alerts ──────────────────────────────────────────
    const allAlerts: AnyAlert[] = [];
    const t2DedupSet = new Set<string>();

    let activeKeywordCount = 0;
    let totalVolatilitySum = 0;
    interface ActiveRecord {
      keywordTargetId: string;
      query:           string;
      volatilityScore: number;
    }
    const activeRecords: ActiveRecord[] = [];

    for (const target of targets) {
      const key   = `${target.query}\0${target.locale}\0${target.device}`;
      const snaps = snapshotMap.get(key) ?? [];

      if (snaps.length < 2) continue;

      interface PairRecord {
        fromSnapshotId:      string;
        toSnapshotId:        string;
        fromCapturedAt:      Date;
        toCapturedAt:        Date;
        pairVolatilityScore: number;
        regime:              VolatilityRegime;
      }

      const pairs: PairRecord[] = [];
      for (let i = 0; i < snaps.length - 1; i++) {
        const A = snaps[i];
        const B = snaps[i + 1];
        const profile = computeVolatility([A, B]);
        pairs.push({
          fromSnapshotId:      A.id,
          toSnapshotId:        B.id,
          fromCapturedAt:      A.capturedAt,
          toCapturedAt:        B.capturedAt,
          pairVolatilityScore: profile.volatilityScore,
          regime:              classifyRegime(profile.volatilityScore),
        });
      }

      const fullProfile = computeVolatility(snaps);
      if (fullProfile.sampleSize >= 1) {
        activeKeywordCount++;
        totalVolatilitySum += fullProfile.volatilityScore;
        activeRecords.push({
          keywordTargetId: target.id,
          query:           target.query,
          volatilityScore: fullProfile.volatilityScore,
        });
      }

      // T1
      if (pairs.length >= 2) {
        const lastPair = pairs[pairs.length - 1];
        const prevPair = pairs[pairs.length - 2];
        if (lastPair.regime !== prevPair.regime) {
          const fromRegime = prevPair.regime;
          const toRegime   = lastPair.regime;
          allAlerts.push({
            triggerType:         "T1",
            keywordTargetId:     target.id,
            query:               target.query,
            fromRegime,
            toRegime,
            fromSnapshotId:      lastPair.fromSnapshotId,
            toSnapshotId:        lastPair.toSnapshotId,
            fromCapturedAt:      lastPair.fromCapturedAt.toISOString(),
            toCapturedAt:        lastPair.toCapturedAt.toISOString(),
            pairVolatilityScore: lastPair.pairVolatilityScore,
            _severityRank:       computeT1SeverityRank(
                                   fromRegime,
                                   toRegime,
                                   lastPair.pairVolatilityScore,
                                   prevPair.pairVolatilityScore,
                                 ),
            _toCapturedAtMs:     lastPair.toCapturedAt.getTime(),
            _toSnapshotId:       lastPair.toSnapshotId,
            _keywordTargetId:    target.id,
          });
        }
      }

      // T2
      for (const pair of pairs) {
        if (pair.pairVolatilityScore > spikeThreshold) {
          const dedupKey = `${target.id}\0${pair.toSnapshotId}\0${spikeThreshold}`;
          if (!t2DedupSet.has(dedupKey)) {
            t2DedupSet.add(dedupKey);
            const exceedanceMargin = Math.round((pair.pairVolatilityScore - spikeThreshold) * 100) / 100;
            allAlerts.push({
              triggerType:         "T2",
              keywordTargetId:     target.id,
              query:               target.query,
              fromSnapshotId:      pair.fromSnapshotId,
              toSnapshotId:        pair.toSnapshotId,
              fromCapturedAt:      pair.fromCapturedAt.toISOString(),
              toCapturedAt:        pair.toCapturedAt.toISOString(),
              pairVolatilityScore: pair.pairVolatilityScore,
              threshold:           spikeThreshold,
              exceedanceMargin,
              _severityRank:       computeT2SeverityRank(pair.pairVolatilityScore, spikeThreshold),
              _toCapturedAtMs:     pair.toCapturedAt.getTime(),
              _toSnapshotId:       pair.toSnapshotId,
              _keywordTargetId:    target.id,
            });
          }
        }
      }
    }

    // T3
    if (totalVolatilitySum > 0) {
      activeRecords.sort((a, b) => {
        if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
        const qCmp = a.query.localeCompare(b.query);
        if (qCmp !== 0) return qCmp;
        return a.keywordTargetId.localeCompare(b.keywordTargetId);
      });
      const top3    = activeRecords.slice(0, 3);
      const top3Sum = top3.reduce((acc, r) => acc + r.volatilityScore, 0);
      const volatilityConcentrationRatio = Math.round((top3Sum / totalVolatilitySum) * 10000) / 10000;

      if (volatilityConcentrationRatio > concentrationThreshold) {
        allAlerts.push({
          triggerType:                  "T3",
          projectId,
          volatilityConcentrationRatio,
          threshold:                    concentrationThreshold,
          top3RiskKeywords:             top3.map((r) => ({
            keywordTargetId:  r.keywordTargetId,
            query:            r.query,
            volatilityScore:  r.volatilityScore,
            volatilityRegime: classifyRegime(r.volatilityScore),
          })),
          activeKeywordCount,
          _severityRank:                computeT3SeverityRank(volatilityConcentrationRatio, concentrationThreshold),
          _toCapturedAtMs:              latestCapturedAtMs,
          _toSnapshotId:                null,
          _keywordTargetId:             null,
        });
      }
    }

    // T4 — AI Churn Cluster (opt-in, per-keyword)
    if (t4Params.active) {
      const aiChurnStartMs = requestTime.getTime() - t4Params.aiChurnWindowDays * MS_PER_DAY;
      const maxGapMs       = t4Params.aiChurnMaxGapDays * MS_PER_DAY;

      for (const target of targets) {
        const key   = `${target.query}\0${target.locale}\0${target.device}`;
        const snaps = snapshotMap.get(key) ?? [];
        if (snaps.length < 2) continue;

        const cluster = detectT4Cluster(
          snaps,
          aiChurnStartMs,
          t4Params.aiChurnMinFlips,
          maxGapMs,
        );
        if (cluster === null) continue;

        const clusterDurationDays =
          Math.round((cluster.clusterDurationMs / MS_PER_DAY) * 100) / 100;

        allAlerts.push({
          triggerType:         "T4",
          keywordTargetId:     target.id,
          query:               target.query,
          flipCount:           cluster.flipCount,
          clusterFirstFlipAt:  new Date(cluster.clusterFirstFlipMs).toISOString(),
          clusterLastFlipAt:   new Date(cluster.clusterLastFlipMs).toISOString(),
          clusterDurationDays,
          aiChurnMinFlips:     t4Params.aiChurnMinFlips,
          aiChurnMaxGapDays:   t4Params.aiChurnMaxGapDays,
          aiChurnWindowDays:   t4Params.aiChurnWindowDays,
          _severityRank:       computeT4SeverityRank(
                                 cluster.flipCount,
                                 t4Params.aiChurnMinFlips,
                                 cluster.clusterDurationMs,
                                 t4Params.aiChurnMaxGapDays,
                               ),
          _toCapturedAtMs:     cluster.clusterLastFlipMs,
          _toSnapshotId:       cluster.lastFlipToSnapshotId,
          _keywordTargetId:    target.id,
        });
      }
    }

    // ── Sort deterministically ────────────────────────────────────────────────
    allAlerts.sort(compareAlerts);

    // ── Apply filters ─────────────────────────────────────────────────────────
    const filtered = allAlerts.filter((alert) => {
      if (triggerTypesFilter !== null && !triggerTypesFilter.has(alert.triggerType)) return false;
      if (keywordTargetIdFilter !== null && alert._keywordTargetId !== keywordTargetIdFilter) return false;
      if (minSeverityRank !== null && alert._severityRank < minSeverityRank) return false;
      if (minPairVolatilityScore !== null && alert.triggerType === "T2") {
        if ((alert as T2Alert).pairVolatilityScore < minPairVolatilityScore) return false;
      }
      return true;
    });

    // ── Compute prior-window concentration ratio for t3Mode=deltaOnly ─────────
    // This is computed in the data-loading phase (not inside suppressAlerts).
    let priorWindowConcentrationRatio: number | null = null;
    if (t3Mode === "deltaOnly" && priorWindowSnaps.length >= 2) {
      priorWindowConcentrationRatio = computeConcentrationRatio(priorWindowSnaps, targets);
    }

    // ── Apply suppression (post-filter, pre-cursor) ───────────────────────────
    // Suppression is a pure function that preserves relative sort order.
    const suppressed = suppressAlerts(filtered, {
      opts: suppressionOpts,
      priorWindowConcentrationRatio,
    });

    // ── Apply cursor ──────────────────────────────────────────────────────────
    let startIndex = 0;
    if (cursorPayload !== null) {
      let found = false;
      for (let i = 0; i < suppressed.length; i++) {
        if (isAfterCursor(suppressed[i], cursorPayload)) {
          startIndex = i;
          found = true;
          break;
        }
      }
      if (!found) startIndex = suppressed.length;
    }

    // ── Slice page ────────────────────────────────────────────────────────────
    const page    = suppressed.slice(startIndex, startIndex + limit);
    const hasMore = startIndex + limit < suppressed.length;

    const nextCursor: string | null = hasMore && page.length > 0
      ? encodeCursor(page[page.length - 1])
      : null;

    const emitted = page.map(stripSortFields);

    return successResponse({
      alerts:                emitted,
      alertCount:            emitted.length,
      totalAlerts:           suppressed.length,
      nextCursor,
      hasMore,
      windowDays,
      spikeThreshold,
      concentrationThreshold,
      suppressionMode,
      t1Mode,
      t2Mode,
      t3Mode,
      ...(t4Params.active ? {
        aiChurnMinFlips:   t4Params.aiChurnMinFlips,
        aiChurnMaxGapDays: t4Params.aiChurnMaxGapDays,
        aiChurnWindowDays: t4Params.aiChurnWindowDays,
      } : {}),
      limit,
      computedAt:            requestTime.toISOString(),
    });
  } catch (err) {
    console.error("GET /api/seo/alerts error:", err);
    return serverError();
  }
}
