import Foundation

/// 一覧・通知・ウィジェットの届け方。
enum FeedMode: String, CaseIterable, Identifiable {
    /// 知らなかった便利なツールを、いち早くすべて
    case discovered
    /// 価値のあるものだけを、選んだ職種に合わせて
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

/// アプリで選んだモードと職種。ウィジェットも同じ設定で表示するよう App Group に保存する。
enum ModePreferences {
    private static let modeKey = "feedMode"
    private static let professionKey = "profession"

    static var mode: FeedMode {
        get { SharedStore.defaults.string(forKey: modeKey).flatMap(FeedMode.init(rawValue:)) ?? .discovered }
        set { SharedStore.defaults.set(newValue.rawValue, forKey: modeKey) }
    }

    /// CURATED で選んだ職種。未選択なら nil(「その他(全般)」として扱う)
    static var profession: Profession? {
        get { SharedStore.defaults.string(forKey: professionKey).flatMap(Profession.init(rawValue:)) }
        set { SharedStore.defaults.set(newValue?.rawValue, forKey: professionKey) }
    }
}

extension AIServiceItem {
    /// このモードで表示・通知する対象か。CURATED で職種が未選択なら「その他(全般)」扱い。
    func matches(mode: FeedMode, profession: Profession?) -> Bool {
        switch mode {
        case .discovered: return true
        case .curated: return isCurated(for: profession ?? .general)
        }
    }
}

extension Array where Element == AIServiceItem {
    func applying(mode: FeedMode, profession: Profession?) -> [AIServiceItem] {
        filter { $0.matches(mode: mode, profession: profession) }
    }
}
