/**
 * Content Graph Diagnostics — Phase 2 Aggregator
 *
 * Combines all Phase 2 intelligence signals into a single diagnostic object.
 * Compute-on-read. All constituent functions are read-only.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 */
import { computeTopicCoverage, TopicCoverageResult } from "./topic-coverage";
import { computeEntityCoverage, EntityCoverageResult } from "./entity-coverage";
import { computeInternalAuthority, InternalAuthorityResult } from "./internal-authority";
import { computeSchemaCoverage, SchemaCoverageResult } from "./schema-coverage";
import { computeArchetypeDistribution, ArchetypeDistributionResult } from "./archetype-distribution";

export interface ContentGraphDiagnostics {
  topicCoverage: TopicCoverageResult;
  entityCoverage: EntityCoverageResult;
  internalAuthority: InternalAuthorityResult;
  schemaCoverage: SchemaCoverageResult;
  archetypeDistribution: ArchetypeDistributionResult;
}

/**
 * Compute all Content Graph intelligence signals for a project.
 *
 * All constituent queries run concurrently via Promise.all.
 * Result is fully deterministic given stable DB state.
 */
export async function computeContentGraphDiagnostics(
  projectId: string
): Promise<ContentGraphDiagnostics> {
  const [
    topicCoverage,
    entityCoverage,
    internalAuthority,
    schemaCoverage,
    archetypeDistribution,
  ] = await Promise.all([
    computeTopicCoverage(projectId),
    computeEntityCoverage(projectId),
    computeInternalAuthority(projectId),
    computeSchemaCoverage(projectId),
    computeArchetypeDistribution(projectId),
  ]);

  return {
    topicCoverage,
    entityCoverage,
    internalAuthority,
    schemaCoverage,
    archetypeDistribution,
  };
}
