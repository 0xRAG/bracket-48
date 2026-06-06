import Foundation
import Supabase
import WorldCupBracketCore

actor SupabaseBracketService: BracketServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func listBrackets() async throws -> [BackendBracketSummary] {
        let userID = try authenticatedUserID()
        let rows: [BracketRow] = try await client
            .from("brackets")
            .select("id,user_id,phase,display_name,group_stage_bracket_id,picks,submitted_at")
            .eq("user_id", value: userID.uuidString)
            .order("submitted_at", ascending: false)
            .execute()
            .value

        var summaries: [BackendBracketSummary] = []

        for row in rows {
            summaries.append(
                BackendBracketSummary(
                    id: row.id,
                    phase: row.phase.modelValue,
                    displayName: row.displayName,
                    submittedAt: row.submittedAt,
                    groupStageBracketID: row.groupStageBracketID,
                    linkedPoolIDs: try await linkedPoolIDs(for: row.id),
                    groupStagePredictions: row.picks?.predictions?.map {
                        BackendGroupStagePrediction(
                            groupID: $0.groupID,
                            orderedTeamIDs: $0.orderedTeamIDs,
                            predictedThirdPlaceAdvances: $0.predictedThirdPlaceAdvances
                        )
                    } ?? [],
                    knockoutPicks: row.picks?.picks?.map {
                        BackendKnockoutPick(
                            matchID: $0.matchID,
                            round: $0.round,
                            pickedWinnerTeamID: $0.pickedWinnerTeamID
                        )
                    } ?? []
                )
            )
        }

        return summaries
    }

    func submitGroupStageBracket(_ submission: GroupStageBracketSubmission) async throws -> BackendBracketSummary {
        let payload = GroupStageBracketPayload(
            predictions: submission.predictions.map {
                GroupStagePredictionPayload(
                    groupID: $0.groupID,
                    orderedTeamIDs: $0.orderedTeams.map(\.id),
                    predictedThirdPlaceAdvances: $0.predictedThirdPlaceAdvances
                )
            }
        )

        return try await submitBracket(
            phase: .groupStage,
            displayName: submission.displayName,
            picks: payload
        )
    }

    func updateGroupStageBracket(id: UUID, _ submission: GroupStageBracketSubmission) async throws -> BackendBracketSummary {
        let userID = try authenticatedUserID()
        let payload = GroupStageBracketPayload(
            predictions: submission.predictions.map {
                GroupStagePredictionPayload(
                    groupID: $0.groupID,
                    orderedTeamIDs: $0.orderedTeams.map(\.id),
                    predictedThirdPlaceAdvances: $0.predictedThirdPlaceAdvances
                )
            }
        )
        let row = UpdateBracketRow(displayName: submission.displayName, picks: payload)

        let saved: BracketRow = try await client
            .from("brackets")
            .update(row)
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userID.uuidString)
            .eq("phase", value: DatabaseBracketPhase.groupStage.rawValue)
            .select("id,user_id,phase,display_name,group_stage_bracket_id,picks,submitted_at")
            .single()
            .execute()
            .value

        return BackendBracketSummary(
            id: saved.id,
            phase: saved.phase.modelValue,
            displayName: saved.displayName,
            submittedAt: saved.submittedAt,
            groupStageBracketID: saved.groupStageBracketID,
            linkedPoolIDs: try await linkedPoolIDs(for: saved.id),
            groupStagePredictions: saved.picks?.predictions?.map {
                BackendGroupStagePrediction(
                    groupID: $0.groupID,
                    orderedTeamIDs: $0.orderedTeamIDs,
                    predictedThirdPlaceAdvances: $0.predictedThirdPlaceAdvances
                )
            } ?? [],
            knockoutPicks: []
        )
    }

    func submitKnockoutBracket(_ submission: KnockoutBracketSubmission) async throws -> BackendBracketSummary {
        let payload = KnockoutBracketPayload(
            picks: submission.picks.map {
                KnockoutPickPayload(
                    matchID: $0.matchID,
                    round: $0.round.rawValue,
                    pickedWinnerTeamID: $0.pickedWinner.id
                )
            }
        )

        return try await submitBracket(
            phase: .knockout,
            displayName: submission.displayName,
            groupStageBracketID: submission.groupStageBracketID,
            picks: payload
        )
    }

    func enterBracket(bracketID: UUID, poolID: UUID, phase: BracketPhase) async throws {
        let userID = try authenticatedUserID()
        let row = NewPoolEntryRow(
            poolID: poolID,
            bracketID: bracketID,
            userID: userID,
            phase: DatabaseBracketPhase(phase)
        )

        try await client
            .from("pool_entries")
            .insert(row)
            .execute()
    }

    func deleteBracket(id: UUID) async throws {
        let userID = try authenticatedUserID()

        try await client
            .from("brackets")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }

    private func submitBracket(
        phase: BracketPhase,
        displayName: String,
        groupStageBracketID: UUID? = nil,
        picks: some Encodable
    ) async throws -> BackendBracketSummary {
        let userID = try authenticatedUserID()
        let row = NewBracketRow(
            userID: userID,
            phase: DatabaseBracketPhase(phase),
            displayName: displayName,
            groupStageBracketID: groupStageBracketID,
            picks: picks
        )

        let saved: BracketRow = try await client
            .from("brackets")
            .insert(row)
            .select("id,user_id,phase,display_name,group_stage_bracket_id,picks,submitted_at")
            .single()
            .execute()
            .value

        return BackendBracketSummary(
            id: saved.id,
            phase: saved.phase.modelValue,
            displayName: saved.displayName,
            submittedAt: saved.submittedAt,
            groupStageBracketID: saved.groupStageBracketID,
            linkedPoolIDs: [],
            groupStagePredictions: saved.picks?.predictions?.map {
                BackendGroupStagePrediction(
                    groupID: $0.groupID,
                    orderedTeamIDs: $0.orderedTeamIDs,
                    predictedThirdPlaceAdvances: $0.predictedThirdPlaceAdvances
                )
            } ?? [],
            knockoutPicks: saved.picks?.picks?.map {
                BackendKnockoutPick(
                    matchID: $0.matchID,
                    round: $0.round,
                    pickedWinnerTeamID: $0.pickedWinnerTeamID
                )
            } ?? []
        )
    }

    private func linkedPoolIDs(for bracketID: UUID) async throws -> Set<UUID> {
        let rows: [PoolEntryRow] = try await client
            .from("pool_entries")
            .select("id,pool_id,bracket_id,user_id,phase")
            .eq("bracket_id", value: bracketID.uuidString)
            .execute()
            .value

        return Set(rows.map(\.poolID))
    }

    private func authenticatedUserID() throws -> UUID {
        guard let userID = client.auth.currentUser?.id else {
            throw BackendServiceError.notAuthenticated
        }

        return userID
    }
}

private struct NewBracketRow<Picks: Encodable>: Encodable {
    let userID: UUID
    let phase: DatabaseBracketPhase
    let displayName: String
    let groupStageBracketID: UUID?
    let picks: Picks

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case phase
        case displayName = "display_name"
        case groupStageBracketID = "group_stage_bracket_id"
        case picks
    }
}

private struct UpdateBracketRow<Picks: Encodable>: Encodable {
    let displayName: String
    let picks: Picks

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case picks
    }
}

private struct NewPoolEntryRow: Encodable {
    let poolID: UUID
    let bracketID: UUID
    let userID: UUID
    let phase: DatabaseBracketPhase

    enum CodingKeys: String, CodingKey {
        case poolID = "pool_id"
        case bracketID = "bracket_id"
        case userID = "user_id"
        case phase
    }
}

private struct GroupStageBracketPayload: Encodable {
    let predictions: [GroupStagePredictionPayload]
}

private struct GroupStagePredictionPayload: Encodable {
    let groupID: String
    let orderedTeamIDs: [String]
    let predictedThirdPlaceAdvances: Bool

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case orderedTeamIDs = "ordered_team_ids"
        case predictedThirdPlaceAdvances = "predicted_third_place_advances"
    }
}

private struct KnockoutBracketPayload: Encodable {
    let picks: [KnockoutPickPayload]
}

private struct KnockoutPickPayload: Encodable {
    let matchID: String
    let round: String
    let pickedWinnerTeamID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case round
        case pickedWinnerTeamID = "picked_winner_team_id"
    }
}
