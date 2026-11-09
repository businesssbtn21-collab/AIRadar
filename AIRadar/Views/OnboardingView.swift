import SwiftUI

/// 初めて起動した未購入の人に、できることを実際の画面の画像で見せてから購入を案内する。
/// 横にめくるページは指に追従し、途中で止めたり戻したりできる(標準のページ送りを使う)。
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: Int? = 0
    @State private var hasAppeared = false

    private struct Page {
        let image: String
        let title: String
        let message: String
    }

    private let pages = [
        Page(image: "Onboarding1", title: "新しいAIツールを\n毎朝お届け",
             message: "次々に登場するAIの新サービスや大型アップデートを、期待度・注目度つきで一覧にしています。"),
        Page(image: "Onboarding2", title: "ウィジェットで\n開かずにチェック",
             message: "ホーム画面に置くだけで、新しい情報に自動で切り替わります。"),
        Page(image: "Onboarding3", title: "あなたの職種に\n合うものだけ",
             message: "職種を選ぶと、仕事に役立つ期待度の高いツールだけに絞って届けます。"),
        Page(image: "Onboarding4", title: "AIに聞いて\n探せる",
             message: "「営業で使える新しいツールは？」のように聞くと、iPhone の中の AI が探して答えます。"),
    ]

    private var purchasePageIndex: Int { pages.count }
    private var currentPage: Int { page ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("スキップ") { go(to: purchasePageIndex) }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(currentPage < purchasePageIndex ? 1 : 0)
                    .animation(.smooth(duration: 0.25), value: currentPage)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        featurePage(pages[index], isFirst: index == 0)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                    purchasePage
                        .containerRelativeFrame(.horizontal)
                        .id(purchasePageIndex)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)

            pageIndicator
                .padding(.vertical, 12)

            Button {
                go(to: currentPage + 1)
            } label: {
                Text(currentPage == pages.count - 1 ? "購入について見る" : "次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(currentPage < purchasePageIndex ? 1 : 0)
            .disabled(currentPage >= purchasePageIndex)
            .animation(.smooth(duration: 0.25), value: currentPage)
        }
        .background(background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: currentPage)
        .onChange(of: currentPage) { _, newPage in
            // 購入ページまで見たら、次からは課金画面だけを出す
            if newPage == purchasePageIndex {
                UserDefaults.standard.set(true, forKey: OnboardingPolicy.seenKey)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.7, bounce: 0)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - ページ

    private func featurePage(_ page: Page, isFirst: Bool) -> some View {
        VStack(spacing: 24) {
            Image(page.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .padding(.horizontal, 48)
                .frame(maxHeight: .infinity)
                // めくる量に合わせて少し縮み、奥へ流れる(指に追従するので途中で止めても自然)
                .scrollTransition(axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * 0.12)
                        .offset(x: reduceMotion ? 0 : phase.value * -36)
                        .opacity(1 - abs(phase.value) * 0.6)
                }
                // 最初の1枚だけ、開いたときに下からふわっと出る
                .offset(y: isFirst && !hasAppeared && !reduceMotion ? 40 : 0)
                .opacity(isFirst && !hasAppeared ? 0 : 1)

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.system(.title, weight: .bold))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            // 文字は画像より大きく動かして奥行きを出す
            .scrollTransition(axis: .horizontal) { content, phase in
                content
                    .offset(x: reduceMotion ? 0 : phase.value * 90)
                    .opacity(1 - abs(phase.value))
            }
            .offset(y: isFirst && !hasAppeared && !reduceMotion ? 20 : 0)
            .opacity(isFirst && !hasAppeared ? 0 : 1)
            .padding(.bottom, 8)
        }
    }

    private var purchasePage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: currentPage == purchasePageIndex)
                    .padding(.top, 24)

                Text("すべての機能を、ずっと")
                    .font(.system(.title, weight: .bold))
                    .tracking(-0.5)

                Text("一度の購入で、これからのアップデートも追加料金なしで使えます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                FeatureList()
                    .padding(.horizontal, 32)

                PurchaseSection()
                    .padding(.top, 8)
            }
        }
        .scrollIndicators(.hidden)
        .scrollTransition(axis: .horizontal) { content, phase in
            content.opacity(1 - abs(phase.value))
        }
    }

    // MARK: - 部品

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0...purchasePageIndex, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == currentPage ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0), value: currentPage)
        .accessibilityElement()
        .accessibilityLabel("\(currentPage + 1) / \(purchasePageIndex + 1) ページ")
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.16), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
    }

    private func go(to index: Int) {
        let target = min(index, purchasePageIndex)
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.45, bounce: 0)) {
            page = target
        }
    }
}

/// 押した瞬間に少し縮むボタン(離すまで待たずに反応を返す)
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2, bounce: 0), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView()
}
