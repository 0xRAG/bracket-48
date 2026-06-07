import SwiftUI
import Bracket48Core

struct ScoringGuideView: View {
    private let rules = ScoringRuleSet.worldCupDefault

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Two-part bracket")
                        .font(.title2.bold())
                    Text("First predict the group stage. After that, fill out a knockout bracket from the Round of 32 through the champion.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Group Stage") {
                GuideRow(
                    icon: "list.number",
                    title: "Rank every group",
                    detail: "Put all four teams in each group into your exact predicted finish order."
                )
                GuideRow(
                    icon: "arrow.up.forward.circle.fill",
                    title: "Pick third-place advancers",
                    detail: "The top two teams in every group advance automatically. You must also choose exactly 8 of the 12 third-place teams to advance."
                )
                GuideRow(
                    icon: "checkmark.seal.fill",
                    title: "Lock it in",
                    detail: "Saving your group-stage bracket opens the knockout stage for that same bracket."
                )
            }

            Section {
                ScoreRow(title: "Correct group winner", points: rules.correctGroupWinner)
                ScoreRow(title: "Correct group runner-up", points: rules.correctGroupRunnerUp)
                ScoreRow(title: "Correct third-place team", points: rules.correctGroupThirdPlace)
                ScoreRow(title: "Correct third-place advancement result", points: rules.correctThirdPlaceAdvancement)
                ScoreRow(title: "Perfect top three in a group", points: rules.perfectGroupTopThreeBonus)
            } header: {
                Text("Group-Stage Scoring")
            } footer: {
                Text("A perfect group is worth \(groupPointsPerGroup) points. Across 12 groups, the group-stage maximum is \(groupStageMaximum) points.")
            }

            Section("Knockout Stage") {
                GuideRow(
                    icon: "trophy.fill",
                    title: "Advance winners",
                    detail: "Pick the winner of each matchup. Later rounds unlock from your earlier picks until you choose a champion."
                )
                GuideRow(
                    icon: "scope",
                    title: "Score by round",
                    detail: "Correct picks are worth more as the tournament gets deeper."
                )
            }

            Section {
                ScoreRow(title: "Round of 32 winner", points: knockoutPoints(for: .roundOf32))
                ScoreRow(title: "Round of 16 winner", points: knockoutPoints(for: .roundOf16))
                ScoreRow(title: "Quarterfinal winner", points: knockoutPoints(for: .quarterfinal))
                ScoreRow(title: "Semifinal winner", points: knockoutPoints(for: .semifinal))
                ScoreRow(title: "Champion", points: knockoutPoints(for: .final))
            } header: {
                Text("Knockout Scoring")
            } footer: {
                Text("If every knockout pick is correct, the knockout maximum is \(knockoutMaximum) points.")
            }

            Section("Total") {
                ScoreRow(title: "Maximum possible score", points: groupStageMaximum + knockoutMaximum)
            }
        }
        .navigationTitle("Scoring")
        .scrollContentBackground(.hidden)
        .background(AppBackground())
    }

    private var groupPointsPerGroup: Int {
        rules.correctGroupWinner
            + rules.correctGroupRunnerUp
            + rules.correctGroupThirdPlace
            + rules.correctThirdPlaceAdvancement
            + rules.perfectGroupTopThreeBonus
    }

    private var groupStageMaximum: Int {
        groupPointsPerGroup * 12
    }

    private var knockoutMaximum: Int {
        knockoutPoints(for: .roundOf32) * 16
            + knockoutPoints(for: .roundOf16) * 8
            + knockoutPoints(for: .quarterfinal) * 4
            + knockoutPoints(for: .semifinal) * 2
            + knockoutPoints(for: .final)
    }

    private func knockoutPoints(for round: KnockoutRound) -> Int {
        rules.knockoutRoundPoints[round, default: 0]
    }
}

private struct GuideRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ScoreRow: View {
    let title: String
    let points: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(points) pts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
