import Foundation
import Observation

@MainActor
@Observable
final class TipJarStore {
    static let freeMethodLimit = 1

    /// UserDefaults key for the one-time premium-output trial flag.
    /// Persisted so a free user can export exactly ONE watermark-free premium
    /// card / poster, ever. Never reset by the app — the trial is irrevocably
    /// one-time, so there is no bypass loop (CLAUDE.md #1 conversion lever:
    /// let the creator *taste* a clean, watermark-free result so "why pay?"
    /// becomes an experienced desire).
    static let premiumTrialKey = "tipjarnow.premiumOutputTrial.used.v1"

    var methods: [TipMethod] = []

    /// Whether the single free premium-output trial has already been spent.
    /// Mirrored into UserDefaults on every write so the trial survives relaunch
    /// and cannot recur. Initialized from the persisted flag at launch.
    private(set) var premiumTrialUsed: Bool = UserDefaults.standard.bool(forKey: TipJarStore.premiumTrialKey)

    private let storageKey = "tipjarnow.methods.v1"

    init() {
        load()

        // Snapshot mode (fastlane screenshots): seed two realistic, QR-renderable
        // methods so every captured screen shows the app genuinely in use
        // (lesson #44 / Apple 2.3.3 — this app was rejected for non-real shots).
        // Assigned directly (persist() NOT called) so nothing is written to
        // UserDefaults; production behavior untouched.
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            methods = [
                TipMethod(kind: .paypal, addressOrLink: "alexcreates", displayName: "Alex the Busker"),
                TipMethod(kind: .venmo, addressOrLink: "alex-creates", displayName: "Alex the Busker"),
            ]
        }
    }

    // MARK: - One-time premium-output trial

    /// True when the user may still claim their single free premium output.
    /// Callers pass live entitlement: premium users never see the trial (they
    /// already own everything); a free user who hasn't spent the trial does.
    func premiumTrialAvailable(isPremium: Bool) -> Bool {
        !isPremium && !premiumTrialUsed
    }

    /// Burn the one-time trial. Idempotent: calling more than once is a no-op,
    /// so a double-tap or a retried export can never grant a second free output.
    /// Returns `true` only on the call that actually consumed an available
    /// trial, so the UI shows the aspirational re-lock prompt exactly once.
    @discardableResult
    func consumePremiumTrial() -> Bool {
        guard !premiumTrialUsed else { return false }
        premiumTrialUsed = true
        UserDefaults.standard.set(true, forKey: Self.premiumTrialKey)
        return true
    }

    func add(_ method: TipMethod) {
        methods.append(method)
        persist()
    }

    func remove(_ method: TipMethod) {
        methods.removeAll { $0.id == method.id }
        persist()
    }

    func update(_ method: TipMethod) {
        if let i = methods.firstIndex(where: { $0.id == method.id }) {
            methods[i] = method
            persist()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(methods) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TipMethod].self, from: data) else {
            return
        }
        methods = decoded
    }
}
