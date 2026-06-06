import Foundation
import WorldCupBracketCore

struct BackendUserProfile: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
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
        URL(string: "https://worldcupbracket.app/join/\(inviteCode)")
    }
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
