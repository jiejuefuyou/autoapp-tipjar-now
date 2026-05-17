import SwiftUI

@main
struct TipJarNowApp: App {
    @State private var iap = IAPManager()
    @State private var store = TipJarStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(iap)
                .environment(store)
                .task { await iap.refresh() }
        }
    }
}
