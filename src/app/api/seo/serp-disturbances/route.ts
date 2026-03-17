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
import {
  SerpDisturbanceQuerySchema,
  getSerpDisturbanceLayerFlags,
  resolveSerpDisturbanceLayers,
} from "@/lib/seo/serp-disturbance-query";
import {
  buildSerpDisturbanceMeta,
  buildSerpDisturbanceZeroState,
} from "@/lib/seo/serp-disturbance-response";

function keywordHasDominanceShift(
  snapshots: { rawPayload: unknown }[]
): boolean {
  if (snapshots.length < 2) return false;
  const first = computeDomainDominance(snapshots[0].rawPayload);
  const last = computeDomainDominance(snapshots[snapshots.length - 1].rawPayload);
  if (first.dominanceIndex === null || last.dominanceIndex === null) return false;
  return Math.abs(last.dominanceIndex - first.dominanceIndex) >= 0.2;
}

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const rawParams = Object.fromEntries(
      new URL(request.url).searchParams.entries()
    );
    const parsed = SerpDisturbanceQuerySchema.safeParse(rawParams);
    if (!parsed.success) {
      const msgs = parsed.error.issues
        .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
        .join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }

    const { windowDays } = parsed.data;

    let resolved;
    try {
      resolved = resolveSerpDisturbanceLayers(parsed.data.include);
    } catch (error) {
      return badRequest(
        error instanceof Error ? error.message : "Invalid include parameter"
      );
    }

    const {
      needDisturbance,
      needAttribution,
      needWeather,
      needForecast,
      needAlerts,
      needBriefing,
      needImpact,
      needAffected,
      needHints,
    } = getSerpDisturbanceLayerFlags(resolved.layerSet);

    const targets = await prisma.keywordTarget.findMany({
      where: { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select: { id: true, query: true, locale: true, device: true },
    });

    if (targets.length === 0) {
      const meta = buildSerpDisturbanceMeta({
        windowDays,
        requestedLayers: resolved.requestedLayers,
        resolvedLayers: resolved.resolvedLayers,
        keywordTargetCount: 0,
        snapshotCount: 0,
      });
      const result = buildSerpDisturbanceZeroState({
        includeDisturbance: needDisturbance,
        includeAttribution: needAttribution,
        includeWeather: needWeather,
        includeForecast: needForecast,
        includeAlerts: needAlerts,
        includeBriefing: needBriefing,
        includeImpact: needImpact,
        includeAffected: needAffected,
        includeHints: needHints,
      });
      return successResponse({ meta, ...result });
    }

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

    type SnapRow = {
      id: string;
      capturedAt: Date;
      aiOverviewStatus: string;
      rawPayload: unknown;
    };

    const snapshotMap = new Map<string, SnapRow[]>();
    for (const snap of allSnapshots) {
      const key = `${snap.query}\0${snap.locale}\0${snap.device}`;
      const bucket = snapshotMap.get(key) ?? [];
      bucket.push({
        id: snap.id,
        capturedAt: snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload: snap.rawPayload,
      });
      snapshotMap.set(key, bucket);
    }

    const keywordSnapshots: SnapshotSet[] = targets.map((target) => {
      const key = `${target.query}\0${target.locale}\0${target.device}`;
      return {
        keywordTargetId: target.id,
        snapshots: snapshotMap.get(key) ?? [],
      };
    });

    const disturbance = computeSerpDisturbances(keywordSnapshots);

    let firstHalfDisturbance = disturbance;
    let secondHalfDisturbance = disturbance;

    if (
      needForecast ||
      needAlerts ||
      needBriefing ||
      needImpact ||
      needAffected ||
      needHints
    ) {
      const firstHalfSnapshots: SnapshotSet[] = keywordSnapshots.map(
        ({ keywordTargetId, snapshots }) => {
          const mid = Math.floor(snapshots.length / 2);
          return { keywordTargetId, snapshots: snapshots.slice(0, mid) };
        }
      );
      const secondHalfSnapshots: SnapshotSet[] = keywordSnapshots.map(
        ({ keywordTargetId, snapshots }) => {
          const mid = Math.floor(snapshots.length / 2);
          return { keywordTargetId, snapshots: snapshots.slice(mid) };
        }
      );

      firstHalfDisturbance = computeSerpDisturbances(firstHalfSnapshots);
      secondHalfDisturbance = computeSerpDisturbances(secondHalfSnapshots);
    }

    const meta = buildSerpDisturbanceMeta({
      windowDays,
      requestedLayers: resolved.requestedLayers,
      resolvedLayers: resolved.resolvedLayers,
      keywordTargetCount: targets.length,
      snapshotCount: allSnapshots.length,
    });

    const result: Record<string, unknown> = { meta };

    if (needDisturbance) {
      Object.assign(result, disturbance);
    }

    if (needAttribution) {
      const observatory = computeSerpObservatory(snapshotMap);
      const keywordSignals: KeywordSignalSet[] = [];
      const impactInputs: KeywordImpactInput[] = [];

      for (const { keywordTargetId, snapshots } of keywordSnapshots) {
        if (snapshots.length < 1) continue;

        const target = targets.find((entry) => entry.id === keywordTargetId);
        if (!target) continue;

        const driftInput = snapshots.map((snapshot) => ({
          snapshotId: snapshot.id,
          capturedAt: snapshot.capturedAt,
          signals: extractFeatureSignals(snapshot.rawPayload),
        }));
        const drift = computeIntentDrift(driftInput);
        const hasIntentDrift = drift.transitions.length > 0;
        const hasDominanceShift = keywordHasDominanceShift(snapshots);

        keywordSignals.push({
          keywordTargetId,
          hasIntentDrift,
          hasDominanceShift,
        });

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

      const eventAttribution = computeSerpEventAttribution(
        disturbance,
        observatory,
        keywordSignals
      );
      result.eventAttribution = eventAttribution;

      if (needWeather) {
        const weather = computeSerpWeather(
          observatory,
          disturbance,
          eventAttribution
        );
        result.weather = weather;

        if (
          needForecast ||
          needAlerts ||
          needBriefing ||
          needImpact ||
          needAffected ||
          needHints
        ) {
          const forecast = computeSerpWeatherForecast(
            weather,
            disturbance,
            eventAttribution,
            keywordSignals,
            firstHalfDisturbance,
            secondHalfDisturbance
          );
          if (needForecast) {
            result.forecast = forecast;
          }

          if (
            needAlerts ||
            needBriefing ||
            needImpact ||
            needAffected ||
            needHints
          ) {
            const alerts = computeSerpWeatherAlerts(
              disturbance,
              eventAttribution,
              weather,
              forecast
            );
            if (needAlerts) {
              result.alerts = alerts;
            }

            if (needBriefing || needImpact || needAffected || needHints) {
              const briefing = computeSerpAlertBriefing(
                disturbance,
                eventAttribution,
                weather,
                forecast,
                alerts,
                disturbance.affectedKeywordCount
              );
              if (needBriefing) {
                result.briefing = briefing;
              }

              if (needImpact || needAffected || needHints) {
                const impactRanking = computeSerpKeywordImpactRanking(
                  impactInputs,
                  eventAttribution
                );
                if (needImpact) {
                  result.keywordImpactRanking = impactRanking;
                }

                if (needAffected || needHints) {
                  const affectedKeywords = selectAlertAffectedKeywords(
                    impactRanking,
                    alerts,
                    eventAttribution
                  );
                  if (needAffected) {
                    result.alertAffectedKeywords = affectedKeywords;
                  }

                  if (needHints) {
                    result.operatorActionHints = computeSerpOperatorActionHints(
                      disturbance,
                      eventAttribution,
                      weather,
                      forecast,
                      alerts,
                      affectedKeywords
                    );
                  }
                }
              }
            }
          }
        }
      }
    }

    return successResponse(result);
  } catch (error) {
    console.error("GET /api/seo/serp-disturbances error:", error);
    return serverError();
  }
}
