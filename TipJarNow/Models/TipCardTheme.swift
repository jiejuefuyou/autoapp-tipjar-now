import SwiftUI

/// A visual theme for the shareable Tip Card + printable QR poster.
///
/// Each theme is a self-contained palette: a background gradient, the on-card
/// text/QR foreground, an accent used for the handle pill + watermark, and the
/// background the QR code sits on (QR codes scan most reliably on a solid light
/// panel, so most themes keep a near-white QR plate even on dark cards).
///
/// `isPro == false` themes are usable by everyone; the rest require TipJar Pro.
/// A single free theme (`classicLight`) ships so the share / poster loop works
/// for free users (watermarked) — Pro removes the watermark and unlocks every
/// remaining design (see `proCount`).
///
/// All `Color` values are concrete (`Color(red:green:blue:)`) — never a
/// `HierarchicalShapeStyle` like `.secondary`/`.tint` — so theme colors can be
/// used directly in `ShapeStyle` ternaries without the type-inference trap
/// (CLAUDE.md lesson #62: `cond ? .secondary : .tint` fails to compile).
struct TipCardTheme: Identifiable, Hashable {
    let id: String
    /// Localization key for the human-facing theme name (resolved via .lproj).
    let nameKey: String
    let isPro: Bool

    /// Background gradient stops (top-leading → bottom-trailing).
    let backgroundColors: [Color]
    /// Primary on-card content color (creator name, body text).
    let foreground: Color
    /// Secondary on-card content color (sub-labels, "Tips appreciated").
    let foregroundSecondary: Color
    /// Accent color — handle pill background + small flourishes.
    let accent: Color
    /// Content color rendered on top of `accent` (e.g. handle text).
    let onAccent: Color
    /// Solid panel the QR code is rendered on (kept light for scan reliability).
    let qrPanel: Color

    var gradient: LinearGradient {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Catalog

    /// Free theme — clean light card. Always available (watermarked for free).
    static let classicLight = TipCardTheme(
        id: "classicLight",
        nameKey: "theme.classicLight",
        isPro: false,
        backgroundColors: [
            Color(red: 1.00, green: 1.00, blue: 1.00),
            Color(red: 0.94, green: 0.96, blue: 0.95)
        ],
        foreground: Color(red: 0.09, green: 0.12, blue: 0.11),
        foregroundSecondary: Color(red: 0.38, green: 0.42, blue: 0.41),
        accent: Color(red: 0.06, green: 0.73, blue: 0.51),
        onAccent: Color(red: 1.00, green: 1.00, blue: 1.00),
        qrPanel: Color(red: 1.00, green: 1.00, blue: 1.00)
    )

    static let midnight = TipCardTheme(
        id: "midnight",
        nameKey: "theme.midnight",
        isPro: true,
        backgroundColors: [
            Color(red: 0.07, green: 0.09, blue: 0.16),
            Color(red: 0.13, green: 0.16, blue: 0.27)
        ],
        foreground: Color(red: 0.96, green: 0.97, blue: 1.00),
        foregroundSecondary: Color(red: 0.66, green: 0.71, blue: 0.82),
        accent: Color(red: 0.39, green: 0.55, blue: 0.97),
        onAccent: Color(red: 1.00, green: 1.00, blue: 1.00),
        qrPanel: Color(red: 1.00, green: 1.00, blue: 1.00)
    )

    /// Warm coffee-shop palette for baristas / cafés.
    static let barista = TipCardTheme(
        id: "barista",
        nameKey: "theme.barista",
        isPro: true,
        backgroundColors: [
            Color(red: 0.36, green: 0.22, blue: 0.13),
            Color(red: 0.58, green: 0.39, blue: 0.24)
        ],
        foreground: Color(red: 0.99, green: 0.96, blue: 0.90),
        foregroundSecondary: Color(red: 0.86, green: 0.78, blue: 0.67),
        accent: Color(red: 0.93, green: 0.74, blue: 0.42),
        onAccent: Color(red: 0.26, green: 0.15, blue: 0.08),
        qrPanel: Color(red: 0.99, green: 0.97, blue: 0.93)
    )

    /// High-energy neon for street performers / buskers.
    static let busker = TipCardTheme(
        id: "busker",
        nameKey: "theme.busker",
        isPro: true,
        backgroundColors: [
            Color(red: 0.05, green: 0.03, blue: 0.12),
            Color(red: 0.20, green: 0.05, blue: 0.26)
        ],
        foreground: Color(red: 0.99, green: 0.98, blue: 1.00),
        foregroundSecondary: Color(red: 0.78, green: 0.72, blue: 0.92),
        accent: Color(red: 0.99, green: 0.27, blue: 0.67),
        onAccent: Color(red: 1.00, green: 1.00, blue: 1.00),
        qrPanel: Color(red: 1.00, green: 1.00, blue: 1.00)
    )

    /// Vivid gradient with glow for streamers.
    static let streamer = TipCardTheme(
        id: "streamer",
        nameKey: "theme.streamer",
        isPro: true,
        backgroundColors: [
            Color(red: 0.42, green: 0.18, blue: 0.85),
            Color(red: 0.12, green: 0.42, blue: 0.92)
        ],
        foreground: Color(red: 1.00, green: 1.00, blue: 1.00),
        foregroundSecondary: Color(red: 0.84, green: 0.86, blue: 0.98),
        accent: Color(red: 0.20, green: 0.94, blue: 0.78),
        onAccent: Color(red: 0.06, green: 0.10, blue: 0.20),
        qrPanel: Color(red: 1.00, green: 1.00, blue: 1.00)
    )

    /// Clean, professional light card for freelancers / invoices.
    static let freelancer = TipCardTheme(
        id: "freelancer",
        nameKey: "theme.freelancer",
        isPro: true,
        backgroundColors: [
            Color(red: 0.96, green: 0.97, blue: 0.99),
            Color(red: 0.89, green: 0.92, blue: 0.97)
        ],
        foreground: Color(red: 0.11, green: 0.16, blue: 0.24),
        foregroundSecondary: Color(red: 0.40, green: 0.46, blue: 0.56),
        accent: Color(red: 0.18, green: 0.40, blue: 0.78),
        onAccent: Color(red: 1.00, green: 1.00, blue: 1.00),
        qrPanel: Color(red: 1.00, green: 1.00, blue: 1.00)
    )

    /// Elegant gold-on-charcoal for events / weddings / tip jars at the door.
    static let event = TipCardTheme(
        id: "event",
        nameKey: "theme.event",
        isPro: true,
        backgroundColors: [
            Color(red: 0.10, green: 0.10, blue: 0.11),
            Color(red: 0.20, green: 0.18, blue: 0.14)
        ],
        foreground: Color(red: 0.98, green: 0.96, blue: 0.91),
        foregroundSecondary: Color(red: 0.80, green: 0.76, blue: 0.68),
        accent: Color(red: 0.84, green: 0.69, blue: 0.36),
        onAccent: Color(red: 0.12, green: 0.10, blue: 0.06),
        qrPanel: Color(red: 0.99, green: 0.98, blue: 0.95)
    )

    /// Warm dusk gradient (peach → magenta) for artists / illustrators.
    static let sunset = TipCardTheme(
        id: "sunset",
        nameKey: "theme.sunset",
        isPro: true,
        backgroundColors: [
            Color(red: 0.98, green: 0.55, blue: 0.34),
            Color(red: 0.86, green: 0.24, blue: 0.50)
        ],
        foreground: Color(red: 1.00, green: 0.99, blue: 0.97),
        foregroundSecondary: Color(red: 1.00, green: 0.90, blue: 0.85),
        accent: Color(red: 1.00, green: 0.95, blue: 0.90),
        onAccent: Color(red: 0.74, green: 0.20, blue: 0.40),
        qrPanel: Color(red: 1.00, green: 0.99, blue: 0.97)
    )

    /// Calm teal-to-deep-blue for podcasters / writers / "buy me a coffee".
    static let ocean = TipCardTheme(
        id: "ocean",
        nameKey: "theme.ocean",
        isPro: true,
        backgroundColors: [
            Color(red: 0.02, green: 0.42, blue: 0.55),
            Color(red: 0.03, green: 0.20, blue: 0.42)
        ],
        foreground: Color(red: 0.96, green: 0.99, blue: 1.00),
        foregroundSecondary: Color(red: 0.73, green: 0.87, blue: 0.93),
        accent: Color(red: 0.28, green: 0.86, blue: 0.80),
        onAccent: Color(red: 0.02, green: 0.20, blue: 0.30),
        qrPanel: Color(red: 0.98, green: 1.00, blue: 1.00)
    )

    /// Botanical green for makers / gardeners / sustainability creators.
    static let forest = TipCardTheme(
        id: "forest",
        nameKey: "theme.forest",
        isPro: true,
        backgroundColors: [
            Color(red: 0.09, green: 0.27, blue: 0.18),
            Color(red: 0.16, green: 0.40, blue: 0.24)
        ],
        foreground: Color(red: 0.96, green: 0.99, blue: 0.95),
        foregroundSecondary: Color(red: 0.77, green: 0.88, blue: 0.78),
        accent: Color(red: 0.62, green: 0.84, blue: 0.42),
        onAccent: Color(red: 0.07, green: 0.22, blue: 0.13),
        qrPanel: Color(red: 0.98, green: 1.00, blue: 0.97)
    )

    /// Minimalist near-black mono for designers / photographers who want the
    /// QR to be the entire statement.
    static let mono = TipCardTheme(
        id: "mono",
        nameKey: "theme.mono",
        isPro: true,
        backgroundColors: [
            Color(red: 0.07, green: 0.07, blue: 0.08),
            Color(red: 0.16, green: 0.16, blue: 0.17)
        ],
        foreground: Color(red: 0.98, green: 0.98, blue: 0.98),
        foregroundSecondary: Color(red: 0.68, green: 0.68, blue: 0.70),
        accent: Color(red: 0.92, green: 0.92, blue: 0.93),
        onAccent: Color(red: 0.10, green: 0.10, blue: 0.11),
        qrPanel: Color(red: 1.00, green: 1.00, blue: 1.00)
    )

    /// Soft pink blossom for crafters / florists / cozy small-shop tip jars.
    static let blossom = TipCardTheme(
        id: "blossom",
        nameKey: "theme.blossom",
        isPro: true,
        backgroundColors: [
            Color(red: 1.00, green: 0.92, blue: 0.94),
            Color(red: 0.99, green: 0.83, blue: 0.88)
        ],
        foreground: Color(red: 0.40, green: 0.13, blue: 0.24),
        foregroundSecondary: Color(red: 0.62, green: 0.36, blue: 0.46),
        accent: Color(red: 0.91, green: 0.40, blue: 0.56),
        onAccent: Color(red: 1.00, green: 0.98, blue: 0.99),
        qrPanel: Color(red: 1.00, green: 0.99, blue: 0.99)
    )

    /// All themes in display order. First entry is the free default.
    static let all: [TipCardTheme] = [
        classicLight, midnight, barista, busker, streamer, freelancer, event,
        sunset, ocean, forest, mono, blossom
    ]

    /// Number of premium (paid) themes — computed so paywall / upsell copy that
    /// quotes a theme count stays in sync as the catalog grows (no hardcoded
    /// number to drift). Used by `ShareCardView` / `PaywallView`.
    static var proCount: Int { all.filter(\.isPro).count }

    /// Total number of themes (free + premium), for "N card themes" copy.
    static var totalCount: Int { all.count }

    /// The free default theme.
    static var free: TipCardTheme { classicLight }

    /// Look up a theme by id, falling back to the free default.
    static func theme(id: String?) -> TipCardTheme {
        guard let id else { return free }
        return all.first { $0.id == id } ?? free
    }
}
