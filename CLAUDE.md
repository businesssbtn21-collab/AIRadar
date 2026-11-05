# AIRadar(AIレーダー)

新しいAIサービスの登場・大型アップデートを、ウィジェットと通知で追うiOSアプリ。App Store公開中。

- Bundle ID: `com.ryuta.airadar` / ウィジェット `com.ryuta.airadar.widget` / App Group `group.com.ryuta.airadar`
- ASC App ID: 6800782138 / Team: AJMXFYG2BY / 署名は手動
- リポジトリ: https://github.com/businesssbtn21-collab/AIRadar (public)
- 価格: 本体無料 + 非消耗型IAP「フルアクセス」`com.ryuta.airadar.fullaccess` ¥900。1.1以前の有料版購入者は追加課金なし

## 構成

- `AIRadar/` アプリ本体、`AIRadarWidget/` ウィジェット拡張、`Shared/` 両方で共有(モデル・App Groupのストア)
- Xcode 16 のフォルダ同期方式なので、上記フォルダに置いたファイルは自動でターゲットに入る
- `AIRadar/Services/` にフィード取得(FeedStore)・設定(AppSettings)・課金(StoreManager)
- `Shared/AIServiceItem.swift` がカテゴリとモデル。`Shared/WidgetFilter.swift` がウィジェットの絞り込み(App Intents)

## 触るときの注意

- **カテゴリなどの列挙型を増やすとき**: 旧バージョンのアプリが解析に失敗しないか必ず確認する。1.3以降は未知のカテゴリを `other` として読む
- **配信フィードは2本立て**: `feed-v2.json`(1.3以降が読む本体) と `feed.json`(1.2以前向け。`tools/build_legacy_feed.py` で生成)。feed.json は手で編集しない → `/airadar-feed`
- **フィードは毎朝自動で更新される**: クラウドのルーティンが `claude/feed-auto` に候補を置き、GitHub Actions(`.github/workflows/publish-feed.yml`)が `tools/validate_feed.py` で点検して main に反映する。点検の決まりを変えるときは、スクリプトとスキルの両方を直す
- **App Intents の `AppEnum`**: `caseDisplayRepresentations` は静的な辞書リテラルで全ケース書く(他の列挙型から生成するとビルドが通らない)
- **中国本土ストア対応**: `Shared/ChinaStorefrontPolicy.swift` が未許認可の生成AIサービス(ChatGPT/OpenAI/Gemini/Claude/Anthropic/Midjourney)に触れる項目を非表示にする。アプリの説明文・キーワード・スクショにもこれらの名前を書かない(Guideline 5)
- **隠し機能を足さない**(Guideline 2.3.1)。開発者本人の無料利用はオファーコードで行う
- **公開物に本名を書かない**。著作権欄は「© 2026 AIRadar」、gitの作者名は `businesssbtn21-collab`

## よく使う操作

- ビルド確認: `xcodebuild -project AIRadar.xcodeproj -scheme AIRadar -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- 提出一式: `/app-submit` スキル参照(アーカイブ→`xcodebuild -exportArchive`の`destination=upload`で直接アップロード→ASC)
- `git push` はCLIからできない(認証なし)。GitHub Desktop の「Push origin」を押す
