/**
 * readiness-classification.ts — VEDA Brain Classification Layer
 *
 * Deterministically classifies each keyword/territory into a structured
 * readiness category based on signals from all other brain modules.
 *
 * Categories:
 *   - structurally_aligned:    mapped, archetype matches, entities covered, good authority
 *   - under_covered:           mapped but topic territory is thin
 *   - archetype_misaligned:    mapped but archetype does not match SERP pattern
 *   - entity_incomplete:       mapped but missing entities seen in SERPs
 *   - weak_authority_support:  mapped but internal link support is insufficient
 *   - schema_underpowered:     mapped but missing schema types seen in SERPs
 *   - unmapped:                keyword has no page mapping
 *
 * A keyword may receive multiple classifications (not mutually exclusive).
 * This is a structured classification layer, not a vanity metric.
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { KeywordPageMappingResult } from "./keyword-page-mapping";
import type { ArchetypeAlignmentResult } from "./archetype-alignment";
import type { EntityGapAnalysisResult } from "./entity-gap-analysis";
import type { TopicTerritoryGapsResult } from "./topic-territory-gaps";
import type { AuthorityOpportunityResult } from "./authority-opportunity";
import type { SchemaOpportunityResult } from "./schema-opportunity";

// =============================================================================
// Types
// =============================================================================

export type ReadinessCategory =
  | "structurally_aligned"
  | "under_covered"
  | "archetype_misaligned"
  | "entity_incomplete"
  | "weak_authority_support"
  | "schema_underpowered"
  | "unmapped";

export interface KeywordReadiness {
  query: string;
  categories: ReadinessCategory[];
  isPrimary: boolean;
  mappedPageId: string | null;
}

export interface ReadinessClassificationResult {
  classifications: KeywordReadiness[];
  categoryCounts: Record<ReadinessCategory, number>;
  fullyAlignedCount: number;
  keywordsWithIssues: number;
}

// =============================================================================
// Core computation
// =============================================================================

export function computeReadinessClassification(
  mapping: KeywordPageMappingResult,
  archetypeAlignment: ArchetypeAlignmentResult,
  entityGaps: EntityGapAnalysisResult,
  topicGaps: TopicTerritoryGapsResult,
  authorityOpps: AuthorityOpportunityResult,
  schemaOpps: SchemaOpportunityResult
): ReadinessClassificationResult {
  // Build lookup maps by query
  const archetypeByQuery = new Map<string, typeof archetypeAlignment.entries[0]>();
  for (const e of archetypeAlignment.entries) archetypeByQuery.set(e.query, e);

  const entityByQuery = new Map<string, typeof entityGaps.entries[0]>();
  for (const e of entityGaps.entries) entityByQuery.set(e.query, e);

  const authorityByQuery = new Map<string, typeof authorityOpps.opportunities[0]>();
  for (const o of authorityOpps.opportunities) authorityByQuery.set(o.query, o);

  const schemaByQuery = new Map<string, typeof schemaOpps.entries[0]>();
  for (const e of schemaOpps.entries) schemaByQuery.set(e.query, e);

  // Uncategorized keywords set (from topic territory gaps)
  const uncategorizedSet = new Set(topicGaps.uncategorizedKeywords.map((u) => u.query));

  const categoryCounts: Record<ReadinessCategory, number> = {
    structurally_aligned: 0,
    under_covered: 0,
    archetype_misaligned: 0,
    entity_incomplete: 0,
    weak_authority_support: 0,
    schema_underpowered: 0,
    unmapped: 0,
  };

  const classifications: KeywordReadiness[] = [];
  let fullyAlignedCount = 0;
  let keywordsWithIssues = 0;

  for (const m of mapping.mappings) {
    const categories: ReadinessCategory[] = [];

    if (!m.bestMatch) {
      categories.push("unmapped");
    } else {
      // Check archetype alignment
      const arch = archetypeByQuery.get(m.query);
      if (arch && !arch.aligned && arch.mismatchReason !== "no_serp_archetype_signal" && arch.mismatchReason !== "no_mapped_page") {
        categories.push("archetype_misaligned");
      }

      // Check entity gaps
      const entity = entityByQuery.get(m.query);
      if (entity && entity.missingFromProject.length > 0) {
        categories.push("entity_incomplete");
      }

      // Check topic territory coverage
      if (uncategorizedSet.has(m.query)) {
        categories.push("under_covered");
      }

      // Check authority support
      const auth = authorityByQuery.get(m.query);
      if (auth && auth.opportunityType !== "none") {
        categories.push("weak_authority_support");
      }

      // Check schema
      const schema = schemaByQuery.get(m.query);
      if (schema && schema.missingSchemaTypes.length > 0) {
        categories.push("schema_underpowered");
      }

      // If no issues found, it's structurally aligned
      if (categories.length === 0) {
        categories.push("structurally_aligned");
      }
    }

    // Deterministic sort of categories
    categories.sort();

    // Update counts
    for (const cat of categories) {
      categoryCounts[cat]++;
    }

    if (categories.length === 1 && categories[0] === "structurally_aligned") {
      fullyAlignedCount++;
    } else {
      keywordsWithIssues++;
    }

    classifications.push({
      query: m.query,
      categories,
      isPrimary: m.isPrimary,
      mappedPageId: m.bestMatch?.pageId ?? null,
    });
  }

  // Deterministic sort: query asc
  classifications.sort((a, b) => a.query.localeCompare(b.query));

  return {
    classifications,
    categoryCounts,
    fullyAlignedCount,
    keywordsWithIssues,
  };
}
