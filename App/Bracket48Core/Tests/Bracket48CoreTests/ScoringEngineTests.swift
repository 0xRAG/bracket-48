import Testing

@testable import Bracket48Core

@Suite("ScoringEngine")
struct ScoringEngineTests {
    private let engine = ScoringEngine()
    private let entryID: TournamentEntryID = "entry-1"

    @Test("scores exact group order using default group-stage rules")
    func exactGroupOrderScoring() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "pan"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            knockoutPicks: []
        )
        let results = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "A", orderedTeamIDs: ["usa", "mex", "can", "pan"])
            ],
            advancingThirdPlaceTeamIDs: ["can"],
            knockoutResults: []
        )

        let score = engine.score(entryID: entryID, predictions: predictions, results: results)

        #expect(score.groupStagePoints == 14)
        #expect(score.knockoutPoints == 0)
        #expect(score.totalPoints == 14)
        #expect(score.events.map(\.points).sorted() == [2, 2, 3, 3, 4])
        #expect(score.events.allSatisfy { !$0.id.isEmpty && !$0.reason.isEmpty })
    }

    @Test("scores partially correct group order")
    func partiallyCorrectGroupOrderScoring() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "B",
                    orderedTeamIDs: ["bra", "ser", "sui", "cmr"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            knockoutPicks: []
        )
        let results = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "B", orderedTeamIDs: ["bra", "sui", "ser", "cmr"])
            ],
            advancingThirdPlaceTeamIDs: ["ser"],
            knockoutResults: []
        )

        let score = engine.score(entryID: entryID, predictions: predictions, results: results)

        #expect(score.groupStagePoints == 6)
        #expect(score.events.map(\.id) == [
            "group:B:third-place-advancement",
            "group:B:winner"
        ])
    }

    @Test("scores incorrect third-place advancement result as zero for that rule")
    func incorrectThirdPlaceAdvancement() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "C",
                    orderedTeamIDs: ["arg", "pol", "mex", "ksa"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            knockoutPicks: []
        )
        let results = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "C", orderedTeamIDs: ["arg", "pol", "mex", "ksa"])
            ],
            advancingThirdPlaceTeamIDs: [],
            knockoutResults: []
        )

        let score = engine.score(entryID: entryID, predictions: predictions, results: results)

        #expect(score.groupStagePoints == 12)
        #expect(!score.events.contains { $0.id == "group:C:third-place-advancement" })
    }

    @Test("scores knockout picks by round")
    func knockoutScoring() {
        let predictions = BracketPredictions(
            groupStagePredictions: [],
            knockoutPicks: [
                KnockoutPick(matchID: "r32-1", round: .roundOf32, pickedWinnerTeamID: "usa"),
                KnockoutPick(matchID: "r16-1", round: .roundOf16, pickedWinnerTeamID: "arg"),
                KnockoutPick(matchID: "qf-1", round: .quarterfinal, pickedWinnerTeamID: "bra"),
                KnockoutPick(matchID: "sf-1", round: .semifinal, pickedWinnerTeamID: "fra"),
                KnockoutPick(matchID: "final", round: .final, pickedWinnerTeamID: "fra")
            ]
        )
        let results = TournamentResults(
            groupStandings: [],
            advancingThirdPlaceTeamIDs: [],
            knockoutResults: [
                MatchResult(matchID: "r32-1", round: .roundOf32, winnerTeamID: "usa"),
                MatchResult(matchID: "r16-1", round: .roundOf16, winnerTeamID: "arg"),
                MatchResult(matchID: "qf-1", round: .quarterfinal, winnerTeamID: "bra"),
                MatchResult(matchID: "sf-1", round: .semifinal, winnerTeamID: "fra"),
                MatchResult(matchID: "final", round: .final, winnerTeamID: "fra")
            ]
        )

        let score = engine.score(entryID: entryID, predictions: predictions, results: results)

        #expect(score.groupStagePoints == 0)
        #expect(score.knockoutPoints == 50)
        #expect(score.totalPoints == 50)
        #expect(score.events.map(\.points) == [4, 6, 8, 12, 20])
    }

    @Test("combines group-stage and knockout scores")
    func combinedScoring() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "D",
                    orderedTeamIDs: ["eng", "usa", "wal", "irn"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            knockoutPicks: [
                KnockoutPick(matchID: "final", round: .final, pickedWinnerTeamID: "eng")
            ]
        )
        let results = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "D", orderedTeamIDs: ["eng", "usa", "wal", "irn"])
            ],
            advancingThirdPlaceTeamIDs: ["wal"],
            knockoutResults: [
                MatchResult(matchID: "final", round: .final, winnerTeamID: "eng")
            ]
        )

        let score = engine.score(entryID: entryID, predictions: predictions, results: results)

        #expect(score.groupStagePoints == 14)
        #expect(score.knockoutPoints == 20)
        #expect(score.totalPoints == 34)
    }

    @Test("scoring is idempotent for the same inputs")
    func scoringIsIdempotent() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "pan"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            knockoutPicks: [
                KnockoutPick(matchID: "final", round: .final, pickedWinnerTeamID: "usa")
            ]
        )
        let results = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "A", orderedTeamIDs: ["usa", "mex", "can", "pan"])
            ],
            advancingThirdPlaceTeamIDs: ["can"],
            knockoutResults: [
                MatchResult(matchID: "final", round: .final, winnerTeamID: "usa")
            ]
        )

        let firstScore = engine.score(entryID: entryID, predictions: predictions, results: results)
        let secondScore = engine.score(entryID: entryID, predictions: predictions, results: results)

        #expect(firstScore == secondScore)
    }

    @Test("rescoring reflects corrected results")
    func rescoringReflectsCorrectedResults() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "pan"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            knockoutPicks: []
        )
        let originalResults = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "A", orderedTeamIDs: ["usa", "mex", "can", "pan"])
            ],
            advancingThirdPlaceTeamIDs: ["can"],
            knockoutResults: []
        )
        let correctedResults = TournamentResults(
            groupStandings: [
                FinalGroupStanding(groupID: "A", orderedTeamIDs: ["mex", "usa", "can", "pan"])
            ],
            advancingThirdPlaceTeamIDs: ["can"],
            knockoutResults: []
        )

        let originalScore = engine.score(entryID: entryID, predictions: predictions, results: originalResults)
        let correctedScore = engine.score(entryID: entryID, predictions: predictions, results: correctedResults)

        #expect(originalScore.totalPoints == 14)
        #expect(correctedScore.totalPoints == 4)
    }

    @Test("calculates maximum available score from submitted predictions")
    func maximumAvailableScore() {
        let predictions = BracketPredictions(
            groupStagePredictions: [
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "pan"],
                    predictedThirdPlaceAdvances: true
                ),
                GroupStagePrediction(
                    groupID: "B",
                    orderedTeamIDs: ["bra", "sui", "ser", "cmr"],
                    predictedThirdPlaceAdvances: false
                )
            ],
            knockoutPicks: [
                KnockoutPick(matchID: "r32-1", round: .roundOf32, pickedWinnerTeamID: "usa"),
                KnockoutPick(matchID: "final", round: .final, pickedWinnerTeamID: "usa")
            ]
        )

        let maximum = engine.maximumAvailableScore(for: predictions)

        #expect(maximum.groupStagePoints == 28)
        #expect(maximum.knockoutPoints == 24)
        #expect(maximum.totalPoints == 52)
    }
}
