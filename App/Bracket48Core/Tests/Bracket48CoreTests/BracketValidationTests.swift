import Testing

@testable import Bracket48Core

@Suite("Bracket validation")
struct BracketValidationTests {
    @Test("validates complete group-stage picks")
    func validatesCompleteGroupStagePicks() {
        let validation = GroupStagePickValidator.validate(
            predictions: [
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "kor"],
                    predictedThirdPlaceAdvances: true
                ),
                GroupStagePrediction(
                    groupID: "B",
                    orderedTeamIDs: ["arg", "jpn", "mar", "sen"],
                    predictedThirdPlaceAdvances: false
                )
            ],
            expectedGroupIDs: ["A", "B"]
        )

        #expect(validation.isComplete)
        #expect(validation.expectedGroupCount == 2)
        #expect(validation.expectedTeamsPerGroup == 4)
    }

    @Test("reports missing incomplete and duplicate groups")
    func reportsInvalidGroupStagePicks() {
        let validation = GroupStagePickValidator.validate(
            predictions: [
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "can"],
                    predictedThirdPlaceAdvances: true
                ),
                GroupStagePrediction(
                    groupID: "A",
                    orderedTeamIDs: ["usa", "mex", "can", "kor"],
                    predictedThirdPlaceAdvances: true
                )
            ],
            expectedGroupIDs: ["A", "B"]
        )

        #expect(!validation.isComplete)
        #expect(validation.missingGroupIDs == ["B"])
        #expect(validation.incompleteGroupIDs == ["A"])
        #expect(validation.duplicateGroupIDs == ["A"])
    }

    @Test("validates complete knockout picks")
    func validatesCompleteKnockoutPicks() {
        let validation = KnockoutPickValidator.validate(
            picks: [
                KnockoutPick(matchID: "r32-1", round: .roundOf32, pickedWinnerTeamID: "usa"),
                KnockoutPick(matchID: "r16-1", round: .roundOf16, pickedWinnerTeamID: "usa")
            ],
            expectedMatchIDs: ["r32-1", "r16-1"]
        )

        #expect(validation.isComplete)
    }

    @Test("reports missing knockout picks")
    func reportsMissingKnockoutPicks() {
        let validation = KnockoutPickValidator.validate(
            picks: [
                KnockoutPick(matchID: "r32-1", round: .roundOf32, pickedWinnerTeamID: "usa")
            ],
            expectedMatchIDs: ["r32-1", "r16-1"]
        )

        #expect(!validation.isComplete)
        #expect(validation.missingMatchIDs == ["r16-1"])
    }
}
