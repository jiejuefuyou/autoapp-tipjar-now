import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ContentView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(TipJarStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var addingMethod = false
    @State private var editingMethod: TipMethod?
    @State private var selectedMethod: TipMethod?
    @State private var showCopiedToast = false
    @State private var showShareCard = false
    @State private var showPosterExport = false
    /// Free user tapped "Add Method" while at the free limit — explain the
    /// limit before routing to the paywall (audit [NAV]: a silent paywall
    /// jump reads as a bug/nag).
    @State private var showMethodLimitDialog = false

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
                        if let m = currentMethod {
                            Button {
                                editingMethod = m
                            } label: {
                                Label(LocalizedStringKey("Edit Current"), systemImage: "pencil")
                            }
                        }
                        if let m = currentMethod, m.qrImage != nil {
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
            .sheet(item: $editingMethod) { method in
                MethodEditView(editing: method) { updated in
                    store.update(updated)
                    selectedMethod = updated
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
            // Audit [NAV]: explain the free-method limit at the moment of the
            // blocked add instead of silently presenting the paywall. Reuses
            // existing localized keys — no new strings.
            .confirmationDialog(
                Text(LocalizedStringKey("Free tier: 1 method. Pro: unlimited methods + themes.")),
                isPresented: $showMethodLimitDialog,
                titleVisibility: .visible
            ) {
                Button(LocalizedStringKey("Unlock Pro")) { showPaywall = true }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {}
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
            // Audit [NAV]: surface method switching as visible pills when the
            // user has > 1 method, instead of burying it in the overflow menu.
            if store.methods.count > 1 {
                methodSwitcher(current: method)
            }

            heroCard(for: method)

            qrCodeImage(for: method)

            if !method.addressOrLink.isEmpty {
                Text(method.addressOrLink)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal)
            }

            actionButtonsRow(for: method)

            if !iap.isPremium && store.methods.count >= TipJarStore.freeMethodLimit {
                proHint
            }
        }
        .padding(Spacing.md)
    }

    /// Horizontal pill switcher shown above the hero card when the user has
    /// more than one saved method (audit [NAV] — switching was previously only
    /// reachable via the top-right overflow menu). The selected pill is a
    /// filled accent capsule (fill + outline differ, so the cue isn't
    /// color-only); switching gives a selection haptic. Pills reuse the
    /// methods' localized display names — no new strings.
    @ViewBuilder
    private func methodSwitcher(current: TipMethod) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(store.methods) { m in
                    let isSelected = m.id == current.id
                    Button {
                        guard !isSelected else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        if reduceMotion {
                            selectedMethod = m
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedMethod = m
                            }
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: m.kind.symbol)
                                .font(.caption.weight(.semibold))
                            Text(m.displayName ?? m.kind.displayName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 44)   // HIG hit target (lesson #16)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : Color(.separator),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(m.displayName ?? m.kind.displayName))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    /// The QR slot: the (synthesized or uploaded) code on a white brand card,
    /// with the "add your code" overlay for image-only wallets that have none.
    /// Extracted from qrCardView so the SwiftUI type-checker doesn't time out.
    @ViewBuilder
    private func qrCodeImage(for method: TipMethod) -> some View {
        qrImage(for: method)
            .resizable()
            .interpolation(.none)
            // 264 + 2×24 padding = same 312pt panel as before, but the larger
            // margin guarantees a ≥4-module QR quiet zone for scan reliability
            // (audit [VISUAL]).
            .frame(width: 264, height: 264)
            .padding(Spacing.lg)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.tertiary, lineWidth: 1)
            )
            .overlay {
                if method.qrImage == nil && method.kind.requiresUploadedQR {
                    setupCodeOverlay(for: method)
                }
            }
            .accessibilityLabel(Text(qrAccessibilityLabel(for: method)))
    }

    /// Overlay shown on the QR slot when an image-only method (WeChat / Alipay /
    /// PayPay / LINE Pay / Zelle) has no uploaded receive code yet. Tapping it
    /// opens the editor's PhotosPicker so the user supplies their real QR.
    @ViewBuilder
    private func setupCodeOverlay(for method: TipMethod) -> some View {
        Button {
            editingMethod = method
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 40))
                Text(LocalizedStringKey("Add your receive code"))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(Spacing.md)
            .frame(width: 264, height: 264)   // matches the QR slot frame above
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func qrAccessibilityLabel(for method: TipMethod) -> LocalizedStringKey {
        if method.qrImage == nil && method.kind.requiresUploadedQR {
            return LocalizedStringKey("No receive code yet. Tap to add your payment QR.")
        }
        return LocalizedStringKey("QR code to send a tip")
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
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)   // long names at AX sizes shrink rather than truncate
                    .padding(.horizontal, Spacing.md)

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
        // A scannable QR exists once a URL is synthesized OR a code is uploaded.
        let canShare = method.qrImage != nil
        HStack(spacing: 12) {
            // Copy Link only makes sense for URL-based methods (image-only
            // wallets have no link to copy).
            if let link = method.paymentURL?.absoluteString {
                Button {
                    copyLink(link)
                } label: {
                    Label(LocalizedStringKey("Copy Link"), systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showShareCard = true
            } label: {
                Label(LocalizedStringKey("Share Card"), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canShare)
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
        // Single resolver (TipMethodQR): uploaded image → synthesized URL QR →
        // placeholder. Never re-encodes a raw handle string into a dead QR.
        Image(uiImage: method.qrImageOrPlaceholder)
    }

    private func handleAddMethod() {
        if !iap.isPremium && store.methods.count >= TipJarStore.freeMethodLimit {
            // Explain the limit first (confirmationDialog above) — tapping
            // "Unlock Pro" there routes to the paywall.
            showMethodLimitDialog = true
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
        case .revolut:
            // Revolut's brand is monochrome — pure black vanishes on the
            // dark-mode hero card, so use the adaptive primary (black in
            // light, white in dark). Dark-mode audit fix.
            return Color.primary
        case .wise:
            // Wise's bright lime washes out on the light-mode card; use the
            // brand's deep forest green in light mode, lime in dark.
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.61, green: 0.97, blue: 0.36, alpha: 1)  // Wise lime
                    : UIColor(red: 0.09, green: 0.20, blue: 0.00, alpha: 1)  // Wise forest
            })
        }
    }
}

// MARK: - QR Generator

enum QRGenerator {
    static func image(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        // "Q" (25% error correction) over "M" (15%): posters are scanned
        // printed, at an angle, across a counter — payloads are short so the
        // extra module density is trivial (audit [VISUAL]).
        filter.correctionLevel = "Q"
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 10
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
