import os
import json
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

SYSTEM_PROMPT = """You are an expert SEO strategist with deep knowledge of search engine algorithms, keyword research, and content strategy.

When given a seed keyword or topic, you generate comprehensive keyword research data that helps content creators and marketers rank higher in search results."""


def research_keywords(seed_keyword: str, count: int = 15) -> list[dict]:
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=os.getenv("OPENROUTER_API_KEY"),
    )

    prompt = f"""Perform keyword research for the seed keyword: "{seed_keyword}"

Generate exactly {count} keyword suggestions. For each keyword, provide:
- keyword: the keyword phrase
- intent: search intent (Informational / Commercial / Transactional / Navigational)
- difficulty: SEO difficulty (Low / Medium / High)
- volume: estimated monthly search volume (Low <1K / Medium 1K-10K / High >10K)
- content_angle: a one-sentence content idea to target this keyword

Return ONLY valid JSON in this exact format, no other text:
{{
  "keywords": [
    {{
      "keyword": "...",
      "intent": "...",
      "difficulty": "...",
      "volume": "...",
      "content_angle": "..."
    }}
  ]
}}"""

    response = client.chat.completions.create(
        model="nvidia/nemotron-3-super-120b-a12b:free",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
    )

    raw = response.choices[0].message.content.strip()
    if raw.startswith("```"):
        raw = raw[raw.index("\n") + 1:]
        raw = raw[:raw.rfind("```")].strip()

    data = json.loads(raw)
    return data["keywords"]
