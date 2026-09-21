import WidgetKit
import SwiftUI

struct FeedEntry: TimelineEntry {
    let date: Date
    let items: [AIServiceItem]
    /// ヘッダーに出す絞り込みの要約(絞り込みなしなら nil)
    let filterLabel: String?
    /// フィード自体は空ではないが、絞り込み条件に合う項目がなかった状態
    let filteredOutEverything: Bool
}

struct FeedTimelineProvider: AppIntentTimelineProvider {
    private static let placeholderItem = AIServiceItem(
        id: "placeholder",
        name: "Nova Mind 5",
        provider: "サンプルAI Labs",
        category: .chat,
        summary: "新モデル公開",
        changeNote: "新モデルとして公開",
        kind: .new,
        expectationScore: 98,
        attentionScore: 90,
        date: Date(),
        url: nil
    )

    func placeholder(in context: Context) -> FeedEntry {
        FeedEntry(date: Date(), items: [Self.placeholderItem], filterLabel: nil, filteredOutEverything: false)
    }

    func snapshot(for configuration: WidgetFilterIntent, in context: Context) async -> FeedEntry {
        let entry = makeEntry(for: configuration)
        guard entry.items.isEmpty && !entry.filteredOutEverything else { return entry }
        return FeedEntry(date: entry.date,
                         items: [Self.placeholderItem],
                         filterLabel: entry.filterLabel,
                         filteredOutEverything: false)
    }

    func timeline(for configuration: WidgetFilterIntent, in context: Context) async -> Timeline<FeedEntry> {
        // アプリ側の更新時は WidgetCenter 経由で即時リロードされる。これは保険の定期更新。
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [makeEntry(for: configuration)], policy: .after(next))
    }

    private func makeEntry(for configuration: WidgetFilterIntent) -> FeedEntry {
        let all = ChinaStorefrontPolicy.filter(SharedStore.loadItems())
        let filtered = all.applying(configuration)
        return FeedEntry(
            date: Date(),
            items: filtered,
            filterLabel: configuration.summaryLabel,
            filteredOutEverything: filtered.isEmpty && !all.isEmpty
        )
    }
}

struct AIRadarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FeedEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            lockScreenView
        default:
            smallView
        }
    }

    private var topItem: AIServiceItem? { entry.items.first }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let item = topItem {
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    badge(item.kind)
                    Text(item.rank)
                        .font(.caption2.bold())
                        .foregroundStyle(.purple)
                }
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(item.changeNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                attentionRow(item)
            } else {
                Spacer()
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 項目が無いときの案内。絞り込みで消えた場合は条件の見直しを促す。
    private var emptyMessage: String {
        entry.filteredOutEverything ? "条件に合う更新はありません" : "アプリを開いて更新"
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.items.isEmpty {
                Spacer()
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    HStack(spacing: 6) {
                        badge(item.kind)
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.attentionLevel) \(item.attentionScore)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(item.rank)
                            .font(.caption.bold())
                            .foregroundStyle(item.rank == "S" ? .purple : .blue)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let item = topItem {
                Text("\(item.kind.label) \(item.name)")
                    .font(.headline)
                    .lineLimit(1)
                Text(item.changeNote)
                    .font(.caption2)
                    .lineLimit(2)
                Text("注目度 \(item.attentionLevel) \(item.attentionScore)")
                    .font(.caption2)
            } else {
                Text(entry.filteredOutEverything ? "条件に合う更新なし" : "AIレーダー")
                    .font(.headline)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption2)
            Text("AIレーダー")
                .font(.caption2.bold())
            if let label = entry.filterLabel {
                Text(label)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private func attentionRow(_ item: AIServiceItem) -> some View {
        Text("注目度 \(item.attentionLevel) \(item.attentionScore)")
            .font(.caption2)
            .foregroundStyle(.orange)
    }

    private func badge(_ kind: UpdateKind) -> some View {
        Text(kind.label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(kind == .new ? Color.red : Color.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

struct AIRadarWidget: Widget {
    let kind = "AIRadarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetFilterIntent.self, provider: FeedTimelineProvider()) { entry in
            AIRadarWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AIレーダー")
        .description("期待値の高い新しいAIサービスの登場・更新を表示します。長押し →「ウィジェットを編集」でカテゴリや期待度を絞り込めます。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct AIRadarWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIRadarWidget()
    }
}
