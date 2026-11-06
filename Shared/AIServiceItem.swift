import Foundation

/// AIツールの種類。検索・絞り込み・通知設定すべてで共通して使うカテゴリ一覧。
enum ServiceCategory: String, Codable, CaseIterable, Identifiable {
    case chat
    case coding
    case imageGeneration
    case videoGeneration
    case videoEditing
    case audioMusic
    case writing
    case design
    case dataAnalysis
    case agent
    case search
    /// ChatGPTやClaudeなどに後から足して使う拡張(スキル・プラグイン・MCPコネクタ・GPTsなど)
    case pluginSkill
    case other

    var id: String { rawValue }

    /// 将来フィードに新しいカテゴリが増えても、このバージョンのアプリで読み込みが失敗しないようにする
    /// (知らないカテゴリは「その他」として扱う)
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = ServiceCategory(rawValue: rawValue) ?? .other
    }

    var label: String {
        switch self {
        case .chat: return "チャット"
        case .coding: return "コーディング"
        case .imageGeneration: return "画像生成"
        case .videoGeneration: return "動画生成"
        case .videoEditing: return "動画編集"
        case .audioMusic: return "音声・音楽"
        case .writing: return "文章・ライティング"
        case .design: return "デザイン"
        case .dataAnalysis: return "データ分析"
        case .agent: return "自動化・エージェント"
        case .search: return "検索・リサーチ"
        case .pluginSkill: return "プラグイン・スキル"
        case .other: return "その他"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .imageGeneration: return "photo"
        case .videoGeneration: return "video"
        case .videoEditing: return "scissors"
        case .audioMusic: return "waveform"
        case .writing: return "pencil.line"
        case .design: return "paintbrush"
        case .dataAnalysis: return "chart.bar"
        case .agent: return "gearshape.2"
        case .search: return "magnifyingglass"
        case .pluginSkill: return "puzzlepiece.extension"
        case .other: return "sparkles"
        }
    }
}

enum UpdateKind: String, Codable {
    case new
    case update

    var label: String {
        switch self {
        case .new: return "NEW"
        case .update: return "UPDATE"
        }
    }

    /// 一覧のバッジ用に短縮した表記
    var shortLabel: String {
        switch self {
        case .new: return "NEW"
        case .update: return "UPD"
        }
    }
}

struct AIServiceItem: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let provider: String
    let category: ServiceCategory
    let summary: String
    let changeNote: String
    let kind: UpdateKind
    let expectationScore: Int
    /// 注目度: ネット上の実反応(Hacker News/Product Hunt/X等の言及・投票数)をキュレーション時に集計したスコア(0-100)
    let attentionScore: Int
    let date: Date
    let url: URL?
    /// 向いている職種(Profession の raw 値、全職種向けは "all")。
    /// 将来職種が増えても旧版が壊れないよう文字列のまま持ち、知らない値は無視する。
    /// 省略時はカテゴリから推定する
    var professions: [String]? = nil

    /// CURATED に載せる期待度の下限
    static let curatedMinimumScore = 85

    func isRelevant(to profession: Profession) -> Bool {
        if profession == .general { return true }
        guard let professions, !professions.isEmpty else {
            return Profession.inferred(from: category).contains(profession)
        }
        return professions.contains("all") || professions.contains(profession.rawValue)
    }

    /// CURATED モードで表示・通知する対象か(期待度が高く、かつ選んだ職種向け)
    func isCurated(for profession: Profession) -> Bool {
        expectationScore >= Self.curatedMinimumScore && isRelevant(to: profession)
    }

    /// 詳細画面の「公式サイトを開く」に使うリンク。フィードが書き換えられても
    /// ほかのアプリを起動するリンク(tel: など)を開かないよう、http/https だけを通す
    var webURL: URL? {
        guard let url, let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }

    /// 期待度ランク: 90以上=S, 75以上=A, それ未満=B
    var rank: String {
        switch expectationScore {
        case 90...: return "S"
        case 75..<90: return "A"
        default: return "B"
        }
    }

    /// 注目度を炎の数で表現
    var attentionLevel: String {
        switch attentionScore {
        case 85...: return "🔥🔥🔥"
        case 60..<85: return "🔥🔥"
        case 35..<60: return "🔥"
        default: return ""
        }
    }

    /// 同一サービスでも更新があれば別イベントとして扱うためのキー
    var eventKey: String {
        "\(id)-\(Int(date.timeIntervalSince1970))"
    }
}
