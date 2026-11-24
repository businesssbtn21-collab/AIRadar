import Foundation

/// 未購入の人が無料で見られる範囲。一覧の最新数件だけを見せ、残りと各機能(CURATED・AIに聞く・通知・ウィジェット・設定)は購入で解放する。
enum FreeTier {
    /// 無料で一覧に出す件数(新しい順)
    static let visibleCount = 3

    static func visible<T>(_ items: [T], isUnlocked: Bool) -> [T] {
        isUnlocked ? items : Array(items.prefix(visibleCount))
    }

    /// 無料では見られずに隠れている件数
    static func hiddenCount(total: Int, isUnlocked: Bool) -> Int {
        isUnlocked ? 0 : max(0, total - visibleCount)
    }
}
