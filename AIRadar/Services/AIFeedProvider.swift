import Foundation

/// AIサービスフィードの取得元。
/// 現状は MockAIFeedProvider が稼働。実運用では RemoteAIFeedProvider に切り替え、
/// GitHub等にホストしたキュレーションJSONやニュースAPIを指す想定。
protocol AIFeedProvider {
    func fetchFeed() async throws -> [AIServiceItem]
}
