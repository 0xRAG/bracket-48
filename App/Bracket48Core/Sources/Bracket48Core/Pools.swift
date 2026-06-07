import Foundation

public struct Pool: Identifiable, Codable, Equatable, Sendable {
    public let id: PoolID
    public let tournamentID: TournamentID
    public let name: String
    public let ownerUserID: UserID
    public let inviteCode: InviteCode
    public let type: PoolType
    public let status: PoolStatus
    public let entryLimit: PoolEntryLimit
    public let lockWindows: [BracketPhase: SubmissionWindow]

    public init(
        id: PoolID,
        tournamentID: TournamentID,
        name: String,
        ownerUserID: UserID,
        inviteCode: InviteCode,
        type: PoolType,
        status: PoolStatus,
        entryLimit: PoolEntryLimit = .onePerUserPerPhase,
        lockWindows: [BracketPhase: SubmissionWindow] = [:]
    ) {
        self.id = id
        self.tournamentID = tournamentID
        self.name = name
        self.ownerUserID = ownerUserID
        self.inviteCode = inviteCode
        self.type = type
        self.status = status
        self.entryLimit = entryLimit
        self.lockWindows = lockWindows
    }

    public func accepts(phase: BracketPhase) -> Bool {
        switch (type, phase) {
        case (.fullTournament, .groupStage), (.fullTournament, .knockout), (.knockoutOnly, .knockout):
            true
        case (.knockoutOnly, .groupStage):
            false
        }
    }

    public func isOpen(for phase: BracketPhase, at date: Date) -> Bool {
        guard status == .open else {
            return false
        }
        guard let window = lockWindows[phase] else {
            return true
        }

        return window.contains(date)
    }
}

public enum PoolType: String, Codable, Equatable, Sendable {
    case fullTournament
    case knockoutOnly
}

public enum PoolStatus: String, Codable, Equatable, Sendable {
    case open
    case locked
    case archived
}

public enum PoolEntryLimit: String, Codable, Equatable, Sendable {
    case onePerUserPerPhase
}

public enum PoolMembershipRole: String, Codable, Equatable, Sendable {
    case owner
    case member
}

public enum PoolMembershipStatus: String, Codable, Equatable, Sendable {
    case active
    case removed
}

public enum BracketPhase: String, Codable, Equatable, Sendable, CaseIterable {
    case groupStage
    case knockout
}

public struct SubmissionWindow: Codable, Equatable, Sendable {
    public let opensAt: Date
    public let locksAt: Date

    public init(opensAt: Date, locksAt: Date) {
        self.opensAt = opensAt
        self.locksAt = locksAt
    }

    public func contains(_ date: Date) -> Bool {
        date >= opensAt && date < locksAt
    }
}

public struct PoolMembership: Identifiable, Codable, Equatable, Sendable {
    public var id: String {
        "\(poolID.rawValue):\(userID.rawValue)"
    }

    public let poolID: PoolID
    public let userID: UserID
    public let role: PoolMembershipRole
    public let status: PoolMembershipStatus
    public let joinedAt: Date

    public init(
        poolID: PoolID,
        userID: UserID,
        role: PoolMembershipRole,
        status: PoolMembershipStatus,
        joinedAt: Date
    ) {
        self.poolID = poolID
        self.userID = userID
        self.role = role
        self.status = status
        self.joinedAt = joinedAt
    }
}

public struct PoolEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: TournamentEntryID
    public let poolID: PoolID
    public let userID: UserID
    public let phase: BracketPhase
    public let submittedAt: Date

    public init(
        id: TournamentEntryID,
        poolID: PoolID,
        userID: UserID,
        phase: BracketPhase,
        submittedAt: Date
    ) {
        self.id = id
        self.poolID = poolID
        self.userID = userID
        self.phase = phase
        self.submittedAt = submittedAt
    }
}

public enum PoolEntryValidationIssue: String, Codable, Equatable, Sendable {
    case poolDoesNotAcceptPhase
    case poolIsLocked
    case userIsNotActiveMember
    case duplicateEntry
}

public enum PoolEntryValidator {
    public static func validate(
        entry: PoolEntry,
        pool: Pool,
        memberships: [PoolMembership],
        existingEntries: [PoolEntry],
        at date: Date
    ) -> [PoolEntryValidationIssue] {
        var issues: [PoolEntryValidationIssue] = []

        if !pool.accepts(phase: entry.phase) {
            issues.append(.poolDoesNotAcceptPhase)
        }

        if !pool.isOpen(for: entry.phase, at: date) {
            issues.append(.poolIsLocked)
        }

        let isActiveMember = memberships.contains { membership in
            membership.poolID == pool.id && membership.userID == entry.userID && membership.status == .active
        }
        if !isActiveMember {
            issues.append(.userIsNotActiveMember)
        }

        let hasDuplicateEntry = existingEntries.contains { existingEntry in
            existingEntry.poolID == entry.poolID
                && existingEntry.userID == entry.userID
                && existingEntry.phase == entry.phase
        }
        if hasDuplicateEntry {
            issues.append(.duplicateEntry)
        }

        return issues
    }
}
