/**
 * load-brain-input.ts — VEDA Brain Input Loader
 *
 * Centralizes all Prisma fetching required for Brain Phase 1 diagnostics.
 * Returns a typed VedaBrainInput that brain modules consume as pure data.
 *
 * Rules:
 *   - Read-only. No mutations. No EventLog writes.
 *   - Project-scoped via projectId parameter.
 *   - All queries run concurrently via Promise.all.
 *   - Brain modules receive this input and perform no DB access themselves.
 */
import { prisma } from "@/lib/prisma";

// =============================================================================
// Raw input types — shaped for brain module consumption
// =============================================================================

export interface BrainKeywordTarget {
  id: string;
  query: string;
  locale: string;
  device: string;
  isPrimary: boolean;
  intent: string | null;
}

export interface BrainPage {
  id: string;
  url: string;
  title: string;
  siteId: string;
  contentArchetypeId: string | null;
  publishingState: string;
  isIndexable: boolean;
}

export interface BrainPageTopic {
  pageId: string;
  topicId: string;
  role: string;
}

export interface BrainPageEntity {
  pageId: string;
  entityId: string;
  role: string;
}

export interface BrainTopic {
  id: string;
  key: string;
  label: string;
}

export interface BrainEntity {
  id: string;
  key: string;
  label: string;
  entityType: string;
}

export interface BrainContentArchetype {
  id: string;
  key: string;
  label: string;
}

export interface BrainSchemaUsage {
  pageId: string;
  schemaType: string;
  isPrimary: boolean;
}

export interface BrainInternalLink {
  sourcePageId: string;
  targetPageId: string;
  anchorText: string | null;
  linkRole: string;
}

export interface BrainSerpSnapshot {
  query: string;
  locale: string;
  device: string;
  capturedAt: Date;
  rawPayload: unknown;
  aiOverviewStatus: string;
}

export interface BrainSearchPerformance {
  pageUrl: string;
  query: string;
  impressions: number;
  clicks: number;
  ctr: number;
  avgPosition: number;
}

// =============================================================================
// Aggregated brain input
// =============================================================================

export interface VedaBrainInput {
  projectId: string;
  keywordTargets: BrainKeywordTarget[];
  pages: BrainPage[];
  topics: BrainTopic[];
  entities: BrainEntity[];
  archetypes: BrainContentArchetype[];
  pageTopics: BrainPageTopic[];
  pageEntities: BrainPageEntity[];
  schemaUsages: BrainSchemaUsage[];
  internalLinks: BrainInternalLink[];
  latestSnapshotsPerKeyword: BrainSerpSnapshot[];
  searchPerformance: BrainSearchPerformance[];
}

// =============================================================================
// Loader
// =============================================================================

/**
 * Load all raw inputs for VEDA Brain Phase 1 diagnostics.
 *
 * For SERP snapshots, fetches only the most recent snapshot per keyword target
 * (query+locale+device) to keep the input bounded.
 */
export async function loadBrainInput(
  projectId: string
): Promise<VedaBrainInput> {
  const [
    keywordTargets,
    pages,
    topics,
    entities,
    archetypes,
    pageTopics,
    pageEntities,
    schemaUsages,
    internalLinks,
    serpSnapshots,
    searchPerformance,
  ] = await Promise.all([
    prisma.keywordTarget.findMany({
      where: { projectId },
      select: {
        id: true,
        query: true,
        locale: true,
        device: true,
        isPrimary: true,
        intent: true,
      },
      orderBy: [{ query: "asc" }, { locale: "asc" }, { device: "asc" }],
    }),
    prisma.cgPage.findMany({
      where: { projectId },
      select: {
        id: true,
        url: true,
        title: true,
        siteId: true,
        contentArchetypeId: true,
        publishingState: true,
        isIndexable: true,
      },
      orderBy: [{ url: "asc" }],
    }),
    prisma.cgTopic.findMany({
      where: { projectId },
      select: { id: true, key: true, label: true },
      orderBy: [{ key: "asc" }],
    }),
    prisma.cgEntity.findMany({
      where: { projectId },
      select: { id: true, key: true, label: true, entityType: true },
      orderBy: [{ key: "asc" }],
    }),
    prisma.cgContentArchetype.findMany({
      where: { projectId },
      select: { id: true, key: true, label: true },
      orderBy: [{ key: "asc" }],
    }),
    prisma.cgPageTopic.findMany({
      where: { projectId },
      select: { pageId: true, topicId: true, role: true },
      orderBy: [{ pageId: "asc" }, { topicId: "asc" }],
    }),
    prisma.cgPageEntity.findMany({
      where: { projectId },
      select: { pageId: true, entityId: true, role: true },
      orderBy: [{ pageId: "asc" }, { entityId: "asc" }],
    }),
    prisma.cgSchemaUsage.findMany({
      where: { projectId },
      select: { pageId: true, schemaType: true, isPrimary: true },
      orderBy: [{ pageId: "asc" }, { schemaType: "asc" }],
    }),
    prisma.cgInternalLink.findMany({
      where: { projectId },
      select: {
        sourcePageId: true,
        targetPageId: true,
        anchorText: true,
        linkRole: true,
      },
      orderBy: [{ sourcePageId: "asc" }, { targetPageId: "asc" }],
    }),
    // Latest snapshot per keyword target — raw SQL for "distinct on" efficiency
    prisma.$queryRaw<BrainSerpSnapshot[]>`
      SELECT DISTINCT ON (query, locale, device)
        query, locale, device, "capturedAt", "rawPayload", "aiOverviewStatus"
      FROM "SERPSnapshot"
      WHERE "projectId" = ${projectId}::uuid
      ORDER BY query, locale, device, "capturedAt" DESC
    `,
    prisma.searchPerformance.findMany({
      where: { projectId },
      select: {
        pageUrl: true,
        query: true,
        impressions: true,
        clicks: true,
        ctr: true,
        avgPosition: true,
      },
      orderBy: [{ query: "asc" }, { pageUrl: "asc" }],
    }),
  ]);

  return {
    projectId,
    keywordTargets: keywordTargets as BrainKeywordTarget[],
    pages: pages as BrainPage[],
    topics,
    entities,
    archetypes,
    pageTopics: pageTopics as BrainPageTopic[],
    pageEntities: pageEntities as BrainPageEntity[],
    schemaUsages: schemaUsages as BrainSchemaUsage[],
    internalLinks: internalLinks as BrainInternalLink[],
    latestSnapshotsPerKeyword: serpSnapshots,
    searchPerformance,
  };
}
