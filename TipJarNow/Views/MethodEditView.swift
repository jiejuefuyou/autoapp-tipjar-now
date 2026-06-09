import SwiftUI
import PhotosUI
import UIKit

/// Add or edit a tip method.
///
/// Two flavors of capture, driven by `kind.payloadKind`:
///   • URL-based (PayPal / Venmo / Cash App / Revolut / Wise): the user types a
///     handle or pastes a link; we synthesize the payable URL and show a live
///     "your QR will link to …" preview so a QR-to-nowhere is impossible to ship
///     silently.
///   • Image-only wallets (WeChat / Alipay / PayPay / LINE Pay / Zelle): there
///     is no public payable URL — the receive code IS an image — so the user
///     uploads their own QR via PhotosPicker, which is rendered verbatim on the
///     card/poster. An optional label may still be entered.
struct MethodEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TipMethodKind
    @State private var address: String
    @State private var displayNameOverride: String
    @State private var qrImageData: Data?

    /// PhotosPicker selection (image-only wallets).
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var imageLoadFailed = false

    private let editingID: UUID?
    let onSave: (TipMethod) -> Void

    /// Add a new method.
    init(onSave: @escaping (TipMethod) -> Void) {
        _kind = State(initialValue: .paypal)
        _address = State(initialValue: "")
        _displayNameOverride = State(initialValue: "")
        _qrImageData = State(initialValue: nil)
        self.editingID = nil
        self.onSave = onSave
    }

    /// Edit an existing method (preserves its id so `store.update` matches).
    init(editing method: TipMethod, onSave: @escaping (TipMethod) -> Void) {
        _kind = State(initialValue: method.kind)
        _address = State(initialValue: method.addressOrLink)
        _displayNameOverride = State(initialValue: method.displayName ?? "")
        _qrImageData = State(initialValue: method.qrImageData)
        self.editingID = method.id
        self.onSave = onSave
    }

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

                if kind.requiresUploadedQR {
                    uploadSection
                } else {
                    urlSection
                }

                Section(LocalizedStringKey("Display Name (optional)")) {
                    TextField(LocalizedStringKey("e.g. \"My Venmo\""), text: $displayNameOverride)
                }
            }
            .navigationTitle(Text(navigationTitleKey))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Save")) {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            // Load + downscale the picked image off the main actor's hot path.
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadPickedImage(newItem) }
            }
        }
    }

    // MARK: - URL-based capture

    @ViewBuilder
    private var urlSection: some View {
        Section(LocalizedStringKey("Address / Handle")) {
            TextField(LocalizedStringKey(addressPlaceholderKey), text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Text(LocalizedStringKey(addressHintKey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Live resolved-target preview so the user sees exactly what their QR
        // links to before saving — kills the silent "QR to nowhere" failure.
        Section {
            if let url = previewMethod.paymentURL {
                Label {
                    Text(url.absoluteString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "link")
                        .foregroundStyle(.green)
                }
            } else if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label {
                    Text(LocalizedStringKey("This doesn't look like a valid link yet. Check the format in the hint above."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text(LocalizedStringKey("Your QR will link to"))
        }
    }

    // MARK: - Image-only capture (upload your own receive code)

    @ViewBuilder
    private var uploadSection: some View {
        Section {
            if let data = qrImageData, let uiImage = UIImage(data: data) {
                HStack {
                    Spacer()
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .padding(Spacing.sm)
                        .background(.white, in: RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .strokeBorder(.tertiary, lineWidth: 1)
                        )
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    qrImageData == nil
                        ? LocalizedStringKey("Choose receive code image")
                        : LocalizedStringKey("Replace receive code image"),
                    systemImage: "photo.on.rectangle.angled"
                )
                .frame(minHeight: 44)
            }

            if qrImageData != nil {
                Button(role: .destructive) {
                    qrImageData = nil
                    pickerItem = nil
                } label: {
                    Label(LocalizedStringKey("Remove image"), systemImage: "trash")
                        .frame(minHeight: 44)
                }
            }

            if imageLoadFailed {
                Label {
                    Text(LocalizedStringKey("Couldn't load that image. Please try another."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text(LocalizedStringKey("Receive code"))
        } footer: {
            Text(LocalizedStringKey(addressHintKey))
        }

        // Optional human-readable label (e.g. a WeChat ID) shown under the QR.
        Section(LocalizedStringKey("Label (optional)")) {
            TextField(LocalizedStringKey(addressPlaceholderKey), text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Picked-image processing

    /// Load the picked image, downscale to a QR-friendly size, and JPEG-encode
    /// so the persisted method JSON stays small (a full-res camera shot is
    /// several MB; a QR only needs ~600px). Runs on a background task.
    private func loadPickedImage(_ item: PhotosPickerItem) async {
        imageLoadFailed = false
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data)
        else {
            imageLoadFailed = true
            return
        }
        let downscaled = Self.downscaledJPEG(uiImage, maxDimension: 700, quality: 0.85)
        qrImageData = downscaled ?? data
    }

    /// Aspect-fit downscale + JPEG encode. Returns nil if encoding fails.
    static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: - Save

    /// A method built from the *current* field values, used both for the live
    /// preview and for the final save (so preview == what gets saved).
    private var previewMethod: TipMethod {
        let nameOverride = displayNameOverride.trimmingCharacters(in: .whitespaces)
        return TipMethod(
            id: editingID ?? UUID(),
            kind: kind,
            addressOrLink: address.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: nameOverride.isEmpty ? nil : nameOverride,
            qrImageData: qrImageData
        )
    }

    /// Save is enabled only when the method has a real payable target:
    ///   • URL methods: the typed handle/link resolves to a valid URL.
    ///   • Image methods: a receive-code image has been uploaded.
    private var canSave: Bool {
        previewMethod.hasPayableTarget
    }

    private var navigationTitleKey: LocalizedStringKey {
        editingID == nil ? LocalizedStringKey("Add Method") : LocalizedStringKey("Edit Method")
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
        onSave(previewMethod)
    }
}
