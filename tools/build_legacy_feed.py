#!/usr/bin/env python3
"""feed-v2.json から、旧バージョン(1.2以前)向けの feed.json を作る。

1.2以前のアプリは知らないカテゴリが来るとフィード全体の読み込みに失敗するため、
1.3で増えたカテゴリは "other" に落として配信する。
1.3以降のアプリは feed-v2.json を直接読む。
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 1.2以前のアプリが知っているカテゴリ
LEGACY_CATEGORIES = {
    "chat", "coding", "imageGeneration", "videoGeneration", "videoEditing",
    "audioMusic", "writing", "design", "dataAnalysis", "agent", "search", "other",
}

items = json.loads((ROOT / "feed-v2.json").read_text(encoding="utf-8"))
for item in items:
    if item["category"] not in LEGACY_CATEGORIES:
        item["category"] = "other"

(ROOT / "feed.json").write_text(
    json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(f"feed.json を更新しました（{len(items)}件）")
