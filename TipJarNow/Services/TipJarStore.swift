import Foundation
import Observation

@MainActor
@Observable
final class TipJarStore {
    static let freeMethodLimit = 1

    var methods: [TipMethod] = []

    private let storageKey = "tipjarnow.methods.v1"

    init() {
        load()
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
