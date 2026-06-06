import Foundation

public struct Tournament: Equatable, Sendable {
    public let id: TournamentID
    public let name: String
    public let year: Int
    public let phase: TournamentPhase
    public let advancementRules: AdvancementRules
    public let teams: [Team]
    public let groups: [TournamentGroup]
    public let matches: [TournamentMatch]
    public let knockoutSlots: [KnockoutSlot]

    public init(
        id: TournamentID,
        name: String,
        year: Int,
        phase: TournamentPhase,
        advancementRules: AdvancementRules = .worldCup2026,
        teams: [Team],
        groups: [TournamentGroup],
        matches: [TournamentMatch],
        knockoutSlots: [KnockoutSlot]
    ) {
        self.id = id
        self.name = name
        self.year = year
        self.phase = phase
        self.advancementRules = advancementRules
        self.teams = teams
        self.groups = groups
        self.matches = matches
        self.knockoutSlots = knockoutSlots
    }

    public var isGroupStageComplete: Bool {
        !groupStageMatches.isEmpty && groupStageMatches.allSatisfy { $0.status == .final }
    }

    public var isKnockoutBracketOpen: Bool {
        isGroupStageComplete && phase == .knockoutOpen
    }

    public var groupStageMatches: [TournamentMatch] {
        matches.filter { $0.phase == .groupStage }
    }

    public var knockoutMatches: [TournamentMatch] {
        matches.filter { $0.phase == .knockout }
    }

    public func match(providerID: ProviderID, providerName: String? = nil) -> TournamentMatch? {
        matches.first { match in
            match.providerReferences.contains { reference in
                reference.providerID == providerID && (providerName == nil || reference.providerName == providerName)
            }
        }
    }

    public func validationIssues() -> [TournamentValidationIssue] {
        var issues: [TournamentValidationIssue] = []

        if groups.count != advancementRules.groupCount {
            issues.append(
                TournamentValidationIssue(
                    code: .invalidGroupCount,
                    message: "Expected \(advancementRules.groupCount) groups, found \(groups.count)."
                )
            )
        }

        let teamIDs = Set(teams.map(\.id))
        for group in groups {
            if group.teamIDs.count != advancementRules.teamsPerGroup {
                issues.append(
                    TournamentValidationIssue(
                        code: .invalidTeamsPerGroup,
                        message: "\(group.name) has \(group.teamIDs.count) teams."
                    )
                )
            }

            for teamID in group.teamIDs where !teamIDs.contains(teamID) {
                issues.append(
                    TournamentValidationIssue(
                        code: .unknownTeamReference,
                        message: "\(group.name) references unknown team \(teamID.rawValue)."
                    )
                )
            }
        }

        if advancementRules.automaticAdvancersPerGroup != 2 || advancementRules.bestThirdPlaceAdvancers != 8 {
            issues.append(
                TournamentValidationIssue(
                    code: .invalidAdvancementRules,
                    message: "2026 World Cup advancement must be top 2 plus 8 third-place teams."
                )
            )
        }

        let requiredRounds = Set(KnockoutRound.allCases)
        let representedRounds = Set(knockoutSlots.map(\.round))
        if !requiredRounds.isSubset(of: representedRounds) {
            issues.append(
                TournamentValidationIssue(
                    code: .missingKnockoutRounds,
                    message: "Knockout slots must represent Round of 32 through final."
                )
            )
        }

        return issues
    }
}

public enum TournamentPhase: String, Codable, Sendable {
    case preTournament
    case groupStageOpen
    case groupStageLocked
    case groupStageComplete
    case knockoutOpen
    case knockoutLocked
    case complete
}

public struct AdvancementRules: Equatable, Codable, Sendable {
    public let groupCount: Int
    public let teamsPerGroup: Int
    public let automaticAdvancersPerGroup: Int
    public let bestThirdPlaceAdvancers: Int

    public init(
        groupCount: Int,
        teamsPerGroup: Int,
        automaticAdvancersPerGroup: Int,
        bestThirdPlaceAdvancers: Int
    ) {
        self.groupCount = groupCount
        self.teamsPerGroup = teamsPerGroup
        self.automaticAdvancersPerGroup = automaticAdvancersPerGroup
        self.bestThirdPlaceAdvancers = bestThirdPlaceAdvancers
    }

    public static let worldCup2026 = AdvancementRules(
        groupCount: 12,
        teamsPerGroup: 4,
        automaticAdvancersPerGroup: 2,
        bestThirdPlaceAdvancers: 8
    )
}

public struct Team: Identifiable, Equatable, Codable, Sendable {
    public let id: TeamID
    public let name: String
    public let countryCode: String
    public let fifaCode: String
    public let seed: Int?
    public let providerReferences: [ProviderReference]

    public init(
        id: TeamID,
        name: String,
        countryCode: String,
        fifaCode: String,
        seed: Int? = nil,
        providerReferences: [ProviderReference] = []
    ) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.fifaCode = fifaCode
        self.seed = seed
        self.providerReferences = providerReferences
    }
}

public struct TournamentGroup: Identifiable, Equatable, Codable, Sendable {
    public let id: GroupID
    public let name: String
    public let teamIDs: [TeamID]

    public init(id: GroupID, name: String, teamIDs: [TeamID]) {
        self.id = id
        self.name = name
        self.teamIDs = teamIDs
    }
}

public struct TournamentMatch: Identifiable, Equatable, Sendable {
    public let id: MatchID
    public let phase: MatchPhase
    public let groupID: GroupID?
    public let knockoutRound: KnockoutRound?
    public let homeTeamID: TeamID?
    public let awayTeamID: TeamID?
    public let startsAt: Date?
    public let status: MatchStatus
    public let score: MatchScore?
    public let winnerTeamID: TeamID?
    public let providerReferences: [ProviderReference]
    public let adminCorrections: [AdminCorrection]

    public init(
        id: MatchID,
        phase: MatchPhase,
        groupID: GroupID? = nil,
        knockoutRound: KnockoutRound? = nil,
        homeTeamID: TeamID? = nil,
        awayTeamID: TeamID? = nil,
        startsAt: Date? = nil,
        status: MatchStatus,
        score: MatchScore? = nil,
        winnerTeamID: TeamID? = nil,
        providerReferences: [ProviderReference] = [],
        adminCorrections: [AdminCorrection] = []
    ) {
        self.id = id
        self.phase = phase
        self.groupID = groupID
        self.knockoutRound = knockoutRound
        self.homeTeamID = homeTeamID
        self.awayTeamID = awayTeamID
        self.startsAt = startsAt
        self.status = status
        self.score = score
        self.winnerTeamID = winnerTeamID
        self.providerReferences = providerReferences
        self.adminCorrections = adminCorrections
    }

    public func applyingProviderResult(
        status: MatchStatus,
        score: MatchScore?,
        winnerTeamID: TeamID?
    ) -> TournamentMatch {
        TournamentMatch(
            id: id,
            phase: phase,
            groupID: groupID,
            knockoutRound: knockoutRound,
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            startsAt: startsAt,
            status: status,
            score: score,
            winnerTeamID: winnerTeamID,
            providerReferences: providerReferences,
            adminCorrections: adminCorrections
        )
    }

    public func applyingAdminCorrection(_ correction: AdminCorrection) -> TournamentMatch {
        TournamentMatch(
            id: id,
            phase: phase,
            groupID: groupID,
            knockoutRound: knockoutRound,
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            startsAt: startsAt,
            status: correction.correctedStatus ?? status,
            score: correction.correctedScore ?? score,
            winnerTeamID: correction.correctedWinnerTeamID ?? winnerTeamID,
            providerReferences: providerReferences,
            adminCorrections: adminCorrections + [correction]
        )
    }
}

public enum MatchPhase: String, Codable, Sendable {
    case groupStage
    case knockout
}

public enum MatchStatus: String, Codable, Sendable {
    case scheduled
    case inProgress
    case final
    case postponed
    case canceled
}

public struct MatchScore: Equatable, Codable, Sendable {
    public let home: Int
    public let away: Int
    public let decidedByPenaltyShootout: Bool

    public init(home: Int, away: Int, decidedByPenaltyShootout: Bool = false) {
        self.home = home
        self.away = away
        self.decidedByPenaltyShootout = decidedByPenaltyShootout
    }
}

public struct ProviderReference: Equatable, Codable, Sendable {
    public let providerName: String
    public let providerID: ProviderID
    public let lastSyncedAt: Date?

    public init(providerName: String, providerID: ProviderID, lastSyncedAt: Date? = nil) {
        self.providerName = providerName
        self.providerID = providerID
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct AdminCorrection: Identifiable, Equatable, Sendable {
    public let id: String
    public let correctedByUserID: String
    public let correctedAt: Date
    public let reason: String
    public let correctedStatus: MatchStatus?
    public let correctedScore: MatchScore?
    public let correctedWinnerTeamID: TeamID?

    public init(
        id: String,
        correctedByUserID: String,
        correctedAt: Date,
        reason: String,
        correctedStatus: MatchStatus? = nil,
        correctedScore: MatchScore? = nil,
        correctedWinnerTeamID: TeamID? = nil
    ) {
        self.id = id
        self.correctedByUserID = correctedByUserID
        self.correctedAt = correctedAt
        self.reason = reason
        self.correctedStatus = correctedStatus
        self.correctedScore = correctedScore
        self.correctedWinnerTeamID = correctedWinnerTeamID
    }
}

public struct KnockoutSlot: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let round: KnockoutRound
    public let matchID: MatchID
    public let side: MatchSide
    public let source: KnockoutSlotSource
    public let resolvedTeamID: TeamID?

    public init(
        id: String,
        round: KnockoutRound,
        matchID: MatchID,
        side: MatchSide,
        source: KnockoutSlotSource,
        resolvedTeamID: TeamID? = nil
    ) {
        self.id = id
        self.round = round
        self.matchID = matchID
        self.side = side
        self.source = source
        self.resolvedTeamID = resolvedTeamID
    }
}

public enum MatchSide: String, Codable, Sendable {
    case home
    case away
}

public enum KnockoutSlotSource: Equatable, Codable, Sendable {
    case groupPlacement(groupID: GroupID, position: Int)
    case bestThirdPlace(rank: Int)
    case matchWinner(matchID: MatchID)
    case toBeDetermined
}

public struct TournamentValidationIssue: Equatable, Sendable {
    public let code: Code
    public let message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }

    public enum Code: String, Sendable {
        case invalidGroupCount
        case invalidTeamsPerGroup
        case unknownTeamReference
        case invalidAdvancementRules
        case missingKnockoutRounds
    }
}
