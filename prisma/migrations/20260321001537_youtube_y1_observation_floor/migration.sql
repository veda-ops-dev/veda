-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "public"."EntityType" ADD VALUE 'ytSearchTarget';
ALTER TYPE "public"."EntityType" ADD VALUE 'ytSearchSnapshot';

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "public"."EventType" ADD VALUE 'YT_SEARCH_TARGET_CREATED';
ALTER TYPE "public"."EventType" ADD VALUE 'YT_SEARCH_SNAPSHOT_RECORDED';

-- CreateTable
CREATE TABLE "public"."YtSearchTarget" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "query" TEXT NOT NULL,
    "locale" TEXT NOT NULL,
    "device" TEXT NOT NULL,
    "locationCode" TEXT NOT NULL,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "YtSearchTarget_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."YtSearchSnapshot" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "projectId" UUID NOT NULL,
    "ytSearchTargetId" UUID NOT NULL,
    "capturedAt" TIMESTAMP(3) NOT NULL,
    "validAt" TIMESTAMP(3),
    "checkUrl" TEXT,
    "itemsCount" INTEGER NOT NULL,
    "itemTypes" TEXT[],
    "rawPayload" JSONB NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'dataforseo-youtube-organic',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "YtSearchSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."YtSearchElement" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "snapshotId" UUID NOT NULL,
    "projectId" UUID NOT NULL,
    "elementType" TEXT NOT NULL,
    "rankAbsolute" INTEGER NOT NULL,
    "rankGroup" INTEGER NOT NULL,
    "blockRank" INTEGER NOT NULL,
    "blockName" TEXT,
    "channelId" TEXT,
    "videoId" TEXT,
    "isShort" BOOLEAN,
    "isLive" BOOLEAN,
    "isMovie" BOOLEAN,
    "isVerified" BOOLEAN,
    "observedPublishedAt" TIMESTAMP(3),
    "rawPayload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "YtSearchElement_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "YtSearchTarget_projectId_idx" ON "public"."YtSearchTarget"("projectId");

-- CreateIndex
CREATE UNIQUE INDEX "YtSearchTarget_projectId_query_locale_device_locationCode_key" ON "public"."YtSearchTarget"("projectId", "query", "locale", "device", "locationCode");

-- CreateIndex
CREATE INDEX "YtSearchSnapshot_projectId_ytSearchTargetId_capturedAt_idx" ON "public"."YtSearchSnapshot"("projectId", "ytSearchTargetId", "capturedAt");

-- CreateIndex
CREATE INDEX "YtSearchSnapshot_projectId_idx" ON "public"."YtSearchSnapshot"("projectId");

-- CreateIndex
CREATE UNIQUE INDEX "YtSearchSnapshot_projectId_ytSearchTargetId_capturedAt_key" ON "public"."YtSearchSnapshot"("projectId", "ytSearchTargetId", "capturedAt");

-- CreateIndex
CREATE INDEX "YtSearchElement_projectId_channelId_idx" ON "public"."YtSearchElement"("projectId", "channelId");

-- CreateIndex
CREATE INDEX "YtSearchElement_projectId_videoId_idx" ON "public"."YtSearchElement"("projectId", "videoId");

-- CreateIndex
CREATE INDEX "YtSearchElement_snapshotId_idx" ON "public"."YtSearchElement"("snapshotId");

-- CreateIndex
CREATE UNIQUE INDEX "YtSearchElement_snapshotId_rankAbsolute_key" ON "public"."YtSearchElement"("snapshotId", "rankAbsolute");

-- AddForeignKey
ALTER TABLE "public"."YtSearchTarget" ADD CONSTRAINT "YtSearchTarget_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "public"."Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."YtSearchSnapshot" ADD CONSTRAINT "YtSearchSnapshot_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "public"."Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."YtSearchSnapshot" ADD CONSTRAINT "YtSearchSnapshot_ytSearchTargetId_fkey" FOREIGN KEY ("ytSearchTargetId") REFERENCES "public"."YtSearchTarget"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."YtSearchElement" ADD CONSTRAINT "YtSearchElement_snapshotId_fkey" FOREIGN KEY ("snapshotId") REFERENCES "public"."YtSearchSnapshot"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."YtSearchElement" ADD CONSTRAINT "YtSearchElement_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "public"."Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
