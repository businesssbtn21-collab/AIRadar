import Foundation

/// 「AIに聞く」の質問を、フィードで絞り込める形に分解したもの。
/// iPhone の AI が使えるときは AI が作り、使えないときは言い換え辞書(`SmartSearch.parse`)が作る。
struct SearchIntent: Equatable {
    var categories: Set<ServiceCategory> = []
    var professions: Set<Profession> = []
    /// 名前・提供元・説明から探す語(小文字)
    var keywords: [String] = []
    /// 新しく出たもの(kind == .new)だけにする
    var onlyNew = false

    var isEmpty: Bool {
        categories.isEmpty && professions.isEmpty && keywords.isEmpty
    }
}

enum SmartSearch {
    // MARK: - 言い換え辞書での分解

    private static let categoryWords: [(ServiceCategory, [String])] = [
        (.chat, ["チャット", "会話", "対話", "相談", "chat", "llm", "大型モデル", "言語モデル"]),
        (.coding, ["コード", "コーディング", "プログラム", "プログラミング", "アプリ開発", "code", "coding"]),
        (.imageGeneration, ["画像", "イラスト", "絵", "写真", "image"]),
        (.videoGeneration, ["動画を作", "動画生成", "動画", "映像", "video"]),
        (.videoEditing, ["動画編集", "字幕", "切り抜き"]),
        (.audioMusic, ["音声", "音楽", "文字起こし", "読み上げ", "議事録", "効果音", "電話", "voice", "music"]),
        (.writing, ["文章", "ライティング", "執筆", "ブログ", "記事", "メール文"]),
        (.design, ["デザイン", "ロゴ", "スライド", "資料作り", "design"]),
        (.dataAnalysis, ["データ", "分析", "表計算", "エクセル", "excel", "集計"]),
        (.agent, ["自動化", "エージェント", "代わりに", "pc操作", "操作", "agent"]),
        (.search, ["検索", "リサーチ", "調べ", "search"]),
        (.pluginSkill, ["プラグイン", "スキル", "mcp", "拡張", "連携"]),
    ]

    private static let professionWords: [(Profession, [String])] = [
        (.engineer, ["エンジニア", "開発者", "プログラマ"]),
        (.designer, ["デザイナー"]),
        (.videoCreator, ["動画クリエイター", "youtuber", "動画投稿", "配信者"]),
        (.marketer, ["マーケ", "sns", "広告", "集客", "宣伝"]),
        (.writer, ["ライター", "編集者", "ブロガー"]),
        (.sales, ["営業", "接客", "商談", "セールス", "コールセンター"]),
        (.backOffice, ["事務", "経理", "人事", "総務", "バックオフィス", "請求"]),
        (.founder, ["経営", "社長", "個人事業", "起業", "小さな会社"]),
        (.student, ["学生", "研究", "勉強", "論文"]),
    ]

    /// 名前としては意味のない英字(「AI」など)
    private static let ignoredWords: Set<String> = ["ai", "the", "for", "and", "app", "tool", "tools"]

    static func parse(_ query: String) -> SearchIntent {
        let text = query.lowercased()
        var intent = SearchIntent()
        for (category, words) in categoryWords where words.contains(where: text.contains) {
            intent.categories.insert(category)
        }
        for (profession, words) in professionWords where words.contains(where: text.contains) {
            intent.professions.insert(profession)
        }
        intent.onlyNew = ["新登場", "新サービス", "新しく出た", "新しく登場"].contains(where: text.contains)

        // 英字の語(サービス名・会社名)はそのまま探す
        let latinWords = text.split { !($0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-")) }
        intent.keywords = latinWords.map(String.init)
            .filter { $0.count >= 2 && !ignoredWords.contains($0) }
            .filter { word in !categoryWords.contains { $0.1.contains(word) } && !professionWords.contains { $0.1.contains(word) } }
        return intent
    }

    // MARK: - AIの答えの整形

    /// AIが書いた答えから、マークダウンの記号(太字・見出し・箇条書き)と余分な空行・字下げを取り除く。
    /// 画面の文字はそのまま表示するので、記号が残ると「* **…**」のように見えてしまう
    static func plainAnswer(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { line -> String in
                var line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
                    .trimmingCharacters(in: .whitespaces)
                while line.hasPrefix("#") { line.removeFirst() }
                if line.hasPrefix("* ") || line.hasPrefix("- ") {
                    line = "・" + line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                }
                return line.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    // MARK: - 並べ替え

    /// 質問に合う項目を、合う度合いの高い順に返す。何も読み取れない質問では空を返す。
    static func rank(_ items: [AIServiceItem], for intent: SearchIntent, now: Date = Date()) -> [AIServiceItem] {
        guard !intent.isEmpty else { return [] }
        let scored: [(item: AIServiceItem, score: Double)] = items.compactMap { item in
            if intent.onlyNew && item.kind != .new { return nil }
            let match = matchScore(item, intent)
            guard match > 0 else { return nil }
            // 合う度合いが同じなら、新しいもの・期待度の高いものを上に
            let days = max(0, now.timeIntervalSince(item.date) / 86_400)
            let freshness = max(0, 14 - days) / 14
            return (item, match + freshness + Double(item.expectationScore) / 200)
        }
        return scored.sorted { $0.score > $1.score }.map(\.item)
    }

    private static func matchScore(_ item: AIServiceItem, _ intent: SearchIntent) -> Double {
        var score = 0.0
        if intent.categories.contains(item.category) { score += 4 }
        if !intent.professions.isEmpty {
            let tags = Set(item.professions ?? [])
            if intent.professions.contains(where: { tags.contains($0.rawValue) }) {
                score += 3
            } else if intent.professions.contains(where: { item.isRelevant(to: $0) }) {
                score += 1  // 全職種向け・カテゴリからの推定
            }
        }
        for keyword in intent.keywords {
            if item.name.lowercased().contains(keyword) {
                score += 3
            } else if [item.provider, item.summary, item.changeNote].contains(where: { $0.lowercased().contains(keyword) }) {
                score += 2
            }
        }
        return score
    }
}
