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
        // プレビューは待たせたくないので、保存済みの内容だけで組み立てる
        let entry = makeEntry(for: configuration, from: ChinaStorefrontPolicy.filter(SharedStore.loadItems()))
        guard entry.items.isEmpty && !entry.filteredOutEverything else { return entry }
        return FeedEntry(date: entry.date,
                         items: [Self.placeholderItem],
                         filterLabel: entry.filterLabel,
                         filteredOutEverything: false)
    }

    func timeline(for configuration: WidgetFilterIntent, in context: Context) async -> Timeline<FeedEntry> {
        // アプリを開かなくても最新になるよう、ウィジェット自身がフィードを取りに行く。
        // 取得できなければ保存済みの内容で表示する。
        let all = await FeedSync.itemsRefreshingIfNeeded()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [makeEntry(for: configuration, from: all)], policy: .after(next))
    }

    private func makeEntry(for configuration: WidgetFilterIntent, from all: [AIServiceItem]) -> FeedEntry {
        // アプリで選んだモード(CURATED なら厳選分だけ)を先にかけ、その上にウィジェット個別の絞り込みを重ねる
        let mode = ModePreferences.mode
        let filtered = all
            .applying(mode: mode, curation: ModePreferences.curation)
            .applying(configuration)
        let labels = [mode == .curated ? "厳選" : nil, configuration.summaryLabel].compactMap { $0 }
        return FeedEntry(
            date: Date(),
            items: filtered,
            filterLabel: labels.isEmpty ? nil : labels.joined(separator: "・"),
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

    /// 小サイズ。名前と説明を途中で切らずに全部見せるため、見出しの行を省いて
    /// 種別・ランク・注目度を1行にまとめ、長いときは文字を少し小さくして収める。
    private var smallView: some View {
        Group {
            if let item = topItem {
                SmallItemView(item: item, filterLabel: entry.filterLabel)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    Spacer()
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
        Group {
            if let item = topItem {
                LockItemView(item: item)
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

    private func badge(_ kind: UpdateKind) -> some View {
        KindBadge(kind: kind)
    }
}

struct KindBadge: View {
    let kind: UpdateKind

    var body: some View {
        Text(kind.label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(kind == .new ? Color.red : Color.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

/// ホーム画面の小サイズの中身。名前は最大3行・説明は最大5行まで使い、
/// それでも入らないときだけ文字を縮めて、末尾が「…」で切れないようにする。
struct SmallItemView: View {
    let item: AIServiceItem
    let filterLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                KindBadge(kind: item.kind)
                Text(item.rank)
                    .font(.caption2.bold())
                    .foregroundStyle(.purple)
                if let filterLabel {
                    Text(filterLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 2)
                Text("\(item.attentionLevel)\(item.attentionScore)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
            Text(item.name)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(3)
                .minimumScaleFactor(0.65)
                .layoutPriority(2)
            Text(item.changeNote)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(5)
                .minimumScaleFactor(0.65)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// ロック画面(横長)の中身。名前(長ければ2行)と説明だけにし、注目度は省いて全部見せる。
/// 入りきらないときは文字を縮める。
struct LockItemView: View {
    let item: AIServiceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(item.kind.label) \(item.name)")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            Text(item.changeNote)
                .font(.system(size: 11))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
