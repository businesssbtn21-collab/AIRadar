import SwiftUI

/// 「AIに聞く」: 普通の言葉で聞くと、iPhone の中の AI がフィードから探して答える。
/// 押した瞬間に言い換え辞書での結果を出し、AIの答えが届いたら差し替える。
struct AISearchSheet: View {
    @EnvironmentObject private var store: FeedStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var result: AISearchResult?
    @State private var isThinking = false
    /// 続けて聞き直したとき、前の質問へのAIの答えで上書きしないための印
    @State private var askID = UUID()
    @FocusState private var isQueryFocused: Bool

    private let examples = [
        "営業で使える新しいツールは？",
        "無料で動画を作れるAI",
        "議事録の文字起こしに使えるもの",
        "経理の作業を自動化したい",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    queryField
                    if result == nil {
                        exampleChips
                    }
                }

                if isThinking {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("AIが答えを考えています…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                } else if let answer = result?.answer {
                    Section {
                        Label {
                            Text(answer)
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let result {
                    if result.items.isEmpty {
                        if !isThinking {
                            ContentUnavailableView(
                                "見つかりませんでした",
                                systemImage: "magnifyingglass",
                                description: Text("言葉を変えて聞いてみてください")
                            )
                        }
                    } else {
                        Section("見つかったツール") {
                            ForEach(result.items) { item in
                                NavigationLink(value: item) {
                                    ServiceRow(item: item)
                                }
                            }
                        }
                    }

                    Section {
                        Text(footnote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.smooth, value: isThinking)
            .navigationTitle("AIに聞く")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(for: AIServiceItem.self) { item in
                ServiceDetailScreen(item: item)
            }
            .onAppear {
                // キーボードを最初から出すと、例の質問のボタンが1回では押せないことがあるので出さない
                AISearchEngine.prewarm()
            }
        }
    }

    private var queryField: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
            TextField("例: 営業で使える新しいツールは？", text: $query)
                .focused($isQueryFocused)
                .submitLabel(.search)
                .onSubmit { ask(query) }
            if !query.isEmpty {
                Button {
                    ask(query)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("聞く")
            }
        }
    }

    private var exampleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button(example) {
                        query = example
                        ask(example)
                    }
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
    }

    private func ask(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isQueryFocused = false
        let id = UUID()
        askID = id
        withAnimation(.smooth) {
            result = AISearchEngine.quickSearch(trimmed, in: store.items)
            isThinking = AISearchEngine.isAIAvailable
        }
        guard AISearchEngine.isAIAvailable else { return }
        Task {
            let found = await AISearchEngine.aiSearch(trimmed, in: store.items)
            guard askID == id else { return }
            withAnimation(.smooth) {
                if let found {
                    result = found
                }
                isThinking = false
            }
        }
    }

    private var footnote: String {
        if AISearchEngine.isAIAvailable {
            return "iPhone の中の AI が答えています。質問は外に送られません。答えは AIレーダーの配信データだけを元にしています。"
        }
        return "この iPhone では AI の答えなしで探しています(Apple Intelligence に対応した iPhone・iOS 26 以降では、AI が答えを書きます)。"
    }
}
