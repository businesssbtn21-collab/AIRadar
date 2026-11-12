import Foundation

/// 一覧・通知・ウィジェットの届け方。
enum FeedMode: String, CaseIterable, Identifiable {
    /// 知らなかった便利なツールを、いち早くすべて
    case discovered
    /// 価値のあるものだけを、自分で決めた条件(職種・使っているツール・期待度)に合わせて
    case curated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discovered: return "DISCOVERED"
        case .curated: return "CURATED"
        }
    }

    var subtitle: String {
        switch self {
        case .discovered: return "いち早く発見"
        case .curated: return "価値あるものだけ"
        }
    }
}

/// CURATED で届ける内容を決める条件。すべてユーザーが決める。
struct CurationPreferences: Codable, Equatable {
    /// 選んだ職種(複数可)。空なら職種で絞らない(「その他(全般)」と同じ)
    var professions: Set<Profession> = []
    /// 使っているツール(フィードの提供元の名前)。ここに含まれる提供元の項目を届ける
    var myTools: Set<String> = []
    /// 職種で選ぶときの期待度の下限
    var minimumScore: Int = AIServiceItem.curatedMinimumScore
    /// 使っているツールの新着・更新は、期待度や職種に関係なく届ける
    var alwaysShowMyTools: Bool = true

    static let minimumScoreRange = 50...100

    /// 職種で絞るか(未選択や「その他(全般)」を含むときは絞らない)
    var filtersByProfession: Bool {
        !professions.isEmpty && !professions.contains(.general)
    }

    /// 一覧の上に出す短い説明(例: 「期待度85以上 × エンジニア・デザイナー + ツール2件」)
    var summary: String {
        if professions.isEmpty && !myTools.isEmpty {
            return "使っているツール\(myTools.count)件"
        }
        let jobs: String
        if !filtersByProfession {
            jobs = Profession.general.label
        } else {
            let sorted = Profession.allCases.filter(professions.contains)
            jobs = sorted.count <= 2 ? sorted.map(\.label).joined(separator: "・") : "\(sorted[0].label)ほか\(sorted.count - 1)職種"
        }
        var text = "期待度\(minimumScore)以上 × \(jobs)"
        if !myTools.isEmpty { text += " + ツール\(myTools.count)件" }
        return text
    }

    init(professions: Set<Profession> = [], myTools: Set<String> = [],
         minimumScore: Int = AIServiceItem.curatedMinimumScore, alwaysShowMyTools: Bool = true) {
        self.professions = professions
        self.myTools = myTools
        self.minimumScore = minimumScore
        self.alwaysShowMyTools = alwaysShowMyTools
    }

    /// 将来の版で項目や職種が増えても読めるよう、足りない値は既定値、知らない職種は無視する
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawProfessions = try c.decodeIfPresent([String].self, forKey: .professions) ?? []
        professions = Set(rawProfessions.compactMap(Profession.init(rawValue:)))
        myTools = try c.decodeIfPresent(Set<String>.self, forKey: .myTools) ?? []
        minimumScore = try c.decodeIfPresent(Int.self, forKey: .minimumScore) ?? AIServiceItem.curatedMinimumScore
        alwaysShowMyTools = try c.decodeIfPresent(Bool.self, forKey: .alwaysShowMyTools) ?? true
    }
}

/// アプリで選んだモードと条件。ウィジェットも同じ設定で表示するよう App Group に保存する。
enum ModePreferences {
    private static let modeKey = "feedMode"
    /// 1.5以前の「職種1つ」の保存先。読み込み時に新しい形へ引き継ぐ
    private static let legacyProfessionKey = "profession"
    private static let curationKey = "curationPreferences"

    static var mode: FeedMode {
        get { SharedStore.defaults.string(forKey: modeKey).flatMap(FeedMode.init(rawValue:)) ?? .discovered }
        set { SharedStore.defaults.set(newValue.rawValue, forKey: modeKey) }
    }

    /// まだ一度も条件を決めていないか(CURATED に切り替えたときに条件の画面を出す判断に使う)
    static var hasChosenCuration: Bool {
        SharedStore.defaults.data(forKey: curationKey) != nil
            || SharedStore.defaults.string(forKey: legacyProfessionKey) != nil
    }

    static var curation: CurationPreferences {
        get {
            if let data = SharedStore.defaults.data(forKey: curationKey),
               let saved = try? JSONDecoder().decode(CurationPreferences.self, from: data) {
                return saved
            }
            if let legacy = SharedStore.defaults.string(forKey: legacyProfessionKey).flatMap(Profession.init(rawValue:)) {
                return CurationPreferences(professions: [legacy])
            }
            return CurationPreferences()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                SharedStore.defaults.set(data, forKey: curationKey)
            }
        }
    }
}

extension AIServiceItem {
    /// 使っているツールの項目か。提供元の名前が一致するか、サービス名に含まれていれば該当とする
    /// (一覧から選んだ提供元のほか、自分で入力したツール名「Cursor」なども拾えるように)
    func isFromMyTools(_ curation: CurationPreferences) -> Bool {
        curation.myTools.contains { tool in
            let tool = tool.trimmingCharacters(in: .whitespaces)
            guard !tool.isEmpty else { return false }
            return provider.caseInsensitiveCompare(tool) == .orderedSame || name.localizedCaseInsensitiveContains(tool)
        }
    }

    /// 自分で決めた条件に合うか。
    /// 「期待度が下限以上で、選んだ職種のどれかに役立つ」か、「使っているツールの項目」なら届ける
    func isCurated(for curation: CurationPreferences) -> Bool {
        let fromMyTools = isFromMyTools(curation)
        if curation.alwaysShowMyTools && fromMyTools { return true }
        guard expectationScore >= curation.minimumScore else { return false }
        if fromMyTools { return true }
        // 職種を選ばずツールだけを選んだ人には、使っているツールの項目だけを見せる
        if curation.professions.isEmpty { return curation.myTools.isEmpty }
        if curation.professions.contains(.general) { return true }
        return curation.professions.contains { isRelevant(to: $0) }
    }

    /// このモードで表示・通知する対象か
    func matches(mode: FeedMode, curation: CurationPreferences) -> Bool {
        switch mode {
        case .discovered: return true
        case .curated: return isCurated(for: curation)
        }
    }
}

extension Array where Element == AIServiceItem {
    func applying(mode: FeedMode, curation: CurationPreferences) -> [AIServiceItem] {
        filter { $0.matches(mode: mode, curation: curation) }
    }
}
