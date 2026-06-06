public struct GroupStagePrediction: Equatable, Sendable {
    public let groupID: GroupID
    public let orderedTeamIDs: [TeamID]
    public let predictedThirdPlaceAdvances: Bool

    public init(
        groupID: GroupID,
        orderedTeamIDs: [TeamID],
        predictedThirdPlaceAdvances: Bool
    ) {
        self.groupID = groupID
        self.orderedTeamIDs = orderedTeamIDs
        self.predictedThirdPlaceAdvances = predictedThirdPlaceAdvances
    }
}

public struct FinalGroupStanding: Equatable, Sendable {
    public let groupID: GroupID
    public let orderedTeamIDs: [TeamID]

    public init(groupID: GroupID, orderedTeamIDs: [TeamID]) {
        self.groupID = groupID
        self.orderedTeamIDs = orderedTeamIDs
    }
}

public enum KnockoutRound: String, CaseIterable, Codable, Sendable {
    case roundOf32
    case roundOf16
    case quarterfinal
    case semifinal
    case final
}

public struct KnockoutPick: Equatable, Sendable {
    public let matchID: MatchID
    public let round: KnockoutRound
    public let pickedWinnerTeamID: TeamID

    public init(
        matchID: MatchID,
        round: KnockoutRound,
        pickedWinnerTeamID: TeamID
    ) {
        self.matchID = matchID
        self.round = round
        self.pickedWinnerTeamID = pickedWinnerTeamID
    }
}

public struct MatchResult: Equatable, Sendable {
    public let matchID: MatchID
    public let round: KnockoutRound
    public let winnerTeamID: TeamID

    public init(
        matchID: MatchID,
        round: KnockoutRound,
        winnerTeamID: TeamID
    ) {
        self.matchID = matchID
        self.round = round
        self.winnerTeamID = winnerTeamID
    }
}

public struct TournamentResults: Equatable, Sendable {
    public let groupStandings: [FinalGroupStanding]
    public let advancingThirdPlaceTeamIDs: Set<TeamID>
    public let knockoutResults: [MatchResult]

    public init(
        groupStandings: [FinalGroupStanding],
        advancingThirdPlaceTeamIDs: Set<TeamID>,
        knockoutResults: [MatchResult]
    ) {
        self.groupStandings = groupStandings
        self.advancingThirdPlaceTeamIDs = advancingThirdPlaceTeamIDs
        self.knockoutResults = knockoutResults
    }
}

public struct BracketPredictions: Equatable, Sendable {
    public let groupStagePredictions: [GroupStagePrediction]
    public let knockoutPicks: [KnockoutPick]

    public init(
        groupStagePredictions: [GroupStagePrediction],
        knockoutPicks: [KnockoutPick]
    ) {
        self.groupStagePredictions = groupStagePredictions
        self.knockoutPicks = knockoutPicks
    }
}
