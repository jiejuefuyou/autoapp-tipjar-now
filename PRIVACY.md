# Privacy Policy for TipJar Now

**Last updated**: 2026-05-17
**Developer**: Hao Sun (jiejuefuyou@gmail.com)
**Effective for**: TipJar Now iOS app, v1.0+

## What we collect

**Nothing.** TipJar Now is a 100% offline app. We collect zero information about you, your usage, your payment methods, or your device.

## Local storage only

Your saved payment methods (PayPal handle, Venmo username, WeChat Pay QR data, etc.) are stored **only on your device**, using iOS's encrypted standard `UserDefaults` and (if you upload custom QR images) the iOS Documents directory.

- We **never** transmit this data anywhere.
- We **never** sync it across devices (no cloud, no server).
- If you delete the app, all data is permanently gone (no recovery possible).

## Third-party services

None. TipJar Now does not include any third-party SDKs (no Firebase, no Crashlytics, no analytics, no ads).

The only network call is when you tap **Restore Purchases** or **Buy Pro** — this contacts Apple's StoreKit servers per Apple's iOS payment processing. Apple's privacy policy applies: https://www.apple.com/legal/privacy/

## QR code generation

QR codes are generated locally on your device using Apple's CoreImage framework (`CIFilter.qrCodeGenerator()`). The string content (e.g., your PayPal email) is encoded into the QR code on-device and displayed only on screen. Nothing is sent to any server.

## Push notifications

None. We do not send notifications.

## App Tracking Transparency (ATT)

We do not track you across apps or websites owned by other companies. Per Apple's ATT requirement, this app does not invoke the ATT permission prompt because we have nothing to track.

## Children

This app does not target users under 13. It is rated 4+ in App Store Connect because it contains no objectionable content.

## Your rights

Since we collect nothing, there is no data to access, correct, or delete. If you want to remove all your saved payment methods, simply delete the app.

## Changes to this policy

If we change this policy, we'll update the "Last updated" date above. Material changes will be noted in app release notes.

## Contact

For privacy questions: **jiejuefuyou@gmail.com**

For app issues: https://github.com/jiejuefuyou/autoapp-tipjar-now/issues

For Apple's compliant support page (per App Store Review Guideline 1.5): https://jiejuefuyou.github.io/support-tipjarnow.html
