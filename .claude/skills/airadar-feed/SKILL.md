---
name: airadar-feed
description: AIレーダー(AIRadar)の配信フィードを更新する。「フィード更新して」「新しいAIの情報を入れて」「feed.jsonを更新」と言われたときに使う。実在するAIサービスの新着・更新を調べて feed-v2.json に追加し、旧バージョン向けの feed.json を生成してGitHubへ反映するまでの手順。
---

# AIレーダーのフィード更新

配信元: `https://raw.githubusercontent.com/businesssbtn21-collab/AIRadar/main/feed-v2.json`
作業場所: `/Users/ryuta/Documents/自作アプリ/AIRadar`

## フィードは2本立て(壊さないために必須)

| ファイル | 読むアプリ | 中身 |
|---|---|---|
| `feed-v2.json` | 1.3以降 | 本体。全カテゴリ使える |
| `feed.json` | 1.2以前 | `tools/build_legacy_feed.py` で自動生成。未知カテゴリを `other` に変換 |

**1.2以前のアプリは知らないカテゴリが来るとフィード全体の解析に失敗する。** `feed.json` を手で編集しない。必ず生成する。

## 手順

1. **実際のニュースを調べる**(WebSearch)。実在しないサービスや不確かな日付を書かない。公式サイトやリリースノートで裏を取る
2. `feed-v2.json` の**配列の先頭**に追加する
3. `python3 tools/build_legacy_feed.py` を実行して `feed.json` を再生成
4. `git add -A` → commit(作者は `businesssbtn21-collab`。本名は使わない)
5. **プッシュはCLIからできない**(認証情報なし)。GitHub Desktop の「Push origin」を押す。computer-use で操作できるが、Claudeのウィンドウがフルスクリーンだと他アプリを操作できないので、その場合は解除を依頼する
6. `curl -s <配信URL> | python3 -m json.tool | head` で反映を確認

## 項目の書式

```json
{
  "id": "一意の英小文字とハイフン",
  "name": "サービス名",
  "provider": "提供元",
  "category": "chat",
  "summary": "2〜3行の説明",
  "changeNote": "一覧に出る短い変更点(20〜30字)",
  "kind": "new",
  "expectationScore": 88,
  "attentionScore": 85,
  "date": "2026-08-13T09:00:00Z",
  "url": "https://example.com",
  "professions": ["engineer", "student"]
}
```

- `professions`: 向いている職種(1.4以降の CURATED モードで使う)。**必ず書く**(省略するとカテゴリから推定されるが粗い)
  - 値: `engineer`(エンジニア) / `designer`(デザイナー) / `videoCreator`(動画クリエイター) / `marketer`(マーケター・SNS運用) / `writer`(ライター・編集) / `sales`(営業・接客) / `backOffice`(事務・経理・人事) / `founder`(経営者・個人事業主) / `student`(学生・研究者) / `all`(全職種。汎用の大型チャットモデルなど)
  - 打ち間違いは `build_legacy_feed.py` がエラーで止める

- `category`: chat / coding / imageGeneration / videoGeneration / videoEditing / audioMusic / writing / design / dataAnalysis / agent / search / pluginSkill / other
  - `pluginSkill` =「プラグイン・スキル」。Claudeのスキル・Mods、MCPコネクタ、ChatGPTのプラグインなど、既存のAIに後から足す拡張
- `kind`: `new`(新登場) か `update`(更新)
- `expectationScore`: 90以上=S、75以上=A、それ未満=B。**80以上でユーザーに通知が飛ぶ**ので、過大評価しない
- `attentionScore`: ネット上の話題度。前回より+20以上で「急上昇」通知が飛ぶ
- `date`: 実際の発表日(ISO8601・UTC)

## 2つのモード(1.4以降)

- **DISCOVERED**: 全項目を新しい順に出す。大型モデルだけでなく、**Bランクでも便利な小さめのツールを積極的に載せる**(「知らなかった便利なツール」を届けるモード)
- **CURATED**: **期待度85以上** かつ 選んだ職種向けの項目だけを出す。期待度は過大評価しない
- 営業・接客、事務・経理・人事、経営者向けの項目が少ない。これらの職種に役立つツールを優先して探す

## 中国向けの制約

アプリ側で、中国本土ストアの利用者には ChatGPT / OpenAI / Gemini / Claude / Anthropic / Midjourney を含む項目を出さない処理が入っている(App Store Review Guideline 5)。フィードにこれらの名前を書くこと自体は問題ないが、**アプリの説明文やスクリーンショットには書かない**。

## 更新頻度

週1〜2回。放置すると情報が古くなり、アプリの価値が落ちる。
