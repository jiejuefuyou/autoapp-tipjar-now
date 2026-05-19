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
}

struct TipMethod: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: TipMethodKind
    var addressOrLink: String  // PayPal email / Venmo handle / WeChat QR URL / etc
    var displayName: String?   // Optional override
    var qrImageData: Data?     // Manually-uploaded QR image (for PayPay / WeChat)

    init(id: UUID = UUID(), kind: TipMethodKind, addressOrLink: String, displayName: String? = nil, qrImageData: Data? = nil) {
        self.id = id
        self.kind = kind
        self.addressOrLink = addressOrLink
        self.displayName = displayName
        self.qrImageData = qrImageData
    }

    var paymentURL: URL? {
        switch kind {
        case .paypal:
            // PayPal.me URL
            if addressOrLink.contains("paypal.me") {
                return URL(string: addressOrLink.starts(with: "http") ? addressOrLink : "https://\(addressOrLink)")
            }
            return URL(string: "https://paypal.me/\(addressOrLink)")
        case .venmo:
            return URL(string: "https://venmo.com/\(addressOrLink)")
        case .cashApp:
            return URL(string: "https://cash.app/\(addressOrLink)")
        case .wechat, .alipay, .paypay, .linePay:
            // Custom URL or QR image
            return URL(string: addressOrLink)
        case .zelle, .revolut, .wise:
            return URL(string: addressOrLink)
        }
    }
}
