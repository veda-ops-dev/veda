/**
 * API Response helpers
 * Per docs/operations-planning-api/01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md
 */
import { NextResponse } from "next/server";

// --- Success responses ---

export function successResponse(data: unknown, status = 200) {
  return NextResponse.json({ data }, { status });
}

export function createdResponse(data: unknown) {
  return successResponse(data, 201);
}

export function listResponse(
  data: unknown[],
  pagination: {
    page: number;
    limit: number;
    total: number;
  }
) {
  return NextResponse.json({
    data,
    pagination: {
      ...pagination,
      hasMore: pagination.page * pagination.limit < pagination.total,
    },
  });
}

// --- Error responses ---
// Per API contract: { error: { code, message, details? } }

export interface ApiErrorDetail {
  code: string;
  field?: string;
  message: string;
}

export function errorResponse(
  code: string,
  message: string,
  status: number,
  details?: ApiErrorDetail[]
) {
  return NextResponse.json(
    {
      error: {
        code,
        message,
        ...(details ? { details } : {}),
      },
    },
    { status }
  );
}

export function badRequest(message: string, details?: ApiErrorDetail[]) {
  return errorResponse("BAD_REQUEST", message, 400, details);
}

export function unauthorized(message = "Unauthorized") {
  return errorResponse("UNAUTHORIZED", message, 401);
}

export function notFound(message = "Not found") {
  return errorResponse("NOT_FOUND", message, 404);
}

export function conflict(
  message: string,
  code = "CONFLICT",
  details?: ApiErrorDetail[]
) {
  return errorResponse(code, message, 409, details);
}

export function serverError(message = "Internal server error") {
  return errorResponse("SERVER_ERROR", message, 500);
}

// --- Pagination helpers ---
// Per API contract: ?page=1&limit=20, page 1-indexed, limit max 100

export function parsePagination(searchParams: URLSearchParams) {
  const page = Math.max(1, parseInt(searchParams.get("page") || "1", 10));
  const limit = Math.min(
    100,
    Math.max(1, parseInt(searchParams.get("limit") || "20", 10))
  );
  const skip = (page - 1) * limit;
  return { page, limit, skip };
}
