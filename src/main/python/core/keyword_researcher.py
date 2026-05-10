import os
import json
import anthropic
from dotenv import load_dotenv

load_dotenv()

SYSTEM_PROMPT = """You are an expert SEO strategist with deep knowledge of search engine algorithms, keyword research, and content strategy.

When given a seed keyword or topic, you generate comprehensive keyword research data that helps content creators and marketers rank higher in search results."""

def research_keywords(seed_keyword: str, count: int = 15) -> list[dict]:
    client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

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

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2000,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=[{"role": "user", "content": prompt}],
    )

    raw = response.content[0].text.strip()
    data = json.loads(raw)
    return data["keywords"]
