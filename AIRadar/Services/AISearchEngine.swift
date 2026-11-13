import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 「AIに聞く」の結果
struct AISearchResult {
    var items: [AIServiceItem]
    /// AIが書いた短い答え(AIが使えないとき・まだ考えているときは nil)
    var answer: String?
    var usedAI: Bool
}

/// iPhone の中で動く Apple の AI(Foundation Models)で質問を読み取り、フィードから探す。
/// 無料で、質問は端末の外に出ない。AIは数秒〜十数秒かかるので、先に言い換え辞書での結果をすぐ出し、
/// AIの結果が届いたら差し替える。AIが使えない端末では辞書での結果だけになる。
@MainActor
enum AISearchEngine {
    static let maxResults = 20

    /// iOS 26 以降で、Apple Intelligence に対応・有効な端末か
    static var isAIAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// 言い換え辞書ですぐに探す(AIを待たずに出す結果)
    static func quickSearch(_ query: String, in items: [AIServiceItem]) -> AISearchResult {
        let ranked = SmartSearch.rank(items, for: SmartSearch.parse(query))
        return AISearchResult(items: Array(ranked.prefix(maxResults)), answer: nil, usedAI: false)
    }

    /// 「AIに聞く」を開いたときに呼ぶ。最初の質問の待ち時間を減らすため、AIを先に読み込んでおく
    static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            preparedIntentSession = makeIntentSession()
        }
        #endif
    }

    /// AIで探す。AIが使えない・失敗したときは nil(辞書での結果をそのまま使う)
    static func aiSearch(_ query: String, in items: [AIServiceItem]) async -> AISearchResult? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            return try? await searchWithAI(query, in: items)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static var preparedIntentSession: LanguageModelSession?

    @available(iOS 26.0, *)
    private static func makeIntentSession() -> LanguageModelSession {
        let session = LanguageModelSession(instructions: """
            あなたは、新しいAIツールを紹介するアプリの検索係です。
            利用者の質問を読み、当てはまるツールの種類・職種・固有名詞を選んでください。当てはまらないものは選ばないでください。
            """)
        session.prewarm()
        return session
    }

    @available(iOS 26.0, *)
    private static func searchWithAI(_ query: String, in items: [AIServiceItem]) async throws -> AISearchResult {
        // 1. 質問を、フィードで絞り込める形に分解させる(選べる値は決まっている)
        //    会話の履歴がたまらないよう、セッションは1回ごとに作り直す
        let intentSession = preparedIntentSession ?? makeIntentSession()
        preparedIntentSession = makeIntentSession()
        let generated = try await intentSession.respond(to: query, generating: GeneratedIntent.self).content

        // AIの読み取りに、辞書での読み取りを足して取りこぼしを減らす
        var intent = SmartSearch.parse(query)
        intent.categories.formUnion(generated.categories.compactMap { ServiceCategory(rawValue: $0.rawValue) })
        intent.professions.formUnion(generated.professions.compactMap { Profession(rawValue: $0.rawValue) })
        let keywords = generated.keywords.map { $0.lowercased() }.filter { $0.count >= 2 && $0 != "ai" }
        intent.keywords = Array(Set(intent.keywords + keywords))
        intent.onlyNew = intent.onlyNew || generated.onlyNew

        let ranked = Array(SmartSearch.rank(items, for: intent).prefix(maxResults))
        guard !ranked.isEmpty else {
            return AISearchResult(items: [], answer: nil, usedAI: true)
        }

        // 2. 上位の候補だけを渡して、短い答えを書かせる(候補にないツールは書かせない)
        let candidates = ranked.prefix(3).map { item in
            "・\(item.name)(\(item.provider)): \(item.changeNote)。\(item.summary)"
        }.joined(separator: "\n")
        let answerSession = LanguageModelSession(instructions: """
            あなたは、新しいAIツールを紹介するアプリの案内係です。
            渡された候補の内容だけを根拠に、質問への答えをやさしい日本語の2文以内で書いてください。
            いちばん合う候補の名前と、なぜ合うのかを具体的に書いてください。候補にないツールや、候補に書かれていないことは書かないでください。
            箇条書き・見出し・太字などの記号は使わず、普通の文章で書いてください。
            """)
        let answer = try? await answerSession.respond(to: "質問: \(query)\n\n候補:\n\(candidates)").content
        return AISearchResult(items: ranked, answer: answer.map(SmartSearch.plainAnswer), usedAI: true)
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
enum CategoryChoice: String {
    case chat, coding, imageGeneration, videoGeneration, videoEditing, audioMusic
    case writing, design, dataAnalysis, agent, search, pluginSkill, repository
}

@available(iOS 26.0, *)
@Generable
enum ProfessionChoice: String {
    case engineer, designer, videoCreator, marketer, writer, sales, backOffice, founder, student
}

@available(iOS 26.0, *)
@Generable
struct GeneratedIntent {
    @Guide(description: "質問に合うツールの種類。chat=会話、coding=プログラミング、imageGeneration=画像生成、videoGeneration=動画生成、videoEditing=動画編集、audioMusic=音声・音楽・文字起こし、writing=文章、design=デザイン、dataAnalysis=データ分析、agent=作業の自動化、search=検索・リサーチ、pluginSkill=AIに足す拡張、repository=GitHubなどで公開されている自分で入れるツール")
    var categories: [CategoryChoice]
    @Guide(description: "質問者の職種や使う場面。engineer=エンジニア、designer=デザイナー、videoCreator=動画制作、marketer=マーケティング・SNS、writer=ライター、sales=営業・接客、backOffice=事務・経理・人事、founder=経営者・個人事業主、student=学生・研究")
    var professions: [ProfessionChoice]
    @Guide(description: "質問に出てきたサービス名・会社名などの固有名詞。なければ空")
    var keywords: [String]
    @Guide(description: "新しく登場したサービスだけを探しているなら true")
    var onlyNew: Bool
}
#endif
