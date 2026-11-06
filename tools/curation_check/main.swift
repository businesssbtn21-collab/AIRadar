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

// MARK: - モードによる絞り込み

let mixed = [
    item("high-designer", expectation: 92, professions: ["designer"]),
    item("high-engineer", expectation: 88, professions: ["engineer"]),
    item("low-designer", expectation: 70, professions: ["designer"]),
]
check(mixed.applying(mode: .discovered, profession: .designer).count == 3, "DISCOVERED はすべて表示")
check(mixed.applying(mode: .curated, profession: nil).map(\.id) == ["high-designer", "high-engineer"],
      "CURATED で職種未選択なら期待度85以上をすべて表示")
check(mixed.applying(mode: .curated, profession: .designer).map(\.id) == ["high-designer"],
      "CURATED は期待度85以上かつ職種向けだけ")

// 通知は1件ずつ判定するので、一覧と同じ判定を単体でも使えること
check(mixed[1].matches(mode: .discovered, profession: .designer), "DISCOVERED の通知は職種を問わない")
check(!mixed[1].matches(mode: .curated, profession: .designer), "CURATED の通知は職種が合わなければ出さない")
check(!mixed[2].matches(mode: .curated, profession: nil), "CURATED の通知は期待度85未満を出さない")

// MARK: - モードの保存(ウィジェットと共有)

SharedStore.defaults.removeObject(forKey: "feedMode")
SharedStore.defaults.removeObject(forKey: "profession")
check(ModePreferences.mode == .discovered, "未保存なら DISCOVERED")
check(ModePreferences.profession == nil, "未保存なら職種なし")
ModePreferences.mode = .curated
ModePreferences.profession = .writer
check(ModePreferences.mode == .curated, "モードを保存して読み戻せる")
check(ModePreferences.profession == .writer, "職種を保存して読み戻せる")
ModePreferences.profession = nil
check(ModePreferences.profession == nil, "職種を未選択に戻せる")
SharedStore.defaults.removeObject(forKey: "feedMode")
SharedStore.defaults.removeObject(forKey: "profession")

// MARK: - 評価のお願いを出すタイミング

let day: TimeInterval = 24 * 60 * 60
let installed = Date(timeIntervalSince1970: 1_800_000_000)
func shouldAsk(days: Double, launches: Int, asked: String?, current: String = "1.4") -> Bool {
    ReviewPromptPolicy.shouldRequest(firstLaunch: installed, launchCount: launches,
                                     lastRequestedVersion: asked, currentVersion: current,
                                     now: installed.addingTimeInterval(days * day))
}
check(!shouldAsk(days: 2.9, launches: 10, asked: nil), "使い始めて3日未満は出さない")
check(!shouldAsk(days: 5, launches: 4, asked: nil), "起動5回未満は出さない")
check(shouldAsk(days: 3, launches: 5, asked: nil), "3日以上・5回以上で初めてなら出す")
check(!shouldAsk(days: 30, launches: 50, asked: "1.4"), "同じバージョンでは2回出さない")
check(shouldAsk(days: 30, launches: 50, asked: "1.3.1"), "新しいバージョンならまた出せる")

let reviewDefaults = UserDefaults(suiteName: "airadar.curation_check.review")!
reviewDefaults.removePersistentDomain(forName: "airadar.curation_check.review")
ReviewPromptTracker.defaults = reviewDefaults
for i in 0..<5 { ReviewPromptTracker.recordLaunch(now: installed.addingTimeInterval(Double(i) * day)) }
check(ReviewPromptTracker.shouldRequestNow(currentVersion: "1.4", now: installed.addingTimeInterval(4 * day)),
      "起動を記録すると条件を満たす(初回起動日は最初の記録)")
ReviewPromptTracker.markRequested(version: "1.4")
check(!ReviewPromptTracker.shouldRequestNow(currentVersion: "1.4", now: installed.addingTimeInterval(9 * day)),
      "お願いしたバージョンを記録する")
reviewDefaults.removePersistentDomain(forName: "airadar.curation_check.review")

// MARK: - 購入済みフラグ(ウィジェットが自分でフィードを取りに行ってよいか)

SharedStore.defaults.removeObject(forKey: "isUnlocked")
FeedSync.saveUnlocked(true, checkedInForeground: false)
check(FeedSync.isUnlocked, "裏で起こされたときの確認でも、購入済みは書き込む")
FeedSync.saveUnlocked(false, checkedInForeground: false)
check(FeedSync.isUnlocked, "裏で起こされたときの「未購入」では購入済みを消さない(ロック中などに購入情報を読めないことがある)")
FeedSync.saveUnlocked(false, checkedInForeground: true)
check(!FeedSync.isUnlocked, "画面に出ているときの確認なら未購入を書き込む(返金など)")
SharedStore.defaults.removeObject(forKey: "isUnlocked")

// MARK: -

if failures == 0 {
    print("ALL PASS")
} else {
    print("\(failures) FAILED")
    exit(1)
}
