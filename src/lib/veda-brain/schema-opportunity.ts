/**
 * schema-opportunity.ts — VEDA Brain Comparison Module
 *
 * Compares structured data (schema) usage on project pages against
 * schema patterns observed in SERP results (via rawPayload features).
 *
 * Detects:
 *   - Pages targeting keywords where SERP results use schema types the page lacks
 *   - Schema types common in SERPs but absent from project pages
 *   - Pages with no schema at all targeting competitive keywords
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { VedaBrainInput } from "./load-brain-input";
import type { KeywordPageMappingResult } from "./keyword-page-mapping";

// =============================================================================
// Types
// =============================================================================

export interface SchemaOpportunityEntry {
  query: string;
  mappedPageId: string | null;
  mappedPageUrl: string | null;
  pageSchemaTypes: string[];
  serpSchemaSignals: string[];
  missingSchemaTypes: string[];
  hasNoSchema: boolean;
}

export interface SchemaOpportunityResult {
  entries: SchemaOpportunityEntry[];
  pagesWithoutSchema: number;
  totalMissingSchemaOpportunities: number;
  serpSchemaFrequency: { schemaType: string; count: number }[];
}

// =============================================================================
// SERP schema detection helpers
// =============================================================================

/**
 * Extract schema-related signals from SERP features.
 * Detects SERP feature types that imply schema usage.
 */
const FEATURE_TO_SCHEMA: Record<string, string> = {
  featured_snippet: "Article",
  faq: "FAQ",
  how_to: "HowTo",
  recipe: "Recipe",
  product: "Product",
  review: "Review",
  video: "VideoObject",
  local_pack: "LocalBusiness",
  knowledge_panel: "Organization",
};

function extractSerpSchemaSignals(rawPayload: unknown): string[] {
  const signals = new Set<string>();
  if (!rawPayload || typeof rawPayload !== "object") return [];
  const payload = rawPayload as Record<string, unknown>;

  // Strategy 1: DataForSEO items array — non-organic item types
  if (Array.isArray(payload.items)) {
    for (const item of payload.items) {
      if (item && typeof item === "object") {
        const type = (item as Record<string, unknown>).type;
        if (typeof type === "string" && type !== "organic") {
          const mapped = FEATURE_TO_SCHEMA[type];
          if (mapped) signals.add(mapped);
        }
      }
    }
  }

  // Strategy 2: Simple payload features array
  if (Array.isArray(payload.features)) {
    for (const f of payload.features) {
      const featureStr = typeof f === "string" ? f : (f as Record<string, unknown>)?.type;
      if (typeof featureStr === "string") {
        const mapped = FEATURE_TO_SCHEMA[featureStr];
        if (mapped) signals.add(mapped);
      }
    }
  }

  return Array.from(signals).sort();
}

// =============================================================================
// Core computation
// =============================================================================

export function computeSchemaOpportunity(
  input: VedaBrainInput,
  mapping: KeywordPageMappingResult
): SchemaOpportunityResult {
  // Build page → schema types
  const pageSchemas = new Map<string, string[]>();
  for (const su of input.schemaUsages) {
    if (!pageSchemas.has(su.pageId)) pageSchemas.set(su.pageId, []);
    pageSchemas.get(su.pageId)!.push(su.schemaType);
  }

  // Build page URL lookup
  const pageById = new Map<string, typeof input.pages[0]>();
  for (const p of input.pages) pageById.set(p.id, p);

  // Snapshot lookup
  const snapshotMap = new Map<string, typeof input.latestSnapshotsPerKeyword[0]>();
  for (const s of input.latestSnapshotsPerKeyword) {
    snapshotMap.set(`${s.query.toLowerCase()}|${s.locale}|${s.device}`, s);
  }

  const entries: SchemaOpportunityEntry[] = [];
  let pagesWithoutSchema = 0;
  let totalMissingSchemaOpportunities = 0;
  const globalSerpSchemaCount = new Map<string, number>();

  for (const m of mapping.mappings) {
    const mappedPageId = m.bestMatch?.pageId ?? null;
    const page = mappedPageId ? pageById.get(mappedPageId) : null;
    const pageSchemaTypes = mappedPageId
      ? (pageSchemas.get(mappedPageId) ?? []).slice().sort()
      : [];
    const hasNoSchema = mappedPageId !== null && pageSchemaTypes.length === 0;

    if (hasNoSchema) pagesWithoutSchema++;

    // SERP schema signals
    const snapshotKey = `${m.query.toLowerCase()}|${m.locale}|${m.device}`;
    const snapshot = snapshotMap.get(snapshotKey);
    const serpSchemaSignals = snapshot
      ? extractSerpSchemaSignals(snapshot.rawPayload)
      : [];

    // Track global frequency
    for (const ss of serpSchemaSignals) {
      globalSerpSchemaCount.set(ss, (globalSerpSchemaCount.get(ss) ?? 0) + 1);
    }

    // Missing schema types
    const pageSet = new Set(pageSchemaTypes);
    const missingSchemaTypes = serpSchemaSignals
      .filter((s) => !pageSet.has(s))
      .sort();

    totalMissingSchemaOpportunities += missingSchemaTypes.length;

    entries.push({
      query: m.query,
      mappedPageId,
      mappedPageUrl: page?.url ?? null,
      pageSchemaTypes,
      serpSchemaSignals,
      missingSchemaTypes,
      hasNoSchema,
    });
  }

  entries.sort((a, b) => a.query.localeCompare(b.query));

  const serpSchemaFrequency = Array.from(globalSerpSchemaCount.entries())
    .map(([schemaType, count]) => ({ schemaType, count }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.schemaType.localeCompare(b.schemaType);
    });

  return {
    entries,
    pagesWithoutSchema,
    totalMissingSchemaOpportunities,
    serpSchemaFrequency,
  };
}
