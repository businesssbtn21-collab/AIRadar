import Foundation

/// 初めて起動した未購入の人に、課金画面の前にできることを画像で案内する。
/// 最後のページ(購入ページ)まで見たら記録し、次からは課金画面だけを出す。
enum OnboardingPolicy {
    static let seenKey = "hasSeenOnboarding"

    static func shouldShow(hasSeen: Bool, isUnlocked: Bool) -> Bool {
        !hasSeen && !isUnlocked
    }
}
