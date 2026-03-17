/**
 * topic-territory-gaps.ts — VEDA Brain Comparison Module
 *
 * Identifies topic territory gaps by comparing:
 *   - Topics declared in the Content Graph
 *   - Keywords tracked in the SERP Observatory
 *   - Actual keyword-page mappings
 *
 * Detects:
 *   - Topics with no keyword coverage (declared but untracked)
 *   - Keywords with no topic association (tracked but uncategorized)
 *   - Topics with thin page support (few pages, weak coverage)
 *   - Keyword clusters that lack topic structure
 *
 * Uses deterministic normalized token overlap for topic↔keyword matching.
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { VedaBrainInput } from "./load-brain-input";
import type { KeywordPageMappingResult } from "./keyword-page-mapping";

// =============================================================================
// Types
// =============================================================================

export interface TopicTerritory {
  topicId: string;
  topicKey: string;
  topicLabel: string;
  pageCount: number;
  matchedKeywords: string[];
  unmatchedKeywords: boolean; // true if topic has zero matched keywords
}

export interface UncategorizedKeyword {
  query: string;
  mappedPageId: string | null;
  hasMapping: boolean;
}

export interface TopicTerritoryGapsResult {
  topicTerritories: TopicTerritory[];
  untrackedTopics: string[];       // topic keys with zero keyword matches
  thinTopics: string[];            // topic keys with pageCount <= 1
  uncategorizedKeywords: UncategorizedKeyword[];
  summary: {
    totalTopics: number;
    untrackedTopicCount: number;
    thinTopicCount: number;
    uncategorizedKeywordCount: number;
  };
}

// =============================================================================
// Token helpers
// =============================================================================

function tokenize(input: string): string[] {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .filter((t) => t.length > 1);
}

function tokenOverlap(queryTokens: string[], targetTokens: string[]): number {
  if (queryTokens.length === 0 || targetTokens.length === 0) return 0;
  const targetSet = new Set(targetTokens);
  let matches = 0;
  for (const qt of queryTokens) {
    if (targetSet.has(qt)) matches++;
  }
  return matches / queryTokens.length;
}

// =============================================================================
// Core computation
// =============================================================================

const TOPIC_MATCH_THRESHOLD = 0.4;

export function computeTopicTerritoryGaps(
  input: VedaBrainInput,
  mapping: KeywordPageMappingResult
): TopicTerritoryGapsResult {
  // Build topic → page count
  const topicPageCount = new Map<string, number>();
  for (const pt of input.pageTopics) {
    topicPageCount.set(pt.topicId, (topicPageCount.get(pt.topicId) ?? 0) + 1);
  }

  // Build page → topic IDs
  const pageTopicIds = new Map<string, Set<string>>();
  for (const pt of input.pageTopics) {
    if (!pageTopicIds.has(pt.pageId)) pageTopicIds.set(pt.pageId, new Set());
    pageTopicIds.get(pt.pageId)!.add(pt.topicId);
  }

  // Match keywords to topics via:
  //   1. Mapped page's topics (if keyword maps to a page that has topics)
  //   2. Token overlap between keyword query and topic key/label
  const topicMatchedKeywords = new Map<string, string[]>();
  for (const t of input.topics) topicMatchedKeywords.set(t.id, []);

  const keywordTopicAssigned = new Set<string>();

  for (const m of mapping.mappings) {
    let assigned = false;

    // Strategy 1: Via mapped page's topics
    if (m.bestMatch) {
      const topics = pageTopicIds.get(m.bestMatch.pageId);
      if (topics && topics.size > 0) {
        for (const topicId of topics) {
          topicMatchedKeywords.get(topicId)?.push(m.query);
        }
        assigned = true;
      }
    }

    // Strategy 2: Token overlap with topic key/label
    if (!assigned) {
      const queryTokens = tokenize(m.query);
      for (const topic of input.topics) {
        const keyTokens = tokenize(topic.key.replace(/-/g, " "));
        const labelTokens = tokenize(topic.label);
        const overlap = Math.max(
          tokenOverlap(queryTokens, keyTokens),
          tokenOverlap(queryTokens, labelTokens)
        );
        if (overlap >= TOPIC_MATCH_THRESHOLD) {
          topicMatchedKeywords.get(topic.id)?.push(m.query);
          assigned = true;
        }
      }
    }

    if (assigned) keywordTopicAssigned.add(m.query);
  }

  // Build territories
  const topicTerritories: TopicTerritory[] = input.topics.map((t) => {
    const matched = topicMatchedKeywords.get(t.id) ?? [];
    return {
      topicId: t.id,
      topicKey: t.key,
      topicLabel: t.label,
      pageCount: topicPageCount.get(t.id) ?? 0,
      matchedKeywords: matched.slice().sort(),
      unmatchedKeywords: matched.length === 0,
    };
  });

  topicTerritories.sort((a, b) => a.topicKey.localeCompare(b.topicKey));

  const untrackedTopics = topicTerritories
    .filter((t) => t.unmatchedKeywords)
    .map((t) => t.topicKey)
    .sort();

  const thinTopics = topicTerritories
    .filter((t) => t.pageCount <= 1)
    .map((t) => t.topicKey)
    .sort();

  // Uncategorized keywords
  const uncategorizedKeywords: UncategorizedKeyword[] = mapping.mappings
    .filter((m) => !keywordTopicAssigned.has(m.query))
    .map((m) => ({
      query: m.query,
      mappedPageId: m.bestMatch?.pageId ?? null,
      hasMapping: m.bestMatch !== null,
    }))
    .sort((a, b) => a.query.localeCompare(b.query));

  return {
    topicTerritories,
    untrackedTopics,
    thinTopics,
    uncategorizedKeywords,
    summary: {
      totalTopics: input.topics.length,
      untrackedTopicCount: untrackedTopics.length,
      thinTopicCount: thinTopics.length,
      uncategorizedKeywordCount: uncategorizedKeywords.length,
    },
  };
}
