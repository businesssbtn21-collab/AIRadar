import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case newest
    case expectation
    case attention

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "新着順"
        case .expectation: return "期待度順"
        case .attention: return "注目度順"
        }
    }
}

struct FilterOptions {
    var kind: UpdateKind?
    var minExpectation: Int = 0
    var minAttention: Int = 0
    var sortOption: SortOption = .newest

    var isActive: Bool {
        kind != nil || minExpectation > 0 || minAttention > 0 || sortOption != .newest
    }

    mutating func reset() {
        self = FilterOptions()
    }
}

extension Array where Element == AIServiceItem {
    func applying(_ filter: FilterOptions, searchText: String, category: ServiceCategory?) -> [AIServiceItem] {
        var result = self

        if let category {
            result = result.filter { $0.category == category }
        }
        if let kind = filter.kind {
            result = result.filter { $0.kind == kind }
        }
        if filter.minExpectation > 0 {
            result = result.filter { $0.expectationScore >= filter.minExpectation }
        }
        if filter.minAttention > 0 {
            result = result.filter { $0.attentionScore >= filter.minAttention }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.provider.localizedCaseInsensitiveContains(trimmed)
                    || $0.summary.localizedCaseInsensitiveContains(trimmed)
                    || $0.changeNote.localizedCaseInsensitiveContains(trimmed)
            }
        }

        switch filter.sortOption {
        case .newest:
            result.sort { $0.date > $1.date }
        case .expectation:
            result.sort { $0.expectationScore > $1.expectationScore }
        case .attention:
            result.sort { $0.attentionScore > $1.attentionScore }
        }
        return result
    }
}
