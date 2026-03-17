/**
 * entity-gap-analysis.ts — VEDA Brain Comparison Module
 *
 * Compares entities covered by project pages against entities referenced
 * in SERP results (detected via heuristic title/URL parsing).
 *
 * Identifies:
 *   - Entities present in project but absent from SERP winners
 *   - Entities appearing in SERP winners but not in project
 *   - Entity coverage breadth per mapped keyword
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { VedaBrainInput } from "./load-brain-input";
import type { KeywordPageMappingResult } from "./keyword-page-mapping";

// =============================================================================
// Types
// =============================================================================

export interface EntityGapEntry {
  query: string;
  mappedPageId: string | null;
  mappedPageUrl: string | null;
  projectEntities: string[];   // entity keys covered by mapped page
  serpMentionedTerms: string[]; // entity-like terms detected in SERP results
  missingFromProject: string[]; // serp terms not in project entities
  uniqueToProject: string[];   // project entities not seen in serp
}

export interface EntityGapAnalysisResult {
  entries: EntityGapEntry[];
  totalGaps: number;
  keywordsWithGaps: number;
  keywordsWithoutMapping: number;
}

// =============================================================================
// Heuristic entity term extraction from SERP results
// =============================================================================

interface MiniResult {
  url: string;
  title: string | null;
}

function extractOrganicResults(rawPayload: unknown): MiniResult[] {
  const results: MiniResult[] = [];
  if (!rawPayload || typeof rawPayload !== "object") return results;
  const payload = rawPayload as Record<string, unknown>;

  if (Array.isArray(payload.items)) {
    for (const item of payload.items) {
      if (
        item &&
        typeof item === "object" &&
        (item as Record<string, unknown>).type === "organic"
      ) {
        const url = (item as Record<string, unknown>).url;
        const title = (item as Record<string, unknown>).title;
        if (typeof url === "string") {
          results.push({ url, title: typeof title === "string" ? title : null });
        }
      }
    }
  }

  if (results.length === 0 && Array.isArray(payload.results)) {
    for (const r of payload.results) {
      if (r && typeof r === "object") {
        const url = (r as Record<string, unknown>).url;
        const title = (r as Record<string, unknown>).title;
        if (typeof url === "string") {
          results.push({ url, title: typeof title === "string" ? title : null });
        }
      }
    }
  }

  return results;
}

/**
 * Extract entity-like terms from SERP result titles and URL slugs.
 * Returns normalized lowercase tokens (multi-word entities via slug hyphens).
 */
function extractSerpEntityTerms(results: MiniResult[], projectEntityKeys: Set<string>): string[] {
  const terms = new Set<string>();

  for (const r of results) {
    // Extract from URL path segments
    try {
      const segments = new URL(r.url).pathname
        .split("/")
        .filter((s) => s.length > 0)
        .map((s) => s.toLowerCase().replace(/-/g, " ").trim())
        .filter((s) => s.length > 1);
      for (const seg of segments) {
        // Check if this segment matches any known project entity key
        if (projectEntityKeys.has(seg.replace(/\s+/g, "-"))) {
          terms.add(seg.replace(/\s+/g, "-"));
        }
      }
    } catch {
      // Invalid URL — skip
    }

    // Extract from title — look for known entity keys
    if (r.title) {
      const titleLower = r.title.toLowerCase();
      for (const key of projectEntityKeys) {
        const keyLabel = key.replace(/-/g, " ");
        if (titleLower.includes(keyLabel)) {
          terms.add(key);
        }
      }
    }
  }

  return Array.from(terms).sort();
}

// =============================================================================
// Core computation
// =============================================================================

export function computeEntityGapAnalysis(
  input: VedaBrainInput,
  mapping: KeywordPageMappingResult
): EntityGapAnalysisResult {
  // Build page → entity keys lookup
  const pageEntityKeys = new Map<string, string[]>();
  const entityKeyById = new Map<string, string>();
  for (const e of input.entities) entityKeyById.set(e.id, e.key);

  for (const pe of input.pageEntities) {
    const key = entityKeyById.get(pe.entityId);
    if (key) {
      if (!pageEntityKeys.has(pe.pageId)) pageEntityKeys.set(pe.pageId, []);
      pageEntityKeys.get(pe.pageId)!.push(key);
    }
  }

  // All project entity keys
  const allEntityKeys = new Set(input.entities.map((e) => e.key));

  // Snapshot lookup
  const snapshotMap = new Map<string, typeof input.latestSnapshotsPerKeyword[0]>();
  for (const s of input.latestSnapshotsPerKeyword) {
    snapshotMap.set(`${s.query.toLowerCase()}|${s.locale}|${s.device}`, s);
  }

  const entries: EntityGapEntry[] = [];
  let totalGaps = 0;
  let keywordsWithGaps = 0;
  let keywordsWithoutMapping = 0;

  for (const m of mapping.mappings) {
    const mappedPageId = m.bestMatch?.pageId ?? null;

    // Project entities on mapped page
    const projectEntities = mappedPageId
      ? (pageEntityKeys.get(mappedPageId) ?? []).slice().sort()
      : [];

    // SERP entity terms
    const snapshotKey = `${m.query.toLowerCase()}|${m.locale}|${m.device}`;
    const snapshot = snapshotMap.get(snapshotKey);
    const serpResults = snapshot ? extractOrganicResults(snapshot.rawPayload) : [];
    const serpMentionedTerms = extractSerpEntityTerms(serpResults, allEntityKeys);

    // Gap analysis
    const projectSet = new Set(projectEntities);
    const serpSet = new Set(serpMentionedTerms);

    const missingFromProject = serpMentionedTerms
      .filter((t) => !projectSet.has(t))
      .sort();
    const uniqueToProject = projectEntities
      .filter((e) => !serpSet.has(e))
      .sort();

    if (!mappedPageId) keywordsWithoutMapping++;
    if (missingFromProject.length > 0) {
      keywordsWithGaps++;
      totalGaps += missingFromProject.length;
    }

    entries.push({
      query: m.query,
      mappedPageId,
      mappedPageUrl: m.bestMatch?.pageUrl ?? null,
      projectEntities,
      serpMentionedTerms,
      missingFromProject,
      uniqueToProject,
    });
  }

  entries.sort((a, b) => a.query.localeCompare(b.query));

  return {
    entries,
    totalGaps,
    keywordsWithGaps,
    keywordsWithoutMapping,
  };
}
