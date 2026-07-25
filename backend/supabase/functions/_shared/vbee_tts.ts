export type VbeeTtsInput = {
  text: string;
  languageCode: string;
};

export type VbeeTtsResult = {
  audioUrl: string;
  requestId: string;
};

export interface VbeeTtsConfig {
  apiKey: string;
  appId: string;
  baseUrl: string;
  pollIntervalMs: number;
  maxPollAttempts: number;
  vietnameseVoiceCode?: string;
  englishVoiceCode?: string;
  defaultVoiceCode?: string;
  voiceCodes?: Readonly<Record<string, string>>;
  callbackUrl?: string;
  speedRate?: string;
  bitrate?: string;
}

type JsonObject = Record<string, unknown>;

export class VbeeTtsError extends Error {
  constructor(
    message: string,
    readonly statusCode = 502,
    readonly code = "VBEE_TTS_FAILED",
  ) {
    super(message);
    this.name = "VbeeTtsError";
  }
}

export async function synthesizeVbeeSpeech(
  input: VbeeTtsInput,
  config: VbeeTtsConfig,
  fetcher: typeof fetch = fetch,
): Promise<VbeeTtsResult> {
  const text = input.text.trim();
  if (!text) {
    throw new VbeeTtsError("Text is required.", 400, "TEXT_REQUIRED");
  }

  const voiceCode = selectVoiceCode(input.languageCode, config);
  if (!voiceCode) {
    throw new VbeeTtsError(
      `Vbee voice is not configured for ${input.languageCode}.`,
      500,
      "VOICE_NOT_CONFIGURED",
    );
  }

  const baseUrl = config.baseUrl.replace(/\/+$/, "");
  const createResponse = await fetcher(`${baseUrl}/api/v1/tts`, {
    method: "POST",
    headers: vbeeHeaders(config),
    body: JSON.stringify({
      app_id: config.appId,
      callback_url: config.callbackUrl ??
        "https://example.com/vbee-callback",
      input_text: text,
      voice_code: voiceCode,
      audio_type: "mp3",
      bitrate: config.bitrate ?? "128",
      speed_rate: config.speedRate ?? "1.0",
    }),
  });
  const createData = await readJson(createResponse);
  if (!createResponse.ok) {
    throw new VbeeTtsError(
      readErrorMessage(createData) ??
        `Vbee TTS request failed (${createResponse.status}).`,
      createResponse.status,
      "SUBMIT_FAILED",
    );
  }

  const requestId = extractRequestId(createData) ?? "";
  const immediateAudioUrl = extractAudioUrl(createData);
  if (immediateAudioUrl) {
    return { audioUrl: immediateAudioUrl, requestId };
  }
  if (!requestId) {
    throw new VbeeTtsError(
      "Vbee did not return a request id.",
      502,
      "MISSING_REQUEST_ID",
    );
  }

  for (let attempt = 0; attempt < config.maxPollAttempts; attempt += 1) {
    await delay(config.pollIntervalMs);
    const statusResponse = await fetcher(
      `${baseUrl}/api/v1/tts/${requestId}`,
      { headers: vbeeHeaders(config) },
    );
    const statusData = await readJson(statusResponse);

    if (!statusResponse.ok) {
      if (statusResponse.status >= 400 && statusResponse.status < 500) {
        throw new VbeeTtsError(
          readErrorMessage(statusData) ??
            `Vbee status request failed (${statusResponse.status}).`,
          statusResponse.status,
          "STATUS_FAILED",
        );
      }
      continue;
    }

    const audioUrl = extractAudioUrl(statusData);
    if (audioUrl) {
      return { audioUrl, requestId };
    }

    const status = extractStatus(statusData);
    if (status && isTerminalFailure(status)) {
      throw new VbeeTtsError(
        readErrorMessage(statusData) ??
          `Vbee synthesis failed with status ${status}.`,
        502,
        status,
      );
    }
  }

  throw new VbeeTtsError(
    "Vbee audio is not ready yet. Please try again.",
    504,
    "POLL_TIMEOUT",
  );
}

function selectVoiceCode(
  languageCode: string,
  config: VbeeTtsConfig,
): string | null {
  const locale = normalizeLocale(languageCode);
  const language = locale.split("-")[0];
  const configured = config.voiceCodes?.[locale] ??
    config.voiceCodes?.[language];
  if (configured?.trim()) return configured.trim();

  if (language === "vi") {
    return config.vietnameseVoiceCode?.trim() ||
      "hn_female_ngochuyen_full_48k-fhg";
  }
  if (language === "en") {
    return config.englishVoiceCode?.trim() ||
      config.defaultVoiceCode?.trim() ||
      null;
  }
  return config.defaultVoiceCode?.trim() || null;
}

function normalizeLocale(languageCode: string): string {
  const code = languageCode.replaceAll("_", "-").trim().toLowerCase();
  if (code.includes("-")) return code;

  switch (code) {
    case "vi":
      return "vi-vn";
    case "en":
      return "en-us";
    case "zh":
      return "zh-cn";
    case "ja":
      return "ja-jp";
    case "ko":
      return "ko-kr";
    default:
      return code;
  }
}

function vbeeHeaders(config: VbeeTtsConfig): HeadersInit {
  return {
    "Authorization": `Bearer ${config.apiKey}`,
    "Content-Type": "application/json",
    "User-Agent": "HelloVietnam/1.0",
    "app-id": config.appId,
  };
}

async function readJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

function extractAudioUrl(data: unknown): string | null {
  for (const candidate of nestedCandidates(data)) {
    const value = candidate.audio_url ?? candidate.audioUrl ??
      candidate.audio_link ?? candidate.audioLink ?? candidate.url;
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function extractRequestId(data: unknown): string | null {
  for (const candidate of nestedCandidates(data)) {
    const value = candidate.request_id ?? candidate.requestId ?? candidate.id;
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function extractStatus(data: unknown): string | null {
  for (const candidate of nestedCandidates(data)) {
    const value = candidate.status ?? candidate.state;
    if (typeof value === "string" && value.trim()) {
      return value.trim().toUpperCase();
    }
  }
  return null;
}

function readErrorMessage(data: unknown): string | null {
  for (const candidate of nestedCandidates(data)) {
    const value = candidate.message ?? candidate.error_message ??
      candidate.errorMessage ?? candidate.error;
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function nestedCandidates(data: unknown): JsonObject[] {
  const root = readObject(data);
  if (!root) return [];

  return [
    root,
    readObject(root.result),
    readObject(root.data),
    readObject(readObject(root.result)?.payload),
    readObject(readObject(root.result)?.result),
  ].filter((value): value is JsonObject => value != null);
}

function readObject(value: unknown): JsonObject | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}

function isTerminalFailure(status: string): boolean {
  return ["FAILED", "FAILURE", "ERROR", "CANCELLED", "REJECTED"].includes(
    status,
  );
}

function delay(ms: number): Promise<void> {
  if (ms <= 0) return Promise.resolve();
  return new Promise((resolve) => setTimeout(resolve, ms));
}
