import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  synthesizeVbeeSpeech,
  VbeeTtsError,
} from "./vbee_tts.ts";

const baseConfig = {
  apiKey: "secret",
  appId: "app",
  baseUrl: "https://vbee.test",
  pollIntervalMs: 0,
  maxPollAttempts: 3,
  vietnameseVoiceCode: "vi-voice",
  englishVoiceCode: "en-voice",
};

Deno.test("Vbee adapter returns the completed audio URL", async () => {
  const calls: string[] = [];
  const fetcher: typeof fetch = async (input) => {
    calls.push(String(input));
    if (calls.length === 1) {
      return Response.json({ result: { request_id: "req-1" } });
    }
    return Response.json({
      result: {
        status: "SUCCESS",
        audio_link: "https://audio.test/req-1.mp3",
      },
    });
  };

  const result = await synthesizeVbeeSpeech(
    { text: "Xin chao", languageCode: "vi" },
    baseConfig,
    fetcher,
  );

  assertEquals(result.audioUrl, "https://audio.test/req-1.mp3");
  assertEquals(result.requestId, "req-1");
  assertEquals(calls, [
    "https://vbee.test/api/v1/tts",
    "https://vbee.test/api/v1/tts/req-1",
  ]);
});

Deno.test("Vbee adapter polls again while synthesis is pending", async () => {
  let callCount = 0;
  const fetcher: typeof fetch = async () => {
    callCount += 1;
    if (callCount === 1) {
      return Response.json({ result: { request_id: "req-2" } });
    }
    if (callCount === 2) {
      return Response.json({ result: { status: "PROCESSING" } });
    }
    return Response.json({
      result: {
        status: "SUCCESS",
        audio_link: "https://audio.test/req-2.mp3",
      },
    });
  };

  const result = await synthesizeVbeeSpeech(
    { text: "Welcome", languageCode: "en-US" },
    baseConfig,
    fetcher,
  );

  assertEquals(result.audioUrl, "https://audio.test/req-2.mp3");
  assertEquals(callCount, 3);
});

Deno.test("Vbee adapter throws a typed error for terminal failures", async () => {
  let callCount = 0;
  const fetcher: typeof fetch = async () => {
    callCount += 1;
    if (callCount === 1) {
      return Response.json({ result: { request_id: "req-3" } });
    }
    return Response.json({
      result: {
        status: "FAILED",
        error_message: "Voice is not available.",
      },
    });
  };

  await assertRejects(
    () =>
      synthesizeVbeeSpeech(
        { text: "Hello", languageCode: "en" },
        baseConfig,
        fetcher,
      ),
    VbeeTtsError,
    "Voice is not available.",
  );
});
