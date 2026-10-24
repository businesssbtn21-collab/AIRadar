import Foundation

/// App Store の評価をお願いするタイミング。使い始めてすぐや、同じバージョンで何度も出さない。
/// (実際に表示するかどうかは iOS が決め、1年に最大3回まで)
enum ReviewPromptPolicy {
    static let minimumDaysSinceFirstLaunch = 3
    static let minimumLaunchCount = 5

    static func shouldRequest(firstLaunch: Date,
                              launchCount: Int,
                              lastRequestedVersion: String?,
                              currentVersion: String,
                              now: Date) -> Bool {
        let days = now.timeIntervalSince(firstLaunch) / (24 * 60 * 60)
        return days >= Double(minimumDaysSinceFirstLaunch)
            && launchCount >= minimumLaunchCount
            && lastRequestedVersion != currentVersion
    }
}

/// 起動回数・初回起動日・お願いしたバージョンを保存する。
enum ReviewPromptTracker {
    static var defaults: UserDefaults = .standard

    private static let firstLaunchKey = "reviewPromptFirstLaunch"
    private static let launchCountKey = "reviewPromptLaunchCount"
    private static let lastRequestedVersionKey = "reviewPromptLastRequestedVersion"

    static func recordLaunch(now: Date = Date()) {
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(now, forKey: firstLaunchKey)
        }
        defaults.set(defaults.integer(forKey: launchCountKey) + 1, forKey: launchCountKey)
    }

    static func shouldRequestNow(currentVersion: String, now: Date = Date()) -> Bool {
        guard let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date else { return false }
        return ReviewPromptPolicy.shouldRequest(
            firstLaunch: firstLaunch,
            launchCount: defaults.integer(forKey: launchCountKey),
            lastRequestedVersion: defaults.string(forKey: lastRequestedVersionKey),
            currentVersion: currentVersion,
            now: now
        )
    }

    static func markRequested(version: String) {
        defaults.set(version, forKey: lastRequestedVersionKey)
    }
}
