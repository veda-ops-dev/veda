/**
 * persist-serp-snapshot.ts — Extracted SERP snapshot persistence logic
 *
 * Pure persistence function: writes SERPSnapshot + EventLog atomically.
 * No provider calls. No HTTP concerns. No request parsing.
 *
 * Extracted from serp-snapshot/route.ts to enable:
 *   - Deterministic hammer testing without provider dependency
 *   - Reuse across routes that write SERP snapshots
 *
 * Invariants preserved:
 *   - Mutation and EventLog co-located in prisma.$transaction()
 *   - Idempotent replay via P2002 handling (no duplicate EventLog)
 *   - Project isolation enforced by caller (projectId is an opaque input)
 *   - No silent mutation: every new write produces an EventLog entry
 */

import { prisma } from "@/lib/prisma";
import { Prisma } from "@prisma/client";

// ---------------------------------------------------------------------------
// Input / Output types
// ---------------------------------------------------------------------------

export interface PersistSerpSnapshotInput {
  projectId: string;
  normalizedQuery: string;
  locale: string;
  device: string;
  capturedAt: Date;
  validAt: Date;
  rawPayload: Prisma.InputJsonValue;
  aiOverviewStatus: string;
  aiOverviewText: string | null;
  /** Metadata for EventLog details — not persisted on the snapshot itself */
  organicResultCount: number;
  aiOverviewPresent: boolean;
  features: string[];
}

export interface PersistSerpSnapshotResult {
  /** The snapshot record (created or existing on P2002 replay) */
  snapshot: {
    id: string;
    projectId: string;
    query: string;
    locale: string;
    device: string;
    capturedAt: Date;
    validAt: Date | null;
    aiOverviewStatus: string;
    source: string;
    batchRef: string | null;
    createdAt: Date;
  };
  /** true = new row created with EventLog; false = P2002 idempotent replay */
  created: boolean;
}

// ---------------------------------------------------------------------------
// Persistence function
// ---------------------------------------------------------------------------

/**
 * Persist a SERP snapshot + EventLog atomically.
 *
 * On P2002 (duplicate unique key), returns the existing row with created=false.
 * The caller decides HTTP status based on the `created` flag.
 *
 * Throws on unexpected errors (connection failure, constraint violations
 * other than the idempotency key, etc.).
 */
export async function persistSerpSnapshot(
  input: PersistSerpSnapshotInput
): Promise<PersistSerpSnapshotResult> {
  try {
    const snapshot = await prisma.$transaction(async (tx) => {
      const created = await tx.sERPSnapshot.create({
        data: {
          projectId: input.projectId,
          query: input.normalizedQuery,
          locale: input.locale,
          device: input.device,
          capturedAt: input.capturedAt,
          validAt: input.validAt,
          rawPayload: input.rawPayload,
          payloadSchemaVersion: null,
          aiOverviewStatus: input.aiOverviewStatus,
          aiOverviewText: input.aiOverviewText,
          source: "dataforseo",
          batchRef: null,
        },
      });

      await tx.eventLog.create({
        data: {
          eventType: "SERP_SNAPSHOT_RECORDED",
          entityType: "serpSnapshot",
          entityId: created.id,
          actor: "human",
          projectId: input.projectId,
          details: {
            query: input.normalizedQuery,
            locale: input.locale,
            device: input.device,
            source: "dataforseo",
            organicResultCount: input.organicResultCount,
            aiOverviewPresent: input.aiOverviewPresent,
            features: input.features,
          },
        },
      });

      return created;
    });

    return { snapshot, created: true };
  } catch (err) {
    // Idempotent replay: unique constraint on (projectId, query, locale, device, capturedAt).
    // No EventLog on replay — the original write already logged the event.
    if (
      err instanceof Prisma.PrismaClientKnownRequestError &&
      err.code === "P2002"
    ) {
      const existing = await prisma.sERPSnapshot.findUnique({
        where: {
          projectId_query_locale_device_capturedAt: {
            projectId: input.projectId,
            query: input.normalizedQuery,
            locale: input.locale,
            device: input.device,
            capturedAt: input.capturedAt,
          },
        },
      });

      if (existing) {
        return { snapshot: existing, created: false };
      }

      // Constraint fired but lookup found nothing — race condition or partial state.
      // Surface as an error so the caller can decide (route returns 500).
      throw new Error(
        "P2002 constraint fired but subsequent lookup returned null — possible race condition"
      );
    }

    throw err;
  }
}
