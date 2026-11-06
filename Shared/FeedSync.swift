import Foundation

/// アプリを開かなくてもウィジェットが最新のフィードを出せるように、
/// ウィジェット拡張からも直接フィードを取得できるようにする。
///
/// アプリ本体は FeedStore 経由で取得・通知まで行う。こちらは「表示用の取得」だけを担当する。
enum FeedSync {
    static let defaultFeedURL = "https://raw.githubusercontent.com/businesssbtn21-collab/AIRadar/main/feed-v2.json"

    private static let feedURLKey = "sharedFeedURL"
    private static let lastFetchAttemptKey = "lastFeedFetchAttempt"
    private static let unlockedKey = "isUnlocked"

    /// ウィジェットの更新要求が続いても取りに行きすぎないための最小間隔
    private static let minimumFetchInterval: TimeInterval = 15 * 60

    // MARK: - アプリ本体から共有する設定

    /// 設定画面でフィードURLを変えてもウィジェットが追随できるよう、App Group に保存しておく
    static func saveFeedURL(_ urlString: String) {
        SharedStore.defaults.set(urlString, forKey: feedURLKey)
    }

    /// 課金済みかどうか。未購入の端末ではウィジェットが勝手に取得しないようにする。
    /// 裏で起こされたとき(ロック中など)は購入情報を読めず未購入に見えることがある。
    /// そこで購入済みを消すと、次にアプリを開くまでウィジェットが自分で更新しなくなるので、
    /// 「未購入」への書き換えは画面に出ているときの確認だけで行う
    static func saveUnlocked(_ unlocked: Bool, checkedInForeground: Bool) {
        guard unlocked || checkedInForeground else { return }
        SharedStore.defaults.set(unlocked, forKey: unlockedKey)
    }

    static var isUnlocked: Bool {
        SharedStore.defaults.bool(forKey: unlockedKey)
    }

    static var feedURL: URL? {
        let string = SharedStore.defaults.string(forKey: feedURLKey) ?? defaultFeedURL
        return URL(string: string)
    }

    // MARK: - 取得

    /// 必要なら取りに行き、表示に使う項目を返す。
    /// 取得できなかったときや間隔が短いときは、保存済みの内容をそのまま返す。
    static func itemsRefreshingIfNeeded() async -> [AIServiceItem] {
        let cached = ChinaStorefrontPolicy.filter(SharedStore.loadItems())
        guard isUnlocked else { return cached }

        let lastAttempt = SharedStore.defaults.object(forKey: lastFetchAttemptKey) as? Date
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < minimumFetchInterval {
            return cached
        }
        SharedStore.defaults.set(Date(), forKey: lastFetchAttemptKey)

        guard let fetched = await fetch() else { return cached }
        SharedStore.saveItems(fetched)
        return fetched
    }

    private static func fetch() async -> [AIServiceItem]? {
        guard let url = feedURL else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let items = try? decoder.decode([AIServiceItem].self, from: data) else { return nil }
        return ChinaStorefrontPolicy.filter(items).sorted { $0.date > $1.date }
    }
}
