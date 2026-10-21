// モード・職種の判定を確かめるスクリプト(テスト用ターゲットがないため)。
// 実行: tools/curation_check/run.sh
import Foundation

var failures = 0

func check(_ condition: Bool, _ name: String) {
    if !condition {
        failures += 1
        print("FAIL: \(name)")
    }
}

func item(_ id: String,
          category: ServiceCategory = .other,
          expectation: Int = 90,
          professions: [String]? = nil) -> AIServiceItem {
    var item = AIServiceItem(id: id, name: id, provider: "p", category: category,
                             summary: "", changeNote: "", kind: .new,
                             expectationScore: expectation, attentionScore: 50,
                             date: Date(), url: nil)
    item.professions = professions
    return item
}

func decode(_ json: String) -> [AIServiceItem]? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode([AIServiceItem].self, from: Data(json.utf8))
}

// MARK: - 職種との関係

let forDesigner = item("d", professions: ["designer"])
check(forDesigner.isRelevant(to: .designer), "タグ付きの職種には関係あり")
check(!forDesigner.isRelevant(to: .engineer), "タグにない職種には関係なし")

let forEveryone = item("a", professions: ["all"])
check(Profession.allCases.allSatisfy { forEveryone.isRelevant(to: $0) }, "all は全職種に関係あり")

let untaggedCoding = item("c", category: .coding)
check(untaggedCoding.isRelevant(to: .engineer), "タグなしの coding はエンジニア向けと推定")
check(untaggedCoding.isRelevant(to: .student), "タグなしの coding は学生向けと推定")
check(!untaggedCoding.isRelevant(to: .designer), "タグなしの coding はデザイナー向けではない")

let untaggedChat = item("chat", category: .chat)
check(Profession.allCases.allSatisfy { untaggedChat.isRelevant(to: $0) }, "タグなしの chat は全職種向け")

let futureTag = item("f", category: .chat, professions: ["futureJob"])
check(!futureTag.isRelevant(to: .engineer), "未知の職種タグだけの項目は既知の職種に出ない")
check(futureTag.isRelevant(to: .general), "未知の職種タグでも「その他(全般)」には出る")

check(item("x", professions: ["designer"]).isRelevant(to: .general), "「その他(全般)」は常に関係あり")

// MARK: - 厳選の条件

check(!item("e84", expectation: 84, professions: ["designer"]).isCurated(for: .designer), "期待度84は厳選に入らない")
check(item("e85", expectation: 85, professions: ["designer"]).isCurated(for: .designer), "期待度85は厳選に入る")
check(!item("e95", expectation: 95, professions: ["designer"]).isCurated(for: .engineer), "職種が合わなければ厳選に入らない")

// MARK: - フィードの読み込み(旧版・将来版との互換)

let base = #""id":"x","name":"x","provider":"p","category":"chat","summary":"","changeNote":"","kind":"new","expectationScore":90,"attentionScore":50,"date":"2026-10-01T00:00:00Z","url":null"#
check(decode("[{\(base)}]")?.first?.professions == nil, "professions なしのJSONが読める")
check(decode(#"[{\#(base),"professions":["futureJob"]}]"#)?.first?.professions == ["futureJob"], "未知の職種を含むJSONが読める")
check(decode(#"[{\#(base),"foo":1}]"#)?.count == 1, "未知のキーを含むJSONが読める")

// MARK: -

if failures == 0 {
    print("ALL PASS")
} else {
    print("\(failures) FAILED")
    exit(1)
}
