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

    var displayName: String {
        switch self {
        case .paypal:  return "PayPal"
        case .venmo:   return "Venmo"
        case .wechat:  return "微信支付 (WeChat Pay)"
        case .alipay:  return "支付宝 (Alipay)"
        case .paypay:  return "PayPay (JP)"
        case .linePay: return "LINE Pay"
        case .cashApp: return "Cash App"
        case .zelle:   return "Zelle"
        case .revolut: return "Revolut"
        case .wise:    return "Wise"
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
