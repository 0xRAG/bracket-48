import Foundation
import WorldCupBracketCore

enum DatabasePoolType: String, Codable, Sendable {
    case fullTournament = "full_tournament"
    case knockoutOnly = "knockout_only"

    init(_ type: PoolType) {
        switch type {
        case .fullTournament:
            self = .fullTournament
        case .knockoutOnly:
            self = .knockoutOnly
        }
    }

    var modelValue: PoolType {
        switch self {
        case .fullTournament:
            .fullTournament
        case .knockoutOnly:
            .knockoutOnly
        }
    }
}

enum DatabasePoolStatus: String, Codable, Sendable {
    case open
    case locked
    case archived

    var modelValue: PoolStatus {
        switch self {
        case .open:
            .open
        case .locked:
            .locked
        case .archived:
            .archived
        }
    }
}

enum DatabasePoolMembershipRole: String, Codable, Sendable {
    case owner
    case member

    var modelValue: PoolMembershipRole {
        switch self {
        case .owner:
            .owner
        case .member:
            .member
        }
    }
}

enum DatabaseBracketPhase: String, Codable, Sendable {
    case groupStage = "group_stage"
    case knockout

    init(_ phase: BracketPhase) {
        switch phase {
        case .groupStage:
            self = .groupStage
        case .knockout:
            self = .knockout
        }
    }

    var modelValue: BracketPhase {
        switch self {
        case .groupStage:
            .groupStage
        case .knockout:
            .knockout
        }
    }
}

struct PoolRow: Codable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let name: String
    let inviteCode: String
    let type: DatabasePoolType
    let status: DatabasePoolStatus

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case inviteCode = "invite_code"
        case type
        case status
    }
}

struct PoolMembershipRow: Codable, Sendable {
    let poolID: UUID
    let userID: UUID
    let role: DatabasePoolMembershipRole

    enum CodingKeys: String, CodingKey {
        case poolID = "pool_id"
        case userID = "user_id"
        case role
    }
}

struct BracketRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let phase: DatabaseBracketPhase
    let displayName: String
    let groupStageBracketID: UUID?
    let picks: BracketPicksRow?
    let submittedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case phase
        case displayName = "display_name"
        case groupStageBracketID = "group_stage_bracket_id"
        case picks
        case submittedAt = "submitted_at"
    }
}

struct BracketPicksRow: Codable, Sendable {
    let predictions: [GroupStagePredictionRow]?
    let picks: [KnockoutPickRow]?
}

struct GroupStagePredictionRow: Codable, Sendable {
    let groupID: String
    let orderedTeamIDs: [String]
    let predictedThirdPlaceAdvances: Bool

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case orderedTeamIDs = "ordered_team_ids"
        case predictedThirdPlaceAdvances = "predicted_third_place_advances"
    }
}

struct KnockoutPickRow: Codable, Sendable {
    let matchID: String
    let round: KnockoutRound
    let pickedWinnerTeamID: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case round
        case pickedWinnerTeamID = "picked_winner_team_id"
    }
}

struct PoolEntryRow: Codable, Sendable {
    let id: UUID?
    let poolID: UUID
    let bracketID: UUID
    let userID: UUID
    let phase: DatabaseBracketPhase

    enum CodingKeys: String, CodingKey {
        case id
        case poolID = "pool_id"
        case bracketID = "bracket_id"
        case userID = "user_id"
        case phase
    }
}

extension BackendPoolSummary {
    init(row: PoolRow, role: PoolMembershipRole) {
        self.init(
            id: row.id,
            name: row.name,
            inviteCode: row.inviteCode,
            type: row.type.modelValue,
            status: row.status.modelValue,
            role: role,
            entryPhases: row.type.modelValue == .fullTournament ? [.groupStage, .knockout] : [.knockout]
        )
    }
}
