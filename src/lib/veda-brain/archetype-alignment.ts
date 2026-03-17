/**
 * archetype-alignment.ts — VEDA Brain Comparison Module
 *
 * Compares page archetypes in the Content Graph against SERP winner patterns.
 * Detects archetype mismatches: keywords targeting pages whose archetype
 * does not match the dominant archetype pattern in SERP results.
 *
 * SERP archetype detection uses heuristic URL/title pattern matching
 * against the rawPayload organic results. This is a best-effort
 * deterministic approximation — not LLM reasoning.
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { VedaBrainInput, BrainPage, BrainSerpSnapshot } from "./load-brain-input";
import type { KeywordPageMappingResult } from "./keyword-page-mapping";

// =============================================================================
// Types
// =============================================================================

export interface SerpArchetypeSignal {
  archetype: string;
  count: number;
}

export interface ArchetypeAlignmentEntry {
  query: string;
  mappedPageId: string | null;
  mappedPageUrl: string | null;
  mappedPageArchetype: string | null;
  serpDominantArchetypes: SerpArchetypeSignal[];
  aligned: boolean;
  mismatchReason: string | null;
}

export interface ArchetypeAlignmentResult {
  entries: ArchetypeAlignmentEntry[];
  alignedCount: number;
  misalignedCount: number;
  noDataCount: number;
}

// =============================================================================
// Heuristic archetype detection from URL/title patterns
// =============================================================================

const ARCHETYPE_PATTERNS: { archetype: string; urlPatterns: RegExp[]; titlePatterns: RegExp[] }[] = [
  {
    archetype: "comparison",
    urlPatterns: [/\bvs\b/i, /\bcompar/i, /\bversus\b/i, /\balternative/i],
    titlePatterns: [/\bvs\.?\b/i, /\bcompar/i, /\bversus\b/i, /\bbest\b.*\bfor\b/i, /\balternative/i],
  },
  {
    archetype: "tutorial",
    urlPatterns: [/\btutorial/i, /\bhow-to\b/i, /\bstep-by-step/i],
    titlePatterns: [/\btutorial\b/i, /\bhow to\b/i, /\bstep[- ]by[- ]step\b/i, /\bguide to\b/i],
  },
  {
    archetype: "guide",
    urlPatterns: [/\bguide\b/i, /\bcomplete\b/i, /\bultimate\b/i],
    titlePatterns: [/\bguide\b/i, /\bcomplete\b/i, /\bultimate\b/i, /\beverything you need\b/i],
  },
  {
    archetype: "reference",
    urlPatterns: [/\bdocs?\b/i, /\breference\b/i, /\bapi\b/i, /\bspec\b/i],
    titlePatterns: [/\bdocumentation\b/i, /\breference\b/i, /\bapi\b/i, /\bspecification\b/i],
  },
  {
    archetype: "review",
    urlPatterns: [/\breview\b/i],
    titlePatterns: [/\breview\b/i, /\bhands[- ]on\b/i],
  },
  {
    archetype: "listicle",
    urlPatterns: [/\btop[- ]\d/i, /\bbest[- ]\d/i],
    titlePatterns: [/\btop\s+\d/i, /\bbest\s+\d/i, /\d+\s+best\b/i],
  },
];

function detectArchetypeFromUrl(url: string, title: string | null): string | null {
  for (const pattern of ARCHETYPE_PATTERNS) {
    for (const re of pattern.urlPatterns) {
      if (re.test(url)) return pattern.archetype;
    }
    if (title) {
      for (const re of pattern.titlePatterns) {
        if (re.test(title)) return pattern.archetype;
      }
    }
  }
  return null;
}

// =============================================================================
// SERP result extraction helper (same strategy as serp-extraction.ts)
// =============================================================================

interface MiniResult {
  url: string;
  title: string | null;
}

function extractOrganicResults(rawPayload: unknown): MiniResult[] {
  const results: MiniResult[] = [];
  if (!rawPayload || typeof rawPayload !== "object") return results;

  const payload = rawPayload as Record<string, unknown>;

  // Strategy 1: DataForSEO items array
  if (Array.isArray(payload.items)) {
    for (const item of payload.items) {
      if (
        item &&
        typeof item === "object" &&
        "type" in item &&
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

  // Strategy 2: Simple test payload — results array
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

// =============================================================================
// Core computation
// =============================================================================

export function computeArchetypeAlignment(
  input: VedaBrainInput,
  mapping: KeywordPageMappingResult
): ArchetypeAlignmentResult {
  // Build lookup maps
  const pageById = new Map<string, BrainPage>();
  for (const p of input.pages) pageById.set(p.id, p);

  const archetypeById = new Map<string, string>();
  for (const a of input.archetypes) archetypeById.set(a.id, a.key);

  // Build snapshot lookup: query|locale|device → snapshot
  const snapshotMap = new Map<string, BrainSerpSnapshot>();
  for (const s of input.latestSnapshotsPerKeyword) {
    const key = `${s.query.toLowerCase()}|${s.locale}|${s.device}`;
    snapshotMap.set(key, s);
  }

  const entries: ArchetypeAlignmentEntry[] = [];
  let alignedCount = 0;
  let misalignedCount = 0;
  let noDataCount = 0;

  for (const m of mapping.mappings) {
    const snapshotKey = `${m.query.toLowerCase()}|${m.locale}|${m.device}`;
    const snapshot = snapshotMap.get(snapshotKey);

    // Get mapped page archetype
    const mappedPage = m.bestMatch ? pageById.get(m.bestMatch.pageId) : null;
    const mappedArchetypeKey = mappedPage?.contentArchetypeId
      ? archetypeById.get(mappedPage.contentArchetypeId) ?? null
      : null;

    // Detect SERP archetypes
    const serpArchetypes: Map<string, number> = new Map();
    if (snapshot) {
      const organicResults = extractOrganicResults(snapshot.rawPayload);
      for (const r of organicResults) {
        const detected = detectArchetypeFromUrl(r.url, r.title);
        if (detected) {
          serpArchetypes.set(detected, (serpArchetypes.get(detected) ?? 0) + 1);
        }
      }
    }

    const serpDominantArchetypes: SerpArchetypeSignal[] = Array.from(serpArchetypes.entries())
      .map(([archetype, count]) => ({ archetype, count }))
      .sort((a, b) => {
        if (b.count !== a.count) return b.count - a.count;
        return a.archetype.localeCompare(b.archetype);
      });

    // Determine alignment
    let aligned = false;
    let mismatchReason: string | null = null;

    if (!m.bestMatch) {
      // No mapped page — can't assess alignment
      mismatchReason = "no_mapped_page";
      noDataCount++;
    } else if (serpDominantArchetypes.length === 0) {
      // No SERP archetype signal — insufficient data
      mismatchReason = "no_serp_archetype_signal";
      noDataCount++;
    } else if (!mappedArchetypeKey) {
      // Page has no archetype assigned
      mismatchReason = "page_missing_archetype";
      misalignedCount++;
    } else {
      // Check if page archetype appears in SERP dominant archetypes
      const topSerpArchetype = serpDominantArchetypes[0].archetype;
      if (mappedArchetypeKey === topSerpArchetype) {
        aligned = true;
        alignedCount++;
      } else if (serpDominantArchetypes.some((s) => s.archetype === mappedArchetypeKey)) {
        // Present but not dominant
        aligned = true;
        alignedCount++;
      } else {
        mismatchReason = `page_archetype_${mappedArchetypeKey}_vs_serp_dominant_${topSerpArchetype}`;
        misalignedCount++;
      }
    }

    entries.push({
      query: m.query,
      mappedPageId: m.bestMatch?.pageId ?? null,
      mappedPageUrl: m.bestMatch?.pageUrl ?? null,
      mappedPageArchetype: mappedArchetypeKey,
      serpDominantArchetypes,
      aligned,
      mismatchReason,
    });
  }

  // Deterministic sort: query asc
  entries.sort((a, b) => a.query.localeCompare(b.query));

  return {
    entries,
    alignedCount,
    misalignedCount,
    noDataCount,
  };
}
