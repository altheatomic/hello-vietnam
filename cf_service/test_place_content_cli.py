import asyncio
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from scripts.place_content_backfill.artifacts import ArtifactStore
from scripts.place_content_backfill.cli import _generate
from scripts.place_content_backfill.constants import APPROVED_PROVINCES
from scripts.place_content_backfill.generator import BudgetExceeded
from scripts.place_content_backfill.models import (
    BaselineRecord,
    GeneratedContent,
    SourceSnapshot,
    TranslationBaseline,
)


class PlaceContentCliTest(unittest.TestCase):
    def test_generate_returns_partial_result_when_budget_is_exhausted(self):
        async def run():
            with tempfile.TemporaryDirectory() as directory:
                store = ArtifactStore(Path(directory), "run-1")
                for index in (1, 2):
                    place_id = f"p{index}"
                    store.append(
                        "baseline",
                        BaselineRecord(
                            place_id=place_id,
                            province_id=APPROVED_PROVINCES[0],
                            name=f"Place {index}",
                            source="manual",
                            vi=TranslationBaseline(
                                id=f"{place_id}-vi",
                                place_id=place_id,
                                lang_code="vi",
                                name=f"Place {index}",
                            ),
                            en=TranslationBaseline(
                                id=f"{place_id}-en",
                                place_id=place_id,
                                lang_code="en",
                                name=f"Place {index}",
                            ),
                        ),
                    )
                    store.append("sources", SourceSnapshot(place_id=place_id))

                content = GeneratedContent(
                    short_description_vi="Một mô tả ngắn đủ thông tin cho địa điểm này.",
                    detailed_description_vi="Đây là phần mô tả chi tiết được viết thận trọng dựa trên thông tin hiện có và giữ tên địa điểm nguyên vẹn trong nội dung.",
                    short_description_en="A concise description for this place with useful context.",
                    detailed_description_en="This detailed description is written cautiously from the available information and keeps the place name unchanged throughout the content.",
                    confidence=0.9,
                )
                calls = 0

                class FakeClient:
                    def __init__(self, *, budget):
                        self.budget = budget

                    async def generate(self, *args, **kwargs):
                        nonlocal calls
                        calls += 1
                        if calls > 1:
                            raise BudgetExceeded("maximum request budget exceeded")
                        return SimpleNamespace(content=content, metadata={})

                with patch("scripts.place_content_backfill.generator.DeepSeekContentClient", FakeClient):
                    result = await _generate(
                        store,
                        max_requests=2,
                        max_input_tokens=None,
                        max_output_tokens=None,
                        max_estimated_cost_usd=None,
                    )
                self.assertEqual(result["generated"], 1)
                self.assertTrue(result["budget_exhausted"])
                self.assertEqual(len(store.read_all("proposals")), 1)

        asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
