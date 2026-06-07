public struct ScoringRuleSet: Equatable, Sendable {
    public let correctGroupWinner: Int
    public let correctGroupRunnerUp: Int
    public let correctGroupThirdPlace: Int
    public let correctThirdPlaceAdvancement: Int
    public let perfectGroupTopThreeBonus: Int
    public let knockoutRoundPoints: [KnockoutRound: Int]

    public init(
        correctGroupWinner: Int,
        correctGroupRunnerUp: Int,
        correctGroupThirdPlace: Int,
        correctThirdPlaceAdvancement: Int,
        perfectGroupTopThreeBonus: Int,
        knockoutRoundPoints: [KnockoutRound: Int]
    ) {
        self.correctGroupWinner = correctGroupWinner
        self.correctGroupRunnerUp = correctGroupRunnerUp
        self.correctGroupThirdPlace = correctGroupThirdPlace
        self.correctThirdPlaceAdvancement = correctThirdPlaceAdvancement
        self.perfectGroupTopThreeBonus = perfectGroupTopThreeBonus
        self.knockoutRoundPoints = knockoutRoundPoints
    }

    public static let worldCupDefault = ScoringRuleSet(
        correctGroupWinner: 4,
        correctGroupRunnerUp: 3,
        correctGroupThirdPlace: 2,
        correctThirdPlaceAdvancement: 2,
        perfectGroupTopThreeBonus: 3,
        knockoutRoundPoints: [
            .roundOf32: 4,
            .roundOf16: 6,
            .quarterfinal: 8,
            .semifinal: 12,
            .final: 20
        ]
    )
}

public enum ScoreSourceType: String, Codable, Sendable {
    case groupStagePrediction
    case knockoutPick
}

public struct ScoreEvent: Equatable, Sendable {
    public let id: String
    public let entryID: TournamentEntryID
    public let sourceType: ScoreSourceType
    public let sourceID: String
    public let points: Int
    public let reason: String

    public init(
        id: String,
        entryID: TournamentEntryID,
        sourceType: ScoreSourceType,
        sourceID: String,
        points: Int,
        reason: String
    ) {
        self.id = id
        self.entryID = entryID
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.points = points
        self.reason = reason
    }
}

public struct ScoreBreakdown: Equatable, Sendable {
    public let entryID: TournamentEntryID
    public let groupStagePoints: Int
    public let knockoutPoints: Int
    public let events: [ScoreEvent]

    public var totalPoints: Int {
        groupStagePoints + knockoutPoints
    }

    public init(
        entryID: TournamentEntryID,
        groupStagePoints: Int,
        knockoutPoints: Int,
        events: [ScoreEvent]
    ) {
        self.entryID = entryID
        self.groupStagePoints = groupStagePoints
        self.knockoutPoints = knockoutPoints
        self.events = events
    }
}

public struct MaximumScore: Equatable, Sendable {
    public let groupStagePoints: Int
    public let knockoutPoints: Int

    public var totalPoints: Int {
        groupStagePoints + knockoutPoints
    }
}

public struct ScoringEngine: Sendable {
    public let rules: ScoringRuleSet

    public init(rules: ScoringRuleSet = .worldCupDefault) {
        self.rules = rules
    }

    public func score(
        entryID: TournamentEntryID,
        predictions: BracketPredictions,
        results: TournamentResults
    ) -> ScoreBreakdown {
        let groupStandingsByID = Dictionary(
            uniqueKeysWithValues: results.groupStandings.map { ($0.groupID, $0) }
        )
        let knockoutResultsByMatchID = Dictionary(
            uniqueKeysWithValues: results.knockoutResults.map { ($0.matchID, $0) }
        )

        var groupStageEvents: [ScoreEvent] = []
        for prediction in predictions.groupStagePredictions.sorted(by: { $0.groupID.rawValue < $1.groupID.rawValue }) {
            guard let standing = groupStandingsByID[prediction.groupID] else {
                continue
            }

            groupStageEvents.append(
                contentsOf: scoreGroupStagePrediction(
                    entryID: entryID,
                    prediction: prediction,
                    standing: standing,
                    advancingThirdPlaceTeamIDs: results.advancingThirdPlaceTeamIDs
                )
            )
        }

        var knockoutEvents: [ScoreEvent] = []
        for pick in predictions.knockoutPicks.sorted(by: knockoutPickSort) {
            guard let result = knockoutResultsByMatchID[pick.matchID],
                  result.winnerTeamID == pick.pickedWinnerTeamID
            else {
                continue
            }

            let points = rules.knockoutRoundPoints[pick.round, default: 0]
            knockoutEvents.append(
                ScoreEvent(
                    id: "knockout:\(pick.matchID.rawValue):winner",
                    entryID: entryID,
                    sourceType: .knockoutPick,
                    sourceID: pick.matchID.rawValue,
                    points: points,
                    reason: "Correct \(pick.round.displayName) winner"
                )
            )
        }

        let events = groupStageEvents + knockoutEvents
        return ScoreBreakdown(
            entryID: entryID,
            groupStagePoints: groupStageEvents.reduce(0) { $0 + $1.points },
            knockoutPoints: knockoutEvents.reduce(0) { $0 + $1.points },
            events: events
        )
    }

    public func maximumAvailableScore(for predictions: BracketPredictions) -> MaximumScore {
        let groupPointsPerPrediction = rules.correctGroupWinner
            + rules.correctGroupRunnerUp
            + rules.correctGroupThirdPlace
            + rules.correctThirdPlaceAdvancement
            + rules.perfectGroupTopThreeBonus

        let groupStagePoints = predictions.groupStagePredictions.count * groupPointsPerPrediction
        let knockoutPoints = predictions.knockoutPicks.reduce(0) { total, pick in
            total + rules.knockoutRoundPoints[pick.round, default: 0]
        }

        return MaximumScore(groupStagePoints: groupStagePoints, knockoutPoints: knockoutPoints)
    }

    private func scoreGroupStagePrediction(
        entryID: TournamentEntryID,
        prediction: GroupStagePrediction,
        standing: FinalGroupStanding,
        advancingThirdPlaceTeamIDs: Set<TeamID>
    ) -> [ScoreEvent] {
        var events: [ScoreEvent] = []
        let predicted = prediction.orderedTeamIDs
        let actual = standing.orderedTeamIDs

        if predicted[safe: 0] == actual[safe: 0] {
            events.append(
                groupStageEvent(
                    entryID: entryID,
                    groupID: prediction.groupID,
                    ruleID: "winner",
                    points: rules.correctGroupWinner,
                    reason: "Correct group winner"
                )
            )
        }

        if predicted[safe: 1] == actual[safe: 1] {
            events.append(
                groupStageEvent(
                    entryID: entryID,
                    groupID: prediction.groupID,
                    ruleID: "runner-up",
                    points: rules.correctGroupRunnerUp,
                    reason: "Correct group runner-up"
                )
            )
        }

        if predicted[safe: 2] == actual[safe: 2] {
            events.append(
                groupStageEvent(
                    entryID: entryID,
                    groupID: prediction.groupID,
                    ruleID: "third-place",
                    points: rules.correctGroupThirdPlace,
                    reason: "Correct third-place team"
                )
            )
        }

        if let actualThirdPlace = actual[safe: 2],
           prediction.predictedThirdPlaceAdvances == advancingThirdPlaceTeamIDs.contains(actualThirdPlace)
        {
            events.append(
                groupStageEvent(
                    entryID: entryID,
                    groupID: prediction.groupID,
                    ruleID: "third-place-advancement",
                    points: rules.correctThirdPlaceAdvancement,
                    reason: "Correct third-place advancement result"
                )
            )
        }

        if Array(predicted.prefix(3)) == Array(actual.prefix(3)) {
            events.append(
                groupStageEvent(
                    entryID: entryID,
                    groupID: prediction.groupID,
                    ruleID: "perfect-top-three",
                    points: rules.perfectGroupTopThreeBonus,
                    reason: "Perfect group top 3"
                )
            )
        }

        return events.sorted { lhs, rhs in
            if lhs.sourceID == rhs.sourceID {
                return lhs.id < rhs.id
            }

            return lhs.sourceID < rhs.sourceID
        }
    }

    private func groupStageEvent(
        entryID: TournamentEntryID,
        groupID: GroupID,
        ruleID: String,
        points: Int,
        reason: String
    ) -> ScoreEvent {
        ScoreEvent(
            id: "group:\(groupID.rawValue):\(ruleID)",
            entryID: entryID,
            sourceType: .groupStagePrediction,
            sourceID: groupID.rawValue,
            points: points,
            reason: reason
        )
    }

    private func knockoutPickSort(_ lhs: KnockoutPick, _ rhs: KnockoutPick) -> Bool {
        if lhs.round.sortOrder == rhs.round.sortOrder {
            return lhs.matchID.rawValue < rhs.matchID.rawValue
        }

        return lhs.round.sortOrder < rhs.round.sortOrder
    }
}

private extension KnockoutRound {
    var sortOrder: Int {
        switch self {
        case .roundOf32:
            1
        case .roundOf16:
            2
        case .quarterfinal:
            3
        case .semifinal:
            4
        case .final:
            5
        }
    }

    var displayName: String {
        switch self {
        case .roundOf32:
            "Round of 32"
        case .roundOf16:
            "Round of 16"
        case .quarterfinal:
            "quarterfinal"
        case .semifinal:
            "semifinal"
        case .final:
            "final"
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
