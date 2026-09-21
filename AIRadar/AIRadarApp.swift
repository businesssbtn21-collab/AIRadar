import SwiftUI
import BackgroundTasks
import UserNotifications

/// アプリがフォアグラウンドの間もローカル通知をバナー表示させる(デフォルトだと抑制される)
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct AIRadarApp: App {
    @StateObject private var store = FeedStore()
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.scenePhase) private var scenePhase
    private let notificationPresenter = NotificationPresenter()

    static let refreshTaskID = "com.ryuta.airadar.refresh"

    init() {
        Self.registerBackgroundTask()
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !storeManager.hasCheckedEntitlements {
                    ProgressView()
                } else if storeManager.isUnlocked {
                    ContentView()
                        .task {
                            await store.refresh()
                        }
                } else {
                    PaywallView()
                }
            }
            .environmentObject(store)
            .environmentObject(AppSettings.shared)
            .environmentObject(storeManager)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Self.scheduleRefresh()
            }
        }
    }

    private static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            scheduleRefresh()
            let work = Task {
                await StoreManager.shared.refreshEntitlements()
                guard await StoreManager.shared.isUnlocked else {
                    refreshTask.setTaskCompleted(success: true)
                    return
                }
                let store = await FeedStore()
                await store.refresh()
                refreshTask.setTaskCompleted(success: true)
            }
            refreshTask.expirationHandler = {
                work.cancel()
                refreshTask.setTaskCompleted(success: false)
            }
        }
    }

    /// 次回のバックグラウンド更新を予約(実行タイミングはOS任せ。目安4時間後以降)
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
