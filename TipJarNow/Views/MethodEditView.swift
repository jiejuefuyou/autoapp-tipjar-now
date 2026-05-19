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
                Section(LocalizedStringKey("Method")) {
                    Picker(LocalizedStringKey("Kind"), selection: $kind) {
                        ForEach(TipMethodKind.allCases) { k in
                            Label(k.displayName, systemImage: k.symbol).tag(k)
                        }
                    }
                }

                Section(LocalizedStringKey("Address / Handle")) {
                    TextField(LocalizedStringKey(addressPlaceholderKey), text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(LocalizedStringKey(addressHintKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(LocalizedStringKey("Display Name (optional)")) {
                    TextField(LocalizedStringKey("e.g. \"My Venmo\""), text: $displayNameOverride)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("Add Method")))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Save")) {
                        save()
                        dismiss()
                    }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var addressPlaceholderKey: String {
        switch kind {
        case .paypal:  return "placeholder.paypal"
        case .venmo:   return "placeholder.venmo"
        case .wechat:  return "placeholder.wechat"
        case .alipay:  return "placeholder.alipay"
        case .paypay:  return "placeholder.paypay"
        case .linePay: return "placeholder.linepay"
        case .cashApp: return "placeholder.cashapp"
        case .zelle:   return "placeholder.zelle"
        case .revolut: return "placeholder.revolut"
        case .wise:    return "placeholder.wise"
        }
    }

    private var addressHintKey: String {
        switch kind {
        case .paypal:  return "hint.paypal"
        case .venmo:   return "hint.venmo"
        case .wechat:  return "hint.wechat"
        case .alipay:  return "hint.alipay"
        case .paypay:  return "hint.paypay"
        case .linePay: return "hint.linepay"
        case .cashApp: return "hint.cashapp"
        case .zelle:   return "hint.zelle"
        case .revolut: return "hint.revolut"
        case .wise:    return "hint.wise"
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
