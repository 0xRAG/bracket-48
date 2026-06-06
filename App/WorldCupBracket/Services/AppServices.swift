import Foundation
import WorldCupBracketCore

protocol AuthServicing: Sendable {
    func currentUser() async throws -> BackendUserProfile?
    func signInWithApple(idToken: String, nonce: String, displayName: String?) async throws -> BackendUserProfile
    func updateDisplayName(_ displayName: String) async throws -> BackendUserProfile
    func signOut() async throws
    func deleteAccount() async throws
}

protocol PoolServicing: Sendable {
    func listPools() async throws -> [BackendPoolSummary]
    func createPool(_ request: CreatePoolRequest) async throws -> BackendPoolSummary
    func joinPool(inviteCode: String) async throws -> BackendPoolSummary
}

protocol BracketServicing: Sendable {
    func listBrackets() async throws -> [BackendBracketSummary]
    func submitGroupStageBracket(_ submission: GroupStageBracketSubmission) async throws -> BackendBracketSummary
    func updateGroupStageBracket(id: UUID, _ submission: GroupStageBracketSubmission) async throws -> BackendBracketSummary
    func submitKnockoutBracket(_ submission: KnockoutBracketSubmission) async throws -> BackendBracketSummary
    func deleteBracket(id: UUID) async throws
    func enterBracket(bracketID: UUID, poolID: UUID, phase: BracketPhase) async throws
}

struct AppServices: Sendable {
    let auth: any AuthServicing
    let pools: any PoolServicing
    let brackets: any BracketServicing

    static let unconfigured = AppServices(
        auth: UnconfiguredAuthService(),
        pools: UnconfiguredPoolService(),
        brackets: UnconfiguredBracketService()
    )

    static func live(configuration: AppConfiguration = .main) throws -> AppServices {
        let client = try SupabaseClientFactory.makeClient(configuration: configuration)

        return AppServices(
            auth: SupabaseAuthService(client: client),
            pools: SupabasePoolService(client: client),
            brackets: SupabaseBracketService(client: client)
        )
    }
}

private struct UnconfiguredAuthService: AuthServicing {
    func currentUser() async throws -> BackendUserProfile? {
        nil
    }

    func signInWithApple(idToken: String, nonce: String, displayName: String?) async throws -> BackendUserProfile {
        throw BackendServiceError.notConfigured
    }

    func updateDisplayName(_ displayName: String) async throws -> BackendUserProfile {
        throw BackendServiceError.notConfigured
    }

    func signOut() async throws {}

    func deleteAccount() async throws {
        throw BackendServiceError.notConfigured
    }
}

private struct UnconfiguredPoolService: PoolServicing {
    func listPools() async throws -> [BackendPoolSummary] {
        []
    }

    func createPool(_ request: CreatePoolRequest) async throws -> BackendPoolSummary {
        throw BackendServiceError.notConfigured
    }

    func joinPool(inviteCode: String) async throws -> BackendPoolSummary {
        throw BackendServiceError.notConfigured
    }
}

private struct UnconfiguredBracketService: BracketServicing {
    func listBrackets() async throws -> [BackendBracketSummary] {
        []
    }

    func submitGroupStageBracket(_ submission: GroupStageBracketSubmission) async throws -> BackendBracketSummary {
        throw BackendServiceError.notConfigured
    }

    func updateGroupStageBracket(id: UUID, _ submission: GroupStageBracketSubmission) async throws -> BackendBracketSummary {
        throw BackendServiceError.notConfigured
    }

    func submitKnockoutBracket(_ submission: KnockoutBracketSubmission) async throws -> BackendBracketSummary {
        throw BackendServiceError.notConfigured
    }

    func deleteBracket(id: UUID) async throws {
        throw BackendServiceError.notConfigured
    }

    func enterBracket(bracketID: UUID, poolID: UUID, phase: BracketPhase) async throws {}
}
