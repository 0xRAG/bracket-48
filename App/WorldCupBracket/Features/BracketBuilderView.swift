import SwiftUI
import WorldCupBracketCore

struct BracketBuilderView: View {
    @Environment(AppModel.self) private var appModel
    @State private var editMode: EditMode = .active
    var onSubmitted: (() -> Void)?
    var onScoringInfo: (() -> Void)?

    var body: some View {
        @Bindable var appModel = appModel

        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rank Each Group")
                        .font(.title2.bold())
                    Text("Drag teams into your exact 1 through 4 order. Toggle whether the third-place team advances.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InfoLine(title: "Lock Deadline", value: "Before group stage begins")
                    InfoLine(
                        title: "Third-place picks",
                        value: "\(appModel.selectedThirdPlaceAdvancersCount) of \(appModel.maxThirdPlaceAdvancers)"
                    )
                }
                .padding(.vertical, 4)
            }

            ForEach($appModel.predictions) { $prediction in
                Section("Group \(prediction.groupID)") {
                    let limitReached = appModel.selectedThirdPlaceAdvancersCount >= appModel.maxThirdPlaceAdvancers

                    ForEach(Array(prediction.orderedTeams.enumerated()), id: \.element.id) { index, team in
                        TeamRankRow(rank: index + 1, team: team)
                    }
                    .onMove { source, destination in
                        appModel.moveTeam(groupID: prediction.groupID, from: source, to: destination)
                    }

                    Toggle(
                        "Third place advances",
                        isOn: Binding(
                            get: { prediction.predictedThirdPlaceAdvances },
                            set: { appModel.setThirdPlaceAdvances(groupID: prediction.groupID, advances: $0) }
                        )
                    )
                    .accessibilityHint("Controls whether your predicted third-place team advances to the knockout stage.")
                    .disabled(!prediction.predictedThirdPlaceAdvances && limitReached)
                }
            }

            if !appModel.groupStageValidation.isComplete || !appModel.hasRequiredThirdPlaceAdvancers {
                Section("Needs Attention") {
                    ValidationSummary(
                        validation: appModel.groupStageValidation,
                        selectedThirdPlaceAdvancersCount: appModel.selectedThirdPlaceAdvancersCount,
                        maxThirdPlaceAdvancers: appModel.maxThirdPlaceAdvancers
                    )
                }
            }

            if let backendStatusMessage = appModel.backendStatusMessage {
                Section {
                    Text(backendStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Create Bracket")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onScoringInfo?()
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("How scoring works")
            }
        }
        .environment(\.editMode, $editMode)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    await appModel.submitGroupStageBracketRemotelyAndShowKnockout()
                    if appModel.step == .knockout {
                        onSubmitted?()
                    }
                }
            } label: {
                Text(appModel.isBackendBusy ? "Saving Bracket" : "Continue to Knockout")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!appModel.canSubmitBracket)
            .padding()
            .background(.regularMaterial)
        }
    }
}

private struct ValidationSummary: View {
    let validation: GroupStagePickValidation
    let selectedThirdPlaceAdvancersCount: Int
    let maxThirdPlaceAdvancers: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !validation.missingGroupIDs.isEmpty {
                Text("Missing groups: \(validation.missingGroupIDs.map(\.rawValue).joined(separator: ", "))")
            }
            if !validation.incompleteGroupIDs.isEmpty {
                Text("Incomplete groups: \(validation.incompleteGroupIDs.map(\.rawValue).joined(separator: ", "))")
            }
            if !validation.duplicateGroupIDs.isEmpty {
                Text("Duplicate groups: \(validation.duplicateGroupIDs.map(\.rawValue).joined(separator: ", "))")
            }
            if selectedThirdPlaceAdvancersCount != maxThirdPlaceAdvancers {
                Text("Select exactly \(maxThirdPlaceAdvancers) third-place teams to advance.")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.red)
    }
}

private struct TeamRankRow: View {
    let rank: Int
    let team: AppTeam

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: Circle())

            Text(team.flagEmoji)
                .font(.title2)
                .frame(width: 32, height: 32)
                .background(Color(hex: team.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.headline)
                Text(team.code)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(team.name), position \(rank)")
    }
}
