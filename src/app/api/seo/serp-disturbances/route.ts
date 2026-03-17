/**
 * GET /api/seo/serp-disturbances -- SIL-16 through SIL-24:
 * SERP Disturbance Detection, Event Attribution, Weather, Forecasting,
 * Forecast Momentum Enrichment, Weather Alerts, Alert Briefing Packets,
 * Keyword Impact Ranking, Alert-Affected Keyword Set, and Operator Action Hints.
 *
 * Read-only compute-on-read observatory surface.
 *
 * Route Layer Gating:
 *   Optional `include` query param controls which layers are computed/returned.
 *   Supported values: disturbance, attribution, weather, forecast, alerts,
 *                     briefing, impact, affected, hints
 *   Default (omitted): all layers computed and returned.
 *   Dependencies auto-resolve:
 *     hints    → affected → impact → briefing → alerts → forecast
 *              → weather → attribution → disturbance
 *
 * No writes. No EventLog. No mutations. No materialized tables.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project -> 400.
 * Determinism: all computation is deterministic for any given snapshot set.
 *
 * Query params (zod.strict -- unknown params -> 400):
 *   windowDays  int 1-365, default 60  -- snapshot lookback window
 *   include     optional string         -- comma-separated layer list
 */

import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeSerpDisturbances,
  type SnapshotSet,
} from "@/lib/seo/serp-disturbance";
import { computeSerpObservatory } from "@/lib/seo/serp-observatory";
import {
  computeSerpEventAttribution,
  type KeywordSignalSet,
} from "@/lib/seo/serp-event-attribution";
import { computeSerpWeather } from "@/lib/seo/serp-weather";
import { computeSerpWeatherForecast } from "@/lib/seo/serp-weather-forecast";
import { computeSerpWeatherAlerts } from "@/lib/seo/serp-weather-alerts";
import { computeSerpAlertBriefing } from "@/lib/seo/serp-alert-briefing";
import {
  computeSerpKeywordImpactRanking,
  selectAlertAffectedKeywords,
  type KeywordImpactInput,
} from "@/lib/seo/serp-keyword-impact";
import { computeSerpOperatorActionHints } from "@/lib/seo/serp-operator-hints";
import { computeVolatility } from "@/lib/seo/volatility-service";
import { computeIntentDrift } from "@/lib/seo/intent-drift";
import { computeDomainDominance } from "@/lib/seo/domain-dominance";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";

// -----------------------------------------------------------------------------
// Query param validation -- .strict() rejects unknown params
// -----------------------------------------------------------------------------

const VALID_LAYERS = new Set([
  "disturbance", "attribution", "weather", "forecast", "alerts",
  "briefing", "impact", "affected", "hints",
]);

const QuerySchema = z
  .object({
    windowDays: z.coerce.number().int().min(1).max(365).default(60),
    include: z.string().optional(),
  })
  .strict();

// -----------------------------------------------------------------------------
// Layer dependency resolution
// -----------------------------------------------------------------------------

/**
 * Parse and validate the `include` param into a set of requested layers.
 * Returns null if include is not provided (= compute all).
 * Returns a Set of valid layer names with dependencies auto-resolved.
 * Throws a string error message if invalid values are found.
 */
function resolveIncludeLayers(includeParam: string | undefined): Set<string> | null {
  if (includeParam === undefined || includeParam === "") return null;

  const requested = new Set(includeParam.split(",").map((s) => s.trim()).filter(Boolean));
  const invalid = Array.from(requested).filter((v) => !VALID_LAYERS.has(v));
  if (invalid.length > 0) {
    throw `Unknown include values: ${invalid.join(", ")}. Valid: ${Array.from(VALID_LAYERS).join(", ")}`;
  }

  // Auto-resolve dependencies (higher layers require lower layers)
  const resolved = new Set(requested);
  if (resolved.has("hints"))    { resolved.add("affected"); }
  if (resolved.has("affected")) { resolved.add("impact"); }
  if (resolved.has("impact"))   { resolved.add("briefing"); }
  if (resolved.has("briefing")) { resolved.add("alerts"); resolved.add("forecast"); resolved.add("weather"); resolved.add("attribution"); resolved.add("disturbance"); }
  if (resolved.has("alerts"))   { resolved.add("forecast"); resolved.add("weather"); resolved.add("attribution"); resolved.add("disturbance"); }
  if (resolved.has("forecast")) { resolved.add("weather"); resolved.add("attribution"); resolved.add("disturbance"); }
  if (resolved.has("weather"))  { resolved.add("attribution"); resolved.add("disturbance"); }
  if (resolved.has("attribution")) { resolved.add("disturbance"); }

  return resolved;
}

// -----------------------------------------------------------------------------
// Per-keyword signal helpers
// -----------------------------------------------------------------------------

/**
 * Returns true when the top domain's dominanceIndex changed by >= 0.20
 * between the first and last snapshot for this keyword.
 */
function keywordHasDominanceShift(
  snapshots: { rawPayload: unknown }[]
): boolean {
  if (snapshots.length < 2) return false;
  const first = computeDomainDominance(snapshots[0].rawPayload);
  const last  = computeDomainDominance(snapshots[snapshots.length - 1].rawPayload);
  if (first.dominanceIndex === null || last.dominanceIndex === null) return false;
  return Math.abs(last.dominanceIndex - first.dominanceIndex) >= 0.20;
}

// -----------------------------------------------------------------------------
// GET handler
// -----------------------------------------------------------------------------

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    // ── Validate query params ─────────────────────────────────────────────
    const rawParams = Object.fromEntries(
      new URL(request.url).searchParams.entries()
    );
    const parsed = QuerySchema.safeParse(rawParams);
    if (!parsed.success) {
      const msgs = parsed.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }

    const { windowDays } = parsed.data;

    // ── Parse include parameter ───────────────────────────────────────────
    let layers: Set<string> | null;
    try {
      layers = resolveIncludeLayers(parsed.data.include);
    } catch (msg) {
      return badRequest(msg as string);
    }

    // When layers is null, all layers are requested
    const needDisturbance  = layers === null || layers.has("disturbance");
    const needAttribution  = layers === null || layers.has("attribution");
    const needWeather      = layers === null || layers.has("weather");
    const needForecast     = layers === null || layers.has("forecast");
    const needAlerts       = layers === null || layers.has("alerts");
    const needBriefing     = layers === null || layers.has("briefing");
    const needImpact       = layers === null || layers.has("impact");
    const needAffected     = layers === null || layers.has("affected");
    const needHints        = layers === null || layers.has("hints");

    // ── Load keyword targets (project-scoped, deterministic order) ────────
    const targets = await prisma.keywordTarget.findMany({
      where: { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select: { id: true, query: true, locale: true, device: true },
    });

    // No targets -- return zero-signal result
    if (targets.length === 0) {
      const zeroDisturbance = {
        volatilityCluster: false,
        featureShiftDetected: false,
        dominantNewFeatures: [],
        rankingTurbulence: false,
        affectedKeywordCount: 0,
      };
      const zeroAttribution = {
        cause: "unknown",
        confidence: 0,
        supportingSignals: [],
      };
      const zeroWeather = {
        state: "calm",
        driver: "unknown",
        confidence: 0,
        stability: "high",
        featureClimate: "stable_features",
        summary: "Calm SERP climate with no significant disturbance signals.",
      };
      const zeroForecast = {
        trend: "stable",
        expectedState: "calm",
        confidence: 0,
        driverMomentum: "unknown",
        momentum: "stable",
        forecastSummary: "SERP climate stable with no significant disturbance signals.",
      };
      const zeroBriefing = {
        primaryAlert: null,
        weatherState: "calm",
        forecastTrend: "stable",
        momentum: "stable",
        driver: "unknown",
        affectedKeywords: 0,
        supportingSignals: [],
        summary: "Calm SERP conditions with no significant disturbance.",
      };

      const result: Record<string, unknown> = {};
      if (needDisturbance) Object.assign(result, zeroDisturbance);
      if (needAttribution) result.eventAttribution = zeroAttribution;
      if (needWeather)     result.weather = zeroWeather;
      if (needForecast)    result.forecast = zeroForecast;
      if (needAlerts)      result.alerts = [];
      if (needBriefing)    result.briefing = zeroBriefing;
      if (needImpact)      result.keywordImpactRanking = [];
      if (needAffected)    result.alertAffectedKeywords = [];
      if (needHints)       result.operatorActionHints = [];
      return successResponse(result);
    }

    // ── Load snapshots within window (project-scoped, deterministic order) -
    const windowStart = new Date(
      Date.now() - windowDays * 24 * 60 * 60 * 1000
    );

    const allSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        capturedAt: { gte: windowStart },
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id: true,
        query: true,
        locale: true,
        device: true,
        capturedAt: true,
        aiOverviewStatus: true,
        rawPayload: true,
      },
    });

    // ── Group snapshots by natural key ────────────────────────────────────
    type SnapRow = {
      id: string;
      capturedAt: Date;
      aiOverviewStatus: string;
      rawPayload: unknown;
    };
    const snapshotMap = new Map<string, SnapRow[]>();
    for (const snap of allSnapshots) {
      const key = `${snap.query}\0${snap.locale}\0${snap.device}`;
      let bucket = snapshotMap.get(key);
      if (!bucket) {
        bucket = [];
        snapshotMap.set(key, bucket);
      }
      bucket.push({
        id: snap.id,
        capturedAt: snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload: snap.rawPayload,
      });
    }

    // ── Build SnapshotSet[] for disturbance computation ───────────────────
    const keywordSnapshots: SnapshotSet[] = targets.map((target) => {
      const key = `${target.query}\0${target.locale}\0${target.device}`;
      return {
        keywordTargetId: target.id,
        snapshots: snapshotMap.get(key) ?? [],
      };
    });

    // ── SIL-16: Compute disturbances (full window) ────────────────────────
    const disturbance = computeSerpDisturbances(keywordSnapshots);

    // ── SIL-19B: Window bisection for momentum ───────────────────────────
    let firstHalfDisturbance = disturbance;
    let secondHalfDisturbance = disturbance;

    if (needForecast || needAlerts || needBriefing || needImpact || needAffected || needHints) {
      const firstHalfSnapshots: SnapshotSet[] = keywordSnapshots.map(({ keywordTargetId, snapshots }) => {
        const mid = Math.floor(snapshots.length / 2);
        return { keywordTargetId, snapshots: snapshots.slice(0, mid) };
      });
      const secondHalfSnapshots: SnapshotSet[] = keywordSnapshots.map(({ keywordTargetId, snapshots }) => {
        const mid = Math.floor(snapshots.length / 2);
        return { keywordTargetId, snapshots: snapshots.slice(mid) };
      });

      firstHalfDisturbance = computeSerpDisturbances(firstHalfSnapshots);
      secondHalfDisturbance = computeSerpDisturbances(secondHalfSnapshots);
    }

    // ── Build response based on requested layers ──────────────────────────
    const result: Record<string, unknown> = {};

    if (needDisturbance) {
      Object.assign(result, disturbance);
    }

    let eventAttribution;
    if (needAttribution) {
      const observatory = computeSerpObservatory(snapshotMap);

      // ── Per-keyword signal computation (shared by attribution + impact) ──
      const keywordSignals: KeywordSignalSet[] = [];
      const impactInputs: KeywordImpactInput[] = [];

      for (const { keywordTargetId, snapshots } of keywordSnapshots) {
        if (snapshots.length < 1) continue;

        const target = targets.find((t) => t.id === keywordTargetId);
        if (!target) continue;

        // Intent drift (for attribution)
        const driftInput = snapshots.map((s) => ({
          snapshotId: s.id,
          capturedAt: s.capturedAt,
          signals: extractFeatureSignals(s.rawPayload),
        }));
        const drift = computeIntentDrift(driftInput);
        const hasIntentDrift = drift.transitions.length > 0;
        const hasDominanceShift = keywordHasDominanceShift(snapshots);

        keywordSignals.push({ keywordTargetId, hasIntentDrift, hasDominanceShift });

        // Volatility profile (for impact ranking)
        if (needImpact || needAffected || needHints) {
          const profile = computeVolatility(snapshots);
          impactInputs.push({
            keywordTargetId,
            query: target.query,
            volatilityScore: profile.volatilityScore,
            averageRankShift: profile.averageRankShift,
            aiOverviewChurn: profile.aiOverviewChurn,
            featureVolatility: profile.featureVolatility,
            hasIntentDrift,
            hasDominanceShift,
          });
        }
      }

      eventAttribution = computeSerpEventAttribution(
        disturbance,
        observatory,
        keywordSignals
      );
      result.eventAttribution = eventAttribution;

      if (needWeather) {
        const weather = computeSerpWeather(observatory, disturbance, eventAttribution);
        result.weather = weather;

        if (needForecast || needAlerts || needBriefing || needImpact || needAffected || needHints) {
          const forecast = computeSerpWeatherForecast(
            weather,
            disturbance,
            eventAttribution,
            keywordSignals,
            firstHalfDisturbance,
            secondHalfDisturbance,
          );
          if (needForecast) result.forecast = forecast;

          if (needAlerts || needBriefing || needImpact || needAffected || needHints) {
            const alerts = computeSerpWeatherAlerts(
              disturbance,
              eventAttribution,
              weather,
              forecast,
            );
            if (needAlerts) result.alerts = alerts;

            if (needBriefing || needImpact || needAffected || needHints) {
              const briefing = computeSerpAlertBriefing(
                disturbance,
                eventAttribution,
                weather,
                forecast,
                alerts,
                disturbance.affectedKeywordCount,
              );
              if (needBriefing) result.briefing = briefing;

              // ── SIL-22: Keyword Impact Ranking ──────────────────────────
              if (needImpact || needAffected || needHints) {
                const impactRanking = computeSerpKeywordImpactRanking(
                  impactInputs,
                  eventAttribution,
                );
                if (needImpact) result.keywordImpactRanking = impactRanking;

                // ── SIL-23: Alert-Affected Keyword Set ──────────────────
                if (needAffected || needHints) {
                  const affectedKeywords = selectAlertAffectedKeywords(
                    impactRanking,
                    alerts,
                    eventAttribution,
                  );
                  if (needAffected) result.alertAffectedKeywords = affectedKeywords;

                  // ── SIL-24: Operator Action Hints ─────────────────────
                  if (needHints) {
                    const hints = computeSerpOperatorActionHints(
                      disturbance,
                      eventAttribution,
                      weather,
                      forecast,
                      alerts,
                      affectedKeywords,
                    );
                    result.operatorActionHints = hints;
                  }
                }
              }
            }
          }
        }
      }
    }

    return successResponse(result);
  } catch (err) {
    console.error("GET /api/seo/serp-disturbances error:", err);
    return serverError();
  }
}
