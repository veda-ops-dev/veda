/**
 * Internal Authority — Content Graph Intelligence (Phase 2)
 *
 * Analyzes the internal link graph to detect authority flow patterns.
 * Compute-on-read. No writes. No side effects.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 *
 * Signals:
 *   isolatedPages  — pages with zero inbound AND zero outbound links
 *   weakPages      — pages with zero inbound links (but have outbound)
 *   strongestPages — top pages by inbound link count
 */
import { prisma } from "@/lib/prisma";

export interface StrongestPageEntry {
  pageId: string;
  inboundLinks: number;
}

export interface InternalAuthorityResult {
  isolatedPages: string[];
  weakPages: string[];
  strongestPages: StrongestPageEntry[];
}

const STRONGEST_PAGES_LIMIT = 10;

/**
 * Compute internal authority signals for a project.
 *
 * Deterministic ordering:
 *   isolatedPages  — pageId asc
 *   weakPages      — pageId asc
 *   strongestPages — inboundLinks desc, pageId asc
 */
export async function computeInternalAuthority(
  projectId: string
): Promise<InternalAuthorityResult> {
  const [allPages, inboundGroups, outboundGroups] = await Promise.all([
    prisma.cgPage.findMany({
      where: { projectId },
      select: { id: true },
      orderBy: [{ id: "asc" }],
    }),
    prisma.cgInternalLink.groupBy({
      by: ["targetPageId"],
      where: { projectId },
      _count: { sourcePageId: true },
    }),
    prisma.cgInternalLink.groupBy({
      by: ["sourcePageId"],
      where: { projectId },
      _count: { targetPageId: true },
    }),
  ]);

  const inboundMap = new Map<string, number>();
  for (const g of inboundGroups) {
    inboundMap.set(g.targetPageId, g._count.sourcePageId);
  }

  const outboundMap = new Map<string, number>();
  for (const g of outboundGroups) {
    outboundMap.set(g.sourcePageId, g._count.targetPageId);
  }

  const isolatedPages: string[] = [];
  const weakPages: string[] = [];

  for (const p of allPages) {
    const inbound = inboundMap.get(p.id) ?? 0;
    const outbound = outboundMap.get(p.id) ?? 0;
    if (inbound === 0 && outbound === 0) {
      isolatedPages.push(p.id);
    } else if (inbound === 0) {
      weakPages.push(p.id);
    }
  }

  // strongestPages: top N by inbound links desc, pageId asc
  const strongestPages: StrongestPageEntry[] = Array.from(inboundMap.entries())
    .map(([pageId, inboundLinks]) => ({ pageId, inboundLinks }))
    .sort((a, b) => {
      if (b.inboundLinks !== a.inboundLinks) return b.inboundLinks - a.inboundLinks;
      return a.pageId.localeCompare(b.pageId);
    })
    .slice(0, STRONGEST_PAGES_LIMIT);

  return {
    isolatedPages,
    weakPages,
    strongestPages,
  };
}
