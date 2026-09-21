import Foundation

/// 中国本土のApp Storeでは、現地で許認可のない生成AIサービスへの言及を表示できない
/// (App Store Review Guideline 5)。該当ストアの利用者には関連項目を出さない。
enum ChinaStorefrontPolicy {
    static let restrictedStorefront = "CHN"

    private static let storefrontKey = "storefrontCountryCode"
    private static let restrictedTerms = ["chatgpt", "openai", "gemini", "claude", "anthropic", "midjourney"]

    /// ウィジェットからも同期的に参照できるよう、最後に取得したストアの国コードを App Group に保存する
    static var countryCode: String? {
        SharedStore.defaults.string(forKey: storefrontKey)
    }

    static func saveCountryCode(_ code: String?) {
        guard let code else { return }
        SharedStore.defaults.set(code, forKey: storefrontKey)
    }

    static var isRestricted: Bool {
        countryCode == restrictedStorefront
    }

    static func filter(_ items: [AIServiceItem]) -> [AIServiceItem] {
        guard isRestricted else { return items }
        return items.filter { !mentionsRestrictedService($0) }
    }

    static func mentionsRestrictedService(_ item: AIServiceItem) -> Bool {
        let text = [item.name, item.provider, item.summary, item.changeNote, item.url?.absoluteString ?? ""]
            .joined(separator: " ")
            .lowercased()
        return restrictedTerms.contains { text.contains($0) }
    }
}
