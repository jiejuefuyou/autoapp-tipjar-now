import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Print/share sizes for the QR poster. Aspect ratios match real paper /
/// social formats so the rendered PNG drops cleanly into a print shop or a
/// story slot. `pixelSize` is the output resolution at ~150–300 dpi.
enum PosterSize: String, CaseIterable, Identifiable {
    case a4
    case usLetter
    case counter4x6
    case story1080

    var id: String { rawValue }

    /// Localization key for the size's human-facing name.
    var nameKey: String {
        switch self {
        case .a4:         return "poster.size.a4"
        case .usLetter:   return "poster.size.letter"
        case .counter4x6: return "poster.size.counter"
        case .story1080:  return "poster.size.story"
        }
    }

    /// Width:height aspect used for the on-screen preview canvas.
    var aspect: CGFloat {
        switch self {
        case .a4:         return 210.0 / 297.0     // ISO A4
        case .usLetter:   return 8.5 / 11.0        // US Letter
        case .counter4x6: return 4.0 / 6.0         // 4×6 counter card
        case .story1080:  return 1.0               // 1080² square (story-safe)
        }
    }

    /// Output pixel size of the rendered PNG.
    var pixelSize: CGSize {
        switch self {
        case .a4:         return CGSize(width: 1240, height: 1754)   // A4 @150dpi
        case .usLetter:   return CGSize(width: 1275, height: 1650)   // Letter @150dpi
        case .counter4x6: return CGSize(width: 1200, height: 1800)   // 4×6 @300dpi
        case .story1080:  return CGSize(width: 1080, height: 1080)
        }
    }
}

/// The poster artwork itself — a large-format card with a big QR, a
/// "Tips appreciated 💛" headline, the creator name + handle, themed
/// background, and an optional watermark for free users.
///
/// Laid out to fill a passed-in `size` so a single view renders at any
/// `PosterSize`. `ImageRenderer` produces the printable PNG.
struct PosterArtwork: View {
    let method: TipMethod
    let theme: TipCardTheme
    let showWatermark: Bool
    let size: CGSize

    private var creatorName: String {
        let custom = method.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let custom, !custom.isEmpty { return custom }
        return method.kind.displayName
    }

    private var qrImage: UIImage {
        let payload = method.paymentURL?.absoluteString ?? method.addressOrLink
        return QRGenerator.image(from: payload)
            ?? UIImage(systemName: "qrcode")
            ?? UIImage()
    }

    var body: some View {
        // Scale the design to the shortest dimension so proportions hold across
        // A4 / Letter / 4×6 / square without per-size hand-tuning.
        let unit = min(size.width, size.height)
        let qrSide = unit * 0.52

        VStack(spacing: unit * 0.045) {
            Spacer(minLength: 0)

            Text(LocalizedStringKey("Tips appreciated 💛"))
                .font(.system(size: unit * 0.072, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, unit * 0.08)

            Text(creatorName)
                .font(.system(size: unit * 0.042, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.foregroundSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, unit * 0.08)

            Image(uiImage: qrImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: qrSide, height: qrSide)
                .padding(unit * 0.05)
                .background(theme.qrPanel, in: RoundedRectangle(cornerRadius: unit * 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.04)
                        .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                )
                .padding(.top, unit * 0.02)

            HStack(spacing: unit * 0.02) {
                Image(systemName: method.kind.symbol)
                    .font(.system(size: unit * 0.038, weight: .semibold))
                Text(method.addressOrLink)
                    .font(.system(size: unit * 0.040, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, unit * 0.05)
            .padding(.vertical, unit * 0.028)
            .background(theme.accent, in: Capsule())
            .padding(.horizontal, unit * 0.08)

            Text(LocalizedStringKey("Scan to send a tip"))
                .font(.system(size: unit * 0.032, weight: .medium, design: .rounded))
                .foregroundStyle(theme.foregroundSecondary)

            Spacer(minLength: 0)

            if showWatermark {
                Text(LocalizedStringKey("Made with TipJar Now"))
                    .font(.system(size: unit * 0.026, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.foregroundSecondary)
                    .padding(.bottom, unit * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(theme.gradient)
    }
}

enum PosterRenderer {
    /// Render a poster to a printable PNG at the size's native pixel resolution.
    @MainActor
    static func uiImage(
        method: TipMethod,
        theme: TipCardTheme,
        showWatermark: Bool,
        size: PosterSize
    ) -> UIImage? {
        let artwork = PosterArtwork(
            method: method,
            theme: theme,
            showWatermark: showWatermark,
            size: size.pixelSize
        )
        let renderer = ImageRenderer(content: artwork)
        // Content is already authored at pixel dimensions, so render 1:1.
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Sheet for exporting a printable QR poster.
///
/// Tiers mirror the Share Card flow (shared one-time trial in `TipJarStore`):
/// - **Pro**: every size + theme, no watermark.
/// - **Free, trial unclaimed**: tapping a locked size or premium theme claims
///   the single free premium output — unlocking full sizes + the chosen theme,
///   watermark-free, for this session so the creator can print one clean poster.
/// - **Free, trial spent**: square story size + free theme only, watermarked;
///   anything premium routes to the paywall (persisted, so it never recurs).
struct PosterExportView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(TipJarStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let method: TipMethod

    @State private var selectedSize: PosterSize = .story1080
    @State private var selectedThemeID: String = TipCardTheme.free.id
    @State private var showPaywall = false
    @State private var showTrialUsed = false
    @State private var pendingPaywall = false
    /// Session flag set once the user claims their one-time trial here.
    @State private var trialClaimed = false

    /// The single size free users may export.
    private static let freeSize: PosterSize = .story1080

    private var selectedTheme: TipCardTheme { TipCardTheme.theme(id: selectedThemeID) }

    private var trialAvailable: Bool { store.premiumTrialAvailable(isPremium: iap.isPremium) }
    private var premiumOutputUnlocked: Bool { iap.isPremium || trialClaimed }
    private var showWatermark: Bool { !premiumOutputUnlocked }

    /// Honored only when premium output is unlocked; otherwise pinned to the
    /// free theme + free size so gating always holds even if state drifts.
    private var effectiveTheme: TipCardTheme {
        premiumOutputUnlocked ? selectedTheme : TipCardTheme.free
    }
    private var effectiveSize: PosterSize {
        premiumOutputUnlocked ? selectedSize : Self.freeSize
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    posterPreview

                    sizePicker

                    themePicker

                    exportButton

                    if !premiumOutputUnlocked {
                        proUpsell
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle(Text(LocalizedStringKey("Export poster")))
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
            .sheet(isPresented: $showTrialUsed, onDismiss: {
                if pendingPaywall { pendingPaywall = false; showPaywall = true }
            }) {
                trialUsedPrompt
                    .environment(iap)
                    .environment(l10n)
                    .environment(\.locale, l10n.currentLocale)
                    .id(l10n.override)
            }
        }
    }

    /// Claim the one-time trial (or route to the paywall if already spent / a
    /// double tap). Selecting a specific theme is the caller's responsibility.
    /// Returns `true` if premium output is now unlocked for this session.
    @discardableResult
    private func claimTrialOrPaywall() -> Bool {
        if iap.isPremium { return true }
        if trialClaimed { return true }
        if store.consumePremiumTrial() {
            trialClaimed = true
            showTrialUsed = true
            return true
        }
        showPaywall = true
        return false
    }

    /// On-screen preview — scaled down to a comfortable card while preserving
    /// the chosen size's aspect ratio.
    private var posterPreview: some View {
        let previewWidth: CGFloat = 240
        let previewSize = CGSize(
            width: previewWidth,
            height: previewWidth / effectiveSize.aspect
        )
        return PosterArtwork(
            method: method,
            theme: effectiveTheme,
            showWatermark: showWatermark,
            size: previewSize
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .frame(maxWidth: .infinity)
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(LocalizedStringKey("Size"))
                .font(.headline)
            ForEach(PosterSize.allCases) { size in
                let locked = !premiumOutputUnlocked && size != Self.freeSize
                // While the trial is still available, a locked size shows a star
                // (free to try once) instead of a lock.
                let tryable = locked && trialAvailable
                Button {
                    if locked {
                        // Claim the one-time trial (or paywall); on success this
                        // session is unlocked, so honor the tapped size.
                        if claimTrialOrPaywall() {
                            selectedSize = size
                        }
                    } else {
                        selectedSize = size
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedSize == size && !locked
                              ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(Color.accentColor)
                        Text(LocalizedStringKey(size.nameKey))
                            .foregroundStyle(.primary)
                        Spacer()
                        if tryable {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        } else if locked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(sizeAccessibilityLabel(size: size, locked: locked, tryable: tryable)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func sizeAccessibilityLabel(size: PosterSize, locked: Bool, tryable: Bool) -> String {
        let name = NSLocalizedString(size.nameKey, comment: "Poster size name")
        if tryable {
            return "\(name), \(NSLocalizedString("Try free", comment: "Premium size free to try once, for VoiceOver"))"
        }
        if locked {
            return "\(name), \(NSLocalizedString("Premium", comment: "Locked premium size for VoiceOver"))"
        }
        return name
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(LocalizedStringKey("Theme"))
                .font(.headline)
            ThemeChooser(
                selectedThemeID: $selectedThemeID,
                isPremium: premiumOutputUnlocked,
                trialAvailable: trialAvailable,
                onLockedTap: { themeID in
                    // Claim the one-time trial (or paywall); on success select it.
                    if claimTrialOrPaywall() {
                        selectedThemeID = themeID
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private var exportButton: some View {
        Group {
            if let image = PosterRenderer.uiImage(
                method: method,
                theme: effectiveTheme,
                showWatermark: showWatermark,
                size: effectiveSize
            ),
               let png = image.pngData() {
                let item = PosterShareItem(
                    data: png,
                    suggestedName: "TipJarNow-Poster"
                )
                ShareLink(
                    item: item,
                    preview: SharePreview(
                        Text(LocalizedStringKey("Tip poster")),
                        image: Image(uiImage: image)
                    )
                ) {
                    Label(LocalizedStringKey("Export poster"), systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Defensive fallback — rendering a fixed-size view effectively
                // never fails, but never show a dead control.
                Label(LocalizedStringKey("Export poster"), systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var proUpsell: some View {
        VStack(spacing: Spacing.xs) {
            if trialAvailable {
                Text(LocalizedStringKey("Tap any size or premium theme to print one clean, watermark-free poster free."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(LocalizedStringKey("Pro unlocks every size + theme and removes the watermark."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(LocalizedStringKey("Unlock Pro")) { showPaywall = true }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal)
    }

    /// Aspirational prompt after the one free premium poster is granted.
    private var trialUsedPrompt: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .padding(.top, 32)

                    Text(LocalizedStringKey("Here's your free clean poster"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text(LocalizedStringKey("Export it now — no watermark, any size. Unlock Pro to keep every size and theme watermark-free, with a one-time purchase. No subscription."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        pendingPaywall = true
                        showTrialUsed = false
                    } label: {
                        Text(LocalizedStringKey("Unlock Pro"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: Radius.lg))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("trial.cta.unlock")

                    Button(LocalizedStringKey("Maybe later")) {
                        showTrialUsed = false
                    }
                    .font(.subheadline)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Close")) { showTrialUsed = false }
                }
            }
        }
    }
}

/// A `Transferable` PNG payload so `ShareLink` exports a real image file with a
/// sensible filename (rather than sharing an in-memory `Image` with no name).
struct PosterShareItem: Transferable {
    let data: Data
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.data
        }
        .suggestedFileName { "\($0.suggestedName).png" }
    }
}
