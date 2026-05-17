import SwiftUI

struct MethodEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TipMethodKind = .paypal
    @State private var address: String = ""
    @State private var displayNameOverride: String = ""

    let onSave: (TipMethod) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Method") {
                    Picker("Kind", selection: $kind) {
                        ForEach(TipMethodKind.allCases) { k in
                            Label(k.displayName, systemImage: k.symbol).tag(k)
                        }
                    }
                }

                Section("Address / Handle") {
                    TextField(addressPlaceholder, text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(addressHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Display Name (optional)") {
                    TextField("e.g. \"My Venmo\"", text: $displayNameOverride)
                }
            }
            .navigationTitle("Add Method")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var addressPlaceholder: String {
        switch kind {
        case .paypal:  return "user@email.com or paypal.me/handle"
        case .venmo:   return "@your-venmo"
        case .wechat:  return "WeChat Pay receive QR URL"
        case .alipay:  return "Alipay receive QR URL"
        case .paypay:  return "PayPay receive URL"
        case .linePay: return "LINE Pay receive URL"
        case .cashApp: return "$your-tag"
        case .zelle:   return "phone or email"
        case .revolut: return "@your-revtag"
        case .wise:    return "wise.com/pay/me/yourname"
        }
    }

    private var addressHint: String {
        switch kind {
        case .paypal:
            return "Enter your PayPal email or paypal.me/handle. QR will encode to your PayPal page."
        case .venmo:
            return "Just your @handle. QR opens venmo.com/handle."
        case .wechat, .alipay:
            return "Open WeChat / Alipay → 收款码 → save image → upload manually (Pro). For now, paste QR URL if you have one."
        case .paypay:
            return "PayPay 受け取りリンク. 開いて URL コピー."
        case .linePay:
            return "LINE Pay 受け取りリンク."
        case .cashApp:
            return "Your $cashtag (e.g. $john). QR opens cash.app/$john."
        case .zelle:
            return "Zelle phone or email. QR encodes a tel: or mailto: URI."
        case .revolut:
            return "Your @revtag. QR opens revolut.com/pay-me/@revtag."
        case .wise:
            return "Your Wise pay.me link."
        }
    }

    private func save() {
        let nameOverride = displayNameOverride.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let method = TipMethod(
            kind: kind,
            addressOrLink: trimmedAddress,
            displayName: nameOverride.isEmpty ? nil : nameOverride,
            qrImageData: nil
        )
        onSave(method)
    }
}
