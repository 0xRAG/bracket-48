import Foundation
import Testing

@testable import WorldCupBracketCore

@Suite("Local draft state")
struct LocalDraftStateTests {
    @Test("encodes and decodes versioned submitted state")
    func encodesAndDecodesSubmittedState() throws {
        let prediction = LocalGroupStagePrediction(
            groupID: "A",
            orderedTeamIDs: ["usa", "mex", "can", "kor"],
            predictedThirdPlaceAdvances: true
        )
        let state = LocalDraftState(
            currentScreen: .submitted,
            displayName: "Ryan",
            groupName: "Saturday Pool",
            selectedGroupID: "group-1",
            groupStagePredictions: [prediction],
            joinedGroups: [
                LocalJoinedGroup(
                    id: "group-1",
                    name: "Saturday Pool",
                    inviteCode: "SATURDAY",
                    isOwner: true
                ),
                LocalJoinedGroup(
                    id: "joined-friends",
                    name: "Friends League",
                    inviteCode: "FRIENDS",
                    isOwner: false
                )
            ],
            submittedEntry: LocalSubmittedEntry(
                groupName: "Saturday Pool",
                displayName: "Ryan",
                groupStagePredictions: [prediction]
            )
        )

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(LocalDraftState.self, from: data)

        #expect(restored == state)
        #expect(restored.schemaVersion == LocalDraftState.currentSchemaVersion)
        #expect(restored.joinedGroups.count == 2)
    }

    @Test("supports unsubmitted local bracket state")
    func supportsUnsubmittedLocalBracketState() throws {
        let state = LocalDraftState(
            currentScreen: .bracket,
            displayName: "Alex",
            groupName: "",
            selectedGroupID: nil,
            groupStagePredictions: [
                LocalGroupStagePrediction(
                    groupID: "B",
                    orderedTeamIDs: ["arg", "jpn", "mar", "sen"],
                    predictedThirdPlaceAdvances: false
                )
            ],
            submittedEntry: nil
        )

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(LocalDraftState.self, from: data)

        #expect(restored.currentScreen == .bracket)
        #expect(restored.submittedEntry == nil)
        #expect(restored.groupStagePredictions.first?.predictedThirdPlaceAdvances == false)
    }

    @Test("decodes older local state without knockout keys")
    func decodesOlderLocalStateWithoutKnockoutKeys() throws {
        let json = """
        {
          "schemaVersion": 1,
          "currentScreen": "submitted",
          "displayName": "Ryan",
          "groupName": "Saturday Pool",
          "selectedGroupID": "group-1",
          "groupStagePredictions": [
            {
              "groupID": { "rawValue": "A" },
              "orderedTeamIDs": [
                { "rawValue": "usa" },
                { "rawValue": "mex" },
                { "rawValue": "can" },
                { "rawValue": "kor" }
              ],
              "predictedThirdPlaceAdvances": true
            }
          ],
          "submittedEntry": {
            "groupName": "Saturday Pool",
            "displayName": "Ryan",
            "groupStagePredictions": [
              {
                "groupID": { "rawValue": "A" },
                "orderedTeamIDs": [
                  { "rawValue": "usa" },
                  { "rawValue": "mex" },
                  { "rawValue": "can" },
                  { "rawValue": "kor" }
                ],
                "predictedThirdPlaceAdvances": true
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let restored = try JSONDecoder().decode(LocalDraftState.self, from: json)

        #expect(restored.currentScreen == .submitted)
        #expect(restored.knockoutPicks.isEmpty)
        #expect(restored.joinedGroups.isEmpty)
        #expect(restored.submittedKnockoutEntry == nil)
    }
}
