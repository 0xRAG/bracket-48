import Foundation
@preconcurrency import Supabase

enum SupabaseClientFactory {
    static func makeClient(configuration: AppConfiguration = .main) throws -> SupabaseClient {
        guard
            let supabaseURL = configuration.supabaseURL,
            let supabaseAnonKey = configuration.supabaseAnonKey
        else {
            throw BackendServiceError.notConfigured
        }

        return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }
}
