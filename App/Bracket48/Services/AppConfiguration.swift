import Foundation

enum BackendMode: String, Sendable {
    case supabase
}

struct AppConfiguration: Equatable, Sendable {
    let backendMode: BackendMode
    let supabaseURL: URL?
    let supabaseAnonKey: String?

    static var main: AppConfiguration {
        AppConfiguration(bundle: .main)
    }

    init(bundle: Bundle) {
        backendMode = BackendMode(
            rawValue: bundle.trimmedInfoValue(forKey: "WCBBackendMode")
        ) ?? .supabase

        let rawSupabaseURL = bundle.trimmedInfoValue(forKey: "WCBSupabaseURL")
        supabaseURL = URL(string: rawSupabaseURL).filteringPlaceholderURL

        let rawAnonKey = bundle.trimmedInfoValue(forKey: "WCBSupabaseAnonKey")
        supabaseAnonKey = rawAnonKey.isPlaceholderValue ? nil : rawAnonKey
    }

    var isSupabaseConfigured: Bool {
        backendMode == .supabase && supabaseURL != nil && supabaseAnonKey != nil
    }
}

private extension Bundle {
    func trimmedInfoValue(forKey key: String) -> String {
        (object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private extension String {
    var isPlaceholderValue: Bool {
        isEmpty || contains("$(") || contains("YOUR-")
    }
}

private extension Optional where Wrapped == URL {
    var filteringPlaceholderURL: URL? {
        guard let self, !self.absoluteString.isPlaceholderValue else {
            return nil
        }
        return self
    }
}
