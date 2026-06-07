import Foundation
import Supabase
import Bracket48Core

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
            let entryPhases = try await entryPhases(poolID: row.id, userID: userID)
            summaries.append(BackendPoolSummary(row: row, role: membership.role.modelValue, entryPhases: entryPhases))
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

    func listParticipants(poolID: UUID) async throws -> [BackendGroupParticipant] {
        let rows: [PoolParticipantRow] = try await client
            .from("pool_memberships")
            .select("pool_id,user_id,role,joined_at,app_users!inner(display_name)")
            .eq("pool_id", value: poolID.uuidString)
            .eq("status", value: "active")
            .order("joined_at", ascending: true)
            .execute()
            .value

        return rows.map(\.modelValue)
    }

    func listBracketEntries(poolID: UUID) async throws -> [BackendGroupBracketEntry] {
        let rows: [GroupBracketEntryRow] = try await client
            .from("pool_entries")
            .select(
                """
                id,pool_id,bracket_id,user_id,phase,submitted_at,\
                app_users!inner(display_name),\
                brackets!inner(id,user_id,phase,display_name,group_stage_bracket_id,picks,submitted_at)
                """
            )
            .eq("pool_id", value: poolID.uuidString)
            .order("submitted_at", ascending: true)
            .execute()
            .value

        return rows.map(\.modelValue)
    }

    func previewInvite(inviteCode: String) async throws -> BackendInvitePreview? {
        let rows: [InvitePreviewRow] = try await client
            .rpc("preview_pool_invite", params: JoinPoolParams(inviteCodeInput: inviteCode))
            .execute()
            .value

        return rows.first?.modelValue
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

    private func entryPhases(poolID: UUID, userID: UUID) async throws -> Set<BracketPhase> {
        let rows: [PoolEntryRow] = try await client
            .from("pool_entries")
            .select("id,pool_id,bracket_id,user_id,phase")
            .eq("pool_id", value: poolID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        return Set(rows.map { $0.phase.modelValue })
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

private struct PoolParticipantRow: Codable, Sendable {
    let userID: UUID
    let role: DatabasePoolMembershipRole
    let joinedAt: Date
    let appUsers: AppUserDisplayNameRow

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
        case appUsers = "app_users"
    }

    var modelValue: BackendGroupParticipant {
        BackendGroupParticipant(
            id: userID,
            displayName: appUsers.displayName,
            role: role.modelValue,
            joinedAt: joinedAt
        )
    }
}

private struct GroupBracketEntryRow: Codable, Sendable {
    let id: UUID
    let poolID: UUID
    let userID: UUID
    let phase: DatabaseBracketPhase
    let submittedAt: Date
    let appUsers: AppUserDisplayNameRow
    let brackets: BracketRow

    enum CodingKeys: String, CodingKey {
        case id
        case poolID = "pool_id"
        case userID = "user_id"
        case phase
        case submittedAt = "submitted_at"
        case appUsers = "app_users"
        case brackets
    }

    var modelValue: BackendGroupBracketEntry {
        BackendGroupBracketEntry(
            id: id,
            poolID: poolID,
            userID: userID,
            participantDisplayName: appUsers.displayName,
            bracket: BackendBracketSummary(row: brackets, linkedPoolIDs: [poolID]),
            submittedAt: submittedAt
        )
    }
}

private struct AppUserDisplayNameRow: Codable, Sendable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private struct InvitePreviewRow: Codable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let memberCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case memberCount = "member_count"
    }

    var modelValue: BackendInvitePreview {
        BackendInvitePreview(
            id: id,
            name: name,
            inviteCode: inviteCode,
            memberCount: memberCount
        )
    }
}
