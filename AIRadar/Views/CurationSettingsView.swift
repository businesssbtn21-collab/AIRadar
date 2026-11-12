import SwiftUI

/// CURATED で届ける内容の条件をユーザーが決める画面。
/// 職種(複数可)・使っているツール・期待度の下限を選ぶ。シートでも設定画面の中でも使う。
struct CurationSettingsView: View {
    @EnvironmentObject private var store: FeedStore
    @ObservedObject private var settings = AppSettings.shared
    @State private var newToolName = ""

    var body: some View {
        Form {
            professionSection
            toolSection
            scoreSection
        }
        .navigationTitle("厳選の条件")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 職種

    private var professionSection: some View {
        Section {
            ForEach(Profession.allCases) { profession in
                Button {
                    toggle(profession)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: profession.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)
                        Text(profession.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: settings.curation.professions.contains(profession) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(settings.curation.professions.contains(profession) ? Color.accentColor : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("職種(いくつでも)")
        } footer: {
            Text("選んだ職種のどれかに役立つものを届けます。「その他(全般)」を選ぶと職種で絞りません。")
        }
    }

    private func toggle(_ profession: Profession) {
        if settings.curation.professions.contains(profession) {
            settings.curation.professions.remove(profession)
        } else {
            settings.curation.professions.insert(profession)
        }
    }

    // MARK: - 使っているツール

    /// 一覧に出す候補: いまのフィードにある提供元(件数の多い順)+自分で選んだもの
    private var toolCandidates: [String] {
        var counts: [String: Int] = [:]
        for item in store.items { counts[item.provider, default: 0] += 1 }
        let fromFeed = counts.keys.sorted { (counts[$0]!, $1) > (counts[$1]!, $0) }
        let custom = settings.curation.myTools.subtracting(fromFeed).sorted()
        return custom + fromFeed
    }

    private var toolSection: some View {
        Section {
            ForEach(toolCandidates, id: \.self) { tool in
                Button {
                    if settings.curation.myTools.contains(tool) {
                        settings.curation.myTools.remove(tool)
                    } else {
                        settings.curation.myTools.insert(tool)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool)
                                .foregroundStyle(.primary)
                            if let hint = Self.productHint(for: tool) {
                                Text(hint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: settings.curation.myTools.contains(tool) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(settings.curation.myTools.contains(tool) ? Color.accentColor : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack {
                TextField("ほかのツール名を追加(例: Notion)", text: $newToolName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addTool)
                Button("追加", action: addTool)
                    .disabled(newToolName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Toggle("使っているツールは期待度に関係なく表示", isOn: $settings.curation.alwaysShowMyTools)
        } header: {
            Text("使っているツール")
        } footer: {
            Text("選んだツールの新登場・アップデートを届けます。提供元の名前か、サービス名に含まれる言葉で探します。職種を1つも選ばなければ、使っているツールの情報だけを表示します。")
        }
    }

    private func addTool() {
        let name = newToolName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.curation.myTools.insert(name)
        newToolName = ""
    }

    /// 提供元の名前だけでは分かりにくいものに、代表的なサービス名を添える。
    /// 中国本土のストアでは、表示できない名前を出さない
    static func productHint(for provider: String) -> String? {
        guard !ChinaStorefrontPolicy.isRestricted else { return nil }
        let hints = [
            "OpenAI": "ChatGPT など",
            "Anthropic": "Claude など",
            "Google": "Gemini など",
            "Microsoft": "Copilot など",
            "Anysphere": "Cursor",
            "Amazon Web Services": "Kiro など",
            "xAI": "Grok",
            "Moonshot AI": "Kimi",
            "Cognition": "Devin など",
            "Kuaishou": "Kling",
            "Meta": "Meta AI など",
            "Mistral AI": "Le Chat など",
            "ByteDance": "Seedance・Seedream など",
        ]
        return hints[provider]
    }

    // MARK: - 期待度

    private var scoreSection: some View {
        Section {
            Stepper("期待度 \(settings.curation.minimumScore) 以上",
                    value: $settings.curation.minimumScore,
                    in: CurationPreferences.minimumScoreRange, step: 5)
        } header: {
            Text("期待度の下限")
        } footer: {
            Text("職種で選ぶ情報は、この期待度以上のものだけを届けます。下げるほど多く表示されます(はじめは85)。")
        }
    }
}

/// CURATED に初めて切り替えたときなどに出すシート版
struct CurationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CurationSettingsView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完了") { dismiss() }
                    }
                }
        }
    }
}
