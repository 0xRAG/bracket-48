import Foundation
import WorldCupBracketCore

struct DraftStateStore {
    private let userDefaults: UserDefaults
    private let key = "worldCupBracket.draftState.v1"
    private let legacyKey = "worldCupBracket.prototypeState.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> LocalDraftState? {
        guard let data = userDefaults.data(forKey: key) ?? userDefaults.data(forKey: legacyKey) else {
            return nil
        }

        return try? JSONDecoder().decode(LocalDraftState.self, from: data)
    }

    func save(_ state: LocalDraftState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }

    func reset() {
        userDefaults.removeObject(forKey: key)
        userDefaults.removeObject(forKey: legacyKey)
    }
}
