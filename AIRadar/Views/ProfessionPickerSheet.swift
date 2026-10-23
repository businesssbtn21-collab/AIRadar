import SwiftUI

/// CURATED モードで届ける内容を決める職種を1つ選ぶ画面。
struct ProfessionPickerSheet: View {
    @Binding var selection: Profession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Profession.allCases) { profession in
                        Button {
                            selection = profession
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: profession.icon)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
                                Text(profession.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection == profession {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("選んだ職種に役立つ、期待度85以上のものだけを届けます。あとで設定から変えられます。")
                }
            }
            .navigationTitle("職種を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
