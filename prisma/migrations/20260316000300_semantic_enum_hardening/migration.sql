-- Semantic enum hardening
-- Makes thin project scoping state and AI overview status explicit enums.
-- Date: 2026-03-16

-- =============================================================================
-- Enums
-- =============================================================================

CREATE TYPE "ProjectLifecycleState" AS ENUM ('created', 'bootstrapping', 'active', 'paused', 'archived');
CREATE TYPE "AiOverviewStatus" AS ENUM ('present', 'absent', 'parse_error');

-- =============================================================================
-- Project lifecycleState -> ProjectLifecycleState
-- =============================================================================

ALTER TABLE "Project"
  ALTER COLUMN "lifecycleState" DROP DEFAULT;

ALTER TABLE "Project"
  DROP CONSTRAINT IF EXISTS "Project_lifecycleState_check";

ALTER TABLE "Project"
  ALTER COLUMN "lifecycleState" TYPE "ProjectLifecycleState"
  USING ("lifecycleState"::"ProjectLifecycleState");

ALTER TABLE "Project"
  ALTER COLUMN "lifecycleState" SET DEFAULT 'created';

ALTER TABLE "Project"
  ALTER COLUMN "lifecycleState" SET NOT NULL;

-- =============================================================================
-- SERPSnapshot.aiOverviewStatus -> AiOverviewStatus
-- =============================================================================

ALTER TABLE "SERPSnapshot"
  ALTER COLUMN "aiOverviewStatus" TYPE "AiOverviewStatus"
  USING ("aiOverviewStatus"::"AiOverviewStatus");
