/**
 * Archetype Distribution — Content Graph Intelligence (Phase 2)
 *
 * Analyzes page archetype distribution across a project.
 * Compute-on-read. No writes. No side effects.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 *
 * Supports future SERP archetype mismatch detection (Phase 3).
 */
import { prisma } from "@/lib/prisma";

export interface ArchetypeEntry {
  archetypeId: string;
  count: number;
}

export interface ArchetypeDistributionResult {
  archetypes: ArchetypeEntry[];
  pagesWithoutArchetype: number;
}

/**
 * Compute archetype distribution for a project.
 *
 * archetypes: per-archetype page counts, ordered by count desc, archetypeId asc.
 * pagesWithoutArchetype: count of pages with null contentArchetypeId.
 */
export async function computeArchetypeDistribution(
  projectId: string
): Promise<ArchetypeDistributionResult> {
  const [archetypeGroups, pagesWithoutArchetype] = await Promise.all([
    prisma.cgPage.groupBy({
      by: ["contentArchetypeId"],
      where: {
        projectId,
        contentArchetypeId: { not: null },
      },
      _count: { id: true },
    }),
    prisma.cgPage.count({
      where: {
        projectId,
        contentArchetypeId: null,
      },
    }),
  ]);

  const archetypes: ArchetypeEntry[] = archetypeGroups
    .map((g) => ({
      archetypeId: g.contentArchetypeId as string,
      count: g._count.id,
    }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.archetypeId.localeCompare(b.archetypeId);
    });

  return {
    archetypes,
    pagesWithoutArchetype,
  };
}
