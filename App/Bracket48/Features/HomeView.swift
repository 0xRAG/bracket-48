import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Hi, \(appModel.firstName)")
                        .font(.largeTitle.bold())

                    Text(appModel.isBracketLocked ? "Your group-stage bracket is saved. Continue managing your tournament picks from Brackets." : "Group-stage picks are open. Rank each real group, then continue into knockout picks.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Button {
                        if appModel.isBracketLocked {
                            appModel.showBracketsHome()
                        } else {
                            appModel.showBracket()
                        }
                    } label: {
                        Text(appModel.isBracketLocked ? "View Group Bracket" : "Create Bracket")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if appModel.isKnockoutBracketOpen {
                        Button {
                            appModel.showKnockout()
                        } label: {
                            Text(appModel.isKnockoutBracketLocked ? "View Knockout Bracket" : "Create Knockout Bracket")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Tournament Phase") {
                InfoRow(
                    icon: appModel.isBracketLocked ? "lock.fill" : "lock.open.fill",
                    title: appModel.isBracketLocked ? "Picks Saved" : "Picks Open",
                    value: "Live"
                )
                InfoRow(icon: "person.2.fill", title: "Entry Limit", value: "One per group")
                InfoRow(icon: "list.number", title: "Bracket", value: appModel.bracketProgressText)
                InfoRow(
                    icon: "trophy.fill",
                    title: "Knockout",
                    value: appModel.isKnockoutBracketLocked ? "Locked" : (appModel.isKnockoutBracketOpen ? "Open" : "Locked")
                )
            }
        }
        .navigationTitle("Home")
        .scrollContentBackground(.hidden)
        .background(AppBackground())
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.green)

            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
