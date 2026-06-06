import Foundation
import Testing

@testable import WorldCupBracketCore

@Suite("Tournament schema")
struct TournamentSchemaTests {
    @Test("fixture can represent the 2026 World Cup group structure")
    func fixtureRepresentsWorldCupGroupStructure() {
        let tournament = TestTournamentFactory.tournament(phase: .preTournament)

        #expect(tournament.teams.count == 48)
        #expect(tournament.groups.count == 12)
        #expect(tournament.groups.allSatisfy { $0.teamIDs.count == 4 })
        #expect(tournament.advancementRules.automaticAdvancersPerGroup == 2)
        #expect(tournament.advancementRules.bestThirdPlaceAdvancers == 8)
        #expect(tournament.validationIssues().isEmpty)
    }

    @Test("schema represents Round of 32 through champion")
    func schemaRepresentsKnockoutRounds() {
        let tournament = TestTournamentFactory.tournament(phase: .preTournament)

        let representedRounds = Set(tournament.knockoutSlots.map(\.round))

        #expect(representedRounds == Set(KnockoutRound.allCases))
        #expect(tournament.knockoutSlots.contains { $0.round == .roundOf32 && $0.source == .bestThirdPlace(rank: 1) })
        #expect(tournament.knockoutSlots.contains { $0.round == .final && $0.source == .matchWinner(matchID: "sf-1") })
    }

    @Test("group-stage completion state is detected")
    func groupStageCompletionState() {
        let inProgress = TestTournamentFactory.tournament(phase: .groupStageLocked, groupMatchStatus: .inProgress)
        let complete = TestTournamentFactory.tournament(phase: .groupStageComplete, groupMatchStatus: .final)

        #expect(!inProgress.isGroupStageComplete)
        #expect(complete.isGroupStageComplete)
    }

    @Test("knockout bracket open state requires completed groups and knockout phase")
    func knockoutBracketOpenState() {
        let completeButNotOpen = TestTournamentFactory.tournament(phase: .groupStageComplete, groupMatchStatus: .final)
        let open = TestTournamentFactory.tournament(phase: .knockoutOpen, groupMatchStatus: .final)

        #expect(!completeButNotOpen.isKnockoutBracketOpen)
        #expect(open.isKnockoutBracketOpen)
    }

    @Test("provider updates can be matched to internal matches")
    func providerUpdatesCanMatchInternalMatches() throws {
        let tournament = TestTournamentFactory.tournament(phase: .groupStageOpen)

        let match = try #require(tournament.match(providerID: "provider-match-1", providerName: "ExampleSports"))

        #expect(match.id == "group-a-1")
        #expect(match.status == .scheduled)
    }

    @Test("match supports provider result updates")
    func matchSupportsProviderResultUpdates() throws {
        let tournament = TestTournamentFactory.tournament(phase: .groupStageOpen)
        let match = try #require(tournament.match(providerID: "provider-match-1"))

        let updated = match.applyingProviderResult(
            status: .final,
            score: MatchScore(home: 2, away: 1),
            winnerTeamID: "team-a1"
        )

        #expect(updated.status == .final)
        #expect(updated.score == MatchScore(home: 2, away: 1))
        #expect(updated.winnerTeamID == "team-a1")
        #expect(updated.adminCorrections.isEmpty)
    }

    @Test("match supports admin correction audit metadata")
    func matchSupportsAdminCorrectionAuditMetadata() throws {
        let tournament = TestTournamentFactory.tournament(phase: .groupStageOpen)
        let match = try #require(tournament.match(providerID: "provider-match-1"))
        let correction = AdminCorrection(
            id: "correction-1",
            correctedByUserID: "admin-1",
            correctedAt: Date(timeIntervalSince1970: 1_800_000_000),
            reason: "Provider corrected stoppage-time result.",
            correctedStatus: .final,
            correctedScore: MatchScore(home: 1, away: 1),
            correctedWinnerTeamID: nil
        )

        let corrected = match.applyingAdminCorrection(correction)

        #expect(corrected.status == .final)
        #expect(corrected.score == MatchScore(home: 1, away: 1))
        #expect(corrected.adminCorrections == [correction])
    }
}

private enum TestTournamentFactory {
    static func tournament(
        phase: TournamentPhase,
        groupMatchStatus: MatchStatus = .scheduled
    ) -> Tournament {
        let teams = (0..<12).flatMap { groupIndex in
            (1...4).map { teamIndex in
                let groupLetter = String(UnicodeScalar(65 + groupIndex)!)
                return Team(
                    id: TeamID("team-\(groupLetter.lowercased())\(teamIndex)"),
                    name: "Team \(groupLetter)\(teamIndex)",
                    countryCode: "\(groupLetter)\(teamIndex)",
                    fifaCode: "\(groupLetter)\(teamIndex)",
                    seed: groupIndex * 4 + teamIndex
                )
            }
        }

        let groups = (0..<12).map { groupIndex in
            let groupLetter = String(UnicodeScalar(65 + groupIndex)!)
            return TournamentGroup(
                id: GroupID(groupLetter),
                name: "Group \(groupLetter)",
                teamIDs: (1...4).map { TeamID("team-\(groupLetter.lowercased())\($0)") }
            )
        }

        let groupMatches = groups.enumerated().map { index, group in
            TournamentMatch(
                id: MatchID("group-\(group.id.rawValue.lowercased())-1"),
                phase: .groupStage,
                groupID: group.id,
                homeTeamID: group.teamIDs[0],
                awayTeamID: group.teamIDs[1],
                status: groupMatchStatus,
                providerReferences: index == 0
                    ? [ProviderReference(providerName: "ExampleSports", providerID: "provider-match-1")]
                    : []
            )
        }

        return Tournament(
            id: "world-cup-2026",
            name: "World Cup 2026",
            year: 2026,
            phase: phase,
            teams: teams,
            groups: groups,
            matches: groupMatches + knockoutMatches(),
            knockoutSlots: knockoutSlots()
        )
    }

    private static func knockoutMatches() -> [TournamentMatch] {
        let roundOf32 = (1...16).map { index in
            TournamentMatch(
                id: MatchID("r32-\(index)"),
                phase: .knockout,
                knockoutRound: .roundOf32,
                status: .scheduled
            )
        }
        let roundOf16 = (1...8).map { index in
            TournamentMatch(
                id: MatchID("r16-\(index)"),
                phase: .knockout,
                knockoutRound: .roundOf16,
                status: .scheduled
            )
        }
        let quarterfinals = (1...4).map { index in
            TournamentMatch(
                id: MatchID("qf-\(index)"),
                phase: .knockout,
                knockoutRound: .quarterfinal,
                status: .scheduled
            )
        }
        let semifinals = (1...2).map { index in
            TournamentMatch(
                id: MatchID("sf-\(index)"),
                phase: .knockout,
                knockoutRound: .semifinal,
                status: .scheduled
            )
        }
        let final = [
            TournamentMatch(
                id: "final",
                phase: .knockout,
                knockoutRound: .final,
                status: .scheduled
            )
        ]

        return roundOf32 + roundOf16 + quarterfinals + semifinals + final
    }

    private static func knockoutSlots() -> [KnockoutSlot] {
        var slots: [KnockoutSlot] = []

        for index in 1...16 {
            slots.append(
                KnockoutSlot(
                    id: "r32-\(index)-home",
                    round: .roundOf32,
                    matchID: MatchID("r32-\(index)"),
                    side: .home,
                    source: .groupPlacement(groupID: GroupID(String(UnicodeScalar(64 + min(index, 12))!)), position: 1)
                )
            )
            slots.append(
                KnockoutSlot(
                    id: "r32-\(index)-away",
                    round: .roundOf32,
                    matchID: MatchID("r32-\(index)"),
                    side: .away,
                    source: index <= 8 ? .bestThirdPlace(rank: index) : .groupPlacement(
                        groupID: GroupID(String(UnicodeScalar(64 + min(index - 8, 12))!)),
                        position: 2
                    )
                )
            )
        }

        for index in 1...8 {
            slots.append(
                KnockoutSlot(
                    id: "r16-\(index)-home",
                    round: .roundOf16,
                    matchID: MatchID("r16-\(index)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("r32-\((index * 2) - 1)"))
                )
            )
        }

        for index in 1...4 {
            slots.append(
                KnockoutSlot(
                    id: "qf-\(index)-home",
                    round: .quarterfinal,
                    matchID: MatchID("qf-\(index)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("r16-\((index * 2) - 1)"))
                )
            )
        }

        for index in 1...2 {
            slots.append(
                KnockoutSlot(
                    id: "sf-\(index)-home",
                    round: .semifinal,
                    matchID: MatchID("sf-\(index)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("qf-\((index * 2) - 1)"))
                )
            )
        }

        slots.append(
            KnockoutSlot(
                id: "final-home",
                round: .final,
                matchID: "final",
                side: .home,
                source: .matchWinner(matchID: "sf-1")
            )
        )

        return slots
    }
}
