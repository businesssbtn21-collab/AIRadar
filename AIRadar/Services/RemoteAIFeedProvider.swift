import Foundation

/// リモートJSONフィードから取得するプロバイダ(実運用向け)。
///
/// フィードのJSONスキーマ(ISO8601日付):
/// ```json
/// [
///   {
///     "id": "sample-chat-flagship",
///     "name": "Nova Mind 5",
///     "provider": "サンプルAI Labs",
///     "category": "chat",
///     "summary": "説明文",
///     "changeNote": "変更点",
///     "kind": "new",
///     "expectationScore": 98,
///     "date": "2026-07-28T09:00:00Z",
///     "url": "https://example.com"
///   }
/// ]
/// ```
/// GitHubリポジトリに feed.json を置いて raw URL を設定画面に入力すれば動く。
struct RemoteAIFeedProvider: AIFeedProvider {
    let url: URL

    func fetchFeed() async throws -> [AIServiceItem] {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([AIServiceItem].self, from: data)
    }
}
