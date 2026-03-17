/**
 * Entity Coverage — Content Graph Intelligence (Phase 2)
 *
 * Computes entity coverage signals for a project.
 * Compute-on-read. No writes. No side effects.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 */
import { prisma } from "@/lib/prisma";

export interface EntityFrequencyEntry {
  entityId: string;
  count: number;
}

export interface EntityCoverageResult {
  entityCount: number;
  pagesWithEntities: number;
  entityFrequency: EntityFrequencyEntry[];
}

/**
 * Compute entity coverage for a project.
 *
 * entityFrequency: per-entity page counts, deterministically ordered by count desc, entityId asc.
 * Supports future SERP entity dominance comparison (Phase 3).
 */
export async function computeEntityCoverage(
  projectId: string
): Promise<EntityCoverageResult> {
  const [allEntities, pageEntityGroups, distinctPageIds] = await Promise.all([
    prisma.cgEntity.findMany({
      where: { projectId },
      select: { id: true },
      orderBy: [{ id: "asc" }],
    }),
    prisma.cgPageEntity.groupBy({
      by: ["entityId"],
      where: { projectId },
      _count: { pageId: true },
    }),
    prisma.cgPageEntity.findMany({
      where: { projectId },
      select: { pageId: true },
      distinct: ["pageId"],
    }),
  ]);

  const entityCount = allEntities.length;

  const entityFrequency: EntityFrequencyEntry[] = pageEntityGroups
    .map((g) => ({ entityId: g.entityId, count: g._count.pageId }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.entityId.localeCompare(b.entityId);
    });

  return {
    entityCount,
    pagesWithEntities: distinctPageIds.length,
    entityFrequency,
  };
}
