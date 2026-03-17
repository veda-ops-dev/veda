import { PrismaClient, CgLinkRole, CgPageRole, CgPublishingState, CgSurfaceType, Platform, SourceType, ProjectLifecycleState, AiOverviewStatus } from "@prisma/client";
import { randomUUID } from "node:crypto";

const prisma = new PrismaClient({ log: ["error", "warn"] });

function id() {
  return randomUUID();
}

function stamp() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

type TestResult = { name: string; ok: boolean; detail?: string };
const results: TestResult[] = [];

function record(name: string, ok: boolean, detail?: string) {
  results.push({ name, ok, detail });
  const prefix = ok ? "PASS" : "FAIL";
  console.log(`${prefix}  ${name}${detail ? ` — ${detail}` : ""}`);
}

async function expectPass(name: string, fn: () => Promise<void>) {
  try {
    await fn();
    record(name, true);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    record(name, false, message);
  }
}

async function expectReject(name: string, fn: () => Promise<void>) {
  try {
    await fn();
    record(name, false, "operation unexpectedly succeeded");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    record(name, true, message);
  }
}

async function cleanupProjects(projectIds: string[]) {
  if (projectIds.length === 0) return;
  await prisma.eventLog.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgSchemaUsage.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgInternalLink.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgPageEntity.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgPageTopic.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgPage.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgEntity.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgTopic.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgContentArchetype.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgSite.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.cgSurface.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.searchPerformance.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.sERPSnapshot.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.keywordTarget.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.sourceItem.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.sourceFeed.deleteMany({ where: { projectId: { in: projectIds } } });
  await prisma.project.deleteMany({ where: { id: { in: projectIds } } });
}

async function main() {
  const s = stamp();
  const projectAId = id();
  const projectBId = id();
  const projectIds = [projectAId, projectBId];

  try {
    await cleanupProjects(projectIds);

    await prisma.project.createMany({
      data: [
        {
          id: projectAId,
          name: `Hammer A ${s}`,
          slug: `hammer-a-${s}`,
          lifecycleState: ProjectLifecycleState.active,
        },
        {
          id: projectBId,
          name: `Hammer B ${s}`,
          slug: `hammer-b-${s}`,
          lifecycleState: ProjectLifecycleState.active,
        },
      ],
    });

    const [surfaceA, surfaceB] = await Promise.all([
      prisma.cgSurface.create({
        data: {
          projectId: projectAId,
          type: CgSurfaceType.website,
          key: `surface-a-${s}`,
          canonicalIdentifier: `surface-a-${s}`,
        },
      }),
      prisma.cgSurface.create({
        data: {
          projectId: projectBId,
          type: CgSurfaceType.website,
          key: `surface-b-${s}`,
          canonicalIdentifier: `surface-b-${s}`,
        },
      }),
    ]);

    const [siteA, siteB] = await Promise.all([
      prisma.cgSite.create({
        data: {
          projectId: projectAId,
          surfaceId: surfaceA.id,
          domain: `a-${s}.example.com`,
        },
      }),
      prisma.cgSite.create({
        data: {
          projectId: projectBId,
          surfaceId: surfaceB.id,
          domain: `b-${s}.example.com`,
        },
      }),
    ]);

    const [archetypeA, archetypeB] = await Promise.all([
      prisma.cgContentArchetype.create({
        data: {
          projectId: projectAId,
          key: `guide-a-${s}`,
          label: `Guide A ${s}`,
        },
      }),
      prisma.cgContentArchetype.create({
        data: {
          projectId: projectBId,
          key: `guide-b-${s}`,
          label: `Guide B ${s}`,
        },
      }),
    ]);

    const [pageA1, pageA2, pageB1] = await Promise.all([
      prisma.cgPage.create({
        data: {
          projectId: projectAId,
          siteId: siteA.id,
          contentArchetypeId: archetypeA.id,
          url: `https://a-${s}.example.com/page-1`,
          title: `Page A1 ${s}`,
          publishingState: CgPublishingState.published,
        },
      }),
      prisma.cgPage.create({
        data: {
          projectId: projectAId,
          siteId: siteA.id,
          contentArchetypeId: archetypeA.id,
          url: `https://a-${s}.example.com/page-2`,
          title: `Page A2 ${s}`,
          publishingState: CgPublishingState.published,
        },
      }),
      prisma.cgPage.create({
        data: {
          projectId: projectBId,
          siteId: siteB.id,
          contentArchetypeId: archetypeB.id,
          url: `https://b-${s}.example.com/page-1`,
          title: `Page B1 ${s}`,
          publishingState: CgPublishingState.published,
        },
      }),
    ]);

    const [topicA, topicB] = await Promise.all([
      prisma.cgTopic.create({
        data: {
          projectId: projectAId,
          key: `topic-a-${s}`,
          label: `Topic A ${s}`,
        },
      }),
      prisma.cgTopic.create({
        data: {
          projectId: projectBId,
          key: `topic-b-${s}`,
          label: `Topic B ${s}`,
        },
      }),
    ]);

    const [entityA, entityB] = await Promise.all([
      prisma.cgEntity.create({
        data: {
          projectId: projectAId,
          key: `entity-a-${s}`,
          label: `Entity A ${s}`,
          entityType: "concept",
        },
      }),
      prisma.cgEntity.create({
        data: {
          projectId: projectBId,
          key: `entity-b-${s}`,
          label: `Entity B ${s}`,
          entityType: "concept",
        },
      }),
    ]);

    await expectReject("CgSite rejects cross-project surface linkage", async () => {
      await prisma.cgSite.create({
        data: {
          projectId: projectAId,
          surfaceId: surfaceB.id,
          domain: `site-cross-${s}.example.com`,
        },
      });
    });

    await expectReject("CgPage rejects cross-project site linkage", async () => {
      await prisma.cgPage.create({
        data: {
          projectId: projectAId,
          siteId: siteB.id,
          contentArchetypeId: archetypeA.id,
          url: `https://cross-site-${s}.example.com/page`,
          title: "Cross site page",
        },
      });
    });

    await expectReject("CgPage rejects cross-project archetype linkage", async () => {
      await prisma.cgPage.create({
        data: {
          projectId: projectAId,
          siteId: siteA.id,
          contentArchetypeId: archetypeB.id,
          url: `https://cross-archetype-${s}.example.com/page`,
          title: "Cross archetype page",
        },
      });
    });

    await expectReject("CgInternalLink rejects cross-project page linkage", async () => {
      await prisma.cgInternalLink.create({
        data: {
          projectId: projectAId,
          sourcePageId: pageA1.id,
          targetPageId: pageB1.id,
          linkRole: CgLinkRole.support,
        },
      });
    });

    await expectReject("CgSchemaUsage rejects cross-project page linkage", async () => {
      await prisma.cgSchemaUsage.create({
        data: {
          projectId: projectAId,
          pageId: pageB1.id,
          schemaType: "Article",
        },
      });
    });

    await expectReject("CgPageTopic rejects cross-project topic linkage", async () => {
      await prisma.cgPageTopic.create({
        data: {
          projectId: projectAId,
          pageId: pageA1.id,
          topicId: topicB.id,
          role: CgPageRole.primary,
        },
      });
    });

    await expectReject("CgPageEntity rejects cross-project entity linkage", async () => {
      await prisma.cgPageEntity.create({
        data: {
          projectId: projectAId,
          pageId: pageA1.id,
          entityId: entityB.id,
          role: CgPageRole.primary,
        },
      });
    });

    await expectPass("SourceItem allows same URL in different projects", async () => {
      const url = `https://shared-${s}.example.com/source-item`;
      await prisma.sourceItem.create({
        data: {
          projectId: projectAId,
          sourceType: SourceType.webpage,
          platform: Platform.website,
          url,
          contentHash: `hash-a-${s}`,
          operatorIntent: "hammer",
        },
      });
      await prisma.sourceItem.create({
        data: {
          projectId: projectBId,
          sourceType: SourceType.webpage,
          platform: Platform.website,
          url,
          contentHash: `hash-b-${s}`,
          operatorIntent: "hammer",
        },
      });
    });

    await expectPass("SourceFeed allows same feed URL in different projects", async () => {
      const feedUrl = `https://shared-${s}.example.com/feed.xml`;
      await prisma.sourceFeed.create({
        data: {
          projectId: projectAId,
          name: `Feed A ${s}`,
          feedUrl,
          platform: Platform.website,
        },
      });
      await prisma.sourceFeed.create({
        data: {
          projectId: projectBId,
          name: `Feed B ${s}`,
          feedUrl,
          platform: Platform.website,
        },
      });
    });

    await expectPass("Project accepts valid lifecycle enum value", async () => {
      await prisma.project.update({
        where: { id: projectAId },
        data: { lifecycleState: ProjectLifecycleState.paused },
      });
    });

    await expectPass("SERPSnapshot accepts valid AI overview enum value", async () => {
      await prisma.sERPSnapshot.create({
        data: {
          projectId: projectAId,
          query: `query-${s}`,
          locale: "en-US",
          device: "desktop",
          capturedAt: new Date(),
          rawPayload: { ok: true, source: "hammer" },
          aiOverviewStatus: AiOverviewStatus.present,
          aiOverviewText: "Present",
          source: "hammer",
        },
      });
    });

    await expectReject("Project rejects invalid lifecycle enum value", async () => {
      await prisma.$executeRawUnsafe(
        `UPDATE "Project" SET "lifecycleState" = 'nonsense' WHERE "id" = '${projectAId}'`
      );
    });

    await expectReject("SERPSnapshot rejects invalid AI overview enum value", async () => {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "SERPSnapshot" ("id", "projectId", "query", "locale", "device", "capturedAt", "rawPayload", "aiOverviewStatus", "source", "createdAt") VALUES ('${id()}', '${projectAId}', 'invalid-${s}', 'en-US', 'desktop', CURRENT_TIMESTAMP, '{"ok":true}', 'broken_status', 'hammer', CURRENT_TIMESTAMP)`
      );
    });
  } finally {
    await cleanupProjects(projectIds).catch((error) => {
      console.error("Cleanup failed:", error);
    });
    await prisma.$disconnect();
  }

  const failed = results.filter((result) => !result.ok);
  console.log(`\nSummary: ${results.length - failed.length}/${results.length} passed`);

  if (failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

