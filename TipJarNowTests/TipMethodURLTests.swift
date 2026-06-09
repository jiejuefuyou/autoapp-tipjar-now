import XCTest
@testable import TipJarNow

/// The product's entire job is "produce a correct payable QR." These tests pin
/// the `TipMethod.paymentURL` / `payloadKind` / `hasPayableTarget` contract so a
/// regression that ships a QR-to-nowhere fails CI loudly. All deterministic and
/// hermetic — no host bundle, no StoreKit, no UserDefaults.
final class TipMethodURLTests: XCTestCase {

    private func method(_ kind: TipMethodKind, _ address: String, image: Data? = nil) -> TipMethod {
        TipMethod(kind: kind, addressOrLink: address, qrImageData: image)
    }

    // MARK: - URL-based methods produce the correct payable URL

    func testPayPalFromHandle() {
        XCTAssertEqual(method(.paypal, "john").paymentURL?.absoluteString,
                       "https://paypal.me/john")
    }

    func testPayPalFromFullURLRoundTrips() {
        XCTAssertEqual(method(.paypal, "https://paypal.me/john").paymentURL?.absoluteString,
                       "https://paypal.me/john")
    }

    func testPayPalFromSchemelessLinkGetsHTTPS() {
        XCTAssertEqual(method(.paypal, "paypal.me/john").paymentURL?.absoluteString,
                       "https://paypal.me/john")
    }

    func testVenmoUsesPersonalProfilePath() {
        // Regression guard: personal Venmo is /u/<name>, NOT /<name> (business).
        XCTAssertEqual(method(.venmo, "john").paymentURL?.absoluteString,
                       "https://venmo.com/u/john")
    }

    func testVenmoStripsLeadingAtSign() {
        XCTAssertEqual(method(.venmo, "@john").paymentURL?.absoluteString,
                       "https://venmo.com/u/john")
    }

    func testVenmoFullURLRoundTrips() {
        XCTAssertEqual(method(.venmo, "https://venmo.com/u/john").paymentURL?.absoluteString,
                       "https://venmo.com/u/john")
    }

    func testCashAppKeepsSingleDollarSign() {
        // Whether the user types "john" or "$john", the URL has exactly one '$'.
        XCTAssertEqual(method(.cashApp, "john").paymentURL?.absoluteString,
                       "https://cash.app/$john")
        XCTAssertEqual(method(.cashApp, "$john").paymentURL?.absoluteString,
                       "https://cash.app/$john")
    }

    func testRevolutBuildsRevolutMeLink() {
        XCTAssertEqual(method(.revolut, "john").paymentURL?.absoluteString,
                       "https://revolut.me/john")
        XCTAssertEqual(method(.revolut, "@john").paymentURL?.absoluteString,
                       "https://revolut.me/john")
    }

    func testWiseRequiresFullURL() {
        // Wise has no handle form — a bare handle must NOT become a QR-to-nowhere.
        XCTAssertNil(method(.wise, "john").paymentURL,
                     "A bare Wise handle should not synthesize a URL.")
        XCTAssertEqual(method(.wise, "https://wise.com/pay/me/john").paymentURL?.absoluteString,
                       "https://wise.com/pay/me/john")
    }

    func testPercentEncodingForSpacesAndUnicode() {
        // A handle with a space must encode, not produce a malformed URL.
        let url = method(.paypal, "john doe").paymentURL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://paypal.me/john%20doe")

        // Non-ASCII handle still yields a valid (encoded) URL.
        XCTAssertNotNil(method(.revolut, "ジョン").paymentURL)
    }

    // MARK: - Image-only methods never synthesize a URL

    func testImageOnlyMethodsHaveNoPaymentURL() {
        for kind in [TipMethodKind.wechat, .alipay, .paypay, .linePay, .zelle] {
            // Even if the user typed something that looks like a handle/URL,
            // these methods are image-only and must not encode a URL QR.
            XCTAssertNil(method(kind, "anything").paymentURL,
                         "\(kind.rawValue) must not synthesize a payment URL.")
            XCTAssertNil(method(kind, "https://example.com/pay").paymentURL,
                         "\(kind.rawValue) must not synthesize a payment URL even from a URL string.")
        }
    }

    func testPayloadKindClassification() {
        for kind in [TipMethodKind.paypal, .venmo, .cashApp, .revolut, .wise] {
            XCTAssertEqual(kind.payloadKind, .url, "\(kind.rawValue) should be URL-based.")
            XCTAssertFalse(kind.requiresUploadedQR)
        }
        for kind in [TipMethodKind.wechat, .alipay, .paypay, .linePay, .zelle] {
            XCTAssertEqual(kind.payloadKind, .uploadedImage, "\(kind.rawValue) should be image-only.")
            XCTAssertTrue(kind.requiresUploadedQR)
        }
    }

    // MARK: - hasPayableTarget (drives Save-enabled / setup affordance)

    func testURLMethodPayableOnlyWithValidInput() {
        XCTAssertFalse(method(.venmo, "").hasPayableTarget, "Empty handle → not payable.")
        XCTAssertFalse(method(.venmo, "   ").hasPayableTarget, "Whitespace handle → not payable.")
        XCTAssertTrue(method(.venmo, "john").hasPayableTarget)
        // Wise with a bare handle is NOT payable (no URL synthesizable).
        XCTAssertFalse(method(.wise, "john").hasPayableTarget)
        XCTAssertTrue(method(.wise, "https://wise.com/pay/me/john").hasPayableTarget)
    }

    func testImageMethodPayableOnlyWithUploadedImage() {
        // No image → not payable, regardless of the optional label.
        XCTAssertFalse(method(.wechat, "my-wechat").hasPayableTarget)
        XCTAssertFalse(method(.zelle, "").hasPayableTarget)
        // With an uploaded image → payable (the label is irrelevant).
        let fakeImage = Data([0xFF, 0xD8, 0xFF])  // not a real JPEG, but non-nil
        XCTAssertTrue(method(.wechat, "", image: fakeImage).hasPayableTarget)
        XCTAssertTrue(method(.zelle, "label", image: fakeImage).hasPayableTarget)
    }

    // MARK: - QR image resolution (uploaded image wins over synthesized URL)

    func testUploadedImageTakesPrecedenceOverURL() {
        // A 1×1 PNG so UIImage(data:) succeeds deterministically.
        let png = Self.onePixelPNG()
        // Even for a URL-based method, an uploaded image is rendered verbatim.
        let m = method(.paypal, "john", image: png)
        let resolved = m.qrImage
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.size.width ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(resolved?.size.height ?? 0, 1, accuracy: 0.001)
    }

    func testURLMethodSynthesizesQRWhenNoImage() {
        let m = method(.venmo, "john")
        XCTAssertNotNil(m.qrImage, "A valid URL method should synthesize a QR image.")
    }

    func testImageOnlyMethodHasNoQRUntilUploaded() {
        // No URL, no image → no scannable QR (callers show a setup affordance).
        XCTAssertNil(method(.wechat, "label").qrImage)
        // qrImageOrPlaceholder is never nil (UI slot is never blank).
        XCTAssertNotNil(method(.wechat, "label").qrImageOrPlaceholder)
    }

    func testQRGeneratorProducesImageForSamplePayload() {
        XCTAssertNotNil(QRGenerator.image(from: "https://paypal.me/john"),
                        "QR generation must succeed for a normal payload.")
    }

    // MARK: - Uploaded-image downscaling (keeps persisted JSON small)

    @MainActor
    func testDownscaleShrinksLargeImageAndEncodesJPEG() {
        // A 1400×1400 source should be downscaled to fit maxDimension 700.
        let big = Self.solidImage(side: 1400)
        let data = MethodEditView.downscaledJPEG(big, maxDimension: 700, quality: 0.85)
        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertNotNil(decoded)
        XCTAssertLessThanOrEqual(max(decoded!.size.width, decoded!.size.height), 700.5,
                                 "Longest side should be clamped to maxDimension.")
    }

    @MainActor
    func testDownscaleDoesNotUpscaleSmallImage() {
        let small = Self.solidImage(side: 300)
        let data = MethodEditView.downscaledJPEG(small, maxDimension: 700, quality: 0.85)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(max(decoded!.size.width, decoded!.size.height), 300, accuracy: 0.5,
                       "A small image must not be upscaled.")
    }

    // MARK: - Helpers

    @MainActor
    private static func solidImage(side: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }


    /// Minimal valid 1×1 PNG (base64) so `UIImage(data:)` returns a real image.
    private static func onePixelPNG() -> Data {
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        return Data(base64Encoded: b64)!
    }
}
