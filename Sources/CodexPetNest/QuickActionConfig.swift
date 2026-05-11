import Foundation

enum QuickActionKind: String, Codable, CaseIterable {
    case app
    case shortcut
    case terminal
}

struct QuickActionConfig: Codable, Identifiable {
    var id: String = UUID().uuidString
    let nestId: String
    var name: String
    var icon: String
    var kind: QuickActionKind
    var target: String
    var requiresConfirmation: Bool = true
    var enabled: Bool = true
    var order: Int = 0
}

final class QuickActionConfigStore {
    static let shared = QuickActionConfigStore()

    private let fileURL: URL
    private var byNestId: [String: [QuickActionConfig]] = [:]

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let supportDir = home.appendingPathComponent("Library/Application Support/CodexPet Nest")
        fileURL = supportDir.appendingPathComponent("quick-actions.json")
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        load()
    }

    func actions(for nestId: String) -> [QuickActionConfig] {
        return (byNestId[nestId] ?? []).sorted { $0.order < $1.order }
    }

    func enabledActions(for nestId: String) -> [QuickActionConfig] {
        return actions(for: nestId).filter { $0.enabled }
    }

    func add(_ action: QuickActionConfig) {
        var list = byNestId[action.nestId] ?? []
        list.append(action)
        byNestId[action.nestId] = list
        save()
    }

    func update(_ action: QuickActionConfig) {
        var list = byNestId[action.nestId] ?? []
        if let idx = list.firstIndex(where: { $0.id == action.id }) {
            list[idx] = action
            byNestId[action.nestId] = list
            save()
        }
    }

    func delete(id: String, nestId: String) {
        var list = byNestId[nestId] ?? []
        list.removeAll { $0.id == id }
        byNestId[nestId] = list.isEmpty ? nil : list
        save()
    }

    func hasComponent(nestId: String) -> Bool {
        guard let nest = LocalNestManager.shared.installedNests.first(where: { $0.id == nestId }) else {
            return false
        }
        return nest.layout.components?.contains { $0.component == "official.actions.quickActions" } ?? false
    }

    func activeNestHasComponent() -> Bool {
        guard let nest = LocalNestManager.shared.getActiveNest() else { return false }
        return hasComponent(nestId: nest.id)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoded = try? JSONDecoder().decode([String: [QuickActionConfig]].self, from: data)
        byNestId = decoded ?? [:]
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(byNestId) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
