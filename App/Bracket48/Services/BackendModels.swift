import Foundation
import Bracket48Core

struct BackendUserProfile: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let primaryColorID: String
}

struct BackendPoolSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let type: PoolType
    let status: PoolStatus
    let role: PoolMembershipRole
    let entryPhases: Set<BracketPhase>

    var inviteURL: URL? {
        URL(string: "https://bracket48.app/join/?code=\(inviteCode)")
    }
}

struct BackendInvitePreview: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let memberCount: Int
}

struct BackendBracketSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let phase: BracketPhase
    let displayName: String
    let submittedAt: Date
    let groupStageBracketID: UUID?
    let linkedPoolIDs: Set<UUID>
    let groupStagePredictions: [BackendGroupStagePrediction]
    let knockoutPicks: [BackendKnockoutPick]
}

struct BackendGroupStagePrediction: Equatable, Sendable {
    let groupID: String
    let orderedTeamIDs: [String]
    let predictedThirdPlaceAdvances: Bool
}

struct BackendKnockoutPick: Equatable, Sendable {
    let matchID: String
    let round: KnockoutRound
    let pickedWinnerTeamID: String
}

struct GroupStageBracketSubmission: Equatable, Sendable {
    let displayName: String
    let predictions: [GroupStagePredictionDraft]
}

struct KnockoutBracketSubmission: Equatable, Sendable {
    let displayName: String
    let groupStageBracketID: UUID?
    let picks: [KnockoutPickDraft]
}

struct CreatePoolRequest: Equatable, Sendable {
    let name: String
    let type: PoolType
}

enum BackendMatchStatus: String, Codable, Equatable, Sendable {
    case scheduled
    case live
    case final
    case postponed
    case canceled
    case unknown
}

struct BackendTournamentMatch: Identifiable, Equatable, Sendable {
    let id: String
    let providerFixtureID: Int
    let phase: BracketPhase
    let knockoutRound: KnockoutRound?
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
}

struct BackendGroupStanding: Equatable, Sendable {
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
}

struct BackendLeaderboardEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let poolID: UUID
    let bracketID: UUID
    let userID: UUID
    let displayName: String
    let phase: BracketPhase
    let groupStagePoints: Int
    let knockoutPoints: Int
    let totalPoints: Int
    let maxPoints: Int
    let possiblePointsRemaining: Int
    let calculatedAt: Date
}

struct BackendGroupParticipant: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let role: PoolMembershipRole
    let joinedAt: Date
}

struct BackendGroupBracketEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let poolID: UUID
    let userID: UUID
    let participantDisplayName: String
    let bracket: BackendBracketSummary
    let submittedAt: Date
}

enum BackendServiceError: Error, Equatable, Sendable {
    case notConfigured
    case notAuthenticated
    case notFound
    case validationFailed(String)
    case transportFailed(String)
}

extension BackendServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Backend is not configured."
        case .notAuthenticated:
            "No authenticated user session was found."
        case .notFound:
            "The requested backend record was not found."
        case let .validationFailed(message):
            message
        case let .transportFailed(message):
            message
        }
    }
}
