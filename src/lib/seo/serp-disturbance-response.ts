import type { SerpDisturbanceLayer } from "@/lib/seo/serp-disturbance-query";

export type SerpDisturbanceMeta = {
  windowDays: number;
  requestedLayers: SerpDisturbanceLayer[] | null;
  resolvedLayers: SerpDisturbanceLayer[];
  keywordTargetCount: number;
  snapshotCount: number;
};

export function buildSerpDisturbanceMeta(args: {
  windowDays: number;
  requestedLayers: SerpDisturbanceLayer[] | null;
  resolvedLayers: SerpDisturbanceLayer[];
  keywordTargetCount: number;
  snapshotCount: number;
}): SerpDisturbanceMeta {
  return {
    windowDays: args.windowDays,
    requestedLayers: args.requestedLayers,
    resolvedLayers: args.resolvedLayers,
    keywordTargetCount: args.keywordTargetCount,
    snapshotCount: args.snapshotCount,
  };
}

export function buildSerpDisturbanceZeroState(args: {
  includeDisturbance: boolean;
  includeAttribution: boolean;
  includeWeather: boolean;
  includeForecast: boolean;
  includeAlerts: boolean;
  includeBriefing: boolean;
  includeImpact: boolean;
  includeAffected: boolean;
  includeHints: boolean;
}) {
  const result: Record<string, unknown> = {};

  if (args.includeDisturbance) {
    Object.assign(result, {
      volatilityCluster: false,
      featureShiftDetected: false,
      dominantNewFeatures: [],
      rankingTurbulence: false,
      affectedKeywordCount: 0,
    });
  }

  if (args.includeAttribution) {
    result.eventAttribution = {
      cause: "unknown",
      confidence: 0,
      supportingSignals: [],
    };
  }

  if (args.includeWeather) {
    result.weather = {
      state: "calm",
      driver: "unknown",
      confidence: 0,
      stability: "high",
      featureClimate: "stable_features",
      summary: "Calm SERP climate with no significant disturbance signals.",
    };
  }

  if (args.includeForecast) {
    result.forecast = {
      trend: "stable",
      expectedState: "calm",
      confidence: 0,
      driverMomentum: "unknown",
      momentum: "stable",
      forecastSummary: "SERP climate stable with no significant disturbance signals.",
    };
  }

  if (args.includeAlerts) {
    result.alerts = [];
  }

  if (args.includeBriefing) {
    result.briefing = {
      primaryAlert: null,
      weatherState: "calm",
      forecastTrend: "stable",
      momentum: "stable",
      driver: "unknown",
      affectedKeywords: 0,
      supportingSignals: [],
      summary: "Calm SERP conditions with no significant disturbance.",
    };
  }

  if (args.includeImpact) {
    result.keywordImpactRanking = [];
  }

  if (args.includeAffected) {
    result.alertAffectedKeywords = [];
  }

  if (args.includeHints) {
    result.operatorActionHints = [];
  }

  return result;
}
