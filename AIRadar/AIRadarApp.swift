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
        // バックグラウンドに回る前にアプリを終了されても予約が残るよう、起動時にも入れておく
        Self.scheduleRefresh()
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
                // 裏で起こされたときは購入情報を読めず未購入に見えることがあるので、
                // 画面に出ていたときに確かめた結果(共有のフラグ)で判断する
                guard FeedSync.isUnlocked else {
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

    /// 次回のバックグラウンド更新を予約(実行タイミングはOS任せ。1時間後以降の実行を希望)
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
