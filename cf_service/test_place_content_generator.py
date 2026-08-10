import asyncio
import json
import unittest

import httpx

from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.generator import (
    BudgetExceeded,
    DeepSeekContentClient,
    GenerationBudget,
    GenerationCache,
    GenerationError,
    render_prompt,
)
from scripts.place_content_backfill.models import (
    BaselineRecord,
    NameDecision,
    SourceFact,
    SourceSnapshot,
    TranslationBaseline,
)


def _record() -> BaselineRecord:
    return BaselineRecord(
        place_id="place-1",
        province_id=APPROVED_PROVINCES[0],
        name="Sông Hương",
        short_description="Dòng sông ở Huế.",
        vi=TranslationBaseline(id="vi-1", place_id="place-1", lang_code="vi", name="Sông Hương"),
        en=TranslationBaseline(id="en-1", place_id="place-1", lang_code="en", name="Huong River"),
    )


def _decision() -> NameDecision:
    return NameDecision(
        place_id="place-1",
        vietnamese_name="Sông Hương",
        english_name="Huong River",
        rule="generic_prefix:sông",
        source="deterministic_generic_type",
        confidence=0.96,
    )


def _sources() -> SourceSnapshot:
    return SourceSnapshot(
        place_id="place-1",
        facts=(
            SourceFact(
                fact_id="osm.river",
                value="River feature in Hue",
                source_url="https://www.openstreetmap.org/way/1",
                source_kind="osm",
            ),
        ),
    )


def _response_content() -> str:
    return json.dumps(
        {
            "short_description_vi": "Dòng sông nổi bật ở Huế, phù hợp để tìm hiểu cảnh quan địa phương.",
            "detailed_description_vi": "Sông Hương là một không gian cảnh quan gắn với trải nghiệm khám phá Huế. Hãy dùng thông tin này như mô tả khái quát và kiểm tra nguồn trước khi bổ sung chi tiết cụ thể.",
            "short_description_en": "Huong River is a landmark waterway in Hue for discovering the local landscape.",
            "detailed_description_en": "Huong River offers a landscape-focused way to experience Hue. This general description avoids unsupported schedules, prices, dates, ratings, and amenities; verify current details with an authoritative source before publishing.",
            "used_fact_ids": ["osm.river"],
            "warnings": [],
            "confidence": 0.91,
        }
    )


class PlaceContentGeneratorTest(unittest.TestCase):
    def test_rendered_prompt_locks_names_and_untrusted_facts(self):
        prompt = render_prompt(_record(), _decision(), _sources(), "baseline-hash")
        self.assertIn("Huong River", prompt)
        self.assertIn("osm.river", prompt)
        self.assertIn("Return valid JSON", prompt)
        self.assertIn("20-45 words", prompt)
        self.assertIn("90-160 words", prompt)
        self.assertIn("unsupported", prompt.lower())
        self.assertIn("untrusted", prompt.lower())
        self.assertNotIn("DEEPSEEK_API_KEY", prompt)

    def test_valid_json_output_and_safe_metadata(self):
        calls = []

        async def handler(request: httpx.Request) -> httpx.Response:
            calls.append(json.loads(request.content))
            return httpx.Response(
                200,
                json={
                    "model": "approved-model",
                    "choices": [{"message": {"content": _response_content()}, "finish_reason": "stop"}],
                    "usage": {"prompt_tokens": 100, "completion_tokens": 80},
                },
            )

        async def run():
            transport = httpx.MockTransport(handler)
            async with httpx.AsyncClient(transport=transport) as http_client:
                client = DeepSeekContentClient(
                    api_key="test-secret",
                    model="approved-model",
                    http_client=http_client,
                    sleep_fn=lambda _: None,
                )
                result = await client.generate(_record(), _decision(), _sources(), "baseline-hash")
                self.assertEqual(result.content.short_description_en.startswith("Huong River"), True)
                self.assertEqual(result.finish_reason, "stop")
                self.assertEqual(result.input_tokens, 100)
                self.assertEqual(result.output_tokens, 80)
                self.assertNotIn("authorization", result.metadata)
                self.assertEqual(calls[0]["response_format"], {"type": "json_object"})
                self.assertEqual(calls[0]["temperature"], 0.2)
                self.assertEqual(calls[0]["max_tokens"], 1400)

        asyncio.run(run())

    def test_malformed_output_retries_then_fails(self):
        calls = 0

        async def handler(request: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            return httpx.Response(
                200,
                json={"choices": [{"message": {"content": "not-json"}, "finish_reason": "stop"}]},
            )

        async def run():
            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
                client = DeepSeekContentClient(
                    api_key="test-secret",
                    model="approved-model",
                    http_client=http_client,
                    max_attempts=3,
                    sleep_fn=lambda _: None,
                )
                with self.assertRaises(GenerationError):
                    await client.generate(_record(), _decision(), _sources(), "baseline-hash")
            self.assertEqual(calls, 3)

        asyncio.run(run())

    def test_retry_after_and_cache_hit(self):
        calls = 0
        sleeps = []

        async def handler(request: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            if calls == 1:
                return httpx.Response(429, headers={"retry-after": "0"})
            return httpx.Response(
                200,
                json={"choices": [{"message": {"content": _response_content()}, "finish_reason": "stop"}]},
            )

        async def run():
            cache = GenerationCache()
            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
                client = DeepSeekContentClient(
                    api_key="test-secret",
                    model="approved-model",
                    http_client=http_client,
                    cache=cache,
                    sleep_fn=sleeps.append,
                )
                first = await client.generate(_record(), _decision(), _sources(), "baseline-hash")
                second = await client.generate(_record(), _decision(), _sources(), "baseline-hash")
                self.assertFalse(first.cached)
                self.assertTrue(second.cached)
                self.assertEqual(calls, 2)
                self.assertEqual(sleeps, [0.0])

        asyncio.run(run())

    def test_budget_refuses_before_request_and_requires_prices_for_cost_cap(self):
        with self.assertRaises(ValueError):
            GenerationBudget(max_estimated_cost_usd=1.0)
        budget = GenerationBudget(max_requests=0)
        with self.assertRaises(BudgetExceeded):
            budget.before_request("some prompt", 1400)

    def test_unknown_fields_and_truncated_finish_reason_fail(self):
        async def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(
                200,
                json={
                    "choices": [
                        {
                            "message": {
                                "content": json.dumps({"unexpected": True}),
                            },
                            "finish_reason": "length",
                        }
                    ]
                },
            )

        async def run():
            async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
                client = DeepSeekContentClient(
                    api_key="test-secret",
                    model="approved-model",
                    http_client=http_client,
                    max_attempts=1,
                    sleep_fn=lambda _: None,
                )
                with self.assertRaises(GenerationError):
                    await client.generate(_record(), _decision(), _sources(), "baseline-hash")

        asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
