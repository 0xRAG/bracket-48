import SwiftUI
import Bracket48Core

struct KnockoutBracketView: View {
    @Environment(AppModel.self) private var appModel
    var onSubmitted: (() -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                KnockoutHeader()

                ForEach(KnockoutRound.bracketOrder, id: \.self) { round in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(round.title)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(appModel.knockoutBracket.matches(in: round)) { match in
                            KnockoutMatchRow(match: match)
                        }
                    }
                }

                if let champion = appModel.winner(for: "final") {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.green)
                        Text(champion.flagEmoji)
                        Text(champion.name)
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Champion pick, \(champion.name)")
                }

                if let backendStatusMessage = appModel.backendStatusMessage {
                    Text(backendStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .navigationTitle("Knockout")
        .background(AppBackground())
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    let didSubmit = await appModel.submitKnockoutBracketRemotely()
                    if didSubmit {
                        onSubmitted?()
                    }
                }
            } label: {
                Text(appModel.isBackendBusy ? "Saving Knockout Bracket" : appModel.isKnockoutBracketLocked ? "Knockout Bracket Locked" : "Submit Knockout Bracket")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!appModel.canSubmitKnockoutBracket)
            .padding()
            .background(.regularMaterial)
        }
    }
}

private struct KnockoutHeader: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appModel.isKnockoutBracketLocked ? "Knockout Bracket Locked" : "Pick Your Champion")
                .font(.title2.bold())
            Text("Advance winners through each round. Later matchups unlock as your previous picks are made.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            InfoLine(title: "Entry Type", value: "Knockout only")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct KnockoutMatchRow: View {
    @Environment(AppModel.self) private var appModel

    let match: AppKnockoutMatch

    var body: some View {
        let teams = appModel.teams(for: match)
        let winner = appModel.winner(for: match.id)

        VStack(alignment: .leading, spacing: 10) {
            Text(match.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(teams.enumerated()), id: \.offset) { _, team in
                Button {
                    if let team {
                        appModel.pickKnockoutWinner(matchID: match.id, round: match.round, team: team)
                    }
                } label: {
                    HStack {
                        if let team {
                            Text(team.flagEmoji)
                                .font(.title3)
                                .frame(width: 28, height: 28)
                                .background(Color(hex: team.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                            Text(team.name)
                                .font(.headline)
                            Spacer()
                            if winner == team {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        } else {
                            Text("Awaiting previous winner")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(team == nil || appModel.isKnockoutBracketLocked)
                .accessibilityLabel(team.map { "\(match.label), pick \($0.name)" } ?? "\(match.label), awaiting previous winner")
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension KnockoutRound {
    static let bracketOrder: [KnockoutRound] = [.roundOf32, .roundOf16, .quarterfinal, .semifinal, .final]

    var title: String {
        switch self {
        case .roundOf32:
            "Round of 32"
        case .roundOf16:
            "Round of 16"
        case .quarterfinal:
            "Quarterfinals"
        case .semifinal:
            "Semifinals"
        case .final:
            "Final"
        }
    }
}
