import Foundation
import StoreKit
import UserNotifications
import WidgetKit

/// フィードの取得・差分検知・通知・ウィジェット更新を担う中心クラス。
@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var items: [AIServiceItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefresh: Date?
    @Published var errorMessage: String?

    private let settings = AppSettings.shared

    init() {
        items = ChinaStorefrontPolicy.filter(SharedStore.loadItems())
        lastRefresh = SharedStore.lastRefresh
    }

    /// フィードを再取得し、新着・変更を検知したら通知とウィジェット更新を行う。
    /// フォアグラウンドの手動更新とバックグラウンド更新の両方から呼ばれる。
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await settings.makeProvider().fetchFeed()
            ChinaStorefrontPolicy.saveCountryCode(await Storefront.current?.countryCode)
            let sorted = ChinaStorefrontPolicy.filter(fetched).sorted { $0.date > $1.date }

            let previousItems = SharedStore.loadItems()
            let previousKeys = Set(previousItems.map(\.eventKey))
            let previousAttentionByID = Dictionary(uniqueKeysWithValues: previousItems.map { ($0.id, $0.attentionScore) })
            let freshEvents = sorted.filter { !previousKeys.contains($0.eventKey) }
            let spikes = sorted.filter { item in
                guard let previous = previousAttentionByID[item.id] else { return false }
                return item.attentionScore - previous >= settings.spikeThreshold
            }

            items = sorted
            lastRefresh = Date()
            SharedStore.saveItems(sorted)
            WidgetCenter.shared.reloadAllTimelines()

            await notifyIfNeeded(for: freshEvents)
            await notifySpikes(spikes)
        } catch {
            errorMessage = "取得に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 期待度スコアがしきい値以上の未通知イベントだけローカル通知する。
    private func notifyIfNeeded(for events: [AIServiceItem]) async {
        guard settings.notificationsEnabled else { return }

        let notified = SharedStore.notifiedKeys()
        let targets = events.filter {
            matchesNotifyFilter($0)
                && $0.expectationScore >= settings.notifyThreshold
                && !notified.contains($0.eventKey)
        }
        guard !targets.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let notificationSettings = await center.notificationSettings()
        guard notificationSettings.authorizationStatus == .authorized ||
              notificationSettings.authorizationStatus == .provisional else { return }

        for item in targets.prefix(5) {
            let content = UNMutableNotificationContent()
            content.title = "\(item.kind.label): \(item.name)"
            content.body = "\(item.changeNote) — 期待度\(item.rank)ランク(\(item.expectationScore))"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: item.eventKey,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
        SharedStore.markNotified(Set(targets.map(\.eventKey)))
    }

    /// 注目度スコアが急上昇したサービスを通知する。同じ数値では再通知しないようスコア込みのキーで管理する。
    private func notifySpikes(_ spikes: [AIServiceItem]) async {
        guard settings.notificationsEnabled, !spikes.isEmpty else { return }

        let notified = SharedStore.notifiedKeys()
        let targets = spikes.filter {
            matchesNotifyFilter($0) && !notified.contains("spike-\($0.id)-\($0.attentionScore)")
        }
        guard !targets.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let notificationSettings = await center.notificationSettings()
        guard notificationSettings.authorizationStatus == .authorized ||
              notificationSettings.authorizationStatus == .provisional else { return }

        for item in targets.prefix(5) {
            let content = UNMutableNotificationContent()
            content.title = "🔥急上昇: \(item.name)"
            content.body = "注目度が\(item.attentionScore)に上昇中(\(item.provider))"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "spike-\(item.id)-\(item.attentionScore)-\(item.date.timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
        SharedStore.markNotified(Set(targets.map { "spike-\($0.id)-\($0.attentionScore)" }))
    }

    /// 設定画面で選んだカテゴリ・種別の絞り込みを、通知対象にも適用する。
    private func matchesNotifyFilter(_ item: AIServiceItem) -> Bool {
        guard settings.notifyCategories.contains(item.category) else { return false }
        if let kind = settings.notifyKind, item.kind != kind { return false }
        return true
    }
}
