import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var store: FeedStore
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("モード", selection: $settings.mode) {
                        ForEach(FeedMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    if settings.mode == .curated {
                        // 未選択は「その他(全般)」と同じ扱いなので、そのように見せる
                        Picker("職種", selection: Binding {
                            settings.profession ?? .general
                        } set: {
                            settings.profession = $0
                        }) {
                            ForEach(Profession.allCases) { profession in
                                Text(profession.label).tag(profession)
                            }
                        }
                    }
                } header: {
                    Text("モード")
                } footer: {
                    Text("DISCOVERED: 新しいAIツールをいち早く、すべて届けます。\nCURATED: 選んだ職種に役立つ、期待度85以上のものだけを届けます。\n一覧・通知・ウィジェットのすべてに反映されます。")
                }

                Section("データソース") {
                    Picker("取得元", selection: $settings.dataSource) {
                        ForEach(DataSource.allCases) { source in
                            Text(source.label).tag(source)
                        }
                    }
                    if settings.dataSource == .remote {
                        TextField("フィードJSONのURL", text: $settings.remoteURLString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("GitHub等にホストした feed.json の raw URL を入力(スキーマはREADME参照)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("通知") {
                    Toggle("新着・更新を通知", isOn: $settings.notificationsEnabled)
                    if settings.notificationsEnabled {
                        Picker("種別", selection: $settings.notifyKind) {
                            Text("すべて").tag(UpdateKind?.none)
                            Text("NEW(新登場)").tag(UpdateKind?.some(.new))
                            Text("UPDATE(更新)").tag(UpdateKind?.some(.update))
                        }
                        .pickerStyle(.segmented)
                        Stepper("期待度 \(settings.notifyThreshold) 以上のみ",
                                value: $settings.notifyThreshold, in: 0...100, step: 5)
                        Stepper("注目度が +\(settings.spikeThreshold) 以上急上昇したら通知",
                                value: $settings.spikeThreshold, in: 5...50, step: 5)
                        Text("バックグラウンド更新(目安4時間ごと・OS任せ)で新着・変更・注目度の急上昇を検知するとローカル通知します。ウィジェットも自動で最新に更新されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.notificationsEnabled {
                    Section {
                        HStack {
                            Button("すべて選択") {
                                settings.notifyCategories = Set(ServiceCategory.allCases)
                            }
                            Spacer()
                            Button("すべて解除", role: .destructive) {
                                settings.notifyCategories = []
                            }
                        }
                        .font(.footnote)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(ServiceCategory.allCases) { category in
                                categoryChip(category)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("通知するカテゴリ")
                    } footer: {
                        Text("選んだカテゴリのサービスだけを通知対象にします(一覧の絞り込みとは別に設定できます)。")
                    }
                }

                Section {
                    Button("今すぐ更新") {
                        Task { await store.refresh() }
                        dismiss()
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func categoryChip(_ category: ServiceCategory) -> some View {
        let isSelected = settings.notifyCategories.contains(category)
        return Button {
            if isSelected {
                settings.notifyCategories.remove(category)
            } else {
                settings.notifyCategories.insert(category)
            }
        } label: {
            Text(category.label)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
