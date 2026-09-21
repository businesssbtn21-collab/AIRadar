import AppIntents

/// ウィジェットに表示するカテゴリの絞り込み。`すべて` は絞り込みなし。
enum WidgetCategoryFilter: String, AppEnum {
    case all
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

    /// 対応する ServiceCategory。`all` のときは nil(絞り込みなし)。
    var category: ServiceCategory? {
        guard self != .all else { return nil }
        return ServiceCategory(rawValue: rawValue)
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "カテゴリ"

    // AppIntents の制約で、ここは静的な値として全ケースを列挙する必要がある
    // (ServiceCategory.label から生成することはできない)
    static var caseDisplayRepresentations: [WidgetCategoryFilter: DisplayRepresentation] = [
        .all: "すべて",
        .chat: "チャット",
        .coding: "コーディング",
        .imageGeneration: "画像生成",
        .videoGeneration: "動画生成",
        .videoEditing: "動画編集",
        .audioMusic: "音声・音楽",
        .writing: "文章・ライティング",
        .design: "デザイン",
        .dataAnalysis: "データ分析",
        .agent: "自動化・エージェント",
        .search: "検索・リサーチ",
        .other: "その他"
    ]
}

/// ウィジェットに表示する期待度ランクの下限。
enum WidgetRankFilter: String, AppEnum {
    case all
    case aOrAbove
    case sOnly

    /// このランク以上を表示するための期待度スコア下限
    var minimumExpectationScore: Int {
        switch self {
        case .all: return 0
        case .aOrAbove: return 75
        case .sOnly: return 90
        }
    }

    /// ウィジェットのヘッダーに出す短い表示(すべてのときは出さない)
    var shortLabel: String? {
        switch self {
        case .all: return nil
        case .aOrAbove: return "A以上"
        case .sOnly: return "Sのみ"
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "期待度"

    static var caseDisplayRepresentations: [WidgetRankFilter: DisplayRepresentation] = [
        .all: "すべて",
        .aOrAbove: "Aランク以上(期待度75以上)",
        .sOnly: "Sランクのみ(期待度90以上)"
    ]
}

/// ウィジェット長押し →「ウィジェットを編集」で設定する絞り込み。
struct WidgetFilterIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "表示するAIツールの絞り込み" }
    static var description: IntentDescription {
        IntentDescription("ウィジェットに表示するAIツールを、カテゴリと期待度ランクで絞り込みます。")
    }

    @Parameter(title: "カテゴリ", default: .all)
    var category: WidgetCategoryFilter

    @Parameter(title: "期待度", default: .all)
    var rank: WidgetRankFilter

    init() {}

    init(category: WidgetCategoryFilter, rank: WidgetRankFilter) {
        self.category = category
        self.rank = rank
    }

    /// ヘッダーに出す絞り込みの要約。絞り込みなしのときは nil。
    var summaryLabel: String? {
        var parts: [String] = []
        if let category = category.category { parts.append(category.label) }
        if let rankLabel = rank.shortLabel { parts.append(rankLabel) }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }
}

extension Array where Element == AIServiceItem {
    /// ウィジェットの設定に従って絞り込む。
    func applying(_ filter: WidgetFilterIntent) -> [AIServiceItem] {
        self.filter { item in
            if let category = filter.category.category, item.category != category { return false }
            return item.expectationScore >= filter.rank.minimumExpectationScore
        }
    }
}
