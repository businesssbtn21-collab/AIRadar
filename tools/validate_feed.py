#!/usr/bin/env python3
"""配信フィード(feed-v2.json / feed.json)を配信前に点検する。

アプリが読めない形(未知の kind、日付の書式違いなど)が1件でも混ざると、
フィード全体の読み込みに失敗して購入者の画面が更新されなくなる。
自動更新(クラウドのルーティン)でも手作業でも、反映前に必ず通す。

使い方:
  python3 tools/validate_feed.py                     # 形の点検だけ
  python3 tools/validate_feed.py --base origin/main  # 自動更新向け。追加分の件数・書式も点検
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Shared/AIServiceItem.swift の ServiceCategory と同じ
CATEGORIES = {
    "chat", "coding", "imageGeneration", "videoGeneration", "videoEditing",
    "audioMusic", "writing", "design", "dataAnalysis", "agent", "search",
    "pluginSkill", "other",
}
# 1.2以前のアプリが知っているカテゴリ(tools/build_legacy_feed.py と同じ)
LEGACY_CATEGORIES = CATEGORIES - {"pluginSkill"}
# Shared/Profession.swift と同じ。"all" は全職種向け
PROFESSIONS = {
    "engineer", "designer", "videoCreator", "marketer", "writer",
    "sales", "backOffice", "founder", "student", "general", "all",
}
# アプリは UpdateKind を厳密に読むので、これ以外が来るとフィード全体が読めなくなる
KINDS = {"new", "update"}
# Swift の .iso8601 は小数秒やタイムゾーン表記の違いを読めない
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{0,79}$")

# 自動更新1回あたりの上限(--base のとき)
MAX_NEW_ITEMS = 8
# 期待度80以上は購入者に通知が飛ぶので、一度に鳴らしすぎない
NOTIFY_SCORE = 80
MAX_NEW_NOTIFYING = 2
MAX_CHANGE_NOTE = 30
MAX_SUMMARY = 160
MAX_AGE_DAYS = 21


def parse_date(value):
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def check_item(item, errors):
    label = item.get("id", "(idなし)") if isinstance(item, dict) else "(オブジェクトでない項目)"
    if not isinstance(item, dict):
        errors.append(f"{label}: 項目はオブジェクトで書く")
        return
    for key in ("id", "name", "provider", "summary", "changeNote"):
        if not isinstance(item.get(key), str) or not item[key].strip():
            errors.append(f"{label}: {key} は空でない文字列で書く")
    if isinstance(item.get("id"), str) and not ID_PATTERN.match(item["id"]):
        errors.append(f"{label}: id は英小文字・数字・ハイフンだけで書く")
    if item.get("category") not in CATEGORIES:
        errors.append(f"{label}: 未知のカテゴリ {item.get('category')!r}")
    if item.get("kind") not in KINDS:
        errors.append(f"{label}: kind は new か update({item.get('kind')!r} はアプリが読めない)")
    for key in ("expectationScore", "attentionScore"):
        value = item.get(key)
        if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 100:
            errors.append(f"{label}: {key} は0〜100の整数で書く")
    date = item.get("date")
    if not isinstance(date, str) or not DATE_PATTERN.match(date):
        errors.append(f"{label}: date は 2026-01-31T09:00:00Z の形で書く")
    else:
        try:
            if parse_date(date) > datetime.now(timezone.utc) + timedelta(days=2):
                errors.append(f"{label}: date が未来になっている")
        except ValueError:
            errors.append(f"{label}: date が実在しない日時")
    url = item.get("url")
    if url is not None:
        if not isinstance(url, str) or not re.match(r"^https?://[^\s]+$", url) or not url.isascii():
            errors.append(f"{label}: url は空白を含まない http(s) のURLで書く(日本語はエンコードする)")
    professions = item.get("professions")
    if professions is not None:
        if not isinstance(professions, list) or not professions:
            errors.append(f"{label}: professions は空でない配列で書く")
        else:
            unknown = [p for p in professions if p not in PROFESSIONS]
            if unknown:
                errors.append(f"{label}: 未知の職種 {unknown}")


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def check_feeds(errors):
    items = load(ROOT / "feed-v2.json")
    if not isinstance(items, list):
        errors.append("feed-v2.json の一番外側は配列にする")
        return []
    for item in items:
        check_item(item, errors)
    ids = [i.get("id") for i in items if isinstance(i, dict)]
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    if duplicates:
        errors.append(f"id が重複している: {duplicates}")

    legacy = load(ROOT / "feed.json")
    if [i.get("id") for i in legacy] != ids:
        errors.append("feed.json が feed-v2.json と食い違う。python3 tools/build_legacy_feed.py で作り直す")
    bad_legacy = [i.get("id") for i in legacy if i.get("category") not in LEGACY_CATEGORIES]
    if bad_legacy:
        errors.append(f"feed.json に旧版が読めないカテゴリがある: {bad_legacy}")
    return items


def check_additions(items, base, errors):
    """自動更新で足された分だけを、件数・書式・既存項目の保護の観点で点検する。"""
    try:
        shown = subprocess.run(
            ["git", "show", f"{base}:feed-v2.json"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout
    except subprocess.CalledProcessError as error:
        errors.append(f"{base} の feed-v2.json を読めない: {error.stderr.strip()}")
        return
    before = {i["id"]: i for i in json.loads(shown)}
    after = {i["id"]: i for i in items if isinstance(i, dict) and "id" in i}

    removed = sorted(set(before) - set(after))
    if removed:
        errors.append(f"既存の項目が消えている: {removed}")
    changed = sorted(i for i in set(before) & set(after) if before[i] != after[i])
    if changed:
        errors.append(f"既存の項目が書き換わっている(自動更新では追加だけにする): {changed}")

    added = [after[i] for i in after if i not in before]
    if len(added) > MAX_NEW_ITEMS:
        errors.append(f"追加が {len(added)} 件。1回の上限は {MAX_NEW_ITEMS} 件")
    notifying = [i["id"] for i in added if i.get("expectationScore", 0) >= NOTIFY_SCORE]
    if len(notifying) > MAX_NEW_NOTIFYING:
        errors.append(f"期待度{NOTIFY_SCORE}以上(通知が飛ぶ)の追加が {len(notifying)} 件。上限は {MAX_NEW_NOTIFYING} 件: {notifying}")

    oldest = datetime.now(timezone.utc) - timedelta(days=MAX_AGE_DAYS)
    for item in added:
        label = item["id"]
        if len(item.get("changeNote", "")) > MAX_CHANGE_NOTE:
            errors.append(f"{label}: changeNote は{MAX_CHANGE_NOTE}字以内")
        if len(item.get("summary", "")) > MAX_SUMMARY:
            errors.append(f"{label}: summary は{MAX_SUMMARY}字以内")
        if not isinstance(item.get("url"), str) or not item["url"].startswith("https://"):
            errors.append(f"{label}: 追加する項目には https の出典URLを必ず付ける")
        if not item.get("professions"):
            errors.append(f"{label}: 追加する項目には professions を必ず付ける")
        date = item.get("date")
        if isinstance(date, str) and DATE_PATTERN.match(date):
            try:
                if parse_date(date) < oldest:
                    errors.append(f"{label}: {MAX_AGE_DAYS}日より前の発表は自動では足さない")
            except ValueError:
                pass
    print(f"追加 {len(added)} 件: {', '.join(i['id'] for i in added) or 'なし'}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", help="比べる元の git の参照(例: origin/main)")
    args = parser.parse_args()

    errors = []
    items = check_feeds(errors)
    if args.base and items:
        check_additions(items, args.base, errors)
    if errors:
        print("フィードに問題があります:\n- " + "\n- ".join(errors), file=sys.stderr)
        sys.exit(1)
    print(f"点検OK({len(items)}件)")


if __name__ == "__main__":
    main()
