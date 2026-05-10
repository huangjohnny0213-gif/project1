import csv
import os
from datetime import datetime


def export_to_csv(seed_keyword: str, keywords: list[dict]) -> str:
    os.makedirs("output", exist_ok=True)

    slug = seed_keyword.lower().replace(" ", "_")[:30]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = f"output/{slug}_{timestamp}.csv"

    fieldnames = ["keyword", "intent", "difficulty", "volume", "content_angle"]

    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(keywords)

    return filepath
