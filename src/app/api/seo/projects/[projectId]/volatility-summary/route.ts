/**
 * DEAD ROUTE — do not use.
 *
 * This path-param isolation model was rejected. SIL-4 lives at:
 *   GET /api/seo/volatility-summary   (header-scoped via resolveProjectId)
 *
 * This file exists only to prevent Next.js from 404-ing on accidental hits
 * during local dev. It returns 404 unconditionally.
 */
import { NextResponse } from "next/server";
export async function GET() {
  return NextResponse.json({ error: { code: "NOT_FOUND", message: "Not found" } }, { status: 404 });
}
