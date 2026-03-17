-- Content Graph project integrity completion
-- Adds DB-level enforcement for remaining cross-project consistency paths.
-- Date: 2026-03-16

-- =============================================================================
-- Custom: CgSite — project must match referenced CgSurface
-- =============================================================================

CREATE OR REPLACE FUNCTION enforce_cg_site_project_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_surface_project uuid;
BEGIN
  SELECT "projectId" INTO v_surface_project
  FROM "CgSurface"
  WHERE "id" = NEW."surfaceId";

  IF v_surface_project IS NULL THEN
    RAISE EXCEPTION 'CgSite: surface % not found', NEW."surfaceId"
      USING ERRCODE = '23503';
  END IF;

  IF v_surface_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgSite: surface.projectId % does not match row.projectId %',
      v_surface_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cg_site_project_integrity
  BEFORE INSERT OR UPDATE ON "CgSite"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_cg_site_project_integrity();

-- =============================================================================
-- Custom: CgPage — project must match referenced CgSite and CgContentArchetype
-- =============================================================================

CREATE OR REPLACE FUNCTION enforce_cg_page_project_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_site_project uuid;
  v_archetype_project uuid;
BEGIN
  SELECT "projectId" INTO v_site_project
  FROM "CgSite"
  WHERE "id" = NEW."siteId";

  IF v_site_project IS NULL THEN
    RAISE EXCEPTION 'CgPage: site % not found', NEW."siteId"
      USING ERRCODE = '23503';
  END IF;

  IF v_site_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgPage: site.projectId % does not match row.projectId %',
      v_site_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  IF NEW."contentArchetypeId" IS NOT NULL THEN
    SELECT "projectId" INTO v_archetype_project
    FROM "CgContentArchetype"
    WHERE "id" = NEW."contentArchetypeId";

    IF v_archetype_project IS NULL THEN
      RAISE EXCEPTION 'CgPage: contentArchetype % not found', NEW."contentArchetypeId"
        USING ERRCODE = '23503';
    END IF;

    IF v_archetype_project <> NEW."projectId" THEN
      RAISE EXCEPTION 'CgPage: contentArchetype.projectId % does not match row.projectId %',
        v_archetype_project, NEW."projectId"
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cg_page_project_integrity
  BEFORE INSERT OR UPDATE ON "CgPage"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_cg_page_project_integrity();

-- =============================================================================
-- Custom: CgInternalLink — project must match both referenced pages
-- =============================================================================

CREATE OR REPLACE FUNCTION enforce_cg_internal_link_project_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_source_project uuid;
  v_target_project uuid;
BEGIN
  SELECT "projectId" INTO v_source_project
  FROM "CgPage"
  WHERE "id" = NEW."sourcePageId";

  SELECT "projectId" INTO v_target_project
  FROM "CgPage"
  WHERE "id" = NEW."targetPageId";

  IF v_source_project IS NULL THEN
    RAISE EXCEPTION 'CgInternalLink: source page % not found', NEW."sourcePageId"
      USING ERRCODE = '23503';
  END IF;

  IF v_target_project IS NULL THEN
    RAISE EXCEPTION 'CgInternalLink: target page % not found', NEW."targetPageId"
      USING ERRCODE = '23503';
  END IF;

  IF v_source_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgInternalLink: sourcePage.projectId % does not match row.projectId %',
      v_source_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  IF v_target_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgInternalLink: targetPage.projectId % does not match row.projectId %',
      v_target_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cg_internal_link_project_integrity
  BEFORE INSERT OR UPDATE ON "CgInternalLink"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_cg_internal_link_project_integrity();

-- =============================================================================
-- Custom: CgSchemaUsage — project must match referenced page
-- =============================================================================

CREATE OR REPLACE FUNCTION enforce_cg_schema_usage_project_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_page_project uuid;
BEGIN
  SELECT "projectId" INTO v_page_project
  FROM "CgPage"
  WHERE "id" = NEW."pageId";

  IF v_page_project IS NULL THEN
    RAISE EXCEPTION 'CgSchemaUsage: page % not found', NEW."pageId"
      USING ERRCODE = '23503';
  END IF;

  IF v_page_project <> NEW."projectId" THEN
    RAISE EXCEPTION 'CgSchemaUsage: page.projectId % does not match row.projectId %',
      v_page_project, NEW."projectId"
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cg_schema_usage_project_integrity
  BEFORE INSERT OR UPDATE ON "CgSchemaUsage"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_cg_schema_usage_project_integrity();
