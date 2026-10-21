#!/usr/bin/env python3
"""feed-v2.json から、旧バージョン(1.2以前)向けの feed.json を作る。

1.2以前のアプリは知らないカテゴリが来るとフィード全体の読み込みに失敗するため、
1.3で増えたカテゴリは "other" に落として配信する。
1.3以降のアプリは feed-v2.json を直接読む。
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 1.2以前のアプリが知っているカテゴリ
LEGACY_CATEGORIES = {
    "chat", "coding", "imageGeneration", "videoGeneration", "videoEditing",
    "audioMusic", "writing", "design", "dataAnalysis", "agent", "search", "other",
}
# CURATED モードの職種(Shared/Profession.swift と同じ)。"all" は全職種向け
PROFESSIONS = {
    "engineer", "designer", "videoCreator", "marketer", "writer",
    "sales", "backOffice", "founder", "student", "general", "all",
}

items = json.loads((ROOT / "feed-v2.json").read_text(encoding="utf-8"))

# 打ち間違えた職種はアプリ側で黙って無視されるので、配信前にここで止める
errors = []
for item in items:
    professions = item.get("professions")
    if professions is None:
        continue
    if not isinstance(professions, list):
        errors.append(f"{item['id']}: professions は配列で書く")
        continue
    unknown = [p for p in professions if p not in PROFESSIONS]
    if unknown:
        errors.append(f"{item['id']}: 未知の職種 {unknown}")
if errors:
    print("feed-v2.json の職種に誤りがあります:\n" + "\n".join(errors), file=sys.stderr)
    sys.exit(1)

for item in items:
    if item["category"] not in LEGACY_CATEGORIES:
        item["category"] = "other"

(ROOT / "feed.json").write_text(
    json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(f"feed.json を更新しました（{len(items)}件）")
