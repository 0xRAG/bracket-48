import Foundation
import Supabase
import Bracket48Core

actor SupabaseResultsService: ResultsServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func listTournamentMatches() async throws -> [BackendTournamentMatch] {
        let rows: [TournamentMatchRow] = try await client
            .from("tournament_matches")
            .select(
                """
                id,provider_fixture_id,phase,knockout_round,group_name,fixture_name,starts_at,\
                home_team_id,away_team_id,home_slot_label,away_slot_label,status,home_score,away_score,\
                penalty_home_score,penalty_away_score,winner_team_id
                """
            )
            .order("starts_at", ascending: true)
            .execute()
            .value

        return rows.map(\.modelValue)
    }

    func listGroupStandings() async throws -> [BackendGroupStanding] {
        let rows: [GroupStandingRow] = try await client
            .from("group_standings")
            .select(
                """
                group_name,team_id,team_name,position,points,played,won,drawn,lost,\
                goals_for,goals_against,goal_difference
                """
            )
            .order("group_name", ascending: true)
            .order("position", ascending: true)
            .execute()
            .value

        return rows.map(\.modelValue)
    }

    func listLeaderboard(poolID: UUID) async throws -> [BackendLeaderboardEntry] {
        let rows: [LeaderboardRow] = try await client
            .from("bracket_scores")
            .select(
                """
                id,pool_id,bracket_id,user_id,phase,group_stage_points,knockout_points,total_points,\
                max_points,calculated_at,app_users!inner(display_name)
                """
            )
            .eq("pool_id", value: poolID.uuidString)
            .order("total_points", ascending: false)
            .order("calculated_at", ascending: true)
            .order("user_id", ascending: true)
            .execute()
            .value

        return rows.map(\.modelValue)
    }
}

private struct TournamentMatchRow: Codable, Sendable {
    let id: String
    let providerFixtureID: Int
    let phase: DatabaseBracketPhase
    let knockoutRound: DatabaseKnockoutRound?
    let groupName: String?
    let fixtureName: String
    let startsAt: Date?
    let homeTeamID: String?
    let awayTeamID: String?
    let homeSlotLabel: String?
    let awaySlotLabel: String?
    let status: BackendMatchStatus
    let homeScore: Int?
    let awayScore: Int?
    let penaltyHomeScore: Int?
    let penaltyAwayScore: Int?
    let winnerTeamID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case providerFixtureID = "provider_fixture_id"
        case phase
        case knockoutRound = "knockout_round"
        case groupName = "group_name"
        case fixtureName = "fixture_name"
        case startsAt = "starts_at"
        case homeTeamID = "home_team_id"
        case awayTeamID = "away_team_id"
        case homeSlotLabel = "home_slot_label"
        case awaySlotLabel = "away_slot_label"
        case status
        case homeScore = "home_score"
        case awayScore = "away_score"
        case penaltyHomeScore = "penalty_home_score"
        case penaltyAwayScore = "penalty_away_score"
        case winnerTeamID = "winner_team_id"
    }

    var modelValue: BackendTournamentMatch {
        BackendTournamentMatch(
            id: id,
            providerFixtureID: providerFixtureID,
            phase: phase.modelValue,
            knockoutRound: knockoutRound?.modelValue,
            groupName: groupName,
            fixtureName: fixtureName,
            startsAt: startsAt,
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            homeSlotLabel: homeSlotLabel,
            awaySlotLabel: awaySlotLabel,
            status: status,
            homeScore: homeScore,
            awayScore: awayScore,
            penaltyHomeScore: penaltyHomeScore,
            penaltyAwayScore: penaltyAwayScore,
            winnerTeamID: winnerTeamID
        )
    }
}

private struct GroupStandingRow: Codable, Sendable {
    let groupName: String
    let teamID: String?
    let teamName: String
    let position: Int
    let points: Int
    let played: Int?
    let won: Int?
    let drawn: Int?
    let lost: Int?
    let goalsFor: Int?
    let goalsAgainst: Int?
    let goalDifference: Int?

    enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case teamID = "team_id"
        case teamName = "team_name"
        case position
        case points
        case played
        case won
        case drawn
        case lost
        case goalsFor = "goals_for"
        case goalsAgainst = "goals_against"
        case goalDifference = "goal_difference"
    }

    var modelValue: BackendGroupStanding {
        BackendGroupStanding(
            groupName: groupName,
            teamID: teamID,
            teamName: teamName,
            position: position,
            points: points,
            played: played,
            won: won,
            drawn: drawn,
            lost: lost,
            goalsFor: goalsFor,
            goalsAgainst: goalsAgainst,
            goalDifference: goalDifference
        )
    }
}

private struct LeaderboardRow: Codable, Sendable {
    let id: UUID
    let poolID: UUID
    let bracketID: UUID
    let userID: UUID
    let phase: DatabaseBracketPhase
    let groupStagePoints: Int
    let knockoutPoints: Int
    let totalPoints: Int
    let maxPoints: Int
    let calculatedAt: Date
    let appUsers: LeaderboardUserRow

    enum CodingKeys: String, CodingKey {
        case id
        case poolID = "pool_id"
        case bracketID = "bracket_id"
        case userID = "user_id"
        case phase
        case groupStagePoints = "group_stage_points"
        case knockoutPoints = "knockout_points"
        case totalPoints = "total_points"
        case maxPoints = "max_points"
        case calculatedAt = "calculated_at"
        case appUsers = "app_users"
    }

    var modelValue: BackendLeaderboardEntry {
        BackendLeaderboardEntry(
            id: id,
            poolID: poolID,
            bracketID: bracketID,
            userID: userID,
            displayName: appUsers.displayName,
            phase: phase.modelValue,
            groupStagePoints: groupStagePoints,
            knockoutPoints: knockoutPoints,
            totalPoints: totalPoints,
            maxPoints: maxPoints,
            calculatedAt: calculatedAt
        )
    }
}

private struct LeaderboardUserRow: Codable, Sendable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private enum DatabaseKnockoutRound: String, Codable, Sendable {
    case roundOf32 = "round_of_32"
    case roundOf16 = "round_of_16"
    case quarterfinal
    case semifinal
    case final
    case thirdPlace = "third_place"

    var modelValue: KnockoutRound? {
        switch self {
        case .roundOf32:
            .roundOf32
        case .roundOf16:
            .roundOf16
        case .quarterfinal:
            .quarterfinal
        case .semifinal:
            .semifinal
        case .final:
            .final
        case .thirdPlace:
            nil
        }
    }
}
