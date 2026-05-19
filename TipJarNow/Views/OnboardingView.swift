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
                icon: "applewatch",
                titleKey: LocalizedStringKey("On your wrist. Forever."),
                subtitleKey: LocalizedStringKey("$1.99 once. Apple Watch, custom themes, lock screen widget. No subscription."),
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, 50)
            .padding(.trailing, 16)
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
        VStack(spacing: 32) {
            Spacer()
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
                .padding(.horizontal, 32)
            Spacer()
            if showCTA {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text(LocalizedStringKey("Get Started"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(color, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            } else {
                Spacer().frame(height: 80)
            }
        }
    }
}
