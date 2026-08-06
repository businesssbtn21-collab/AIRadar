import SwiftUI

private enum ChainElement {
    case item(AIServiceItem)
    case ellipsis
}

struct ServiceDetailScreen: View {
    let item: AIServiceItem
    @EnvironmentObject private var store: FeedStore

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: item.category.icon)
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.title2.bold())
                            KindBadge(kind: item.kind)
                        }
                        Text(item.provider)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("期待度") {
                HStack {
                    RankBadge(item: item)
                    Text("\(item.expectationScore) / 100")
                        .font(.headline)
                    Spacer()
                    Gauge(value: Double(item.expectationScore), in: 0...100) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .frame(width: 120)
                }
            }

            Section("注目度(ネット上の反応)") {
                HStack {
                    Text(item.attentionLevel)
                    Text("\(item.attentionScore) / 100")
                        .font(.headline)
                    Spacer()
                    Gauge(value: Double(item.attentionScore), in: 0...100) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(.orange)
                    .frame(width: 120)
                }
                Text("Hacker News・Product Hunt・X等での言及・投票をキュレーション時に集計したスコアです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sameCategoryItems.count > 1 {
                Section("他の\(item.category.label)ツールとの比較") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("期待度(\(item.category.label)全\(sameCategoryItems.count)件中\(rank(by: \.expectationScore))位)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        chainText(rankedChain(by: \.expectationScore), score: \.expectationScore)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("注目度(\(item.category.label)全\(sameCategoryItems.count)件中\(rank(by: \.attentionScore))位)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        chainText(rankedChain(by: \.attentionScore), score: \.attentionScore)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("変更内容") {
                Text(item.changeNote)
                Text(item.date.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("概要") {
                Text(item.summary)
            }

            if let url = item.url {
                Section {
                    Link(destination: url) {
                        Label("公式サイトを開く", systemImage: "safari")
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 同じカテゴリ(似た機能)のツールのみを比較対象にする
    private var sameCategoryItems: [AIServiceItem] {
        store.items.filter { $0.category == item.category }
    }

    private func rank(by scoreKeyPath: KeyPath<AIServiceItem, Int>) -> Int {
        let sorted = sameCategoryItems.sorted { $0[keyPath: scoreKeyPath] > $1[keyPath: scoreKeyPath] }
        return (sorted.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
    }

    /// 自分を含む上位5件を「A 98 > B 92 > … > 自分 42」の形で表示するための並び。
    /// 自分が上位5件に入らない場合は上位4件のあとに省略記号を挟んで自分を追加する。
    private func rankedChain(by scoreKeyPath: KeyPath<AIServiceItem, Int>) -> [ChainElement] {
        let sorted = sameCategoryItems.sorted { $0[keyPath: scoreKeyPath] > $1[keyPath: scoreKeyPath] }
        guard let index = sorted.firstIndex(where: { $0.id == item.id }) else {
            return sorted.prefix(5).map { .item($0) }
        }
        if index < 5 {
            return sorted.prefix(5).map { .item($0) }
        }
        var elements: [ChainElement] = sorted.prefix(4).map { .item($0) }
        elements.append(.ellipsis)
        elements.append(.item(sorted[index]))
        return elements
    }

    private func chainText(_ elements: [ChainElement], score: KeyPath<AIServiceItem, Int>) -> Text {
        elements.enumerated().reduce(Text("")) { partial, pair in
            let (index, element) = pair
            let elementText: Text
            switch element {
            case .ellipsis:
                elementText = Text("…").foregroundStyle(.secondary)
            case .item(let other):
                let base = Text("\(other.name) \(other[keyPath: score])")
                elementText = other.id == item.id
                    ? base.bold().foregroundStyle(Color.accentColor)
                    : base.foregroundStyle(.secondary)
            }
            let separator = index == 0 ? Text("") : Text(" > ").foregroundStyle(.secondary)
            return partial + separator + elementText
        }
    }
}
