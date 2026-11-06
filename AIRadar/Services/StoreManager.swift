import Foundation
import StoreKit
import UIKit

/// アプリ本体は無料配布し、全機能のアンロックを非消耗型のApp内課金で販売するためのStoreKit 2ラッパー。
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let fullAccessProductID = "com.ryuta.airadar.fullaccess"

    @Published private(set) var isUnlocked = false
    @Published private(set) var hasCheckedEntitlements = false
    @Published private(set) var product: Product?
    @Published var purchaseErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.fullAccessProductID])
            product = products.first
        } catch {
            purchaseErrorMessage = "商品情報の取得に失敗しました。通信環境をご確認のうえ、もう一度お試しください。"
        }
    }

    /// 現在有効な購入内容を確認し、フルアクセス権を反映する。
    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.fullAccessProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }

        if !unlocked {
            unlocked = await purchasedUnderLegacyPaidAppModel()
        }

        isUnlocked = unlocked
        hasCheckedEntitlements = true
        // 未購入の端末でウィジェットが勝手にフィードを取りに行かないよう共有しておく
        FeedSync.saveUnlocked(unlocked,
                              checkedInForeground: UIApplication.shared.applicationState != .background)
    }

    /// AppTransactionの取得は通信状況によっては応答が返らないことがある。
    /// Paywallが出ないまま待たされるのを避けるため、数秒で打ち切って「旧購入者ではない」扱いにする。
    private func purchasedUnderLegacyPaidAppModel() async -> Bool {
        await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await Self.legacyPaidAppEntitlement() }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return nil
            }
            defer { group.cancelAll() }
            for await value in group {
                return value ?? false
            }
            return false
        }
    }

    private static func legacyPaidAppEntitlement() async -> Bool {
        guard let result = try? await AppTransaction.shared,
              case .verified(let appTransaction) = result else { return false }
        // Sandbox(App Reviewの審査環境を含む)では originalAppVersion が常に "1.0" になり、
        // 誰でも旧有料版の購入者と誤判定されてPaywallが出なくなる。本番のみで判定する。
        guard appTransaction.environment == .production else { return false }
        return LegacyPurchasePolicy.isLegacyPaidPurchase(originalAppVersion: appTransaction.originalAppVersion)
    }

    func purchase() async {
        guard let product else { return }
        purchaseErrorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transactionResult: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = "購入処理に失敗しました。もう一度お試しください。"
        }
    }

    func restore() async {
        purchaseErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isUnlocked {
                purchaseErrorMessage = "復元できる購入履歴が見つかりませんでした。"
            }
        } catch {
            purchaseErrorMessage = "復元に失敗しました。もう一度お試しください。"
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        if transaction.productID == Self.fullAccessProductID {
            await refreshEntitlements()
        }
        await transaction.finish()
    }
}
