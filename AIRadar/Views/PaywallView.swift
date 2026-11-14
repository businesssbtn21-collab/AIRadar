import SwiftUI
import StoreKit

/// アプリは無料ダウンロードだが、全機能を使うにはここで非消耗型IAPを購入してもらう。
struct PaywallView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("AIレーダー フルアクセス")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("最新AIサービスの新着・更新フィードや期待度・注目度スコア、ウィジェット、通知など、すべての機能を使うにはアンロックが必要です。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            FeatureList()
                .padding(.horizontal, 32)

            Spacer()

            PurchaseSection()
        }
    }
}

/// 購入できる機能の一覧(課金画面とオンボーディングの購入ページで共通)
struct FeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("新着・更新フィード(全\(ServiceCategory.allCases.count)カテゴリ)")
            featureRow("DISCOVERED / CURATED の2モード(職種・使っているツールで厳選)")
            featureRow("AIに聞いて探せる「AIに聞く」")
            featureRow("期待度・注目度スコアとツール比較")
            featureRow("ホーム画面・ロック画面ウィジェット")
            featureRow("新着・急上昇の通知")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

/// 購入・復元のボタンと注意書き(課金画面とオンボーディングの購入ページで共通)
struct PurchaseSection: View {
    @ObservedObject private var store = StoreManager.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    isPurchasing = true
                    // 商品情報の取得に失敗していても、このボタンから再取得できるようにしておく
                    if store.product == nil {
                        await store.loadProduct()
                    }
                    if store.product != nil {
                        await store.purchase()
                    }
                    isPurchasing = false
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(isPurchasing || isRestoring)

            Button {
                Task {
                    isRestoring = true
                    await store.restore()
                    isRestoring = false
                }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("購入を復元")
                }
            }
            .font(.footnote)
            .disabled(isPurchasing || isRestoring)

            if let message = store.purchaseErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Text("一度購入すると、以後は無料で全機能を使い続けられます。機種変更時は「購入を復元」をご利用ください。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .task {
            if store.product == nil {
                await store.loadProduct()
            }
        }
    }

    private var purchaseButtonTitle: String {
        if let product = store.product {
            return "\(product.displayPrice) でフル機能を解放"
        }
        return "フル機能を解放する"
    }
}

#Preview {
    PaywallView()
}
