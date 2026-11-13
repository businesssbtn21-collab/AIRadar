import Foundation

/// CURATED モードで「その職種に役立つものだけ」を届けるための職種。
/// フィードの `professions` にはこの raw 値(と全職種向けの "all")を書く。
enum Profession: String, Codable, CaseIterable, Identifiable {
    case engineer
    case designer
    case videoCreator
    case marketer
    case writer
    case sales
    case backOffice
    case founder
    case student
    /// 職種で絞らず、期待度の高いものをすべて届ける
    case general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .engineer: return "エンジニア"
        case .designer: return "デザイナー"
        case .videoCreator: return "動画クリエイター"
        case .marketer: return "マーケター・SNS運用"
        case .writer: return "ライター・編集"
        case .sales: return "営業・接客"
        case .backOffice: return "事務・経理・人事"
        case .founder: return "経営者・個人事業主"
        case .student: return "学生・研究者"
        case .general: return "その他(全般)"
        }
    }

    var icon: String {
        switch self {
        case .engineer: return "chevron.left.forwardslash.chevron.right"
        case .designer: return "paintpalette"
        case .videoCreator: return "video"
        case .marketer: return "megaphone"
        case .writer: return "pencil.line"
        case .sales: return "person.2"
        case .backOffice: return "doc.text"
        case .founder: return "briefcase"
        case .student: return "graduationcap"
        case .general: return "sparkles"
        }
    }

    /// フィードに `professions` が書かれていない項目について、カテゴリから向いている職種を推定する
    static func inferred(from category: ServiceCategory) -> Set<Profession> {
        switch category {
        case .chat, .other:
            return Set(allCases)
        case .coding:
            return [.engineer, .student]
        case .agent:
            return [.engineer, .sales, .backOffice, .founder]
        case .pluginSkill:
            return [.engineer, .founder]
        case .repository:
            return [.engineer, .student]
        case .dataAnalysis:
            return [.engineer, .backOffice, .founder, .student]
        case .search:
            return [.writer, .sales, .founder, .student]
        case .writing:
            return [.writer, .marketer, .sales, .backOffice]
        case .design:
            return [.designer, .marketer]
        case .imageGeneration:
            return [.designer, .videoCreator, .marketer]
        case .videoGeneration, .videoEditing:
            return [.videoCreator, .marketer]
        case .audioMusic:
            return [.videoCreator]
        }
    }
}
