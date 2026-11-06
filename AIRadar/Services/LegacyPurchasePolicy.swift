import Foundation

/// 1.1以前は買い切り有料アプリ(980円)として配信していたため、そのバージョンで
/// ダウンロード済みのユーザーには新しいApp内課金を求めず、引き続き全機能を使えるようにする。
enum LegacyPurchasePolicy {
    /// iPhone では AppTransaction.originalAppVersion にビルド番号(CFBundleVersion)が入る。
    /// 有料で配信していたのは 1.0 = ビルド1、1.1 = ビルド2
    static let lastPaidBuild = 2

    static func isLegacyPaidPurchase(originalAppVersion: String) -> Bool {
        guard let build = Int(originalAppVersion.split(separator: ".").first ?? "") else { return false }
        return build <= lastPaidBuild
    }
}
