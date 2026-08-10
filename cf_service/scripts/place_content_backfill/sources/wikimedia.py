"""Identity-first Wikidata/Wikipedia enrichment."""

from __future__ import annotations

import re
from typing import Any
from urllib.parse import unquote

import httpx

from ..models import BaselineRecord, SourceFact
from .http import request_with_retry


_QID = re.compile(r"^Q[1-9][0-9]*$")
_WIKIPEDIA = re.compile(r"^([a-z]{2,12}):(.+)$")


def is_wikidata_id(value: str | None) -> bool:
    return bool(value and _QID.fullmatch(str(value).strip()))


def parse_wikipedia_tag(value: str | None) -> tuple[str, str] | None:
    if not value:
        return None
    match = _WIKIPEDIA.fullmatch(str(value).strip())
    if not match:
        return None
    return match.group(1), unquote(match.group(2))


def article_identity_matches(
    record: dict[str, Any],
    article: dict[str, Any],
    *,
    coordinate_tolerance: float = 0.03,
) -> bool:
    """Require name plus at least two independent identity corroborations."""

    if _normalize(record.get("name")) != _normalize(article.get("title")):
        return False
    corroborations = 0
    if record.get("province_id") and article.get("province_id"):
        if str(record["province_id"]) != str(article["province_id"]):
            return False
        corroborations += 1
    if record.get("category") and article.get("category"):
        if _normalize(record["category"]) != _normalize(article["category"]):
            return False
        corroborations += 1
    try:
        if record.get("latitude") is not None and article.get("latitude") is not None:
            if abs(float(record["latitude"]) - float(article["latitude"])) > coordinate_tolerance:
                return False
            if abs(float(record["longitude"]) - float(article["longitude"])) > coordinate_tolerance:
                return False
            corroborations += 1
    except (TypeError, ValueError, KeyError):
        return False
    return corroborations >= 2


async def fetch_wikimedia_facts(
    client: httpx.AsyncClient,
    record: BaselineRecord,
) -> list[SourceFact]:
    facts: list[SourceFact] = []
    qid = record.wikidata
    if is_wikidata_id(qid):
        response = await request_with_retry(
            client,
            "GET",
            "https://www.wikidata.org/w/api.php",
            params={
                "action": "wbgetentities",
                "ids": qid,
                "format": "json",
                "props": "labels|descriptions|claims",
            },
            timeout=20,
            headers={"User-Agent": "hello-vietnam-place-content/1.0"},
        )
        response.raise_for_status()
        entity = (response.json().get("entities") or {}).get(qid) or {}
        labels = entity.get("labels") or {}
        descriptions = entity.get("descriptions") or {}
        for lang, field_name in (("vi", "label_vi"), ("en", "label_en")):
            value = (labels.get(lang) or {}).get("value")
            if value:
                facts.append(
                    SourceFact(
                        fact_id=f"wikidata.{field_name}",
                        value=str(value),
                        source_url=f"https://www.wikidata.org/wiki/{qid}",
                        source_kind="wikidata",
                    )
                )
        for lang, field_name in (("vi", "description_vi"), ("en", "description_en")):
            value = (descriptions.get(lang) or {}).get("value")
            if value:
                facts.append(
                    SourceFact(
                        fact_id=f"wikidata.{field_name}",
                        value=str(value),
                        source_url=f"https://www.wikidata.org/wiki/{qid}",
                        source_kind="wikidata",
                    )
                )

    wikipedia = parse_wikipedia_tag(record.wikipedia)
    if wikipedia:
        lang, title = wikipedia
        response = await request_with_retry(
            client,
            "GET",
            f"https://{lang}.wikipedia.org/w/api.php",
            params={
                "action": "query",
                "prop": "extracts",
                "exintro": 1,
                "explaintext": 1,
                "titles": title,
                "format": "json",
            },
            timeout=20,
            headers={"User-Agent": "hello-vietnam-place-content/1.0"},
        )
        response.raise_for_status()
        pages = ((response.json().get("query") or {}).get("pages") or {}).values()
        for page in pages:
            extract = str(page.get("extract") or "").strip()
            if extract:
                # Keep only a bounded evidence excerpt; never copy whole pages.
                facts.append(
                    SourceFact(
                        fact_id="wikipedia.extract",
                        value=extract[:600],
                        source_url=f"https://{lang}.wikipedia.org/wiki/{title.replace(' ', '_')}",
                        source_kind="wikipedia",
                    )
                )
    return facts


def _normalize(value: Any) -> str:
    return " ".join(str(value or "").casefold().split())
