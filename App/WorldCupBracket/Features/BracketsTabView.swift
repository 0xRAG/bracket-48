import SwiftUI
import WorldCupBracketCore

struct BracketsTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var path: [BracketsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            BracketsDashboardView(
                createGroupAction: {
                    appModel.startNewGroupStageBracket()
                    path.append(.groupBuilder)
                },
                createKnockoutAction: {
                    appModel.startNewKnockoutBracket()
                    path.append(.knockout)
                },
                viewGroupAction: { bracket in
                    appModel.viewBracket(bracket)
                    path.append(.groupSubmitted)
                },
                viewKnockoutAction: { bracket in
                    appModel.viewBracket(bracket)
                    path.append(.knockout)
                }
            )
            .navigationDestination(for: BracketsRoute.self) { route in
                switch route {
                case .groupBuilder:
                    BracketBuilderView(
                        onSubmitted: {
                            path.append(.knockout)
                        },
                        onScoringInfo: {
                            path.append(.scoringGuide)
                        }
                    )
                case .groupSubmitted:
                    SubmittedView()
                case .knockout:
                    KnockoutBracketView {
                        path.removeAll()
                        appModel.showBracketsHome()
                    }
                case .scoringGuide:
                    ScoringGuideView()
                }
            }
        }
        .onChange(of: appModel.selectedTab) { _, selectedTab in
            if selectedTab == .brackets, appModel.step == .home {
                path.removeAll()
            }
        }
    }
}

private enum BracketsRoute: Hashable {
    case groupBuilder
    case groupSubmitted
    case knockout
    case scoringGuide
}

private struct BracketsDashboardView: View {
    @Environment(AppModel.self) private var appModel

    let createGroupAction: () -> Void
    let createKnockoutAction: () -> Void
    let viewGroupAction: (BackendBracketSummary) -> Void
    let viewKnockoutAction: (BackendBracketSummary) -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Brackets")
                        .font(.largeTitle.bold())
                    Text("Manage each full bracket as a group stage and knockout stage pair.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Create") {
                Button(action: createGroupAction) {
                    Text("Create Bracket")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Section("Brackets") {
                if appModel.bracketUnits.isEmpty {
                    ContentUnavailableView(
                        "No Brackets",
                        systemImage: "square.grid.3x3",
                        description: Text("Create a bracket to start with group-stage picks.")
                    )
                } else {
                    ForEach(appModel.bracketUnits) { unit in
                        BracketUnitRow(
                            unit: unit,
                            createKnockoutAction: {
                                appModel.viewBracket(unit.groupBracket)
                                createKnockoutAction()
                            },
                            viewGroupAction: {
                                viewGroupAction(unit.groupBracket)
                            },
                            viewKnockoutAction: {
                                if let knockoutBracket = unit.knockoutBracket {
                                    viewKnockoutAction(knockoutBracket)
                                }
                            },
                            deleteGroupAction: {
                                Task {
                                    await appModel.deleteBracketRemotely(unit.groupBracket)
                                }
                            },
                            deleteKnockoutAction: {
                                guard let knockoutBracket = unit.knockoutBracket else {
                                    return
                                }

                                Task {
                                    await appModel.deleteBracketRemotely(knockoutBracket)
                                }
                            }
                        )
                    }
                }
            }

            if !appModel.unpairedKnockoutBrackets.isEmpty {
                Section("Unpaired Knockout Brackets") {
                    ForEach(appModel.unpairedKnockoutBrackets) { bracket in
                        SavedBracketRow(
                            bracket: bracket,
                            viewAction: {
                                viewKnockoutAction(bracket)
                            },
                            deleteAction: {
                                Task {
                                    await appModel.deleteBracketRemotely(bracket)
                                }
                            }
                        )
                    }
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
        .navigationTitle("Brackets")
        .task {
            await appModel.refreshBackendState()
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
    }
}

private struct BracketUnitRow: View {
    let unit: BracketUnit
    let createKnockoutAction: () -> Void
    let viewGroupAction: () -> Void
    let viewKnockoutAction: () -> Void
    let deleteGroupAction: () -> Void
    let deleteKnockoutAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.fill")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tournament Bracket")
                        .font(.headline)
                    Text(unit.groupBracket.submittedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if unit.isEnteredInGroup {
                    Text("In group")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            BracketComponentRow(
                title: "Group Stage",
                icon: "square.grid.3x3.fill",
                status: "Saved",
                viewAction: viewGroupAction,
                deleteAction: deleteGroupAction,
                canDelete: unit.groupBracket.linkedPoolIDs.isEmpty && unit.knockoutBracket == nil
            )

            if unit.knockoutBracket == nil {
                Button(action: createKnockoutAction) {
                    Text("Create Knockout Stage")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                BracketComponentRow(
                    title: "Knockout Stage",
                    icon: "trophy.fill",
                    status: "Saved",
                    viewAction: viewKnockoutAction,
                    deleteAction: deleteKnockoutAction,
                    canDelete: unit.knockoutBracket?.linkedPoolIDs.isEmpty == true
                )
            }
        }
        .padding(.vertical, 6)
    }
}

private struct BracketComponentRow: View {
    let title: String
    let icon: String
    let status: String
    let viewAction: () -> Void
    let deleteAction: () -> Void
    let canDelete: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 26, height: 26)
                    .foregroundStyle(.green)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: viewAction) {
                    Text("View")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(role: .destructive, action: deleteAction) {
                    Text("Delete")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!canDelete)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SavedBracketRow: View {
    let bracket: BackendBracketSummary
    let viewAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Knockout Bracket")
                        .font(.headline)
                    Text(bracket.submittedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(action: viewAction) {
                    Text("View")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(role: .destructive, action: deleteAction) {
                    Text("Delete")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!bracket.linkedPoolIDs.isEmpty)
            }
        }
        .padding(.vertical, 6)
    }
}
