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
        dataSource = DataSource(rawValue: defaults.string(forKey: "dataSource") ?? "") ?? .mock
        remoteURLString = defaults.string(forKey: "remoteURLString") ?? ""
        notifyThreshold = defaults.object(forKey: "notifyThreshold") as? Int ?? 80
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        spikeThreshold = defaults.object(forKey: "spikeThreshold") as? Int ?? 20
        if let savedCategories = defaults.array(forKey: "notifyCategories") as? [String] {
            notifyCategories = Set(savedCategories.compactMap(ServiceCategory.init(rawValue:)))
        } else {
            notifyCategories = Set(ServiceCategory.allCases)
        }
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
