import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ContentView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(TipJarStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var addingMethod = false
    @State private var selectedMethod: TipMethod?
    @State private var showCopiedToast = false
    @State private var showShareCard = false
    @State private var showPosterExport = false

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if store.methods.isEmpty {
                        emptyState
                    } else if let method = currentMethod {
                        qrCardView(for: method)
                    } else {
                        emptyState
                    }
                }
                copiedToast
            }
            .navigationTitle(Text(LocalizedStringKey("TipJar Now")))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {   // 12 = toolbar spacing, matches Radius.md visual rhythm
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel(Text(LocalizedStringKey("Settings")))
                        if !iap.isPremium {
                            Button {
                                showPaywall = true
                            } label: {
                                Label(LocalizedStringKey("Pro"), systemImage: "sparkles")
                                    .font(.caption.bold())
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            handleAddMethod()
                        } label: {
                            Label(LocalizedStringKey("Add Method"), systemImage: "plus")
                        }
                        if currentMethod != nil {
                            Button {
                                showPosterExport = true
                            } label: {
                                Label(LocalizedStringKey("Export poster"), systemImage: "printer")
                            }
                        }
                        if let m = currentMethod {
                            Button(role: .destructive) {
                                store.remove(m)
                            } label: {
                                Label(LocalizedStringKey("Remove Current"), systemImage: "trash")
                            }
                        }
                        Section(LocalizedStringKey("Switch")) {
                            ForEach(store.methods) { m in
                                Button {
                                    selectedMethod = m
                                } label: {
                                    Label(m.kind.displayName, systemImage: m.kind.symbol)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("Payment method options")))
                }
            }
            // CRITICAL: SwiftUI sheet/fullScreenCover attaches modal to scene
            // presentation host, NOT to ContentView's view tree. The .id on
            // TipJarNowApp.swift only rebuilds ContentView itself — modal
            // content stays stale on language change. Force rebuild per-modal.
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
            .sheet(isPresented: $addingMethod) {
                MethodEditView { newMethod in
                    store.add(newMethod)
                    selectedMethod = newMethod
                }
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .id(l10n.override)
            }
            .sheet(isPresented: $showShareCard) {
                if let m = currentMethod {
                    ShareCardView(method: m)
                        .environment(iap)
                        .environment(store)
                        .environment(l10n)
                        .environment(\.locale, l10n.currentLocale)
                        .id(l10n.override)
                }
            }
            .sheet(isPresented: $showPosterExport) {
                if let m = currentMethod {
                    PosterExportView(method: m)
                        .environment(iap)
                        .environment(store)
                        .environment(l10n)
                        .environment(\.locale, l10n.currentLocale)
                        .id(l10n.override)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { _ in /* OnboardingView writes hasSeenOnboarding directly */ }
            )) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
        }
    }

    private var currentMethod: TipMethod? {
        if let s = selectedMethod, store.methods.contains(where: { $0.id == s.id }) {
            return s
        }
        return store.methods.first
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            // Hero glyph — fixed 56pt weight intentional (not Dynamic Type).
            Image(systemName: "qrcode")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(LocalizedStringKey("No payment methods yet"))
                .font(.headline)
            Text(LocalizedStringKey("Add a tip method (PayPal / Venmo / 微信 / PayPay) to show its QR code on demand."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button(LocalizedStringKey("Add a Method")) {
                handleAddMethod()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
    }

    @ViewBuilder
    private func qrCardView(for method: TipMethod) -> some View {
        VStack(spacing: 20) {   // 20 = QR card section rhythm; sits between md(16)/lg(24)
            heroCard(for: method)

            qrImage(for: method)
                .resizable()
                .interpolation(.none)
                .frame(width: 280, height: 280)
                .padding(Spacing.md)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))   // 24 = QR brand card; visual depends on this size
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.tertiary, lineWidth: 1)
                )

            Text(method.addressOrLink)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal)

            actionButtonsRow(for: method)

            if !iap.isPremium && store.methods.count >= TipJarStore.freeMethodLimit {
                proHint
            }
        }
        .padding(Spacing.md)
    }

    /// Hero card — large styled header with brand-color top stripe, big SF
    /// Symbol, method name, and "Send a tip" subtitle. Concept-driven, high
    /// contrast vs body so it reads at-a-glance when the QR is on screen.
    @ViewBuilder
    private func heroCard(for method: TipMethod) -> some View {
        let brand = method.kind.brandColor
        VStack(spacing: 0) {
            // Brand color stripe — top edge
            Rectangle()
                .fill(LinearGradient(
                    colors: [brand, brand.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 6)

            VStack(spacing: 6) {
                // Hero glyph — fixed 44pt weight intentional (not Dynamic Type).
                Image(systemName: method.kind.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(brand)
                    .padding(.top, 12)

                Text(method.displayName ?? method.kind.displayName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey("Send a tip"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)   // 16 = hero card; visual depends on this size matched 3 times (bg/clip/overlay)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    /// Row of Copy + Share Card buttons under the QR. Native iOS feel — copy
    /// gives haptic + toast feedback; "Share Card" opens the designed Tip Card
    /// composer (themes + watermark gating) so users share a branded image
    /// instead of a bare URL string.
    @ViewBuilder
    private func actionButtonsRow(for method: TipMethod) -> some View {
        let link = method.paymentURL?.absoluteString ?? method.addressOrLink
        HStack(spacing: 12) {
            Button {
                copyLink(link)
            } label: {
                Label(LocalizedStringKey("Copy Link"), systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showShareCard = true
            } label: {
                Label(LocalizedStringKey("Share Card"), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    private func copyLink(_ link: String) {
        UIPasteboard.general.string = link
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                showCopiedToast = false
            }
        }
    }

    /// Toast overlay — slides in from the top, auto-dismisses after 1.5s.
    @ViewBuilder
    private var copiedToast: some View {
        VStack {
            if showCopiedToast {
                Label(LocalizedStringKey("Copied"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)   // 18 = pill horizontal; sits between md(16)/lg(24) for toast emphasis
                    .padding(.vertical, 10)     // 10 = pill vertical, between xs(4)/sm(8)
                    .background(.tint, in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Spacing.sm)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var proHint: some View {
        VStack(spacing: Spacing.sm) {
            Text(LocalizedStringKey("Free tier: 1 method. Pro: unlimited methods + themes."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(LocalizedStringKey("Unlock Pro")) {
                showPaywall = true
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal)
    }

    private func qrImage(for method: TipMethod) -> Image {
        let payload: String = method.paymentURL?.absoluteString ?? method.addressOrLink
        return Image(uiImage: QRGenerator.image(from: payload) ?? UIImage(systemName: "qrcode") ?? UIImage())
    }

    private func handleAddMethod() {
        if !iap.isPremium && store.methods.count >= TipJarStore.freeMethodLimit {
            showPaywall = true
            return
        }
        addingMethod = true
    }
}

// MARK: - Brand colors per payment method
//
// Hero card displays a subtle accent stripe + icon tint in each provider's
// brand color. Colors approximate the published brand palette but stay
// readable on both light + dark backgrounds. Not used for marketing — just
// visual differentiation so user can scan-recognize WeChat vs PayPal vs
// Venmo on the hero card at a glance.

extension TipMethodKind {
    var brandColor: Color {
        switch self {
        case .paypal:  return Color(red: 0.00, green: 0.27, blue: 0.55)  // PayPal blue
        case .venmo:   return Color(red: 0.05, green: 0.46, blue: 0.95)  // Venmo blue
        case .wechat:  return Color(red: 0.04, green: 0.78, blue: 0.30)  // WeChat green
        case .alipay:  return Color(red: 0.10, green: 0.59, blue: 0.93)  // Alipay blue
        case .paypay:  return Color(red: 0.93, green: 0.10, blue: 0.10)  // PayPay red
        case .linePay: return Color(red: 0.00, green: 0.78, blue: 0.00)  // LINE green
        case .cashApp: return Color(red: 0.00, green: 0.81, blue: 0.40)  // Cash App green
        case .zelle:   return Color(red: 0.43, green: 0.20, blue: 0.69)  // Zelle purple
        case .revolut: return Color(red: 0.00, green: 0.00, blue: 0.00)  // Revolut black
        case .wise:    return Color(red: 0.61, green: 0.97, blue: 0.36)  // Wise green
        }
    }
}

// MARK: - QR Generator

enum QRGenerator {
    static func image(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 10
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
