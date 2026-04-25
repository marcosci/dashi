"""LLM-driven STAC item enrichment.

Generates a one-paragraph human-readable summary + suggested keywords
from the deterministic per-item metadata (filename, kind, driver, CRS,
bbox, object count). Writes the result back to the STAC item under a
dedicated `dashi:enriched_*` namespace so it never overwrites
human-curated values.

Provider abstraction: the same `enrich_item()` function works against
any OpenAI-chat-compatible endpoint, including local Ollama.

Configuration via environment:
    DASHI_LLM_ENDPOINT       e.g. http://ollama.dashi-llm.svc:11434
    DASHI_LLM_API_BASE_PATH  default '/v1' (OpenAI-compat)
    DASHI_LLM_MODEL          e.g. llama3.2:3b   or   gpt-4o-mini
    DASHI_LLM_API_KEY        optional (Ollama ignores; OpenAI requires)
    DASHI_STAC_URL           catalog endpoint
"""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass

import httpx

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class LlmConfig:
    endpoint: str
    api_base_path: str
    model: str
    api_key: str | None
    timeout_s: float = 60.0

    @classmethod
    def from_env(cls) -> LlmConfig:
        return cls(
            endpoint=os.environ.get("DASHI_LLM_ENDPOINT", "http://ollama.dashi-llm.svc.cluster.local:11434"),
            api_base_path=os.environ.get("DASHI_LLM_API_BASE_PATH", "/v1"),
            model=os.environ.get("DASHI_LLM_MODEL", "llama3.2:3b"),
            api_key=os.environ.get("DASHI_LLM_API_KEY") or None,
        )


SYSTEM_PROMPT = (
    "You enrich spatial-data catalog items. Given deterministic metadata, "
    "produce a JSON object with three keys: title (≤80 chars, plain English), "
    "description (≤300 chars, one paragraph, factual, mention CRS + bbox + "
    "object count if useful), keywords (3–7 short snake_case strings, e.g. "
    "['osm', 'roads', 'urban']). Output the JSON object only, no prose, no "
    "markdown fences."
)


def _build_user_prompt(item: dict) -> str:
    props = item.get("properties", {}) or {}
    bbox = item.get("bbox") or []
    facts = {
        "id": item.get("id"),
        "collection": item.get("collection"),
        "kind": props.get("dashi:kind"),
        "driver": props.get("dashi:driver"),
        "source_name": props.get("dashi:source_name"),
        "source_layer": props.get("dashi:source_layer"),
        "source_crs": props.get("dashi:source_crs"),
        "object_count": props.get("dashi:object_count"),
        "bbox": bbox,
        "datetime": props.get("datetime"),
    }
    return "Generate the JSON for this STAC item. Facts:\n" + json.dumps(
        {k: v for k, v in facts.items() if v is not None}, indent=2
    )


def enrich_item(item: dict, cfg: LlmConfig | None = None) -> dict:
    """Return enriched fields. Does not mutate the input item."""
    cfg = cfg or LlmConfig.from_env()
    body = {
        "model": cfg.model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": _build_user_prompt(item)},
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    headers: dict[str, str] = {"Content-Type": "application/json"}
    if cfg.api_key:
        headers["Authorization"] = f"Bearer {cfg.api_key}"

    url = cfg.endpoint.rstrip("/") + cfg.api_base_path + "/chat/completions"
    with httpx.Client(timeout=cfg.timeout_s) as client:
        r = client.post(url, json=body, headers=headers)
        r.raise_for_status()
        payload = r.json()

    content = (payload.get("choices") or [{}])[0].get("message", {}).get("content", "").strip()
    if not content:
        raise RuntimeError(f"LLM returned empty content: {payload}")

    # Some servers wrap in ```json ... ``` despite response_format.
    if content.startswith("```"):
        content = content.strip("`").lstrip("json").strip()

    enriched = json.loads(content)
    out = {
        "dashi:enriched_title": str(enriched.get("title", ""))[:200],
        "dashi:enriched_description": str(enriched.get("description", ""))[:1000],
        "dashi:enriched_keywords": [str(k)[:64] for k in (enriched.get("keywords") or [])][:10],
        "dashi:enriched_model": cfg.model,
    }
    return out
