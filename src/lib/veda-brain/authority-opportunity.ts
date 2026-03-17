/**
 * authority-opportunity.ts — VEDA Brain Comparison Module
 *
 * Identifies authority opportunities by comparing:
 *   - Internal link authority (inbound link counts)
 *   - Keyword-page mapping (which pages target important keywords)
 *   - Search performance signals (position, impressions)
 *
 * Detects:
 *   - High-value keywords mapped to weakly-supported pages
 *   - Pages targeting primary keywords with zero inbound links
 *   - Pages with strong keyword mappings but isolated in the link graph
 *   - Opportunities to strengthen internal support for mapped pages
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { VedaBrainInput } from "./load-brain-input";
import type { KeywordPageMappingResult } from "./keyword-page-mapping";

// =============================================================================
// Types
// =============================================================================

export interface AuthorityOpportunityEntry {
  query: string;
  isPrimary: boolean;
  mappedPageId: string;
  mappedPageUrl: string;
  inboundLinkCount: number;
  outboundLinkCount: number;
  isIsolated: boolean;
  isWeaklySupported: boolean;
  gscAvgPosition: number | null;
  gscImpressions: number | null;
  opportunityType: AuthorityOpportunityType;
}

export type AuthorityOpportunityType =
  | "isolated_target"        // page targets keyword but has zero links
  | "weak_support"           // page has < 3 inbound links
  | "high_value_undersupported" // primary keyword, page has few inbound links
  | "none";

export interface AuthorityOpportunityResult {
  opportunities: AuthorityOpportunityEntry[];
  summary: {
    isolatedTargets: number;
    weaklySupported: number;
    highValueUndersupported: number;
    wellSupported: number;
  };
}

// =============================================================================
// Constants
// =============================================================================

const WEAK_SUPPORT_THRESHOLD = 3;

// =============================================================================
// Core computation
// =============================================================================

export function computeAuthorityOpportunity(
  input: VedaBrainInput,
  mapping: KeywordPageMappingResult
): AuthorityOpportunityResult {
  // Build inbound/outbound link counts per page
  const inboundCount = new Map<string, number>();
  const outboundCount = new Map<string, number>();
  for (const link of input.internalLinks) {
    inboundCount.set(link.targetPageId, (inboundCount.get(link.targetPageId) ?? 0) + 1);
    outboundCount.set(link.sourcePageId, (outboundCount.get(link.sourcePageId) ?? 0) + 1);
  }

  // Build page URL → page lookup
  const pageById = new Map<string, typeof input.pages[0]>();
  for (const p of input.pages) pageById.set(p.id, p);

  // Build GSC lookup: pageUrl (lowered) → { avgPosition, impressions } (best query)
  const gscByPage = new Map<string, { avgPosition: number; impressions: number }>();
  for (const sp of input.searchPerformance) {
    const existing = gscByPage.get(sp.pageUrl);
    if (!existing || sp.impressions > existing.impressions) {
      gscByPage.set(sp.pageUrl, {
        avgPosition: sp.avgPosition,
        impressions: sp.impressions,
      });
    }
  }

  const opportunities: AuthorityOpportunityEntry[] = [];
  let isolatedTargets = 0;
  let weaklySupported = 0;
  let highValueUndersupported = 0;
  let wellSupported = 0;

  for (const m of mapping.mappings) {
    if (!m.bestMatch) continue;

    const pageId = m.bestMatch.pageId;
    const page = pageById.get(pageId);
    if (!page) continue;

    const inbound = inboundCount.get(pageId) ?? 0;
    const outbound = outboundCount.get(pageId) ?? 0;
    const isIsolated = inbound === 0 && outbound === 0;
    const isWeaklySupported = inbound < WEAK_SUPPORT_THRESHOLD;

    const gsc = gscByPage.get(page.url);

    let opportunityType: AuthorityOpportunityType = "none";
    if (isIsolated) {
      opportunityType = "isolated_target";
      isolatedTargets++;
    } else if (m.isPrimary && isWeaklySupported) {
      opportunityType = "high_value_undersupported";
      highValueUndersupported++;
    } else if (isWeaklySupported) {
      opportunityType = "weak_support";
      weaklySupported++;
    } else {
      wellSupported++;
    }

    opportunities.push({
      query: m.query,
      isPrimary: m.isPrimary,
      mappedPageId: pageId,
      mappedPageUrl: page.url,
      inboundLinkCount: inbound,
      outboundLinkCount: outbound,
      isIsolated,
      isWeaklySupported,
      gscAvgPosition: gsc?.avgPosition ?? null,
      gscImpressions: gsc?.impressions ?? null,
      opportunityType,
    });
  }

  // Deterministic sort: opportunityType priority → query asc
  const typeRank: Record<AuthorityOpportunityType, number> = {
    isolated_target: 0,
    high_value_undersupported: 1,
    weak_support: 2,
    none: 3,
  };
  opportunities.sort((a, b) => {
    const tr = typeRank[a.opportunityType] - typeRank[b.opportunityType];
    if (tr !== 0) return tr;
    return a.query.localeCompare(b.query);
  });

  return {
    opportunities,
    summary: {
      isolatedTargets,
      weaklySupported,
      highValueUndersupported,
      wellSupported,
    },
  };
}
