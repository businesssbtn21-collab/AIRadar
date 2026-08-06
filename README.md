# AIレーダー (AIRadar)

期待値の高い新しいAIサービスの「登場」や「大型アップデート」を見逃さないためのiOSアプリ。
ホーム画面・ロック画面のウィジェットに最新情報を常時表示し、バックグラウンド更新で新着を検知するとローカル通知する。

## 機能

- **フィード一覧**: NEW / UPD バッジ(コンパクト表示)、期待度ランク(S/A/B, 0-100スコア)、注目度(🔥, 0-100スコア)、カテゴリチップによる絞り込み
- **検索・絞り込み・並び替え**: サービス名・提供元・概要での検索、種別(NEW/UPDATE)・期待度しきい値・注目度しきい値によるフィルタ、新着順/期待度順/注目度順の並び替え
- **他ツールとの比較**: 詳細画面で同じカテゴリ内の他サービスと期待度・注目度を「A 98 > B 92 > …」の不等号表記で比較表示
- **ウィジェット**: systemSmall(最新1件)・systemMedium(最新3件)・accessoryRectangular(ロック画面)。期待度ランクと注目度を常時表示。App Group経由でアプリと同期
- **通知**: バックグラウンド更新(BGAppRefresh、目安4時間ごと・実行タイミングはOS任せ)で差分を検知し、(1)設定したしきい値(デフォルト: 期待度80)以上の新着・更新、(2)注目度が急上昇(デフォルト: +20以上)したサービス、をそれぞれローカル通知。通知対象は一覧の絞り込みとは別に、設定画面で**種別(NEW/UPDATE)・カテゴリ**を選んで絞り込める(デフォルトは全カテゴリON)。通知済みイベントは記録して重複通知を防止
- **設定**: データソース切替(モック⇄リモートJSON)、フィードURL、期待度しきい値、注目度急上昇しきい値、通知する種別・カテゴリ

## カテゴリ一覧

AIツールを網羅的に分類するため、以下12カテゴリを使用(検索の絞り込み・通知設定のカテゴリ選択で共通):

| rawValue | 表示名 |
|---|---|
| `chat` | チャット |
| `coding` | コーディング |
| `imageGeneration` | 画像生成 |
| `videoGeneration` | 動画生成 |
| `videoEditing` | 動画編集 |
| `audioMusic` | 音声・音楽 |
| `writing` | 文章・ライティング |
| `design` | デザイン |
| `dataAnalysis` | データ分析 |
| `agent` | 自動化・エージェント |
| `search` | 検索・リサーチ |
| `other` | その他 |

## 構成

```
AIRadar/
├── AIRadar/                 # アプリ本体ターゲット
│   ├── AIRadarApp.swift     # エントリ、BGTask登録、通知許可
│   ├── Services/
│   │   ├── AIFeedProvider.swift       # 取得元プロトコル
│   │   ├── MockAIFeedProvider.swift   # モックデータ(現在稼働中)
│   │   ├── RemoteAIFeedProvider.swift # リモートJSON取得(実運用向け)
│   │   ├── FeedStore.swift            # 取得・差分検知・通知・ウィジェット更新
│   │   └── AppSettings.swift
│   └── Views/               # 一覧・詳細・設定
├── AIRadarWidget/           # ウィジェット拡張ターゲット
├── Shared/                  # 両ターゲット共有(モデル、App Groupストア)
├── Info.plist               # BGTask識別子、UIBackgroundModes
├── AIRadarWidget-Info.plist # widgetkit-extension宣言
└── *.entitlements           # App Group: group.com.ryuta.airadar
```

## 実データ化(モックからの差し替え)

`RemoteAIFeedProvider` は下記スキーマのJSON配列を取得する。GitHubリポジトリに `feed.json` を置き、
raw URL(`https://raw.githubusercontent.com/<user>/<repo>/main/feed.json`)を設定画面に入力して
データソースを「リモートJSON」に切り替えるだけで動く。

```json
[
  {
    "id": "claude-fable-5",
    "name": "Claude Fable 5",
    "provider": "Anthropic",
    "category": "chat",
    "summary": "説明文",
    "changeNote": "変更点の要約",
    "kind": "new",
    "expectationScore": 98,
    "attentionScore": 90,
    "date": "2026-07-28T09:00:00Z",
    "url": "https://www.anthropic.com"
  }
]
```

- `category`: 上記カテゴリ一覧のrawValueのいずれか
- `kind`: new(新登場)/ update(アップデート)
- `expectationScore`: 0-100の期待度(90以上=S、75以上=A)。AIキュレーション時の編集的な評価
- `attentionScore`: 0-100の注目度。Hacker News・Product Hunt・X(旧Twitter)等でのポイント・投票・言及数をキュレーション時に正規化して算出する想定。**前回値との差分**をアプリ側が検知して急上昇通知を出すため、同じidのアイテムは毎回このスコアを更新して配信する
- `date`: ISO8601。同じidでもdateが変われば別イベントとして通知される

### フィードの運用案

1. **手動キュレーション**: GitHubで feed.json を直接編集(いちばん簡単・確実)
2. **GitHub Actions + Claude API**: 毎日AIニュースRSS(Product Hunt, Hacker News等)をClaude APIで要約・採点させてfeed.jsonを自動生成(Akanukeと同じAPI切替パターン)。attentionScoreはHacker News Algolia API・Product Hunt API等の集計値を0-100に正規化して埋め込む
3. 将来的にプッシュ通知サーバー化すればリアルタイム通知も可能(現状はBGAppRefreshのためOS判断で数時間の遅延あり)

### 急上昇通知の仕組み

`FeedStore.refresh()` は取得のたびに前回のスナップショット(App Groupに保存済み)と `attentionScore` を `id` 単位で比較し、設定したしきい値(デフォルト+20)以上上がっていれば「🔥急上昇」通知を出す。通知済みは `id-スコア` の組み合わせで記録するため、同じスコアでの再通知は起きない(スコアが変わるたびに再評価される)。

## 価格方針

**買い切り ¥980(有料App・ダウンロード課金)**。サブスクなし。

- App Store Connect でアプリ価格を ¥980 の価格帯に設定するだけ。アプリ側のコード変更は不要
- 代替案として「無料DL + 非消耗型IAPで¥980アンロック」方式もある(試用→購入の導線を作れるが StoreKit 実装が必要)。現方針は前者
- 注意: フィードを自前サーバーやAPI経由の自動生成にする場合、買い切りでも運用コストが継続発生する。GitHub raw の feed.json 運用ならコストほぼゼロで買い切りと相性が良い

## セットアップ

1. `AIRadar.xcodeproj` をXcodeで開く
2. 両ターゲット(AIRadar / AIRadarWidget)のSigningでチームを設定
3. App Group `group.com.ryuta.airadar` を両ターゲットのCapabilityに登録(シミュレータは自動署名でそのまま動く)
4. 実行後、ホーム画面長押し→ウィジェット追加→「AIレーダー」

### 既知の制約

- ウィジェット自体は通知を出せない(iOSの仕様)。通知はアプリ本体のBGAppRefresh+ローカル通知で実現し、ウィジェットは常時表示を担当
- BGAppRefreshの実行間隔はOSが決めるため保証されない(充電中・Wi-Fi接続時に実行されやすい)
- CLIビルド(`xcodebuild`)を使う場合は `sudo xcode-select -s /Applications/Xcode.app` が必要(現在CommandLineTools指定)
