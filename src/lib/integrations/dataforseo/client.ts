/**
 * DataForSEO API Client
 *
 * Thin HTTP client for the DataForSEO SERP Advanced endpoint.
 * Responsibilities:
 *   - Build Basic Auth header from DATAFORSEO_LOGIN / DATAFORSEO_PASSWORD
 *   - POST to /v3/serp/google/organic/live/advanced
 *   - Parse and return the full JSON response
 *   - Throw a descriptive DataForSeoError on any failure
 *
 * No DB access. No Prisma. No side effects beyond the HTTP call.
 */

const BASE_URL =
  process.env.DATAFORSEO_BASE_URL ?? "https://api.dataforseo.com";

export interface DataForSeoSerpRequest {
  query: string;
  /**
   * BCP-47 locale string (e.g. "en-US").
   * Must match a key in LOCALE_MAP — unsupported locales throw DataForSeoError
   * before any network call is made, so the route can return 400.
   */
  locale: string;
  /** "desktop" | "mobile" */
  device: string;
}

export class DataForSeoError extends Error {
  constructor(
    message: string,
    public readonly statusCode?: number,
    public readonly providerMessage?: string
  ) {
    super(message);
    this.name = "DataForSeoError";
  }
}

/**
 * Build the Basic Auth header from environment variables.
 * Throws DataForSeoError if credentials are absent.
 */
function buildAuthHeader(): string {
  const login = process.env.DATAFORSEO_LOGIN;
  const password = process.env.DATAFORSEO_PASSWORD;

  if (!login || !password) {
    throw new DataForSeoError(
      "DataForSEO credentials missing: set DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD"
    );
  }

  const encoded = Buffer.from(`${login}:${password}`, "utf8").toString(
    "base64"
  );
  return `Basic ${encoded}`;
}

/** Supported locale → DataForSEO location/language mapping. */
const LOCALE_MAP: Record<string, { location_code: number; language_code: string }> = {
  "en-US": { location_code: 2840, language_code: "en" },
};

/**
 * Resolve DataForSEO location_code + language_code from locale.
 * Throws DataForSeoError with a clear message for unsupported locales
 * so the route can return 400 before touching the provider.
 */
export function resolveLocaleParams(
  locale: string
): { location_code: number; language_code: string } {
  const params = LOCALE_MAP[locale];
  if (!params) {
    throw new DataForSeoError(
      `Unsupported locale "${locale}". Currently supported: ${Object.keys(LOCALE_MAP).join(", ")}`
    );
  }
  return params;
}

/**
 * Map device string to DataForSEO device value.
 * DataForSEO expects "desktop" or "mobile" exactly.
 */
function mapDevice(device: string): string {
  return device === "mobile" ? "mobile" : "desktop";
}

/**
 * Fetch a SERP snapshot from DataForSEO.
 *
 * Always sends a single-task array to the live/advanced endpoint.
 * Returns the raw parsed JSON response — normalization is the caller's concern.
 *
 * Throws DataForSeoError on:
 *   - missing credentials
 *   - non-2xx HTTP response
 *   - non-OK task status in the response body
 *   - JSON parse failure
 */
export async function fetchSerpSnapshot(
  req: DataForSeoSerpRequest
): Promise<unknown> {
  const authHeader = buildAuthHeader();
  const endpoint = `${BASE_URL}/v3/serp/google/organic/live/advanced`;

  // Throws DataForSeoError for unsupported locales — caller returns 400.
  const { location_code, language_code } = resolveLocaleParams(req.locale);

  const taskBody = [
    {
      keyword: req.query,
      location_code,
      language_code,
      device: mapDevice(req.device),
    },
  ];

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: authHeader,
      },
      body: JSON.stringify(taskBody),
    });
  } catch (err) {
    throw new DataForSeoError(
      `Network error reaching DataForSEO: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  let json: unknown;
  try {
    json = await response.json();
  } catch {
    throw new DataForSeoError(
      `DataForSEO returned non-JSON response (HTTP ${response.status})`,
      response.status
    );
  }

  if (!response.ok) {
    const msg =
      (json as Record<string, unknown>)?.status_message ??
      `HTTP ${response.status}`;
    throw new DataForSeoError(
      `DataForSEO request failed: ${msg}`,
      response.status,
      String(msg)
    );
  }

  // Check top-level status code in the DataForSEO envelope
  const statusCode = (json as Record<string, unknown>)?.status_code;
  if (typeof statusCode === "number" && statusCode !== 20000) {
    const statusMessage =
      (json as Record<string, unknown>)?.status_message ?? "Unknown error";
    throw new DataForSeoError(
      `DataForSEO API error (status_code ${statusCode}): ${statusMessage}`,
      statusCode,
      String(statusMessage)
    );
  }

  return json;
}
