import Foundation

/// アプリ本体とウィジェットで最新フィードを共有するための App Group ストア。
/// App Group が未設定の環境では standard にフォールバックする(その場合ウィジェットには反映されない)。
enum SharedStore {
    static let appGroupID = "group.com.ryuta.airadar"

    private static let snapshotKey = "feedSnapshot"
    private static let lastRefreshKey = "lastRefresh"
    private static let notifiedKeysKey = "notifiedEventKeys"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func saveItems(_ items: [AIServiceItem]) {
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: snapshotKey)
        }
        defaults.set(Date(), forKey: lastRefreshKey)
    }

    static func loadItems() -> [AIServiceItem] {
        guard let data = defaults.data(forKey: snapshotKey),
              let items = try? decoder.decode([AIServiceItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.date > $1.date }
    }

    static var lastRefresh: Date? {
        defaults.object(forKey: lastRefreshKey) as? Date
    }

    /// 通知済みイベントキー(重複通知の防止用)
    static func notifiedKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: notifiedKeysKey) ?? [])
    }

    static func markNotified(_ keys: Set<String>) {
        var all = notifiedKeys().union(keys)
        // 無限に増えないよう直近500件だけ保持
        if all.count > 500 {
            all = Set(Array(all).suffix(500))
        }
        defaults.set(Array(all), forKey: notifiedKeysKey)
    }
}
