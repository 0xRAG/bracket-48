import Foundation
import Testing

@testable import WorldCupBracketCore

@Suite("Pool entry validation")
struct PoolEntryValidationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("full-tournament pool accepts group-stage and knockout entries from active members")
    func fullTournamentPoolAcceptsBothPhases() {
        let pool = makePool(type: .fullTournament)
        let memberships = [makeMembership(poolID: pool.id, userID: "user-1")]

        let groupEntry = makeEntry(poolID: pool.id, userID: "user-1", phase: .groupStage)
        let knockoutEntry = makeEntry(poolID: pool.id, userID: "user-1", phase: .knockout)

        #expect(PoolEntryValidator.validate(
            entry: groupEntry,
            pool: pool,
            memberships: memberships,
            existingEntries: [],
            at: now
        ).isEmpty)
        #expect(PoolEntryValidator.validate(
            entry: knockoutEntry,
            pool: pool,
            memberships: memberships,
            existingEntries: [],
            at: now
        ).isEmpty)
    }

    @Test("knockout-only pool rejects group-stage entries")
    func knockoutOnlyRejectsGroupStageEntries() {
        let pool = makePool(type: .knockoutOnly)
        let entry = makeEntry(poolID: pool.id, userID: "user-1", phase: .groupStage)

        let issues = PoolEntryValidator.validate(
            entry: entry,
            pool: pool,
            memberships: [makeMembership(poolID: pool.id, userID: "user-1")],
            existingEntries: [],
            at: now
        )

        #expect(issues == [.poolDoesNotAcceptPhase])
    }

    @Test("non-members cannot submit entries")
    func nonMembersCannotSubmitEntries() {
        let pool = makePool(type: .fullTournament)
        let entry = makeEntry(poolID: pool.id, userID: "user-2", phase: .groupStage)

        let issues = PoolEntryValidator.validate(
            entry: entry,
            pool: pool,
            memberships: [makeMembership(poolID: pool.id, userID: "user-1")],
            existingEntries: [],
            at: now
        )

        #expect(issues == [.userIsNotActiveMember])
    }

    @Test("duplicate entries are rejected per user pool and phase")
    func duplicateEntriesAreRejectedPerPhase() {
        let pool = makePool(type: .fullTournament)
        let existingEntry = makeEntry(poolID: pool.id, userID: "user-1", phase: .groupStage)
        let newEntry = makeEntry(id: "entry-2", poolID: pool.id, userID: "user-1", phase: .groupStage)

        let issues = PoolEntryValidator.validate(
            entry: newEntry,
            pool: pool,
            memberships: [makeMembership(poolID: pool.id, userID: "user-1")],
            existingEntries: [existingEntry],
            at: now
        )

        #expect(issues == [.duplicateEntry])
    }

    @Test("locked pools reject entries")
    func lockedPoolsRejectEntries() {
        let pool = makePool(type: .fullTournament, status: .locked)
        let entry = makeEntry(poolID: pool.id, userID: "user-1", phase: .groupStage)

        let issues = PoolEntryValidator.validate(
            entry: entry,
            pool: pool,
            memberships: [makeMembership(poolID: pool.id, userID: "user-1")],
            existingEntries: [],
            at: now
        )

        #expect(issues == [.poolIsLocked])
    }

    @Test("submission windows reject entries after lock")
    func submissionWindowRejectsEntriesAfterLock() {
        let pool = makePool(
            type: .fullTournament,
            lockWindows: [
                .groupStage: SubmissionWindow(
                    opensAt: now.addingTimeInterval(-3_600),
                    locksAt: now.addingTimeInterval(-60)
                )
            ]
        )
        let entry = makeEntry(poolID: pool.id, userID: "user-1", phase: .groupStage)

        let issues = PoolEntryValidator.validate(
            entry: entry,
            pool: pool,
            memberships: [makeMembership(poolID: pool.id, userID: "user-1")],
            existingEntries: [],
            at: now
        )

        #expect(issues == [.poolIsLocked])
    }

    @Test("invite codes are codable first-class values")
    func inviteCodesAreCodable() throws {
        let pool = makePool(type: .fullTournament)

        let data = try JSONEncoder().encode(pool)
        let restored = try JSONDecoder().decode(Pool.self, from: data)

        #expect(restored.inviteCode == "SATURDAY")
        #expect(restored == pool)
    }

    private func makePool(
        type: PoolType,
        status: PoolStatus = .open,
        lockWindows: [BracketPhase: SubmissionWindow] = [:]
    ) -> Pool {
        Pool(
            id: "pool-1",
            tournamentID: "world-cup-2026",
            name: "Saturday Pool",
            ownerUserID: "user-1",
            inviteCode: "SATURDAY",
            type: type,
            status: status,
            lockWindows: lockWindows
        )
    }

    private func makeMembership(poolID: PoolID, userID: UserID) -> PoolMembership {
        PoolMembership(
            poolID: poolID,
            userID: userID,
            role: .member,
            status: .active,
            joinedAt: now.addingTimeInterval(-3_600)
        )
    }

    private func makeEntry(
        id: TournamentEntryID = "entry-1",
        poolID: PoolID,
        userID: UserID,
        phase: BracketPhase
    ) -> PoolEntry {
        PoolEntry(
            id: id,
            poolID: poolID,
            userID: userID,
            phase: phase,
            submittedAt: now
        )
    }
}
