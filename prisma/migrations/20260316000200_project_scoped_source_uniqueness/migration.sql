-- Project-scoped source uniqueness
-- Aligns source capture uniqueness with project ownership boundaries.
-- Date: 2026-03-16

-- =============================================================================
-- SourceItem: URL uniqueness should be project-scoped
-- =============================================================================

DROP INDEX IF EXISTS "SourceItem_url_key";

CREATE UNIQUE INDEX "SourceItem_projectId_url_key"
  ON "SourceItem" ("projectId", "url");

-- =============================================================================
-- SourceFeed: feed URL uniqueness should be project-scoped
-- =============================================================================

DROP INDEX IF EXISTS "SourceFeed_feedUrl_key";

CREATE UNIQUE INDEX "SourceFeed_projectId_feedUrl_key"
  ON "SourceFeed" ("projectId", "feedUrl");
