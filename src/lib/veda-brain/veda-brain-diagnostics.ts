/**
 * veda-brain-diagnostics.ts — VEDA Brain Phase 1 Aggregator
 *
 * Orchestrates all Brain Phase 1 comparison modules into a single
 * deterministic diagnostics object.
 *
 * Pipeline:
 *   loadBrainInput(projectId)
 *   → computeKeywordPageMapping(input)
 *   → run comparison modules concurrently
 *   → computeReadinessClassification(all signals)
 *   → return structured diagnostics
 *
 * Read-only. No mutations. No EventLog writes. Compute-on-read.
 */
import { loadBrainInput, type VedaBrainInput } from "./load-brain-input";
import { computeKeywordPageMapping, type KeywordPageMappingResult } from "./keyword-page-mapping";
import { computeArchetypeAlignment, type ArchetypeAlignmentResult } from "./archetype-alignment";
import { computeEntityGapAnalysis, type EntityGapAnalysisResult } from "./entity-gap-analysis";
import { computeTopicTerritoryGaps, type TopicTerritoryGapsResult } from "./topic-territory-gaps";
import { computeAuthorityOpportunity, type AuthorityOpportunityResult } from "./authority-opportunity";
import { computeSchemaOpportunity, type SchemaOpportunityResult } from "./schema-opportunity";
import { computeReadinessClassification, type ReadinessClassificationResult } from "./readiness-classification";

// =============================================================================
// Types
// =============================================================================

export interface VedaBrainDiagnostics {
  keywordPageMapping: KeywordPageMappingResult;
  archetypeAlignment: ArchetypeAlignmentResult;
  entityGapAnalysis: EntityGapAnalysisResult;
  topicTerritoryGaps: TopicTerritoryGapsResult;
  authorityOpportunity: AuthorityOpportunityResult;
  schemaOpportunity: SchemaOpportunityResult;
  readinessClassification: ReadinessClassificationResult;
}

// =============================================================================
// Aggregator
// =============================================================================

/**
 * Compute full VEDA Brain Phase 1 diagnostics for a project.
 *
 * The keyword-page mapping is computed first as it feeds all comparison modules.
 * Comparison modules run concurrently since they are all pure functions
 * operating on the same input + mapping.
 * Readiness classification runs last as it consumes all other results.
 */
export async function computeVedaBrainDiagnostics(
  projectId: string
): Promise<VedaBrainDiagnostics> {
  // Step 1: Load all raw inputs
  const input: VedaBrainInput = await loadBrainInput(projectId);

  // Step 2: Compute foundational keyword-page mapping
  const keywordPageMapping = computeKeywordPageMapping(input);

  // Step 3: Run comparison modules (all pure, can run concurrently)
  const [
    archetypeAlignment,
    entityGapAnalysis,
    topicTerritoryGaps,
    authorityOpportunity,
    schemaOpportunity,
  ] = await Promise.all([
    Promise.resolve(computeArchetypeAlignment(input, keywordPageMapping)),
    Promise.resolve(computeEntityGapAnalysis(input, keywordPageMapping)),
    Promise.resolve(computeTopicTerritoryGaps(input, keywordPageMapping)),
    Promise.resolve(computeAuthorityOpportunity(input, keywordPageMapping)),
    Promise.resolve(computeSchemaOpportunity(input, keywordPageMapping)),
  ]);

  // Step 4: Compute readiness classification from all signals
  const readinessClassification = computeReadinessClassification(
    keywordPageMapping,
    archetypeAlignment,
    entityGapAnalysis,
    topicTerritoryGaps,
    authorityOpportunity,
    schemaOpportunity
  );

  return {
    keywordPageMapping,
    archetypeAlignment,
    entityGapAnalysis,
    topicTerritoryGaps,
    authorityOpportunity,
    schemaOpportunity,
    readinessClassification,
  };
}
