import SwiftUI

/// 無料版の一覧から開く購入画面。買い終わったら自動で閉じる
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        NavigationStack {
            PaywallView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }
}
