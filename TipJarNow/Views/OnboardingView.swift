import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentScreen = 0

    var body: some View {
        TabView(selection: $currentScreen) {
            screen(
                index: 0,
                icon: "qrcode",
                title: "Show your QR. Get tipped.",
                subtitle: "Open TipJar Now → tap → done. No fumbling for app, no typing addresses.",
                color: .accentColor
            )
            .tag(0)

            screen(
                index: 1,
                icon: "globe",
                title: "10 payment methods.",
                subtitle: "PayPal, Venmo, WeChat, PayPay, LINE Pay, Cash App, Zelle and more.",
                color: .blue
            )
            .tag(1)

            screen(
                index: 2,
                icon: "applewatch",
                title: "On your wrist. Forever.",
                subtitle: "$1.99 once. Apple Watch, custom themes, lock screen widget. No subscription.",
                color: .green,
                showCTA: true
            )
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
    }

    private func screen(
        index: Int,
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        showCTA: Bool = false
    ) -> some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(color)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            if showCTA {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
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
