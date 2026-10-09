import Foundation
import Combine

enum DataSource: String, CaseIterable, Identifiable {
    case mock
    case remote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mock: return "モックデータ"
        case .remote: return "リモートJSON"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var dataSource: DataSource {
        didSet { defaults.set(dataSource.rawValue, forKey: "dataSource") }
    }
    @Published var remoteURLString: String {
        didSet { defaults.set(remoteURLString, forKey: "remoteURLString") }
    }
    /// この期待度スコア以上のNEW/UPDATEだけ通知する
    @Published var notifyThreshold: Int {
        didSet { defaults.set(notifyThreshold, forKey: "notifyThreshold") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    /// 注目度スコアが前回からこの値以上上昇したら「急上昇」として通知する
    @Published var spikeThreshold: Int {
        didSet { defaults.set(spikeThreshold, forKey: "spikeThreshold") }
    }
    /// 通知対象とするカテゴリ(検索・絞り込みと同じ粒度)。ここに含まれるカテゴリのイベントだけ通知する
    @Published var notifyCategories: Set<ServiceCategory> {
        didSet { defaults.set(notifyCategories.map(\.rawValue), forKey: "notifyCategories") }
    }
    /// 通知対象とする種別(nilならNEW/UPDATE両方)
    @Published var notifyKind: UpdateKind? {
        didSet { defaults.set(notifyKind?.rawValue, forKey: "notifyKind") }
    }

    private let defaults = UserDefaults.standard

    private init() {
        dataSource = DataSource(rawValue: defaults.string(forKey: "dataSource") ?? "") ?? .remote
        // feed-v2.json は新しいカテゴリを含む最新版。1.2以前のアプリ向けには、
        // 未知のカテゴリを other に落とした feed.json を別途配信している
        remoteURLString = defaults.string(forKey: "remoteURLString")
            ?? "https://raw.githubusercontent.com/businesssbtn21-collab/AIRadar/main/feed-v2.json"
        notifyThreshold = defaults.object(forKey: "notifyThreshold") as? Int ?? 80
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        spikeThreshold = defaults.object(forKey: "spikeThreshold") as? Int ?? 20
        if let savedCategories = defaults.array(forKey: "notifyCategories") as? [String] {
            // アップデートで増えたカテゴリだけONで追加する。保存した時点で存在していたカテゴリは、
            // ユーザーが自分でOFFにしたものなのでそのまま尊重する
            let knownCategories = Set(defaults.array(forKey: "knownNotifyCategories") as? [String] ?? savedCategories)
            var categories = Set(savedCategories.compactMap(ServiceCategory.init(rawValue:)))
            for category in ServiceCategory.allCases where !knownCategories.contains(category.rawValue) {
                categories.insert(category)
            }
            notifyCategories = categories
        } else {
            notifyCategories = Set(ServiceCategory.allCases)
        }
        defaults.set(ServiceCategory.allCases.map(\.rawValue), forKey: "knownNotifyCategories")
        notifyKind = (defaults.string(forKey: "notifyKind")).flatMap(UpdateKind.init(rawValue:))
    }

    func makeProvider() -> AIFeedProvider {
        switch dataSource {
        case .mock:
            return MockAIFeedProvider()
        case .remote:
            if let url = URL(string: remoteURLString), !remoteURLString.isEmpty {
                return RemoteAIFeedProvider(url: url)
            }
            return MockAIFeedProvider()
        }
    }
}
