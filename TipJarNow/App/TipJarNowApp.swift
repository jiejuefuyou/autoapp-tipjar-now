import SwiftUI

@main
struct TipJarNowApp: App {
    @State private var iap = IAPManager()
    @State private var store = TipJarStore()
    @State private var l10n = LocalizationManager.shared

    init() {
        // EAGER init: force LocalizationManager.shared (and its Bundle.main
        // swizzle in installBundleOverride) to run BEFORE SwiftUI evaluates
        // any Text(LocalizedStringKey(...)) in body. Otherwise swizzle may
        // land after first localized string resolution → wrong .lproj cached.
        _ = LocalizationManager.shared

        // Snapshot mode (fastlane screenshots): skip onboarding so UI tests
        // land on the main screen (gate = @AppStorage "hasSeenOnboarding" in
        // ContentView). Never runs in production.
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(iap)
                .environment(store)
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .id(l10n.override)  // CRITICAL: force complete view tree rebuild on language change.
                                    // Without this SwiftUI caches Text(LocalizedStringKey(...))
                                    // resolutions and the new .lproj is never read.
                .task { await iap.refresh() }
                .tint(.accentColor)
        }
    }
}
