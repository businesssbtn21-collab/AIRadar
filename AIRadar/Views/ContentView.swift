import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var store: FeedStore
    @State private var selectedCategory: ServiceCategory?
    @State private var showSettings = false
    @State private var showFilter = false
    @State private var searchText = ""
    @State private var filter = FilterOptions()
    @AppStorage("hasRespondedToNotificationPrimer") private var hasRespondedToNotificationPrimer = false
    @State private var showNotificationPrimer = false

    private var filteredItems: [AIServiceItem] {
        store.items.applying(filter, searchText: searchText, category: selectedCategory)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter
                list
            }
            .navigationTitle("AIレーダー")
            .searchable(text: $searchText, prompt: "サービス名・提供元で検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsScreen()
            }
            .sheet(isPresented: $showFilter) {
                FilterSheet(filter: $filter)
            }
            .task {
                // 一覧が表示されてから、理由を説明した上で通知許可を尋ねる(HIG推奨: 起動直後の唐突な許可要求を避ける)
                if !hasRespondedToNotificationPrimer && !store.items.isEmpty {
                    showNotificationPrimer = true
                }
            }
            .onChange(of: store.items.isEmpty) { _, isEmpty in
                if !isEmpty && !hasRespondedToNotificationPrimer {
                    showNotificationPrimer = true
                }
            }
            .alert("新着AIサービスを通知でお知らせ", isPresented: $showNotificationPrimer) {
                Button("後で") {
                    hasRespondedToNotificationPrimer = true
                }
                Button("許可する") {
                    hasRespondedToNotificationPrimer = true
                    Task {
                        let center = UNUserNotificationCenter.current()
                        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                    }
                }
            } message: {
                Text("新しいAIサービスの登場や、注目度の急上昇があった時にお知らせします。設定はいつでも変更できます。")
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "すべて", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ServiceCategory.allCases) { category in
                    filterChip(label: category.label, isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        List {
            if let error = store.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let lastRefresh = store.lastRefresh {
                Text("最終更新: \(lastRefresh.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
            if filteredItems.isEmpty && !store.items.isEmpty {
                ContentUnavailableView(
                    "該当するサービスがありません",
                    systemImage: "magnifyingglass",
                    description: Text("検索語やフィルタ条件を変えてお試しください")
                )
                .listRowSeparator(.hidden)
            }
            ForEach(filteredItems) { item in
                NavigationLink(value: item) {
                    ServiceRow(item: item)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: AIServiceItem.self) { item in
            ServiceDetailScreen(item: item)
        }
        .refreshable {
            await store.refresh()
        }
        .overlay {
            if store.isLoading && store.items.isEmpty {
                ProgressView()
            }
        }
    }
}

struct ServiceRow: View {
    let item: AIServiceItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.category.icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)
                    KindBadge(kind: item.kind)
                    RankBadge(item: item)
                }
                Text("\(item.provider)・\(item.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.changeNote)
                    .font(.subheadline)
                    .lineLimit(2)
                Text("注目度 \(item.attentionLevel) \(item.attentionScore)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct KindBadge: View {
    let kind: UpdateKind

    var body: some View {
        Text(kind.shortLabel)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(kind == .new ? Color.red : Color.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

struct RankBadge: View {
    let item: AIServiceItem

    private var color: Color {
        switch item.rank {
        case "S": return .purple
        case "A": return .blue
        default: return .gray
        }
    }

    var body: some View {
        Text(item.rank)
            .font(.caption2.bold())
            .frame(width: 18, height: 18)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(Circle())
    }
}

#Preview {
    ContentView()
        .environmentObject(FeedStore())
        .environmentObject(AppSettings.shared)
}
