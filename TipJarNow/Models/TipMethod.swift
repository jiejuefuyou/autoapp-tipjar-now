import Foundation

enum TipMethodKind: String, Codable, CaseIterable, Identifiable {
    case paypal
    case venmo
    case wechat
    case alipay
    case paypay
    case linePay = "line_pay"
    case cashApp = "cash_app"
    case zelle
    case revolut
    case wise

    var id: String { rawValue }

    /// Display name rendered via the app's localized bundle. Brand names
    /// (PayPal, Venmo, etc.) are largely identical across locales, but we
    /// route through `String(localized:)` so any locale-specific romanization
    /// (e.g. zh-Hans "微信支付" vs. zh-Hant "微信支付") flows through .lproj.
    var displayName: String {
        switch self {
        case .paypal:  return String(localized: "method.paypal")
        case .venmo:   return String(localized: "method.venmo")
        case .wechat:  return String(localized: "method.wechat")
        case .alipay:  return String(localized: "method.alipay")
        case .paypay:  return String(localized: "method.paypay")
        case .linePay: return String(localized: "method.linepay")
        case .cashApp: return String(localized: "method.cashapp")
        case .zelle:   return String(localized: "method.zelle")
        case .revolut: return String(localized: "method.revolut")
        case .wise:    return String(localized: "method.wise")
        }
    }

    /// SF Symbol icon name
    var symbol: String {
        switch self {
        case .paypal:  return "p.circle.fill"
        case .venmo:   return "v.circle.fill"
        case .wechat:  return "w.circle.fill"
        case .alipay:  return "a.circle.fill"
        case .paypay:  return "p.circle"
        case .linePay: return "l.circle.fill"
        case .cashApp: return "c.circle.fill"
        case .zelle:   return "z.circle.fill"
        case .revolut: return "r.circle.fill"
        case .wise:    return "w.circle"
        }
    }

    /// How a payable QR is produced for this method.
    ///
    /// - `.url`: the method exposes a public, deep-linkable handle or payment
    ///   URL, so we can synthesize a QR the recipient's phone camera (or the
    ///   wallet's in-app scanner) resolves to a "pay this person" flow.
    /// - `.uploadedImage`: the method's receive code **is an image** with no
    ///   public URL form — WeChat Pay / Alipay personal receive codes, PayPay,
    ///   LINE Pay, and Zelle (Zelle has no `zellepay.com/<handle>` link; the
    ///   personal receive QR lives only inside the bank app). For these the
    ///   user must supply their own real payment QR image; encoding a URL
    ///   string would produce a QR that scans to nothing (2.3.1 misleading).
    ///
    /// Sources (verified 2026-06): Zelle FAQ "no public payment link/URL";
    /// PayPay app shows a personal barcode/QR with no shareable URL; WeChat/
    /// Alipay personal receive codes are image-only.
    enum PayloadKind: Equatable {
        case url
        case uploadedImage
    }

    var payloadKind: PayloadKind {
        switch self {
        case .paypal, .venmo, .cashApp, .revolut, .wise:
            return .url
        case .wechat, .alipay, .paypay, .linePay, .zelle:
            return .uploadedImage
        }
    }

    /// True when the only way to produce a payable QR is for the user to upload
    /// their own receive-code image (drives the PhotosPicker UI).
    var requiresUploadedQR: Bool { payloadKind == .uploadedImage }
}

struct TipMethod: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: TipMethodKind
    var addressOrLink: String  // PayPal email / Venmo handle / Cash App $tag / etc.
    var displayName: String?   // Optional override
    /// User-uploaded receive-code image (for image-only wallets: WeChat /
    /// Alipay / PayPay / LINE Pay / Zelle). Stored downscaled+JPEG so the
    /// persisted methods JSON stays small. When present it is rendered verbatim
    /// on the card/poster instead of a synthesized QR (see `TipMethod.qrImage`).
    var qrImageData: Data?

    init(id: UUID = UUID(), kind: TipMethodKind, addressOrLink: String, displayName: String? = nil, qrImageData: Data? = nil) {
        self.id = id
        self.kind = kind
        self.addressOrLink = addressOrLink
        self.displayName = displayName
        self.qrImageData = qrImageData
    }

    /// Normalized handle: trimmed, with a single leading sigil (`@`, `$`)
    /// stripped so users can paste either `@john` or `john` and get the same
    /// correct URL. The sigil is re-added per-method where the URL form needs it.
    private var normalizedHandle: String {
        var h = addressOrLink.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = h.first, first == "@" || first == "$" {
            h.removeFirst()
        }
        return h
    }

    /// Percent-encode a path segment so spaces / non-ASCII / reserved chars
    /// don't produce an invalid URL.
    private func encodedPathSegment(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    /// The payable URL for `.url` methods. Returns `nil` for `.uploadedImage`
    /// methods (their QR comes from `qrImageData`, not a URL) and for blank /
    /// clearly-invalid input.
    ///
    /// Per-method formats (verified 2026-06, see PayloadKind sources):
    ///   • PayPal   → https://paypal.me/<handle>      (or a pasted full URL)
    ///   • Venmo    → https://venmo.com/u/<handle>    (personal profile path)
    ///   • Cash App → https://cash.app/$<cashtag>
    ///   • Revolut  → https://revolut.me/<revtag>
    ///   • Wise     → the user's own pasted payment/Quick-Pay link (http[s] only)
    var paymentURL: URL? {
        let handle = normalizedHandle
        guard !handle.isEmpty || isFullURL(addressOrLink) else { return nil }

        switch kind {
        case .paypal:
            // Accept a pasted full paypal.me URL, otherwise build one.
            if addressOrLink.localizedCaseInsensitiveContains("paypal.me") {
                return normalizedFullURL(addressOrLink)
            }
            return URL(string: "https://paypal.me/\(encodedPathSegment(handle))")
        case .venmo:
            if addressOrLink.localizedCaseInsensitiveContains("venmo.com") {
                return normalizedFullURL(addressOrLink)
            }
            // Personal Venmo profile lives at /u/<username>; /<name> is for
            // business profiles only. Synthesizing /u/ keeps the common
            // (personal) case payable.
            return URL(string: "https://venmo.com/u/\(encodedPathSegment(handle))")
        case .cashApp:
            if addressOrLink.localizedCaseInsensitiveContains("cash.app") {
                return normalizedFullURL(addressOrLink)
            }
            return URL(string: "https://cash.app/$\(encodedPathSegment(handle))")
        case .revolut:
            if addressOrLink.localizedCaseInsensitiveContains("revolut.me") {
                return normalizedFullURL(addressOrLink)
            }
            return URL(string: "https://revolut.me/\(encodedPathSegment(handle))")
        case .wise:
            // Personal Wise has no simple handle link; the user pastes their
            // own payment/Quick-Pay URL. Only accept a real http(s) URL so a
            // bare handle never yields a QR-to-nowhere.
            return isFullURL(addressOrLink) ? normalizedFullURL(addressOrLink) : nil
        case .wechat, .alipay, .paypay, .linePay, .zelle:
            // Image-only wallets: no payable URL form.
            return nil
        }
    }

    /// Whether `addressOrLink` currently resolves to something a QR can encode
    /// as payable — a synthesized/ pasted URL for `.url` methods, or an uploaded
    /// image for `.uploadedImage` methods. Used for live input validation.
    var hasPayableTarget: Bool {
        switch kind.payloadKind {
        case .url:           return paymentURL != nil
        case .uploadedImage: return qrImageData != nil
        }
    }

    /// True when the string looks like an absolute http(s) URL.
    private func isFullURL(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.hasPrefix("http://") || t.hasPrefix("https://")
    }

    /// Normalize a user-pasted URL: trim, and prepend https:// if the scheme
    /// is missing so `paypal.me/x` (no scheme) still becomes a valid URL.
    private func normalizedFullURL(_ s: String) -> URL? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = isFullURL(t) ? t : "https://\(t)"
        return URL(string: full)
    }
}
