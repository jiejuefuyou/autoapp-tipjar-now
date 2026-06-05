import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A designed, shareable Tip Card: the method's QR code on a themed background
/// with the creator's name, handle pill, a "Send a tip" caption, and — for free
/// users — a small "Made with TipJar Now" watermark.
///
/// Rendered both on-screen (preview) and off-screen via `ImageRenderer` to
/// produce a shareable PNG. The view is laid out at a fixed logical size so the
/// rendered image is deterministic regardless of device; callers set
/// `ImageRenderer.scale` for the output resolution.
struct TipCardView: View {
    let method: TipMethod
    let theme: TipCardTheme
    /// When false, the "Made with TipJar Now" watermark is drawn (free tier).
    let showWatermark: Bool

    /// Logical canvas size (portrait card, ~4:5). Scaled up at render time.
    static let canvasSize = CGSize(width: 360, height: 450)

    private var creatorName: String {
        let custom = method.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let custom, !custom.isEmpty { return custom }
        return method.kind.displayName
    }

    private var handle: String { method.addressOrLink }

    private var qrImage: UIImage {
        let payload = method.paymentURL?.absoluteString ?? method.addressOrLink
        return QRGenerator.image(from: payload)
            ?? UIImage(systemName: "qrcode")
            ?? UIImage()
    }

    var body: some View {
        VStack(spacing: 18) {
            // Header — "Send a tip" eyebrow + creator name.
            VStack(spacing: 6) {
                Text(LocalizedStringKey("Send a tip"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.foregroundSecondary)

                Text(creatorName)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .padding(.top, 30)
            .padding(.horizontal, 24)

            // QR panel — solid light plate for scan reliability.
            Image(uiImage: qrImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 188, height: 188)
                .padding(16)
                .background(theme.qrPanel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                )

            // Handle pill — method icon + the address/handle in the accent color.
            HStack(spacing: 8) {
                Image(systemName: method.kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(handle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(theme.accent, in: Capsule())
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            // Watermark (free tier only).
            if showWatermark {
                Text(LocalizedStringKey("Made with TipJar Now"))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(theme.foregroundSecondary)
                    .padding(.bottom, 16)
            }
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .background(theme.gradient)
    }
}

// MARK: - Off-screen rendering

enum TipCardRenderer {
    /// Render a `TipCardView` to a high-resolution PNG image for sharing.
    /// Returns `nil` if the renderer cannot produce an image (defensive — in
    /// practice ImageRenderer always succeeds for a fixed-size view tree).
    @MainActor
    static func uiImage(
        method: TipMethod,
        theme: TipCardTheme,
        showWatermark: Bool,
        scale: CGFloat = 3
    ) -> UIImage? {
        let view = TipCardView(method: method, theme: theme, showWatermark: showWatermark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

// MARK: - Theme chooser

/// Horizontal swatch picker shared by the Share Card and Export Poster flows.
/// Pro themes show a lock badge for free users; tapping a locked swatch calls
/// `onLockedTap` (route to paywall) instead of selecting it.
struct ThemeChooser: View {
    @Binding var selectedThemeID: String
    let isPremium: Bool
    let onLockedTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(TipCardTheme.all) { theme in
                    let locked = theme.isPro && !isPremium
                    let isSelected = selectedThemeID == theme.id
                    Button {
                        if locked {
                            onLockedTap()
                        } else {
                            selectedThemeID = theme.id
                        }
                    } label: {
                        swatch(theme: theme, locked: locked, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    // Convey the locked/premium state to VoiceOver (the visible lock
                    // badge isn't otherwise announced). Reuses the existing "Premium"
                    // key — no new localization keys (adversarial-review finding).
                    .accessibilityLabel(Text(locked
                        ? "\(NSLocalizedString(theme.nameKey, comment: "Tip card theme name")), \(NSLocalizedString("Premium", comment: "Locked premium theme for VoiceOver"))"
                        : NSLocalizedString(theme.nameKey, comment: "Tip card theme name")))
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private func swatch(theme: TipCardTheme, locked: Bool, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.gradient)
                    .frame(width: 56, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            // Selected ring uses the brand accent; unselected a
                            // hairline. Both branches are concrete Color so this
                            // ShapeStyle expression type-checks (lesson #62).
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.white.opacity(0.4),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                // Mini QR motif so swatches read as "cards", using theme colors.
                Image(systemName: "qrcode")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(theme.accent)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.45), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                }
            }
            Text(LocalizedStringKey(theme.nameKey))
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}

// MARK: - Share Card composer

/// Sheet that lets the user pick a theme and share the designed Tip Card as an
/// image. Free users share the free theme (watermarked); Pro unlocks all themes
/// and removes the watermark. Tapping a locked theme routes to the paywall.
struct ShareCardView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let method: TipMethod

    @State private var selectedThemeID: String = TipCardTheme.free.id
    @State private var showPaywall = false

    private var selectedTheme: TipCardTheme { TipCardTheme.theme(id: selectedThemeID) }
    private var showWatermark: Bool { !iap.isPremium }

    /// Free users are pinned to the free theme regardless of selection state.
    private var effectiveTheme: TipCardTheme {
        iap.isPremium ? selectedTheme : TipCardTheme.free
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Live preview of the card the user is about to share.
                    TipCardView(
                        method: method,
                        theme: effectiveTheme,
                        showWatermark: showWatermark
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 6)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(LocalizedStringKey("Theme"))
                            .font(.headline)
                        ThemeChooser(
                            selectedThemeID: $selectedThemeID,
                            isPremium: iap.isPremium,
                            onLockedTap: { showPaywall = true }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))

                    shareButton

                    if !iap.isPremium {
                        VStack(spacing: Spacing.xs) {
                            Text(LocalizedStringKey("Pro unlocks 7 card themes and removes the watermark."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(LocalizedStringKey("Unlock Pro")) { showPaywall = true }
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle(Text(LocalizedStringKey("Share Card")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let image = TipCardRenderer.uiImage(
            method: method,
            theme: effectiveTheme,
            showWatermark: showWatermark
        ),
           let png = image.pngData() {
            let item = CardImageShareItem(data: png, suggestedName: "TipJarNow-Card")
            ShareLink(
                item: item,
                preview: SharePreview(
                    Text(LocalizedStringKey("Tip card")),
                    image: Image(uiImage: image)
                )
            ) {
                Label(LocalizedStringKey("Share Card"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Label(LocalizedStringKey("Share Card"), systemImage: "exclamationmark.triangle")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.secondary)
        }
    }
}

/// A `Transferable` PNG payload so `ShareLink` exports a real named image file.
struct CardImageShareItem: Transferable {
    let data: Data
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.data
        }
        .suggestedFileName { "\($0.suggestedName).png" }
    }
}
