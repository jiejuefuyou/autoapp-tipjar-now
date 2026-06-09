---
id: tipjar-now
title: TipJar Now (iOS) - QR tip jar app
category: new-ios-app
priority: P1
status: scaffold
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

🟡 **Scaffold v0.1** (2026-05-06, Tick #95 autoiter). Code skeleton only. Requires:

1. Run `xcodegen generate` to create .xcodeproj
2. Add app icon (1024×1024)
3. Configure ASC IAP (`com.jiejuefuyou.tipjarnow.premium`)
4. Submit binary to App Store Connect

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
│   └── TipJarNowApp.swift          # @main + state injection
├── IAP/
│   └── IAPManager.swift            # StoreKit 2 wrapper (~90 LOC)
├── Models/
│   └── TipMethod.swift             # TipMethodKind enum + TipMethod struct
├── Services/
│   └── TipJarStore.swift           # @Observable + UserDefaults persist
├── Views/
│   ├── ContentView.swift           # Main QR display + method switcher
│   ├── MethodEditView.swift        # Add/edit method form
│   └── PaywallView.swift           # IAP paywall (Pro features)
└── Resources/                      # (icon / privacy / etc)
```

## Free vs Pro

```
Free tier:
  - 1 tip method (single QR)
  - Basic QR
  - No widgets
  - No Apple Watch

Pro ($1.99 one-time):
  - Unlimited methods
  - Apple Watch (planned)
  - Custom themes
  - Lock screen widget (planned)
  - Upload custom QR images (WeChat / PayPay)
  - Haptic feedback
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

## Roadmap (8 weeks to ship)

| Week | Milestone |
|---|---|
| W1 | (this scaffold) project structure + IAP + basic ContentView |
| W2 | Apple Watch companion (independent target) |
| W3 | Widget extension (lock screen QR) |
| W4 | Theme picker + custom QR upload |
| W5 | Localization en/ja/zh-Hans + edge case handling |
| W6 | Polish + onboarding + privacy / terms / restore |
| W7 | TestFlight beta + 30 testers + bug fix |
| W8 | App Store submit + content launch |

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

- Free tier doesn't have widget / Watch (intentional, drives upgrade)
- WeChat / PayPay / LINE Pay 收款 QR 不能 deep link, 需要用户手动 paste URL
- Apple Watch 需要独立 target (后续 W2 添加)
- 无 backend (UserDefaults only, OK for v1)

## License

MIT (subject to change). Code reuses pattern from autoapp-hello / autoapp-altitude-now / autoapp-days-until.

## Contact

Issues: https://github.com/jiejuefuyou/autoapp-tipjar-now/issues (placeholder)
Email: jiejuefuyou@gmail.com
