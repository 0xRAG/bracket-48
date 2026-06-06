import Foundation
import Supabase
import WorldCupBracketCore

actor SupabasePoolService: PoolServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func listPools() async throws -> [BackendPoolSummary] {
        let userID = try authenticatedUserID()
        let memberships: [PoolMembershipRow] = try await client
            .from("pool_memberships")
            .select()
            .eq("user_id", value: userID.uuidString)
            .eq("status", value: "active")
            .execute()
            .value

        var summaries: [BackendPoolSummary] = []

        for membership in memberships {
            let row = try await pool(id: membership.poolID)
            summaries.append(BackendPoolSummary(row: row, role: membership.role.modelValue))
        }

        return summaries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createPool(_ request: CreatePoolRequest) async throws -> BackendPoolSummary {
        let userID = try authenticatedUserID()
        let newPool = NewPoolRow(
            ownerUserID: userID,
            name: request.name,
            inviteCode: Self.makeInviteCode(),
            type: DatabasePoolType(request.type)
        )

        let row: PoolRow = try await client
            .rpc("create_pool", params: CreatePoolParams(pool: newPool))
            .execute()
            .value

        return BackendPoolSummary(row: row, role: .owner)
    }

    func joinPool(inviteCode: String) async throws -> BackendPoolSummary {
        let poolID: UUID = try await client
            .rpc("join_pool_by_invite", params: JoinPoolParams(inviteCodeInput: inviteCode))
            .execute()
            .value

        let row = try await pool(id: poolID)
        return BackendPoolSummary(row: row, role: .member)
    }

    private func pool(id: UUID) async throws -> PoolRow {
        try await client
            .from("pools")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    private func authenticatedUserID() throws -> UUID {
        guard let userID = client.auth.currentUser?.id else {
            throw BackendServiceError.notAuthenticated
        }

        return userID
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0 ..< 8).map { _ in alphabet.randomElement() ?? "A" })
    }
}

private struct NewPoolRow: Encodable {
    let ownerUserID: UUID
    let name: String
    let inviteCode: String
    let type: DatabasePoolType

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
        case inviteCode = "invite_code"
        case type
    }
}

private struct JoinPoolParams: Encodable {
    let inviteCodeInput: String

    enum CodingKeys: String, CodingKey {
        case inviteCodeInput = "invite_code_input"
    }
}

private struct CreatePoolParams: Encodable {
    let nameInput: String
    let typeInput: DatabasePoolType
    let inviteCodeInput: String

    init(pool: NewPoolRow) {
        nameInput = pool.name
        typeInput = pool.type
        inviteCodeInput = pool.inviteCode
    }

    enum CodingKeys: String, CodingKey {
        case nameInput = "name_input"
        case typeInput = "type_input"
        case inviteCodeInput = "invite_code_input"
    }
}
