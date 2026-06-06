import Foundation
import Supabase

actor SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient

    init(configuration: AppConfiguration = .main) throws {
        guard
            let supabaseURL = configuration.supabaseURL,
            let supabaseAnonKey = configuration.supabaseAnonKey
        else {
            throw BackendServiceError.notConfigured
        }

        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUser() async throws -> BackendUserProfile? {
        guard let user = client.auth.currentUser else {
            return nil
        }

        let rows: [AppUserRow] = try await client
            .from("app_users")
            .select()
            .eq("id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            return row.profile
        }

        return BackendUserProfile(id: user.id, displayName: "Player")
    }

    func signInWithApple(idToken: String, nonce: String, displayName: String) async throws -> BackendUserProfile {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        let profile = AppUserRow(id: session.user.id, displayName: displayName.normalizedDisplayName)

        try await client
            .from("app_users")
            .upsert(profile)
            .execute()

        return profile.profile
    }

    func updateDisplayName(_ displayName: String) async throws -> BackendUserProfile {
        guard let user = client.auth.currentUser else {
            throw BackendServiceError.notAuthenticated
        }

        let profile = AppUserRow(id: user.id, displayName: displayName.normalizedDisplayName)

        try await client
            .from("app_users")
            .upsert(profile)
            .execute()

        return profile.profile
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(method: .delete)
        )
        try await client.auth.signOut()
    }
}

private struct AppUserRow: Codable, Sendable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }

    var profile: BackendUserProfile {
        BackendUserProfile(id: id, displayName: displayName)
    }
}

private extension String {
    var normalizedDisplayName: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player" : trimmed
    }
}
