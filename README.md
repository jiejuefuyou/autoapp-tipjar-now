---
id: tipjar-now
title: TipJar Now (iOS) - QR tip jar app
category: new-ios-app
priority: P1
status: live
revenue_usd_month: "100-700"
actions: [open-editor, run-script]
tags: [ios, swiftui, storekit2, qrcode]
ice_score: 6.48
tier_price_usd: 1.99
command: "cd repos/autoapp-tipjar-now && xcodegen generate"
created: 2026-05-06
---
# TipJar Now (iOS)

A native iOS tip-jar / payment-card builder. Service workers (waiters / bartenders / drivers / buskers 等) show a payment QR on demand and export a designed tip card + printable poster. URL-based wallets (PayPal / Venmo / Cash App / Revolut / Wise) synthesize a payable QR from your handle; image-only wallets (WeChat Pay / Alipay / PayPay / LINE Pay / Zelle) let you upload your own receive code. No payment processing, no account, no platform cut.

## Status

🟢 **LIVE** on the App Store (ASC id `6770249058`, bundle `com.jiejuefuyou.tipjarnow`, MARKETING_VERSION tracks `project.yml`). 8-locale i18n (en/ja/zh-Hans/zh-Hant/ko/es/fr/de), StoreKit 2 one-time IAP, CI via `git tag v*` → TestFlight. No Apple Watch app, no widgets — see "Free vs Pro" below for what actually ships.

## Architecture

- **iOS 17+ SwiftUI** (Observable + Observation)
- **StoreKit 2** for IAP (one-time $1.99 unlock)
- **CoreImage CIFilter.qrCodeGenerator** for QR generation
- **UserDefaults** for persistence
- **No external dependencies** (no SPM)

## File structure

```
TipJarNow/
├── App/
│   ├── TipJarNowApp.swift          # @main + state injection
│   ├── LocalizationManager.swift   # ios-core canonical (in-app lang override)
│   └── Theme.swift                 # ios-core canonical (Spacing/Radius/Typography)
├── IAP/
│   └── IAPManager.swift            # StoreKit 2 wrapper (loadingState + PurchaseState)
├── Models/
│   ├── TipMethod.swift             # TipMethodKind enum + TipMethod struct + paymentURL
│   ├── TipMethodQR.swift           # single QR resolver (uploaded image → URL QR)
│   └── TipCardTheme.swift          # 12-theme card/poster catalog
├── Services/
│   ├── TipJarStore.swift           # @Observable + UserDefaults persist + free trial
│   └── ReviewService.swift         # ios-core canonical (self-limited review asks)
├── Views/
│   ├── ContentView.swift           # Main QR display + method switcher pills
│   ├── MethodEditView.swift        # Add/edit form + receive-code upload + link preview
│   ├── PaywallView.swift           # IAP paywall (2.1(b)-safe state machine)
│   ├── TipCardView.swift           # shareable Tip Card + ThemeChooser + ShareCardView
│   ├── PosterExportView.swift      # printable poster (A4 / Letter / 4×6 / 1080²)
│   ├── OnboardingView.swift        # 3-screen onboarding (HIG-compliant Skip)
│   ├── SettingsView.swift          # premium status / language / about
│   └── CrossPromoSection.swift     # ios-core canonical (portfolio cross-promo)
└── Resources/                      # 8 × .lproj + assets + PrivacyInfo
```

## Free vs Pro

```
Free tier:
  - 1 tip method (single QR; uploading your own receive code is free)
  - Free card theme, watermarked card/poster output
  - One-time free premium output: taste any premium theme once,
    watermark-free (persisted, bypass-proof — TipJarStore)

Pro ($1.99 one-time, no subscription):
  - Unlimited methods
  - All 12 designer card themes (count computed from the catalog)
  - Print-ready poster sizes (A4 / US Letter / 4×6)
  - Watermark-free cards & posters
```

## Build steps

```bash
# 1. Generate Xcode project
brew install xcodegen
cd repos/autoapp-tipjar-now
xcodegen generate

# 2. Open in Xcode
open TipJarNow.xcodeproj

# 3. Set development team in project.yml or Xcode signing
# 4. Build to simulator / device
# 5. Test sandbox IAP with test account
```

## ASC setup

```
1. App Store Connect → My Apps → + → New App
   Bundle ID: com.jiejuefuyou.tipjarnow
   Name: TipJar Now
   SKU: tipjarnow-001

2. Add IAP:
   Reference Name: tipjarnow_premium_unlock
   Product ID: com.jiejuefuyou.tipjarnow.premium
   Type: Non-Consumable
   Price: $1.99 (Tier 2)

3. Add localizations (en / ja / zh-Hans):
   Display Name: TipJar Pro
   Description: Unlock unlimited tip methods, printable QR posters, all card themes, and remove the watermark.

4. Pricing: Free
5. Category: Utilities (NOT Finance — the app displays a QR but processes no payments; Finance invites 1.5 / 2.1 financial-services scrutiny)
6. Submit for Review
```

## Shipped milestones

Project structure + IAP, theme picker (12 themes) + user-uploaded receive
codes for image-only wallets, 8-locale localization, onboarding + privacy /
terms / restore, Tip Card share + printable poster export, App Store launch.
No Apple Watch target and no widget extension exist — do not re-add those
claims to user-facing copy (5.2.5 / 2.3.1 vapor-feature risk; the onboarding
"Apple Watch" copy was already removed once in commit 3b09ecd).

## Day 30 ROI projection

```
DAU 200 (organic + niche communities)
Conv 5% × $1.99 × 0.7 (after Apple) = $14/month

DAU 1000 (TikTok 服务业 / Reddit r/bartending hit)
Conv 8% × $1.99 × 0.7 = $111/month

DAU 5000 (1 viral / 1 Reddit hit + ASO long tail)
Conv 10% × $1.99 × 0.7 = $696/month
```

## Marketing positioning

- **ICP 1**: US bartenders / hairdressers (tipping culture strong)
- **ICP 2**: JP omakase chefs / specialty service (チップ pickup growing)
- **ICP 3**: 直播主 / 摆地摊 (中国, 微信收款)
- **ICP 4**: SEA / India ride-share drivers (PayPay / GoPay 等)
- **ICP 5**: B2B angle (服务业老板批量买给员工, 1 客户 = 5-50 unit)

## Known limitations

- WeChat / Alipay / PayPay / LINE Pay / Zelle 没有 public payable URL —
  用户上传自己的收款码图片 (MethodEditView PhotosPicker), 卡片/海报 verbatim 渲染
- 无 backend (UserDefaults only, OK for v1)

## License

MIT (subject to change). Code reuses pattern from autoapp-hello / autoapp-altitude-now / autoapp-days-until.

## Contact

Issues: https://github.com/jiejuefuyou/autoapp-tipjar-now/issues (placeholder)
Email: jiejuefuyou@gmail.com
