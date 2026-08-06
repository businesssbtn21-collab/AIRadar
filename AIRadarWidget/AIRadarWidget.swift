import WidgetKit
import SwiftUI

struct FeedEntry: TimelineEntry {
    let date: Date
    let items: [AIServiceItem]
}

struct FeedTimelineProvider: TimelineProvider {
    private static let placeholderItem = AIServiceItem(
        id: "placeholder",
        name: "Claude Fable 5",
        provider: "Anthropic",
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
        FeedEntry(date: Date(), items: [Self.placeholderItem])
    }

    func getSnapshot(in context: Context, completion: @escaping (FeedEntry) -> Void) {
        let items = SharedStore.loadItems()
        completion(FeedEntry(date: Date(), items: items.isEmpty ? [Self.placeholderItem] : items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeedEntry>) -> Void) {
        let entry = FeedEntry(date: Date(), items: SharedStore.loadItems())
        // アプリ側の更新時は WidgetCenter 経由で即時リロードされる。これは保険の定期更新。
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
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
                Text("アプリを開いて更新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.items.isEmpty {
                Spacer()
                Text("アプリを開いて更新")
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
                Text("AIレーダー")
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
        StaticConfiguration(kind: kind, provider: FeedTimelineProvider()) { entry in
            AIRadarWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AIレーダー")
        .description("期待値の高い新しいAIサービスの登場・更新を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct AIRadarWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIRadarWidget()
    }
}
