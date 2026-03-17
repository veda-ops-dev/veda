/**
 * Schema Coverage — Content Graph Intelligence (Phase 2)
 *
 * Detects structured data coverage across project pages.
 * Compute-on-read. No writes. No side effects.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 */
import { prisma } from "@/lib/prisma";

export interface SchemaTypeEntry {
  type: string;
  count: number;
}

export interface SchemaCoverageResult {
  schemaTypes: SchemaTypeEntry[];
  pagesWithoutSchema: string[];
}

/**
 * Compute schema coverage for a project.
 *
 * schemaTypes: usage counts per schema type, ordered by count desc, type asc.
 * pagesWithoutSchema: page IDs that have no SchemaUsage records, ordered by pageId asc.
 */
export async function computeSchemaCoverage(
  projectId: string
): Promise<SchemaCoverageResult> {
  const [allPages, schemaGroups, pagesWithSchema] = await Promise.all([
    prisma.cgPage.findMany({
      where: { projectId },
      select: { id: true },
      orderBy: [{ id: "asc" }],
    }),
    prisma.cgSchemaUsage.groupBy({
      by: ["schemaType"],
      where: { projectId },
      _count: { pageId: true },
    }),
    prisma.cgSchemaUsage.findMany({
      where: { projectId },
      select: { pageId: true },
      distinct: ["pageId"],
    }),
  ]);

  const schemaPageIds = new Set(pagesWithSchema.map((s) => s.pageId));

  const pagesWithoutSchema = allPages
    .filter((p) => !schemaPageIds.has(p.id))
    .map((p) => p.id);

  const schemaTypes: SchemaTypeEntry[] = schemaGroups
    .map((g) => ({ type: g.schemaType, count: g._count.pageId }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.type.localeCompare(b.type);
    });

  return {
    schemaTypes,
    pagesWithoutSchema,
  };
}
