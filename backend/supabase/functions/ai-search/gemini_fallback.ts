export type GeminiFetch = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

export type GeminiResponse = {
  response: Response;
  data: unknown;
  attempts: number;
  model: string;
};

/// Returns the legacy key first, then the explicitly numbered keys. Duplicate
/// values are ignored so an accidentally repeated secret is never retried.
export function configuredGeminiKeys(
  getEnvironment: (name: string) => string | undefined,
): string[] {
  const names: string[] = [
    "GEMINI_API_KEY",
    "GEMINI_API_KEY_1",
    "GEMINI_API_KEY_2",
    "GEMINI_API_KEY_3",
  ];
  const keys = names
    .map((name) => getEnvironment(name)?.trim() ?? "")
    .filter((key) => key.length > 0);
  return [...new Set(keys)];
}

/// Uses the configured model first and then a current compatible fallback.
/// This prevents an old model ID in Supabase secrets from disabling AI Search.
export function configuredGeminiModels(
  getEnvironment: (name: string) => string | undefined,
): string[] {
  const configuredNames = [
    "GEMINI_AI_SEARCH_MODEL",
    "GEMINI_AI_SEARCH_MODEL_1",
    "GEMINI_AI_SEARCH_MODEL_2",
    "GEMINI_AI_SEARCH_MODEL_3",
  ];
  const models = configuredNames
    .map((name) => getEnvironment(name)?.trim() ?? "")
    .filter((model) => model.length > 0);
  return [...new Set([...models, "gemini-3.5-flash-lite"])];
}

/// Tries the configured model and each key in sequence. Credential, quota,
/// provider, and network failures move to the next key. A missing model moves
/// directly to the next model so an obsolete model ID does not waste all keys.
export async function requestGeminiWithFallback(input: {
  apiKeys: string[];
  models: string[];
  body: unknown;
  fetchFn?: GeminiFetch;
}): Promise<GeminiResponse> {
  const fetchFn = input.fetchFn ?? fetch;
  let lastNetworkError: unknown;
  let lastResponse: GeminiResponse | null = null;
  let attempts = 0;

  for (const model of input.models) {
    for (let index = 0; index < input.apiKeys.length; index += 1) {
      const apiKey = input.apiKeys[index];
      attempts += 1;
      try {
        const response = await fetchFn(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: {
              "x-goog-api-key": apiKey,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(input.body),
          },
        );
        const data = await response.json().catch(() => null);
        const result = { response, data, attempts, model };
        lastResponse = result;

        if (response.ok || !shouldTryNext(response.status)) return result;
        if (shouldTryNextModel(response.status)) {
          console.warn(
            `[ai-search] Gemini model ${model} is unavailable; trying next model.`,
          );
          break;
        }
        if (index < input.apiKeys.length - 1) {
          console.warn(
            `[ai-search] Gemini key ${
              index + 1
            } failed with ${response.status}; trying next key.`,
          );
          continue;
        }
        console.warn(
          `[ai-search] All Gemini keys failed for ${model}; trying next model.`,
        );
      } catch (error) {
        lastNetworkError = error;
        if (index < input.apiKeys.length - 1) {
          console.warn(
            `[ai-search] Gemini key ${
              index + 1
            } request failed; trying next key.`,
          );
          continue;
        }
        console.warn(
          `[ai-search] All Gemini keys had network errors for ${model}; trying next model.`,
        );
      }
    }
  }

  if (lastResponse != null) return lastResponse;
  throw lastNetworkError instanceof Error
    ? lastNetworkError
    : new Error("Gemini request could not be completed.");
}

function shouldTryNextKey(status: number): boolean {
  return status === 401 || status === 403 || status === 429 || status >= 500;
}

function shouldTryNextModel(status: number): boolean {
  return status === 404;
}

function shouldTryNext(status: number): boolean {
  return shouldTryNextKey(status) || shouldTryNextModel(status);
}
