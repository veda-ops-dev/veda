/**
 * proposals.ts — VEDA Brain Phase C1 Proposal Surface
 *
 * Pure projection from VedaBrainDiagnostics into operator-reviewable
 * ArchetypeProposal[] and SchemaProposal[].
 *
 * Phase C1 includes:
 *   - archetypeProposals (from archetypeAlignment)
 *   - schemaProposals    (from schemaOpportunity)
 *
 * Deferred (DQ-001, DQ-002, DQ-003):
 *   - topicProposals
 *   - entityProposals
 *   - authoritySupportProposals
 *
 * Rules:
 *   - No DB access
 *   - No side effects
 *   - No LLM reasoning
 *   - No timestamps in proposalIds
 *   - Fully deterministic output for identical inputs
 *   - Pure function — takes VedaBrainDiagnostics, returns ProposalSurface
 *
 * Per docs/specs/SERP-TO-CONTENT-GRAPH-PROPOSALS.md
 */
import type { VedaBrainDiagnostics } from "./veda-brain-diagnostics";

// =============================================================================
// Helpers
// =============================================================================

/**
 * Stable slugify for proposalId composition.
 * lowercase, non-alphanumeric → hyphen, collapse, trim.
 */
function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

// =============================================================================
// ArchetypeProposal
// =============================================================================

export type ArchetypeSuggestedAction =
  | "review_archetype_alignment"
  | "consider_archetype_aligned_page";

export interface ArchetypeProposal {
  proposalId: string;
  proposalType: "archetype";
  query: string;
  existingPageId: string;
  existingPageUrl: string;
  existingArchetype: string | null;
  serpDominantArchetype: string;
  readinessCategory: "archetype_misaligned";
  evidence: {
    serpDominantCount: number;
    mismatchReason: string;
  };
  suggestedAction: ArchetypeSuggestedAction;
}

/**
 * Project archetypeAlignment into ArchetypeProposal[].
 *
 * Inclusion criteria (all must hold):
 *   - entry.aligned === false
 *   - mismatchReason is not "no_mapped_page" or "no_serp_archetype_signal"
 *   - mappedPageId is non-null
 *   - mappedPageUrl is non-null
 *   - serpDominantArchetypes has at least one entry
 */
function computeArchetypeProposals(
  diagnostics: VedaBrainDiagnostics
): ArchetypeProposal[] {
  const EXCLUDED_REASONS = new Set(["no_mapped_page", "no_serp_archetype_signal"]);
  const proposals: ArchetypeProposal[] = [];

  for (const entry of diagnostics.archetypeAlignment.entries) {
    if (entry.aligned) continue;
    if (!entry.mappedPageId || !entry.mappedPageUrl) continue;
    if (!entry.mismatchReason || EXCLUDED_REASONS.has(entry.mismatchReason)) continue;
    if (entry.serpDominantArchetypes.length === 0) continue;

    const topArchetype = entry.serpDominantArchetypes[0];

    const suggestedAction: ArchetypeSuggestedAction =
      entry.mappedPageArchetype === null
        ? "review_archetype_alignment"
        : "consider_archetype_aligned_page";

    const proposalId =
      "archetype:" + entry.mappedPageId + ":" + slugify(entry.query);

    proposals.push({
      proposalId,
      proposalType: "archetype",
      query: entry.query,
      existingPageId: entry.mappedPageId,
      existingPageUrl: entry.mappedPageUrl,
      existingArchetype: entry.mappedPageArchetype,
      serpDominantArchetype: topArchetype.archetype,
      readinessCategory: "archetype_misaligned",
      evidence: {
        serpDominantCount: topArchetype.count,
        mismatchReason: entry.mismatchReason,
      },
      suggestedAction,
    });
  }

  // Deterministic ordering: query asc, existingPageId asc
  proposals.sort((a, b) => {
    const q = a.query.localeCompare(b.query);
    if (q !== 0) return q;
    return a.existingPageId.localeCompare(b.existingPageId);
  });

  return proposals;
}

// =============================================================================
// SchemaProposal
// =============================================================================

export interface SchemaProposal {
  proposalId: string;
  proposalType: "schema";
  query: string;
  pageId: string;
  pageUrl: string;
  missingSchemaTypes: string[];   // sorted ascending
  existingSchemaTypes: string[];  // sorted ascending
  readinessCategory: "schema_underpowered";
  evidence: {
    serpSchemaSignals: string[];  // sorted ascending
    hasNoSchemaAtAll: boolean;
  };
  suggestedAction: "review_schema_gap";
}

/**
 * Project schemaOpportunity into SchemaProposal[].
 *
 * Inclusion criteria (all must hold):
 *   - entry.mappedPageId is non-null
 *   - entry.mappedPageUrl is non-null
 *   - entry.missingSchemaTypes.length > 0
 */
function computeSchemaProposals(
  diagnostics: VedaBrainDiagnostics
): SchemaProposal[] {
  const proposals: SchemaProposal[] = [];

  for (const entry of diagnostics.schemaOpportunity.entries) {
    if (!entry.mappedPageId || !entry.mappedPageUrl) continue;
    if (entry.missingSchemaTypes.length === 0) continue;

    const sortedMissing = entry.missingSchemaTypes.slice().sort();
    const proposalId =
      "schema:" + entry.mappedPageId + ":" + sortedMissing.join("+") + ":" + slugify(entry.query);

    proposals.push({
      proposalId,
      proposalType: "schema",
      query: entry.query,
      pageId: entry.mappedPageId,
      pageUrl: entry.mappedPageUrl,
      missingSchemaTypes: entry.missingSchemaTypes.slice().sort(),
      existingSchemaTypes: entry.pageSchemaTypes.slice().sort(),
      readinessCategory: "schema_underpowered",
      evidence: {
        serpSchemaSignals: entry.serpSchemaSignals.slice().sort(),
        hasNoSchemaAtAll: entry.hasNoSchema,
      },
      suggestedAction: "review_schema_gap",
    });
  }

  // Deterministic ordering: query asc, pageId asc
  proposals.sort((a, b) => {
    const q = a.query.localeCompare(b.query);
    if (q !== 0) return q;
    return a.pageId.localeCompare(b.pageId);
  });

  return proposals;
}

// =============================================================================
// Public surface
// =============================================================================

export interface ProposalSurface {
  archetypeProposals: ArchetypeProposal[];
  schemaProposals: SchemaProposal[];
}

export interface ProposalSummary {
  archetypeProposalCount: number;
  schemaProposalCount: number;
  totalProposals: number;
}

export interface ComputedProposals {
  proposals: ProposalSurface;
  summary: ProposalSummary;
}

/**
 * Compute Phase C1 proposals from VEDA Brain diagnostics.
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 * Takes the full VedaBrainDiagnostics object and returns the C1 proposal surface.
 */
export function computeProposals(
  diagnostics: VedaBrainDiagnostics
): ComputedProposals {
  const archetypeProposals = computeArchetypeProposals(diagnostics);
  const schemaProposals = computeSchemaProposals(diagnostics);

  return {
    proposals: {
      archetypeProposals,
      schemaProposals,
    },
    summary: {
      archetypeProposalCount: archetypeProposals.length,
      schemaProposalCount: schemaProposals.length,
      totalProposals: archetypeProposals.length + schemaProposals.length,
    },
  };
}
