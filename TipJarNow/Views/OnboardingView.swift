import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentScreen = 0

    var body: some View {
        TabView(selection: $currentScreen) {
            screen(
                index: 0,
                icon: "qrcode",
                titleKey: LocalizedStringKey("Show your QR. Get tipped."),
                subtitleKey: LocalizedStringKey("Open TipJar Now → tap → done. No fumbling for app, no typing addresses."),
                color: .accentColor
            )
            .tag(0)

            screen(
                index: 1,
                icon: "globe",
                titleKey: LocalizedStringKey("10 payment methods."),
                subtitleKey: LocalizedStringKey("PayPal, Venmo, WeChat, PayPay, LINE Pay, Cash App, Zelle and more."),
                color: .blue
            )
            .tag(1)

            screen(
                index: 2,
                icon: "infinity",
                titleKey: LocalizedStringKey("Keep 100% of your tips."),
                subtitleKey: LocalizedStringKey("$1.99 once unlocks unlimited payment methods. No subscription, no platform cut — every tip is yours."),
                color: .green,
                showCTA: true
            )
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            // Skip button — Apple HIG mandates ≥44×44pt hit target.
            // Per CLAUDE.md lesson #15e: 16pt font + padding(.vertical, 14) +
            // explicit frame(minWidth: 60, minHeight: 44) + contentShape.
            Button {
                hasSeenOnboarding = true
            } label: {
                Text(LocalizedStringKey("Skip"))
                    .font(.body.weight(.medium))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 14)   // 14 = HIG-tuned skip vertical (≥44pt hit target)
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, 50)   // 50 = safe-area top offset for notch; geometry-bound
            .padding(.trailing, Spacing.md)
            .accessibilityLabel(Text(LocalizedStringKey("Skip onboarding")))
        }
    }

    private func screen(
        index: Int,
        icon: String,
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey,
        color: Color,
        showCTA: Bool = false
    ) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            // Hero glyph — fixed 80pt weight intentional (not Dynamic Type).
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(color)
            Text(titleKey)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(subtitleKey)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            if showCTA {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text(LocalizedStringKey("Get Started"))
                        .font(Typography.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(color, in: RoundedRectangle(cornerRadius: Radius.md))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, Spacing.xl)
            } else {
                Spacer().frame(height: 80)
            }
        }
    }
}
