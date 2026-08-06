import SwiftUI

struct FilterSheet: View {
    @Binding var filter: FilterOptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("種別") {
                    Picker("種別", selection: $filter.kind) {
                        Text("すべて").tag(UpdateKind?.none)
                        Text("NEW(新登場)").tag(UpdateKind?.some(.new))
                        Text("UPDATE(更新)").tag(UpdateKind?.some(.update))
                    }
                    .pickerStyle(.segmented)
                }

                Section("しきい値で絞り込む") {
                    Stepper("期待度 \(filter.minExpectation) 以上",
                            value: $filter.minExpectation, in: 0...100, step: 5)
                    Stepper("注目度 \(filter.minAttention) 以上",
                            value: $filter.minAttention, in: 0...100, step: 5)
                }

                Section("並び替え") {
                    Picker("並び替え", selection: $filter.sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if filter.isActive {
                    Section {
                        Button("条件をリセット", role: .destructive) {
                            filter.reset()
                        }
                    }
                }
            }
            .navigationTitle("フィルタ・並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
