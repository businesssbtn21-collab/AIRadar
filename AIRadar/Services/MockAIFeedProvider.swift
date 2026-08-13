import Foundation

/// サンプルデータ。実データ化する際は RemoteAIFeedProvider + キュレーションJSONに差し替える。
/// 内容はダミーであり、実在のサービス名・バージョンとは一致しない場合がある。
/// attentionScoreは毎回わずかに変動させ、急上昇通知の動作を手元で確認できるようにしている。
struct MockAIFeedProvider: AIFeedProvider {
    private struct Base {
        let id: String
        let name: String
        let provider: String
        let category: ServiceCategory
        let summary: String
        let changeNote: String
        let kind: UpdateKind
        let expectationScore: Int
        let attentionBase: Int
        let daysAgo: Int
        let url: String
    }

    private static let items: [Base] = [
        Base(id: "sample-chat-flagship", name: "Nova Mind 5", provider: "サンプルAI Labs", category: .chat,
             summary: "長時間の自律エージェント作業に対応する最上位クラスの対話モデル。",
             changeNote: "新モデルとして公開", kind: .new, expectationScore: 98, attentionBase: 90,
             daysAgo: 1, url: "https://example.com/novamind"),
        Base(id: "sample-video-gen", name: "MotionForge", provider: "サンプル社", category: .videoGeneration,
             summary: "テキストから4K・60秒の一貫性ある動画を生成。物理挙動の再現度が大幅向上。",
             changeNote: "v2で生成時間が1/3に短縮", kind: .update, expectationScore: 92, attentionBase: 78,
             daysAgo: 2, url: "https://example.com/motionforge"),
        Base(id: "sample-coding-agent", name: "DevPilot Agent", provider: "サンプルLab", category: .coding,
             summary: "リポジトリ全体を理解してPRまで自動で出すコーディングエージェント。",
             changeNote: "マルチリポ対応を追加", kind: .update, expectationScore: 88, attentionBase: 65,
             daysAgo: 3, url: "https://example.com/devpilot"),
        Base(id: "sample-voice", name: "EchoTalk", provider: "サンプルAudio", category: .audioMusic,
             summary: "遅延200msのリアルタイム音声会話AI。日本語の抑揚が自然に。",
             changeNote: "日本語ボイス20種追加", kind: .update, expectationScore: 76, attentionBase: 40,
             daysAgo: 5, url: "https://example.com/echotalk"),
        Base(id: "sample-search", name: "DeepFind", provider: "サンプル検索", category: .search,
             summary: "出典付きで深掘り調査を自動実行するリサーチAI。",
             changeNote: "新サービスとして公開", kind: .new, expectationScore: 84, attentionBase: 55,
             daysAgo: 6, url: "https://example.com/deepfind"),
        Base(id: "sample-image", name: "PixelMuse", provider: "サンプルArt", category: .imageGeneration,
             summary: "レイヤー分割出力に対応した画像生成。デザインワークフローに直結。",
             changeNote: "PSDエクスポート対応", kind: .update, expectationScore: 71, attentionBase: 30,
             daysAgo: 8, url: "https://example.com/pixelmuse"),
        Base(id: "sample-agent-os", name: "TaskMesh", provider: "サンプルWorks", category: .agent,
             summary: "複数のAIエージェントを連携させて業務フローを自動化するプラットフォーム。",
             changeNote: "新サービスとして公開", kind: .new, expectationScore: 90, attentionBase: 72,
             daysAgo: 10, url: "https://example.com/taskmesh"),
        Base(id: "sample-local-llm", name: "PocketBrain", provider: "サンプルOSS", category: .other,
             summary: "iPhone上でオフライン動作する小型高性能LLMランタイム。",
             changeNote: "メモリ使用量を40%削減", kind: .update, expectationScore: 68, attentionBase: 25,
             daysAgo: 12, url: "https://example.com/pocketbrain"),
        Base(id: "sample-chat-rival", name: "NovaChat", provider: "サンプルAI", category: .chat,
             summary: "長文コンテキストと安価な料金が売りの対話特化モデル。",
             changeNote: "コンテキスト長を200万トークンに拡大", kind: .update, expectationScore: 80, attentionBase: 58,
             daysAgo: 4, url: "https://example.com/novachat"),
        Base(id: "sample-coding-rival", name: "CodeSwift", provider: "サンプルDev", category: .coding,
             summary: "IDE常駐型でリアルタイムにペアプログラミングするAIアシスタント。",
             changeNote: "新サービスとして公開", kind: .new, expectationScore: 79, attentionBase: 48,
             daysAgo: 7, url: "https://example.com/codeswift"),
        Base(id: "sample-video-rival", name: "ClipDream", provider: "サンプルVision", category: .videoGeneration,
             summary: "静止画から短尺動画を自動生成するSNS向けツール。",
             changeNote: "縦型ショート動画テンプレートを追加", kind: .update, expectationScore: 74, attentionBase: 62,
             daysAgo: 9, url: "https://example.com/clipdream"),
        Base(id: "sample-video-editing", name: "CutSense", provider: "サンプルEdit", category: .videoEditing,
             summary: "長尺動画から見どころだけを自動でカットしてショート化するAI編集ツール。",
             changeNote: "新サービスとして公開", kind: .new, expectationScore: 81, attentionBase: 60,
             daysAgo: 4, url: "https://example.com/cutsense"),
        Base(id: "sample-writing", name: "WordCraft", provider: "サンプルText", category: .writing,
             summary: "ブログ・広告コピーをトーン指定で書き分ける文章生成AI。",
             changeNote: "SEO最適化モードを追加", kind: .update, expectationScore: 73, attentionBase: 44,
             daysAgo: 6, url: "https://example.com/wordcraft"),
        Base(id: "sample-design", name: "LayoutMind", provider: "サンプルDesign", category: .design,
             summary: "テキストの指示だけでUIモックアップやバナーを自動生成するデザインAI。",
             changeNote: "新サービスとして公開", kind: .new, expectationScore: 77, attentionBase: 50,
             daysAgo: 8, url: "https://example.com/layoutmind"),
        Base(id: "sample-data", name: "InsightGrid", provider: "サンプルData", category: .dataAnalysis,
             summary: "自然言語で質問するだけでスプレッドシートを分析・可視化するAI。",
             changeNote: "BIダッシュボード連携を追加", kind: .update, expectationScore: 82, attentionBase: 53,
             daysAgo: 3, url: "https://example.com/insightgrid")
    ]

    /// アプリ起動中は固定。これがないと再取得のたびにdateがずれてNEW/UPDATE通知が誤って毎回発火する。
    private static let anchor = Date()

    func fetchFeed() async throws -> [AIServiceItem] {
        // 通信をシミュレート
        try? await Task.sleep(nanoseconds: 400_000_000)

        func daysAgo(_ d: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -d, to: Self.anchor) ?? Self.anchor
        }

        return Self.items.map { base in
            let jitter = Int.random(in: -8...20)
            let attention = min(100, max(0, base.attentionBase + jitter))
            return AIServiceItem(
                id: base.id,
                name: base.name,
                provider: base.provider,
                category: base.category,
                summary: base.summary,
                changeNote: base.changeNote,
                kind: base.kind,
                expectationScore: base.expectationScore,
                attentionScore: attention,
                date: daysAgo(base.daysAgo),
                url: URL(string: base.url)
            )
        }
    }
}
