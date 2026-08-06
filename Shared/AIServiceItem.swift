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
    case other

    var id: String { rawValue }

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
