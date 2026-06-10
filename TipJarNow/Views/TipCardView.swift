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

    /// Shared resolver: uploaded receive-code image → synthesized URL QR →
    /// placeholder (TipMethodQR). Same single reader as ContentView/Poster.
    private var qrImage: UIImage { method.qrImageOrPlaceholder }

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
            // For image-only wallets with no handle, fall back to the method
            // name so the pill still identifies the wallet.
            HStack(spacing: 8) {
                Image(systemName: method.kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(handle.isEmpty ? method.kind.displayName : handle)
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

            // Watermark (free tier only). A tasteful branded chip — a small QR
            // glyph + wordmark in the theme accent — reads as an intentional
            // credit rather than a defacing stamp, so free users still feel
            // good sharing it. Every shared free card is the app's growth loop
            // (a recipient sees "TipJar Now" + scans), so the credit is
            // designed to look good, not just to nag.
            if showWatermark {
                attributionChip
                    .padding(.bottom, 16)
            }
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .background(theme.gradient)
    }

    /// Tasteful "Made with TipJar Now" credit chip drawn on free-tier cards.
    private var attributionChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "qrcode")
                .font(.system(size: 10, weight: .bold))
            Text(LocalizedStringKey("Made with TipJar Now"))
                .font(.system(.caption2, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(theme.foregroundSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.foregroundSecondary.opacity(0.12), in: Capsule())
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
/// `onLockedTap` (route to paywall, or claim the one-time trial) instead of
/// selecting it.
///
/// When `trialAvailable == true`, every premium swatch shows a "Try free" pill
/// instead of a lock — the user's single free premium output is still unclaimed,
/// so the picker advertises that they can taste any premium theme once.
struct ThemeChooser: View {
    @Binding var selectedThemeID: String
    let isPremium: Bool
    /// True while the user still has their one-time free premium output to spend.
    /// Drives the "Try free" pill (vs. a lock badge) on premium swatches.
    var trialAvailable: Bool = false
    /// Called when a free user taps a premium (locked) swatch. Receives the
    /// tapped theme's id so the handler can claim the trial *and* select it.
    let onLockedTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(TipCardTheme.all) { theme in
                    let locked = theme.isPro && !isPremium
                    let isSelected = selectedThemeID == theme.id
                    // A premium swatch is "tryable" (free pill, not a lock) while
                    // the one-time trial is still available.
                    let tryable = locked && trialAvailable
                    Button {
                        if locked {
                            onLockedTap(theme.id)
                        } else {
                            selectedThemeID = theme.id
                        }
                    } label: {
                        swatch(theme: theme, locked: locked, tryable: tryable, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    // Convey the locked/premium/tryable state to VoiceOver (the
                    // visible badge isn't otherwise announced). Reuses existing
                    // "Premium" / "Try free" keys — no new localization keys.
                    .accessibilityLabel(Text(themeAccessibilityLabel(theme: theme, locked: locked, tryable: tryable)))
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private func themeAccessibilityLabel(theme: TipCardTheme, locked: Bool, tryable: Bool) -> String {
        let name = NSLocalizedString(theme.nameKey, comment: "Tip card theme name")
        if tryable {
            return "\(name), \(NSLocalizedString("Try free", comment: "Premium theme free to try once, for VoiceOver"))"
        }
        if locked {
            return "\(name), \(NSLocalizedString("Premium", comment: "Locked premium theme for VoiceOver"))"
        }
        return name
    }

    private func swatch(theme: TipCardTheme, locked: Bool, tryable: Bool, isSelected: Bool) -> some View {
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
                if tryable {
                    // Star badge signals "free to try once" on premium swatches.
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.accentColor, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                } else if locked {
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
/// image.
///
/// Tiers:
/// - **Pro**: every theme, no watermark.
/// - **Free, trial unclaimed**: may *taste* any premium theme ONCE — picking a
///   premium theme claims the one-time free premium output (`TipJarStore`),
///   which removes the watermark and unlocks the chosen design for this card so
///   the creator sees their first clean, watermark-free result (the #1 desire
///   builder). An aspirational prompt then offers to unlock the rest.
/// - **Free, trial spent**: free theme only, watermarked; premium themes route
///   to the paywall. The trial flag is persisted, so it never recurs.
struct ShareCardView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(TipJarStore.self) private var store
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let method: TipMethod

    @State private var selectedThemeID: String = TipCardTheme.free.id
    @State private var showPaywall = false
    @State private var showTrialUsed = false
    /// Set when the user taps "Unlock" in the trial prompt; the paywall is then
    /// presented from the prompt's onDismiss so the two sheets never swap
    /// mid-transition (which would silently drop the paywall presentation).
    @State private var pendingPaywall = false
    /// True for this session once the user has claimed their one-time trial here,
    /// so the clean premium preview persists while they share it even though the
    /// persisted trial flag is already burned.
    @State private var trialClaimed = false

    private var selectedTheme: TipCardTheme { TipCardTheme.theme(id: selectedThemeID) }

    /// Whether this user may currently taste a premium theme for free.
    private var trialAvailable: Bool { store.premiumTrialAvailable(isPremium: iap.isPremium) }

    /// Premium output is unlocked when the user is Pro OR has claimed the trial
    /// in this session. That governs both the honored theme and the watermark.
    private var premiumOutputUnlocked: Bool { iap.isPremium || trialClaimed }

    private var showWatermark: Bool { !premiumOutputUnlocked }

    /// The theme actually rendered/shared. Honors the selection when premium
    /// output is unlocked; otherwise pins to the free theme so gating can't drift.
    private var effectiveTheme: TipCardTheme {
        premiumOutputUnlocked ? selectedTheme : TipCardTheme.free
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
                            isPremium: premiumOutputUnlocked,
                            trialAvailable: trialAvailable,
                            onLockedTap: handlePremiumThemeTap
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))

                    shareButton

                    footer
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
            // Aspirational, non-punitive prompt shown once after the free premium
            // card is granted (lesson #34 — re-inject l10n + iap so the prompt
            // localizes and can route into the paywall).
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

    /// Tap on a premium theme by a free user: claim the one-time trial if it's
    /// still available, otherwise route to the paywall. Claiming burns the
    /// persisted trial immediately (idempotent), unlocks the clean preview for
    /// this session, selects the tapped theme, and surfaces the upsell prompt.
    private func handlePremiumThemeTap(_ themeID: String) {
        guard !iap.isPremium else { selectedThemeID = themeID; return }
        if trialClaimed {
            // Trial already claimed this session — just let them switch themes.
            selectedThemeID = themeID
            return
        }
        if store.consumePremiumTrial() {
            trialClaimed = true
            selectedThemeID = themeID
            showTrialUsed = true
        } else {
            // Trial was already spent in a prior session → paywall.
            showPaywall = true
        }
    }

    @ViewBuilder
    private var footer: some View {
        if !premiumOutputUnlocked {
            VStack(spacing: Spacing.xs) {
                if trialAvailable {
                    // Advertise the free taste before it's claimed.
                    Text(LocalizedStringKey("Tap any premium theme to make one clean, watermark-free card free."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(String(format: NSLocalizedString("Pro unlocks all %lld card themes and removes the watermark.", comment: "Share card upsell with theme count"), TipCardTheme.totalCount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(LocalizedStringKey("Unlock Pro")) { showPaywall = true }
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal)
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
            // A clean, watermark-free share is a genuine "I made something good"
            // moment — the right beat to (occasionally, self-limited) ask for a
            // review. Watermarked free shares are NOT a success beat, so skip
            // them. simultaneousGesture so the ShareLink's own action still runs.
            .simultaneousGesture(TapGesture().onEnded {
                if !showWatermark {
                    ReviewService.recordSuccess()
                    ReviewService.maybeRequestReview()
                }
            })
        } else {
            Label(LocalizedStringKey("Share Card"), systemImage: "exclamationmark.triangle")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.secondary)
        }
    }

    /// Aspirational prompt after the one free premium card is granted. Offers
    /// the unlock without forcing it; the user keeps the clean preview they just
    /// unlocked for this card either way.
    private var trialUsedPrompt: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .padding(.top, 32)

                    Text(LocalizedStringKey("Here's your free clean card"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text(LocalizedStringKey("Share it now — no watermark. Unlock Pro to keep every theme watermark-free and print posters, all for a one-time purchase. No subscription."))
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
