/**
 * Topic Coverage — Content Graph Intelligence (Phase 2)
 *
 * Computes topic distribution signals for a project.
 * Compute-on-read. No writes. No side effects.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 */
import { prisma } from "@/lib/prisma";

export interface TopicFrequencyEntry {
  topicId: string;
  count: number;
}

export interface TopicCoverageResult {
  topicCount: number;
  pagesWithTopics: number;
  orphanTopics: string[];
  topicFrequency: TopicFrequencyEntry[];
}

/**
 * Compute topic coverage for a project.
 *
 * orphanTopics: topics registered in the project that appear on zero pages.
 * topicFrequency: per-topic page counts, deterministically ordered by count desc, topicId asc.
 */
export async function computeTopicCoverage(
  projectId: string
): Promise<TopicCoverageResult> {
  const [allTopics, pageTopicGroups, distinctPageIds] = await Promise.all([
    prisma.cgTopic.findMany({
      where: { projectId },
      select: { id: true },
      orderBy: [{ id: "asc" }],
    }),
    prisma.cgPageTopic.groupBy({
      by: ["topicId"],
      where: { projectId },
      _count: { pageId: true },
    }),
    prisma.cgPageTopic.findMany({
      where: { projectId },
      select: { pageId: true },
      distinct: ["pageId"],
    }),
  ]);

  const topicCount = allTopics.length;

  // Build frequency map
  const frequencyMap = new Map<string, number>();
  for (const g of pageTopicGroups) {
    frequencyMap.set(g.topicId, g._count.pageId);
  }

  // orphanTopics: topics with zero page appearances
  const orphanTopics = allTopics
    .filter((t) => !frequencyMap.has(t.id))
    .map((t) => t.id);

  // topicFrequency: deterministic — count desc, topicId asc
  const topicFrequency: TopicFrequencyEntry[] = pageTopicGroups
    .map((g) => ({ topicId: g.topicId, count: g._count.pageId }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.topicId.localeCompare(b.topicId);
    });

  return {
    topicCount,
    pagesWithTopics: distinctPageIds.length,
    orphanTopics,
    topicFrequency,
  };
}
