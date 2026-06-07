public struct LocalDraftState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public let schemaVersion: Int
    public let currentScreen: LocalAppScreen
    public let displayName: String
    public let groupName: String
    public let selectedGroupID: String?
    public let groupStagePredictions: [LocalGroupStagePrediction]
    public let knockoutPicks: [LocalKnockoutPick]
    public let joinedGroups: [LocalJoinedGroup]
    public let submittedEntry: LocalSubmittedEntry?
    public let submittedKnockoutEntry: LocalSubmittedKnockoutEntry?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case currentScreen
        case displayName
        case groupName
        case selectedGroupID
        case groupStagePredictions
        case knockoutPicks
        case joinedGroups
        case submittedEntry
        case submittedKnockoutEntry
    }

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        currentScreen: LocalAppScreen,
        displayName: String,
        groupName: String,
        selectedGroupID: String?,
        groupStagePredictions: [LocalGroupStagePrediction],
        knockoutPicks: [LocalKnockoutPick] = [],
        joinedGroups: [LocalJoinedGroup] = [],
        submittedEntry: LocalSubmittedEntry?,
        submittedKnockoutEntry: LocalSubmittedKnockoutEntry? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.currentScreen = currentScreen
        self.displayName = displayName
        self.groupName = groupName
        self.selectedGroupID = selectedGroupID
        self.groupStagePredictions = groupStagePredictions
        self.knockoutPicks = knockoutPicks
        self.joinedGroups = joinedGroups
        self.submittedEntry = submittedEntry
        self.submittedKnockoutEntry = submittedKnockoutEntry
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        currentScreen = try container.decode(LocalAppScreen.self, forKey: .currentScreen)
        displayName = try container.decode(String.self, forKey: .displayName)
        groupName = try container.decode(String.self, forKey: .groupName)
        selectedGroupID = try container.decodeIfPresent(String.self, forKey: .selectedGroupID)
        groupStagePredictions = try container.decode([LocalGroupStagePrediction].self, forKey: .groupStagePredictions)
        knockoutPicks = try container.decodeIfPresent([LocalKnockoutPick].self, forKey: .knockoutPicks) ?? []
        joinedGroups = try container.decodeIfPresent([LocalJoinedGroup].self, forKey: .joinedGroups) ?? []
        submittedEntry = try container.decodeIfPresent(LocalSubmittedEntry.self, forKey: .submittedEntry)
        submittedKnockoutEntry = try container.decodeIfPresent(LocalSubmittedKnockoutEntry.self, forKey: .submittedKnockoutEntry)
    }
}

public enum LocalAppScreen: String, Codable, Equatable, Sendable {
    case signUp
    case home
    case bracket
    case group
    case knockout
    case submitted
}

public struct LocalGroupStagePrediction: Codable, Equatable, Sendable {
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

public struct LocalSubmittedEntry: Codable, Equatable, Sendable {
    public let groupName: String
    public let displayName: String
    public let groupStagePredictions: [LocalGroupStagePrediction]

    public init(
        groupName: String,
        displayName: String,
        groupStagePredictions: [LocalGroupStagePrediction]
    ) {
        self.groupName = groupName
        self.displayName = displayName
        self.groupStagePredictions = groupStagePredictions
    }
}

public struct LocalJoinedGroup: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let inviteCode: String
    public let isOwner: Bool

    public init(id: String, name: String, inviteCode: String, isOwner: Bool) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.isOwner = isOwner
    }
}

public struct LocalKnockoutPick: Codable, Equatable, Sendable {
    public let matchID: MatchID
    public let round: KnockoutRound
    public let pickedWinnerTeamID: TeamID

    public init(matchID: MatchID, round: KnockoutRound, pickedWinnerTeamID: TeamID) {
        self.matchID = matchID
        self.round = round
        self.pickedWinnerTeamID = pickedWinnerTeamID
    }
}

public struct LocalSubmittedKnockoutEntry: Codable, Equatable, Sendable {
    public let groupName: String
    public let displayName: String
    public let picks: [LocalKnockoutPick]

    public init(groupName: String, displayName: String, picks: [LocalKnockoutPick]) {
        self.groupName = groupName
        self.displayName = displayName
        self.picks = picks
    }
}
