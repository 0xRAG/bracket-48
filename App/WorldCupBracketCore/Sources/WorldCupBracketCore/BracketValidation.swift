public struct GroupStagePickValidation: Equatable, Sendable {
    public let expectedGroupCount: Int
    public let expectedTeamsPerGroup: Int
    public let missingGroupIDs: [GroupID]
    public let incompleteGroupIDs: [GroupID]
    public let duplicateGroupIDs: [GroupID]

    public var isComplete: Bool {
        missingGroupIDs.isEmpty && incompleteGroupIDs.isEmpty && duplicateGroupIDs.isEmpty
    }

    public init(
        expectedGroupCount: Int,
        expectedTeamsPerGroup: Int,
        missingGroupIDs: [GroupID],
        incompleteGroupIDs: [GroupID],
        duplicateGroupIDs: [GroupID]
    ) {
        self.expectedGroupCount = expectedGroupCount
        self.expectedTeamsPerGroup = expectedTeamsPerGroup
        self.missingGroupIDs = missingGroupIDs
        self.incompleteGroupIDs = incompleteGroupIDs
        self.duplicateGroupIDs = duplicateGroupIDs
    }
}

public enum GroupStagePickValidator {
    public static func validate(
        predictions: [GroupStagePrediction],
        expectedGroupIDs: [GroupID],
        expectedTeamsPerGroup: Int = 4
    ) -> GroupStagePickValidation {
        let predictionsByGroup = Dictionary(grouping: predictions, by: \.groupID)
        let missingGroupIDs = expectedGroupIDs.filter { predictionsByGroup[$0] == nil }
        let duplicateGroupIDs = predictionsByGroup
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }
        let incompleteGroupIDs = predictionsByGroup.compactMap { groupID, groupPredictions -> GroupID? in
            guard let prediction = groupPredictions.first else {
                return nil
            }

            let uniqueTeamCount = Set(prediction.orderedTeamIDs).count
            return prediction.orderedTeamIDs.count == expectedTeamsPerGroup && uniqueTeamCount == expectedTeamsPerGroup
                ? nil
                : groupID
        }
        .sorted { $0.rawValue < $1.rawValue }

        return GroupStagePickValidation(
            expectedGroupCount: expectedGroupIDs.count,
            expectedTeamsPerGroup: expectedTeamsPerGroup,
            missingGroupIDs: missingGroupIDs,
            incompleteGroupIDs: incompleteGroupIDs,
            duplicateGroupIDs: duplicateGroupIDs
        )
    }
}

public struct KnockoutPickValidation: Equatable, Sendable {
    public let expectedMatchIDs: [MatchID]
    public let missingMatchIDs: [MatchID]

    public var isComplete: Bool {
        missingMatchIDs.isEmpty
    }

    public init(expectedMatchIDs: [MatchID], missingMatchIDs: [MatchID]) {
        self.expectedMatchIDs = expectedMatchIDs
        self.missingMatchIDs = missingMatchIDs
    }
}

public enum KnockoutPickValidator {
    public static func validate(
        picks: [KnockoutPick],
        expectedMatchIDs: [MatchID]
    ) -> KnockoutPickValidation {
        let pickedMatchIDs = Set(picks.map(\.matchID))
        return KnockoutPickValidation(
            expectedMatchIDs: expectedMatchIDs,
            missingMatchIDs: expectedMatchIDs.filter { !pickedMatchIDs.contains($0) }
        )
    }
}
