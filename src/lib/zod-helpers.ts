import { ZodError } from "zod";

/**
 * Formats a ZodError into the canonical VALIDATION_ERROR array used by all
 * POST route handlers. Drop-in replacement for the inline flatten pattern.
 *
 * Usage:
 *   return badRequest("Validation failed", formatZodErrors(parsed.error));
 */
export function formatZodErrors(
  error: ZodError
): Array<{ code: "VALIDATION_ERROR"; field?: string; message: string }> {
  const flat = error.flatten();
  return [
    ...flat.formErrors.map((msg) => ({
      code: "VALIDATION_ERROR" as const,
      message: msg,
    })),
    ...Object.entries(flat.fieldErrors).flatMap(([field, messages]) =>
      ((messages as string[] | undefined) ?? []).map((msg) => ({
        code: "VALIDATION_ERROR" as const,
        field,
        message: msg,
      }))
    ),
  ];
}
