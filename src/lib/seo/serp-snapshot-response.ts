export type SerpSnapshotSerializableRow = {
  id: string;
  query: string;
  locale: string;
  device: string;
  capturedAt: Date;
  validAt: Date | null;
  aiOverviewStatus: string;
  aiOverviewText: string | null;
  payloadSchemaVersion: string | null;
  source: string;
  batchRef: string | null;
  createdAt: Date;
  rawPayload?: unknown;
};

const BASE_SERP_SNAPSHOT_SELECT = {
  id: true,
  query: true,
  locale: true,
  device: true,
  capturedAt: true,
  validAt: true,
  aiOverviewStatus: true,
  aiOverviewText: true,
  payloadSchemaVersion: true,
  source: true,
  batchRef: true,
  createdAt: true,
} as const;

export function buildSerpSnapshotSelect(includePayload: boolean) {
  if (includePayload) {
    return {
      ...BASE_SERP_SNAPSHOT_SELECT,
      rawPayload: true,
    };
  }

  return BASE_SERP_SNAPSHOT_SELECT;
}

export function serializeSerpSnapshotRow(row: SerpSnapshotSerializableRow) {
  return {
    id: row.id,
    query: row.query,
    locale: row.locale,
    device: row.device,
    capturedAt: row.capturedAt.toISOString(),
    validAt: row.validAt?.toISOString() ?? null,
    aiOverviewStatus: row.aiOverviewStatus,
    aiOverviewText: row.aiOverviewText,
    payloadSchemaVersion: row.payloadSchemaVersion,
    source: row.source,
    batchRef: row.batchRef,
    createdAt: row.createdAt.toISOString(),
    ...("rawPayload" in row ? { rawPayload: row.rawPayload } : {}),
  };
}

export function serializeSerpSnapshots(rows: SerpSnapshotSerializableRow[]) {
  return rows.map((row) => serializeSerpSnapshotRow(row));
}
