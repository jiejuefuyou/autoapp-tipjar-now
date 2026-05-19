import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(TipJarStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var addingMethod = false
    @State private var selectedMethod: TipMethod?

    var body: some View {
        NavigationStack {
            Group {
                if store.methods.isEmpty {
                    emptyState
                } else if let method = currentMethod {
                    qrCardView(for: method)
                } else {
                    emptyState
                }
            }
            .navigationTitle(Text(LocalizedStringKey("TipJar Now")))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
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
        VStack(spacing: 16) {
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
            .padding(.top, 4)
        }
        .padding()
    }

    @ViewBuilder
    private func qrCardView(for method: TipMethod) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: method.kind.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text(method.displayName ?? method.kind.displayName)
                    .font(.title2.bold())
            }

            qrImage(for: method)
                .resizable()
                .interpolation(.none)
                .frame(width: 280, height: 280)
                .padding()
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
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

            if !iap.isPremium && store.methods.count >= TipJarStore.freeMethodLimit {
                proHint
            }
        }
        .padding()
    }

    private var proHint: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("Free tier: 1 method. Pro: unlimited methods + Apple Watch + themes."))
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
