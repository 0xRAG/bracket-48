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

        if let profile = try await profile(userID: user.id) {
            return profile
        }

        let displayName = user.providerDisplayName ?? "Player"
        return try await saveProfile(AppUserRow(id: user.id, displayName: displayName, primaryColorID: "green"))
    }

    func signInWithApple(idToken: String, nonce: String, displayName: String?) async throws -> BackendUserProfile {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        let existingProfile = try await profile(userID: session.user.id)
        let appleDisplayName = displayName?.normalizedAppleDisplayName
        let providerDisplayName = session.user.providerDisplayName
        let discoveredDisplayName = appleDisplayName ?? providerDisplayName

        if let existingProfile {
            guard existingProfile.displayName == "Player", let discoveredDisplayName else {
                return existingProfile
            }

            return try await saveProfile(AppUserRow(
                id: session.user.id,
                displayName: discoveredDisplayName,
                primaryColorID: existingProfile.primaryColorID
            ))
        }

        guard let discoveredDisplayName else {
            let profile = AppUserRow(id: session.user.id, displayName: "Player", primaryColorID: "green")
            return try await saveProfile(profile)
        }

        let profile = AppUserRow(id: session.user.id, displayName: discoveredDisplayName, primaryColorID: "green")
        return try await saveProfile(profile)
    }

    func updateDisplayName(_ displayName: String) async throws -> BackendUserProfile {
        guard let user = client.auth.currentUser else {
            throw BackendServiceError.notAuthenticated
        }

        let existingProfile = try await profile(userID: user.id)
        let profile = AppUserRow(
            id: user.id,
            displayName: displayName.normalizedDisplayName,
            primaryColorID: existingProfile?.primaryColorID ?? "green"
        )

        return try await saveProfile(profile)
    }

    func updatePrimaryColor(_ primaryColorID: String) async throws -> BackendUserProfile {
        guard let user = client.auth.currentUser else {
            throw BackendServiceError.notAuthenticated
        }

        let existingProfile = try await profile(userID: user.id)
        let profile = AppUserRow(
            id: user.id,
            displayName: existingProfile?.displayName ?? user.providerDisplayName ?? "Player",
            primaryColorID: AppAccentColor.normalized(primaryColorID).rawValue
        )

        return try await saveProfile(profile)
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

    private func profile(userID: UUID) async throws -> BackendUserProfile? {
        let rows: [AppUserRow] = try await client
            .from("app_users")
            .select()
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.profile
    }

    @discardableResult
    private func saveProfile(_ profile: AppUserRow) async throws -> BackendUserProfile {
        let savedProfile: AppUserRow = try await client
            .from("app_users")
            .upsert(profile)
            .select()
            .single()
            .execute()
            .value

        return savedProfile.profile
    }
}

private struct AppUserRow: Codable, Sendable {
    let id: UUID
    let displayName: String
    let primaryColorID: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case primaryColorID = "primary_color"
    }

    var profile: BackendUserProfile {
        BackendUserProfile(id: id, displayName: displayName, primaryColorID: primaryColorID)
    }
}

private extension String {
    var normalizedDisplayName: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player" : trimmed
    }

    var normalizedAppleDisplayName: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension User {
    var providerDisplayName: String? {
        displayName(in: userMetadata)
            ?? identities?.compactMap { identity in
                identity.identityData.flatMap(displayName(in:))
            }.first
    }

    private func displayName(in metadata: [String: AnyJSON]) -> String? {
        let candidateKeys = ["given_name", "first_name", "name", "full_name"]

        for key in candidateKeys {
            guard let value = metadata[key]?.stringValue?.normalizedAppleDisplayName else {
                continue
            }

            if key == "name" || key == "full_name" {
                return value.components(separatedBy: .whitespacesAndNewlines).first { !$0.isEmpty } ?? value
            }

            return value
        }

        return nil
    }
}
