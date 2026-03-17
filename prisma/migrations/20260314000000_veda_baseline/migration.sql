-- VEDA Baseline Migration
-- Fresh observatory schema. Replaces all previous migrations.
-- Date: 2026-03-14

-- =============================================================================
-- Enums
-- =============================================================================

CREATE TYPE "SourceType" AS ENUM ('rss', 'webpage', 'comment', 'reply', 'video', 'other');
CREATE TYPE "Platform" AS ENUM ('website', 'x', 'youtube', 'github', 'reddit', 'hackernews', 'substack', 'linkedin', 'discord', 'other');
CREATE TYPE "SourceItemStatus" AS ENUM ('ingested', 'triaged', 'used', 'archived');
CREATE TYPE "CapturedBy" AS ENUM ('human', 'llm', 'system');
CREATE TYPE "EntityType" AS ENUM ('sourceItem', 'sourceFeed', 'searchPerformance', 'keywordTarget', 'serpSnapshot', 'cgSurface', 'cgSite', 'cgPage', 'cgContentArchetype', 'cgTopic', 'cgEntity', 'cgInternalLink', 'cgSchemaUsage', 'cgPageTopic', 'cgPageEntity', 'vedaProject');
CREATE TYPE "EventType" AS ENUM ('SOURCE_CAPTURED', 'SOURCE_TRIAGED', 'SYSTEM_CONFIG_CHANGED', 'PROJECT_CREATED', 'KEYWORD_TARGET_CREATED', 'SERP_SNAPSHOT_RECORDED', 'CG_SURFACE_CREATED', 'CG_SITE_CREATED', 'CG_PAGE_CREATED', 'CG_ARCHETYPE_CREATED', 'CG_TOPIC_CREATED', 'CG_ENTITY_CREATED', 'CG_INTERNAL_LINK_CREATED', 'CG_SCHEMA_USAGE_CREATED', 'CG_PAGE_TOPIC_CREATED', 'CG_PAGE_ENTITY_CREATED');
CREATE TYPE "ActorType" AS ENUM ('human', 'llm', 'system');
CREATE TYPE "CgSurfaceType" AS ENUM ('website', 'wiki', 'blog', 'x', 'youtube');
CREATE TYPE "CgPublishingState" AS ENUM ('draft', 'published', 'archived');
CREATE TYPE "CgPageRole" AS ENUM ('primary', 'supporting', 'reviewed', 'compared', 'navigation');
CREATE TYPE "CgLinkRole" AS ENUM ('hub', 'support', 'navigation');

-- =============================================================================
-- Tables
-- =============================================================================

-- Project
CREATE TABLE "Project" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "lifecycleState" TEXT DEFAULT 'created',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Project_pkey" PRIMARY KEY ("id")
);

-- SourceItem
CREATE TABLE "SourceItem" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "sourceType" "SourceType" NOT NULL,
    "platform" "Platform" NOT NULL DEFAULT 'other',
    "url" TEXT NOT NULL,
    "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "capturedBy" "CapturedBy" NOT NULL DEFAULT 'human',
    "contentHash" TEXT NOT NULL,
    "snapshotRef" TEXT,
    "snapshotMime" TEXT,
    "snapshotBytes" INTEGER,
    "operatorIntent" TEXT NOT NULL,
    "notes" TEXT,
    "status" "SourceItemStatus" NOT NULL DEFAULT 'ingested',
    "archivedAt" TIMESTAMP(3),
    "sourceFeedId" UUID,
    "projectId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SourceItem_pkey" PRIMARY KEY ("id")
);

-- SourceFeed
CREATE TABLE "SourceFeed" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "feedUrl" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "platformLabel" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "projectId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SourceFeed_pkey" PRIMARY KEY ("id")
);

-- EventLog
CREATE TABLE "EventLog" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "eventType" "EventType" NOT NULL,
    "entityType" "EntityType" NOT NULL,
    "entityId" UUID NOT NULL,
    "actor" "ActorType" NOT NULL,
    "details" JSONB,
    "projectId" UUID NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "EventLog_pkey" PRIMARY KEY ("id")
);

-- KeywordTarget
CREATE TABLE "KeywordTarget" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "query" TEXT NOT NULL,
    "locale" TEXT NOT NULL,
    "device" TEXT NOT NULL,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "intent" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "KeywordTarget_pkey" PRIMARY KEY ("id")
);

-- SERPSnapshot
CREATE TABLE "SERPSnapshot" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "query" TEXT NOT NULL,
    "locale" TEXT NOT NULL,
    "device" TEXT NOT NULL,
    "capturedAt" TIMESTAMP(3) NOT NULL,
    "validAt" TIMESTAMP(3),
    "rawPayload" JSONB NOT NULL,
    "payloadSchemaVersion" TEXT,
    "aiOverviewStatus" TEXT NOT NULL,
    "aiOverviewText" TEXT,
    "source" TEXT NOT NULL,
    "batchRef" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SERPSnapshot_pkey" PRIMARY KEY ("id")
);

-- SearchPerformance
CREATE TABLE "SearchPerformance" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "pageUrl" TEXT NOT NULL,
    "query" TEXT NOT NULL,
    "impressions" INTEGER NOT NULL,
    "clicks" INTEGER NOT NULL,
    "ctr" DOUBLE PRECISION NOT NULL,
    "avgPosition" DOUBLE PRECISION NOT NULL,
    "dateStart" TIMESTAMP(3) NOT NULL,
    "dateEnd" TIMESTAMP(3) NOT NULL,
    "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SearchPerformance_pkey" PRIMARY KEY ("id")
);

-- SystemConfig
CREATE TABLE "SystemConfig" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updatedBy" "ActorType" NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SystemConfig_pkey" PRIMARY KEY ("id")
);

-- CgSurface
CREATE TABLE "CgSurface" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "type" "CgSurfaceType" NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT,
    "canonicalIdentifier" TEXT,
    "canonicalUrl" TEXT,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CgSurface_pkey" PRIMARY KEY ("id")
);

-- CgSite
CREATE TABLE "CgSite" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "surfaceId" UUID NOT NULL,
    "domain" TEXT NOT NULL,
    "framework" TEXT,
    "isCanonical" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CgSite_pkey" PRIMARY KEY ("id")
);

-- CgContentArchetype
CREATE TABLE "CgContentArchetype" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CgContentArchetype_pkey" PRIMARY KEY ("id")
);

-- CgPage
CREATE TABLE "CgPage" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "contentArchetypeId" UUID,
    "url" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "canonicalUrl" TEXT,
    "publishingState" "CgPublishingState" NOT NULL DEFAULT 'draft',
    "isIndexable" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CgPage_pkey" PRIMARY KEY ("id")
);

-- CgTopic
CREATE TABLE "CgTopic" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CgTopic_pkey" PRIMARY KEY ("id")
);

-- CgEntity
CREATE TABLE "CgEntity" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CgEntity_pkey" PRIMARY KEY ("id")
);

-- CgPageTopic
CREATE TABLE "CgPageTopic" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "pageId" UUID NOT NULL,
    "topicId" UUID NOT NULL,
    "role" "CgPageRole" NOT NULL DEFAULT 'supporting',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CgPageTopic_pkey" PRIMARY KEY ("id")
);

-- CgPageEntity
CREATE TABLE "CgPageEntity" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "pageId" UUID NOT NULL,
    "entityId" UUID NOT NULL,
    "role" "CgPageRole" NOT NULL DEFAULT 'supporting',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CgPageEntity_pkey" PRIMARY KEY ("id")
);

-- CgInternalLink
CREATE TABLE "CgInternalLink" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "sourcePageId" UUID NOT NULL,
    "targetPageId" UUID NOT NULL,
    "anchorText" TEXT,
    "linkRole" "CgLinkRole" NOT NULL DEFAULT 'support',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CgInternalLink_pkey" PRIMARY KEY ("id")
);

-- CgSchemaUsage
CREATE TABLE "CgSchemaUsage" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "pageId" UUID NOT NULL,
    "schemaType" TEXT NOT NULL,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CgSchemaUsage_pkey" PRIMARY KEY ("id")
);

-- =============================================================================
-- Unique indexes
-- =============================================================================

CREATE UNIQUE INDEX "Project_slug_key" ON "Project"("slug");
CREATE UNIQUE INDEX "SourceItem_url_key" ON "SourceItem"("url");
CREATE UNIQUE INDEX "SourceFeed_feedUrl_key" ON "SourceFeed"("feedUrl");
CREATE UNIQUE INDEX "KeywordTarget_projectId_query_locale_device_key" ON "KeywordTarget"("projectId", "query", "locale", "device");
CREATE UNIQUE INDEX "SERPSnapshot_projectId_query_locale_device_capturedAt_key" ON "SERPSnapshot"("projectId", "query", "locale", "device", "capturedAt");
CREATE UNIQUE INDEX "SearchPerformance_projectId_query_pageUrl_dateStart_dateEnd_key" ON "SearchPerformance"("projectId", "query", "pageUrl", "dateStart", "dateEnd");
CREATE UNIQUE INDEX "SystemConfig_key_key" ON "SystemConfig"("key");
CREATE UNIQUE INDEX "CgSurface_projectId_key_key" ON "CgSurface"("projectId", "key");
CREATE UNIQUE INDEX "CgSite_projectId_domain_key" ON "CgSite"("projectId", "domain");
CREATE UNIQUE INDEX "CgContentArchetype_projectId_key_key" ON "CgContentArchetype"("projectId", "key");
CREATE UNIQUE INDEX "CgPage_projectId_url_key" ON "CgPage"("projectId", "url");
CREATE UNIQUE INDEX "CgTopic_projectId_key_key" ON "CgTopic"("projectId", "key");
CREATE UNIQUE INDEX "CgEntity_projectId_key_key" ON "CgEntity"("projectId", "key");
CREATE UNIQUE INDEX "CgPageTopic_pageId_topicId_key" ON "CgPageTopic"("pageId", "topicId");
CREATE UNIQUE INDEX "CgPageEntity_pageId_entityId_key" ON "CgPageEntity"("pageId", "entityId");
CREATE UNIQUE INDEX "CgInternalLink_sourcePageId_targetPageId_key" ON "CgInternalLink"("sourcePageId", "targetPageId");
CREATE UNIQUE INDEX "CgSchemaUsage_pageId_schemaType_key" ON "CgSchemaUsage"("pageId", "schemaType");

-- =============================================================================
-- Non-unique indexes
-- =============================================================================

CREATE INDEX "SourceItem_projectId_status_capturedAt_idx" ON "SourceItem"("projectId", "status", "capturedAt");
CREATE INDEX "SourceItem_sourceType_platform_idx" ON "SourceItem"("sourceType", "platform");
CREATE INDEX "SourceFeed_projectId_idx" ON "SourceFeed"("projectId");
CREATE INDEX "EventLog_projectId_timestamp_id_idx" ON "EventLog"("projectId", "timestamp", "id");
CREATE INDEX "EventLog_entityType_entityId_timestamp_idx" ON "EventLog"("entityType", "entityId", "timestamp");
CREATE INDEX "KeywordTarget_projectId_idx" ON "KeywordTarget"("projectId");
CREATE INDEX "SERPSnapshot_projectId_query_locale_device_capturedAt_idx" ON "SERPSnapshot"("projectId", "query", "locale", "device", "capturedAt");
CREATE INDEX "SERPSnapshot_projectId_idx" ON "SERPSnapshot"("projectId");
CREATE INDEX "SearchPerformance_projectId_capturedAt_idx" ON "SearchPerformance"("projectId", "capturedAt");
CREATE INDEX "SearchPerformance_projectId_pageUrl_dateStart_idx" ON "SearchPerformance"("projectId", "pageUrl", "dateStart");
CREATE INDEX "SearchPerformance_projectId_query_dateStart_idx" ON "SearchPerformance"("projectId", "query", "dateStart");
CREATE INDEX "CgSurface_projectId_type_idx" ON "CgSurface"("projectId", "type");
CREATE INDEX "CgSite_projectId_surfaceId_idx" ON "CgSite"("projectId", "surfaceId");
CREATE INDEX "CgContentArchetype_projectId_idx" ON "CgContentArchetype"("projectId");
CREATE INDEX "CgPage_projectId_siteId_publishingState_idx" ON "CgPage"("projectId", "siteId", "publishingState");
CREATE INDEX "CgTopic_projectId_idx" ON "CgTopic"("projectId");
CREATE INDEX "CgEntity_projectId_entityType_idx" ON "CgEntity"("projectId", "entityType");
CREATE INDEX "CgPageTopic_projectId_topicId_idx" ON "CgPageTopic"("projectId", "topicId");
CREATE INDEX "CgPageEntity_projectId_entityId_idx" ON "CgPageEntity"("projectId", "entityId");
CREATE INDEX "CgInternalLink_projectId_sourcePageId_idx" ON "CgInternalLink"("projectId", "sourcePageId");
CREATE INDEX "CgInternalLink_projectId_targetPageId_idx" ON "CgInternalLink"("projectId", "targetPageId");
CREATE INDEX "CgSchemaUsage_projectId_schemaType_idx" ON "CgSchemaUsage"("projectId", "schemaType");
CREATE INDEX "CgSchemaUsage_projectId_pageId_idx" ON "CgSchemaUsage"("projectId", "pageId");

-- =============================================================================
-- Foreign keys
-- =============================================================================

-- SourceItem
ALTER TABLE "SourceItem" ADD CONSTRAINT "SourceItem_sourceFeedId_fkey" FOREIGN KEY ("sourceFeedId") REFERENCES "SourceFeed"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "SourceItem" ADD CONSTRAINT "SourceItem_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- SourceFeed
ALTER TABLE "SourceFeed" ADD CONSTRAINT "SourceFeed_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- EventLog
ALTER TABLE "EventLog" ADD CONSTRAINT "EventLog_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- KeywordTarget
ALTER TABLE "KeywordTarget" ADD CONSTRAINT "KeywordTarget_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- SERPSnapshot
ALTER TABLE "SERPSnapshot" ADD CONSTRAINT "SERPSnapshot_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- SearchPerformance
ALTER TABLE "SearchPerformance" ADD CONSTRAINT "SearchPerformance_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CgSurface
ALTER TABLE "CgSurface" ADD CONSTRAINT "CgSurface_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CgSite
ALTER TABLE "CgSite" ADD CONSTRAINT "CgSite_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgSite" ADD CONSTRAINT "CgSite_surfaceId_fkey" FOREIGN KEY ("surfaceId") REFERENCES "CgSurface"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CgContentArchetype
ALTER TABLE "CgContentArchetype" ADD CONSTRAINT "CgContentArchetype_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CgPage
ALTER TABLE "CgPage" ADD CONSTRAINT "CgPage_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgPage" ADD CONSTRAINT "CgPage_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "CgSite"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgPage" ADD CONSTRAINT "CgPage_contentArchetypeId_fkey" FOREIGN KEY ("contentArchetypeId") REFERENCES "CgContentArchetype"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CgTopic
ALTER TABLE "CgTopic" ADD CONSTRAINT "CgTopic_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CgEntity
ALTER TABLE "CgEntity" ADD CONSTRAINT "CgEntity_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CgPageTopic
ALTER TABLE "CgPageTopic" ADD CONSTRAINT "CgPageTopic_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgPageTopic" ADD CONSTRAINT "CgPageTopic_pageId_fkey" FOREIGN KEY ("pageId") REFERENCES "CgPage"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CgPageTopic" ADD CONSTRAINT "CgPageTopic_topicId_fkey" FOREIGN KEY ("topicId") REFERENCES "CgTopic"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CgPageEntity
ALTER TABLE "CgPageEntity" ADD CONSTRAINT "CgPageEntity_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgPageEntity" ADD CONSTRAINT "CgPageEntity_pageId_fkey" FOREIGN KEY ("pageId") REFERENCES "CgPage"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CgPageEntity" ADD CONSTRAINT "CgPageEntity_entityId_fkey" FOREIGN KEY ("entityId") REFERENCES "CgEntity"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CgInternalLink
ALTER TABLE "CgInternalLink" ADD CONSTRAINT "CgInternalLink_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgInternalLink" ADD CONSTRAINT "CgInternalLink_sourcePageId_fkey" FOREIGN KEY ("sourcePageId") REFERENCES "CgPage"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CgInternalLink" ADD CONSTRAINT "CgInternalLink_targetPageId_fkey" FOREIGN KEY ("targetPageId") REFERENCES "CgPage"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CgSchemaUsage
ALTER TABLE "CgSchemaUsage" ADD CONSTRAINT "CgSchemaUsage_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "CgSchemaUsage" ADD CONSTRAINT "CgSchemaUsage_pageId_fkey" FOREIGN KEY ("pageId") REFERENCES "CgPage"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- =============================================================================
-- Custom: Seed default VEDA project
-- =============================================================================

INSERT INTO "Project" ("id", "name", "slug", "description", "createdAt", "updatedAt")
VALUES (
    '00000000-0000-4000-a000-000000000001',
    'VEDA',
    'veda',
    'Default VEDA observatory project',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- =============================================================================
-- Custom: Project lifecycleState constraint
-- =============================================================================

ALTER TABLE "Project" ADD CONSTRAINT "Project_lifecycleState_check"
  CHECK ("lifecycleState" IN ('created', 'bootstrapping', 'active', 'paused', 'archived'));

-- =============================================================================
-- Custom: CgSurface partial unique index (canonicalIdentifier)
-- Not expressible as Prisma @@unique with partial filter.
-- =============================================================================

CREATE UNIQUE INDEX "CgSurface_projectId_type_canonicalIdentifier_key"
  ON "CgSurface" ("projectId", "type", "canonicalIdentifier")
  WHERE "canonicalIdentifier" IS NOT NULL;

-- =============================================================================
-- Custom: CgPageTopic — cross-project consistency trigger
-- Enforces: CgPageTopic.projectId must equal CgPage.projectId AND CgTopic.projectId
-- =============================================================================

CREATE OR REPLACE FUNCTION enforce_cg_page_topic_project_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_page_project  uuid;
  v_topic_project uuid;
BEGIN
  SELECT "projectId" INTO v_page_project  FROM "CgPage"  WHERE "id" = NEW."pageId";
  SELECT "projectId" INTO v_topic_project FROM "CgTopic" WHERE "id" = NEW."topicId";

  IF v_page_project IS NULL THEN
    RAISE EXCEPTION 'CgPageTopic: page % not found', NEW."pageId"
      USING ERRCODE = '23503';
  END IF;

  IF v_topic_project IS NULL THEN
    RAISE EXCEPTION 'CgPageTopic: topic % not found', NEW."topicId"
      USING ERRCODE = '23503';
  END IF;

  IF v_page_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgPageTopic: page.projectId % does not match row.projectId %',
      v_page_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  IF v_topic_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgPageTopic: topic.projectId % does not match row.projectId %',
      v_topic_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cg_page_topic_project_integrity
  BEFORE INSERT OR UPDATE ON "CgPageTopic"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_cg_page_topic_project_integrity();

-- =============================================================================
-- Custom: CgPageEntity — cross-project consistency trigger
-- Enforces: CgPageEntity.projectId must equal CgPage.projectId AND CgEntity.projectId
-- =============================================================================

CREATE OR REPLACE FUNCTION enforce_cg_page_entity_project_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_page_project   uuid;
  v_entity_project uuid;
BEGIN
  SELECT "projectId" INTO v_page_project   FROM "CgPage"   WHERE "id" = NEW."pageId";
  SELECT "projectId" INTO v_entity_project FROM "CgEntity" WHERE "id" = NEW."entityId";

  IF v_page_project IS NULL THEN
    RAISE EXCEPTION 'CgPageEntity: page % not found', NEW."pageId"
      USING ERRCODE = '23503';
  END IF;

  IF v_entity_project IS NULL THEN
    RAISE EXCEPTION 'CgPageEntity: entity % not found', NEW."entityId"
      USING ERRCODE = '23503';
  END IF;

  IF v_page_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgPageEntity: page.projectId % does not match row.projectId %',
      v_page_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  IF v_entity_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgPageEntity: entity.projectId % does not match row.projectId %',
      v_entity_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cg_page_entity_project_integrity
  BEFORE INSERT OR UPDATE ON "CgPageEntity"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_cg_page_entity_project_integrity();
