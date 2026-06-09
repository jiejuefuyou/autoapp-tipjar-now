import UIKit

/// Single source of truth for "what image goes in the QR slot" for a method.
///
/// Resolution order:
///   1. A user-uploaded receive-code image (`qrImageData`) — used verbatim. This
///      is the ONLY payable path for image-only wallets (WeChat / Alipay /
///      PayPay / LINE Pay / Zelle), and a user of a URL-based method may also
///      upload a custom code if they prefer.
///   2. A QR synthesized from `paymentURL` (URL-based methods: PayPal / Venmo /
///      Cash App / Revolut / Wise).
///   3. `nil` — nothing payable yet (e.g. an image-only method before the user
///      uploads their code). Callers render a neutral placeholder so the UI is
///      never blank, but the card/poster intentionally has no scannable QR.
///
/// Centralizing this means the on-screen QR (`ContentView`), the share card
/// (`TipCardView`), and the poster (`PosterArtwork`) can never drift — the
/// dead-`qrImageData` bug (a persisted field with zero readers) is fixed by
/// having exactly one reader that all three call sites use.
extension TipMethod {

    /// The resolved payable image, or `nil` if the method has no scannable
    /// target yet (uploaded image missing AND no synthesizable URL).
    var qrImage: UIImage? {
        if let data = qrImageData, let uploaded = UIImage(data: data) {
            return uploaded
        }
        if let url = paymentURL {
            return QRGenerator.image(from: url.absoluteString)
        }
        return nil
    }

    /// Non-optional variant for view code: returns `qrImage` or a neutral
    /// system glyph so an `Image` slot is never empty. Use `qrImage == nil`
    /// (or `hasPayableTarget`) to decide whether to show a "set up your code"
    /// affordance instead.
    var qrImageOrPlaceholder: UIImage {
        qrImage ?? UIImage(systemName: "qrcode") ?? UIImage()
    }
}
