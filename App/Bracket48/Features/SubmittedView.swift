import SwiftUI
import Bracket48Core

struct SubmittedView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(appModel.primaryAccentColor.color)

                    Text("Group Bracket")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    if let entry = appModel.submittedEntry {
                        Text(entry.isStandalone ? "\(entry.displayName)'s bracket is saved and ready for knockout picks." : "\(entry.displayName)'s bracket is entered in \(entry.groupName).")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Section("Summary") {
                InfoLine(title: "Status", value: "Saved")
                InfoLine(title: "Groups ranked", value: "\(appModel.predictions.count)")
                if let knockoutEntry = appModel.submittedKnockoutEntry,
                   let champion = knockoutEntry.picks.first(where: { $0.matchID == "final" })?.pickedWinner
                {
                    InfoLine(title: "Champion pick", value: "\(champion.flagEmoji) \(champion.code)")
                }
            }

            Section("Scoring Preview") {
                let maximum = ScoringEngine().maximumAvailableScore(
                    for: BracketPredictions(
                        groupStagePredictions: appModel.predictions.map(\.corePrediction),
                        knockoutPicks: []
                    )
                )

                InfoLine(title: "Possible group-stage points", value: "\(maximum.groupStagePoints)")
            }

            Section {
                Button {
                    appModel.showBracketsHome()
                } label: {
                    Text("Back to Brackets")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .navigationTitle("Group Bracket")
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
    }
}
