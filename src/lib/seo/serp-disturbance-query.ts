import { z } from "zod";

export const SERP_DISTURBANCE_LAYER_ORDER = [
  "disturbance",
  "attribution",
  "weather",
  "forecast",
  "alerts",
  "briefing",
  "impact",
  "affected",
  "hints",
] as const;

export type SerpDisturbanceLayer =
  (typeof SERP_DISTURBANCE_LAYER_ORDER)[number];

const SERP_DISTURBANCE_LAYER_SET = new Set<string>(
  SERP_DISTURBANCE_LAYER_ORDER
);

const SERP_DISTURBANCE_DEPENDENCIES: Record<
  SerpDisturbanceLayer,
  readonly SerpDisturbanceLayer[]
> = {
  disturbance: [],
  attribution: ["disturbance"],
  weather: ["attribution", "disturbance"],
  forecast: ["weather", "attribution", "disturbance"],
  alerts: ["forecast", "weather", "attribution", "disturbance"],
  briefing: ["alerts", "forecast", "weather", "attribution", "disturbance"],
  impact: ["briefing", "alerts", "forecast", "weather", "attribution", "disturbance"],
  affected: ["impact", "briefing", "alerts", "forecast", "weather", "attribution", "disturbance"],
  hints: ["affected", "impact", "briefing", "alerts", "forecast", "weather", "attribution", "disturbance"],
};

export const SerpDisturbanceQuerySchema = z
  .object({
    windowDays: z.coerce.number().int().min(1).max(365).default(60),
    include: z.string().optional(),
  })
  .strict();

export type SerpDisturbanceResolvedLayers = {
  requestedLayers: SerpDisturbanceLayer[] | null;
  resolvedLayers: SerpDisturbanceLayer[];
  layerSet: Set<SerpDisturbanceLayer> | null;
};

export function getSerpDisturbanceLayerFlags(
  layerSet: Set<SerpDisturbanceLayer> | null
) {
  return {
    needDisturbance: layerSet === null || layerSet.has("disturbance"),
    needAttribution: layerSet === null || layerSet.has("attribution"),
    needWeather: layerSet === null || layerSet.has("weather"),
    needForecast: layerSet === null || layerSet.has("forecast"),
    needAlerts: layerSet === null || layerSet.has("alerts"),
    needBriefing: layerSet === null || layerSet.has("briefing"),
    needImpact: layerSet === null || layerSet.has("impact"),
    needAffected: layerSet === null || layerSet.has("affected"),
    needHints: layerSet === null || layerSet.has("hints"),
  };
}

export function resolveSerpDisturbanceLayers(
  includeParam: string | undefined
): SerpDisturbanceResolvedLayers {
  if (includeParam === undefined || includeParam.trim() === "") {
    return {
      requestedLayers: null,
      resolvedLayers: [...SERP_DISTURBANCE_LAYER_ORDER],
      layerSet: null,
    };
  }

  const requestedSet = new Set<SerpDisturbanceLayer>();
  const invalid: string[] = [];

  for (const rawValue of includeParam.split(",")) {
    const value = rawValue.trim();
    if (!value) continue;
    if (!SERP_DISTURBANCE_LAYER_SET.has(value)) {
      invalid.push(value);
      continue;
    }
    requestedSet.add(value as SerpDisturbanceLayer);
  }

  if (invalid.length > 0) {
    throw new Error(
      `Unknown include values: ${invalid.join(", ")}. Valid: ${SERP_DISTURBANCE_LAYER_ORDER.join(", ")}`
    );
  }

  const expand = (layer: SerpDisturbanceLayer, target: Set<SerpDisturbanceLayer>) => {
    if (target.has(layer)) return;
    target.add(layer);
    for (const dependency of SERP_DISTURBANCE_DEPENDENCIES[layer]) {
      expand(dependency, target);
    }
  };

  const resolvedSet = new Set<SerpDisturbanceLayer>();
  for (const layer of requestedSet) {
    expand(layer, resolvedSet);
  }

  const requestedLayers = SERP_DISTURBANCE_LAYER_ORDER.filter((layer) =>
    requestedSet.has(layer)
  );
  const resolvedLayers = SERP_DISTURBANCE_LAYER_ORDER.filter((layer) =>
    resolvedSet.has(layer)
  );

  return {
    requestedLayers,
    resolvedLayers,
    layerSet: new Set(resolvedLayers),
  };
}
