import SwiftUI
import Bracket48Core

struct GroupsTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var path: [GroupsRoute] = []
    @State private var didApplyScreenshotRoute = false

    var body: some View {
        NavigationStack(path: $path) {
            switch appModel.step {
            case .group:
                CreateGroupView()
            default:
                GroupsDashboardView(path: $path)
                    .navigationDestination(for: GroupsRoute.self) { route in
                        switch route {
                        case let .detail(groupID):
                            if let group = appModel.joinedGroups.first(where: { $0.id == groupID }) {
                                GroupDetailView(group: group, path: $path)
                            }
                        case let .winner(groupID):
                            if let group = appModel.joinedGroups.first(where: { $0.id == groupID }) {
                                GroupWinnerView(group: group, path: $path)
                            }
                        case let .bracket(entryID):
                            if let entry = appModel.groupBracketEntriesByGroupID.values.flatMap({ $0 }).first(where: { $0.id == entryID }) {
                                ReadOnlyGroupBracketView(entry: entry)
                            }
                        }
                    }
            }
        }
        #if DEBUG
        .task {
            guard !didApplyScreenshotRoute,
                  ProcessInfo.processInfo.arguments.contains("-WCBUseScreenshotFixtures"),
                  let screenshotScreenIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-WCBScreenshotScreen"),
                  ProcessInfo.processInfo.arguments.indices.contains(screenshotScreenIndex + 1),
                  ProcessInfo.processInfo.arguments[screenshotScreenIndex + 1] == "winner",
                  let group = appModel.joinedGroups.first
            else {
                return
            }

            didApplyScreenshotRoute = true
            path = [.winner(group.id)]
        }
        #endif
    }
}

private enum GroupsRoute: Hashable {
    case detail(String)
    case winner(String)
    case bracket(UUID)
}

private struct GroupsDashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var path: [GroupsRoute]
    @State private var inviteText = ""
    @State private var joinMessage: String?
    @State private var isJoiningInvite = false
    @FocusState private var isInviteFieldFocused: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Groups")
                        .font(.largeTitle.bold())
                    Text("Manage pools, review entry status, and invite friends.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if let pendingInvite = appModel.pendingInvite {
                Section("Group Invite") {
                    PendingInviteCard(
                        invite: pendingInvite,
                        isBusy: appModel.isBackendBusy,
                        refreshAction: {
                            Task {
                                await appModel.refreshPendingInvitePreview()
                            }
                        },
                        joinAction: {
                            Task {
                                await appModel.acceptPendingInvite()
                            }
                        },
                        cancelAction: {
                            appModel.clearPendingInvite()
                        }
                    )
                }
            }

            if appModel.joinedGroups.isEmpty {
                Section("Groups") {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "person.2.slash",
                        description: Text("Create a group or join one with an invite code.")
                    )
                }
            } else {
                Section("Groups") {
                    ForEach(appModel.joinedGroups) { group in
                        GroupMembershipRow(
                            group: group,
                            entryStatus: entryStatus(for: group),
                            leaderboard: appModel.leaderboardsByGroupID[group.id] ?? [],
                            viewGroupAction: {
                                path.append(.detail(group.id))
                            },
                            canEnterBracket: canEnterBracket(in: group),
                            enterBracketAction: {
                                Task {
                                    await appModel.enterPrimaryBracketUnitRemotely(in: group)
                                }
                            }
                        )
                    }
                }
            }

            Section("Add") {
                Button {
                    appModel.showGroup()
                } label: {
                    Text("Create Group")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section("Join With Invite") {
                TextField("Invite code or link", text: $inviteText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isInviteFieldFocused)
                    .submitLabel(.join)
                    .onSubmit {
                        Task {
                            await joinInvite()
                        }
                    }
                    .onChange(of: inviteText) { _, _ in
                        joinMessage = nil
                    }

                if !trimmedInviteText.isEmpty || isJoiningInvite {
                    Button {
                        Task {
                            await joinInvite()
                        }
                    } label: {
                        Text(isJoiningInvite ? "Joining Group" : "Join Group")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(trimmedInviteText.isEmpty || isJoiningInvite)
                }

                if let joinMessage {
                    Text(joinMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Groups")
        .scrollDismissesKeyboard(.interactively)
        .task {
            await appModel.refreshBackendState()
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
    }

    private func entryStatus(for group: JoinedGroup) -> String {
        if group.hasGroupStageEntry && group.hasKnockoutEntry {
            return "Full bracket entered"
        }

        if group.hasGroupStageEntry {
            return appModel.primaryBracketUnit?.knockoutBracket == nil ? "Group bracket entered" : "Knockout not entered"
        }

        return appModel.primaryBracketUnit == nil ? "No bracket yet" : "Ready to enter"
    }

    private func canEnterBracket(in group: JoinedGroup) -> Bool {
        guard let primaryBracketUnit = appModel.primaryBracketUnit else {
            return false
        }

        return !group.hasGroupStageEntry || (primaryBracketUnit.knockoutBracket != nil && !group.hasKnockoutEntry)
    }

    private var trimmedInviteText: String {
        inviteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func joinInvite() async {
        guard !trimmedInviteText.isEmpty, !isJoiningInvite else {
            return
        }

        isJoiningInvite = true
        defer {
            isJoiningInvite = false
        }

        let joined = await appModel.joinGroupRemotely(inviteText: trimmedInviteText)
        let message = appModel.backendStatusMessage ?? (joined ? "Group joined." : "That invite is already in your groups.")

        if joined || message == "That invite is already in your groups." {
            inviteText = ""
            isInviteFieldFocused = false
            joinMessage = nil
        } else {
            joinMessage = message
        }
    }
}

private struct PendingInviteCard: View {
    @Environment(AppModel.self) private var appModel

    let invite: PendingInvite
    let isBusy: Bool
    let refreshAction: () -> Void
    let joinAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(appModel.primaryAccentColor.color)

                VStack(alignment: .leading, spacing: 3) {
                    Text(invite.preview?.name ?? "Group Invite")
                        .font(.headline)
                    Text(detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = invite.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(action: cancelAction) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: invite.preview == nil && invite.errorMessage != nil ? refreshAction : joinAction) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBusy)
            }
        }
        .padding(.vertical, 6)
    }

    private var detailText: String {
        if let preview = invite.preview {
            let memberText = preview.memberCount == 1 ? "1 member" : "\(preview.memberCount) members"
            return "\(memberText) joined"
        }

        if isBusy {
            return "Loading invite..."
        }

        return "Invite code \(invite.inviteCode)"
    }

    private var primaryButtonTitle: String {
        if isBusy {
            return "Loading"
        }

        return invite.preview == nil && invite.errorMessage != nil ? "Try Again" : "Join Group"
    }
}

private struct GroupMembershipRow: View {
    @Environment(AppModel.self) private var appModel

    let group: JoinedGroup
    let entryStatus: String
    let leaderboard: [BackendLeaderboardEntry]
    let viewGroupAction: () -> Void
    let canEnterBracket: Bool
    let enterBracketAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: viewGroupAction) {
                HStack(spacing: 12) {
                    Image(systemName: group.isOwner ? "person.2.fill" : "person.2.badge.plus")
                        .frame(width: 32, height: 32)
                        .foregroundStyle(appModel.primaryAccentColor.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.headline)
                        Text(group.isOwner ? "Owned group" : "Joined group")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(entryStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if canEnterBracket {
                Button(action: enterBracketAction) {
                    Text("Enter Bracket")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            LeaderboardPreview(entries: leaderboard)

        }
        .padding(.vertical, 6)
    }
}

private struct LeaderboardPreview: View {
    @Environment(AppModel.self) private var appModel

    let entries: [BackendLeaderboardEntry]

    private var standings: [GroupStandingRow] {
        GroupStandingRow.combined(from: entries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Leaderboard", systemImage: "list.number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appModel.primaryAccentColor.color)
                Spacer()
                if !standings.isEmpty {
                    Text("\(standings.count) scored")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if standings.isEmpty {
                Text("Scores will appear after submitted brackets are evaluated.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(standings.prefix(3).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .leading)

                            Text(entry.displayName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            Spacer()

                            Text("\(entry.totalPoints)")
                                .font(.subheadline.monospacedDigit().weight(.bold))
                            Text("/ \(entry.maxPoints)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
    }
}

private struct GroupDetailView: View {
    @Environment(AppModel.self) private var appModel

    let group: JoinedGroup
    @Binding var path: [GroupsRoute]

    private var participants: [BackendGroupParticipant] {
        appModel.groupParticipantsByGroupID[group.id] ?? []
    }

    private var standings: [GroupStandingRow] {
        GroupStandingRow.combined(from: appModel.leaderboardsByGroupID[group.id] ?? [])
    }

    private var isComplete: Bool {
        !standings.isEmpty && standings.allSatisfy { $0.possiblePointsRemaining == 0 && $0.maxPoints > 0 }
    }

    private var bracketEntries: [BackendGroupBracketEntry] {
        appModel.groupBracketEntriesByGroupID[group.id] ?? []
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.name)
                        .font(.largeTitle.bold())
                    Text(group.isOwner ? "Owned group" : "Joined group")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                if let inviteURL = group.inviteURL {
                    ShareLink(item: inviteURL) {
                        Text("Share Invite Link")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            if isComplete {
                Section {
                    Button {
                        path.append(.winner(group.id))
                    } label: {
                        WinnerEntryCard(standings: standings)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Current Standings") {
                if standings.isEmpty {
                    ContentUnavailableView(
                        "No Scores Yet",
                        systemImage: "list.number",
                        description: Text("Standings will appear after brackets are entered and scored.")
                    )
                } else {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(standing.displayName)
                                    .font(.headline)
                                if standing.possiblePointsRemaining > 0 {
                                    Text("+\(standing.possiblePointsRemaining) possible")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(standing.totalPoints)")
                                .font(.headline.monospacedDigit())
                            Text("/ \(standing.maxPoints)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Participants") {
                if participants.isEmpty {
                    ContentUnavailableView("No Participants", systemImage: "person.2.slash")
                } else {
                    ForEach(participants) { participant in
                        HStack {
                            Image(systemName: participant.role == .owner ? "crown.fill" : "person.fill")
                                .frame(width: 28)
                                .foregroundStyle(appModel.primaryAccentColor.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.displayName)
                                    .font(.headline)
                                Text(participant.role == .owner ? "Owner" : "Member")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Brackets") {
                if bracketEntries.isEmpty {
                    ContentUnavailableView(
                        "No Brackets Entered",
                        systemImage: "square.grid.3x3",
                        description: Text("Entered brackets will appear here.")
                    )
                } else {
                    ForEach(bracketEntries) { entry in
                        Button {
                            path.append(.bracket(entry.id))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: entry.bracket.phase == .groupStage ? "square.grid.3x3.fill" : "trophy.fill")
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(appModel.primaryAccentColor.color)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.participantDisplayName)
                                        .font(.headline)
                                    Text(entry.bracket.phase == .groupStage ? "Group-stage bracket" : "Knockout bracket")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Group")
        .task {
            await appModel.refreshBackendState()
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
    }
}

private struct WinnerEntryCard: View {
    let standings: [GroupStandingRow]

    private var winners: [GroupStandingRow] {
        guard let winningScore = standings.first?.totalPoints else {
            return []
        }

        return standings.filter { $0.totalPoints == winningScore }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: winners.count > 1 ? "trophy.fill" : "crown.fill")
                .font(.title2.weight(.semibold))
                .frame(width: 42, height: 42)
                .foregroundStyle(.yellow)
                .background(.yellow.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(winners.count > 1 ? "Final Tie" : "Winner")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(winnerNames)
                    .font(.headline)
                if let score = standings.first?.totalPoints {
                    Text("\(score) final points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var winnerNames: String {
        winners.map(\.displayName).joined(separator: ", ")
    }
}

private struct GroupWinnerView: View {
    @Environment(AppModel.self) private var appModel

    let group: JoinedGroup
    @Binding var path: [GroupsRoute]

    private var standings: [GroupStandingRow] {
        GroupStandingRow.combined(from: appModel.leaderboardsByGroupID[group.id] ?? [])
    }

    private var winners: [GroupStandingRow] {
        guard let winningScore = standings.first?.totalPoints else {
            return []
        }

        return standings.filter { $0.totalPoints == winningScore }
    }

    private var winningEntries: [BackendGroupBracketEntry] {
        let winnerIDs = Set(winners.map(\.id))
        return (appModel.groupBracketEntriesByGroupID[group.id] ?? [])
            .filter { winnerIDs.contains($0.userID) }
            .sorted {
                if $0.userID == $1.userID {
                    return $0.bracket.phase.rawValue < $1.bracket.phase.rawValue
                }

                return $0.participantDisplayName.localizedCaseInsensitiveCompare($1.participantDisplayName) == .orderedAscending
            }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: winners.count > 1 ? "trophy.fill" : "crown.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.yellow)
                        .frame(width: 72, height: 72)
                        .background(.yellow.opacity(0.18), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(winners.count > 1 ? "Final Tie" : "Final Winner")
                            .font(.largeTitle.bold())
                        Text(winnerNames)
                            .font(.title2.weight(.semibold))
                        Text(group.name)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let score = standings.first?.totalPoints,
                       let maxPoints = standings.first?.maxPoints
                    {
                        HStack(spacing: 10) {
                            Label("\(score)", systemImage: "number")
                                .font(.headline.monospacedDigit())
                            Text("/ \(maxPoints) points")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Final standings are locked for bragging rights only. No prizes, rewards, betting, or gambling.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }

            Section("Final Standings") {
                if standings.isEmpty {
                    ContentUnavailableView("No Final Scores", systemImage: "trophy")
                } else {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)

                            Text(standing.displayName)
                                .font(.headline)

                            Spacer()

                            Text("\(standing.totalPoints)")
                                .font(.headline.monospacedDigit())
                            Text("/ \(standing.maxPoints)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !winningEntries.isEmpty {
                Section(winners.count > 1 ? "Winning Brackets" : "Winning Bracket") {
                    ForEach(winningEntries) { entry in
                        Button {
                            path.append(.bracket(entry.id))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: entry.bracket.phase == .groupStage ? "list.number" : "trophy.fill")
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(entry.bracket.phase == .groupStage ? appModel.primaryAccentColor.color : .yellow)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.participantDisplayName)
                                        .font(.headline)
                                    Text(entry.bracket.phase == .groupStage ? "Group-stage picks" : "Knockout picks")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Winner")
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
    }

    private var winnerNames: String {
        winners.map(\.displayName).joined(separator: winners.count > 2 ? ", " : " & ")
    }
}

private struct ReadOnlyGroupBracketView: View {
    @Environment(AppModel.self) private var appModel

    let entry: BackendGroupBracketEntry

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.participantDisplayName)
                        .font(.title2.bold())
                    Text(entry.bracket.phase == .groupStage ? "Group-stage bracket" : "Knockout bracket")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            switch entry.bracket.phase {
            case .groupStage:
                ForEach(entry.bracket.groupStagePredictions.sorted { $0.groupID < $1.groupID }, id: \.groupID) { prediction in
                    Section("Group \(prediction.groupID)") {
                        ForEach(Array(prediction.orderedTeamIDs.enumerated()), id: \.element) { index, teamID in
                            ReadOnlyTeamRow(rank: index + 1, team: team(for: teamID))
                        }
                        InfoLine(title: "Third Place", value: prediction.predictedThirdPlaceAdvances ? "Advances" : "Does not advance")
                    }
                }
            case .knockout:
                ForEach(KnockoutRound.bracketOrder, id: \.self) { round in
                    let picks = entry.bracket.knockoutPicks.filter { $0.round == round }
                    if !picks.isEmpty {
                        Section(round.title) {
                            ForEach(picks, id: \.matchID) { pick in
                                HStack {
                                    Text(pick.matchID.uppercased())
                                        .font(.caption.monospaced().weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 72, alignment: .leading)
                                    ReadOnlyTeamSummary(team: team(for: pick.pickedWinnerTeamID))
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Bracket")
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
    }

    private func team(for teamID: String) -> AppTeam? {
        appModel.groups.flatMap(\.teams).first { $0.id == teamID }
    }
}

private struct ReadOnlyTeamRow: View {
    let rank: Int
    let team: AppTeam?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: Circle())
            ReadOnlyTeamSummary(team: team)
        }
    }
}

private struct ReadOnlyTeamSummary: View {
    let team: AppTeam?

    var body: some View {
        if let team {
            Text(team.flagEmoji)
                .font(.title3)
                .frame(width: 30, height: 30)
                .background(Color(hex: team.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.headline)
                Text(team.code)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Unknown team")
                .foregroundStyle(.secondary)
        }

        Spacer()
    }
}

private struct GroupStandingRow: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let totalPoints: Int
    let maxPoints: Int
    let possiblePointsRemaining: Int

    static func combined(from entries: [BackendLeaderboardEntry]) -> [GroupStandingRow] {
        let grouped = Dictionary(grouping: entries, by: \.userID)

        return grouped.map { userID, entries in
            GroupStandingRow(
                id: userID,
                displayName: entries.first?.displayName ?? "Player",
                totalPoints: entries.reduce(0) { $0 + $1.totalPoints },
                maxPoints: entries.reduce(0) { $0 + $1.maxPoints },
                possiblePointsRemaining: entries.reduce(0) { $0 + $1.possiblePointsRemaining }
            )
        }
        .sorted {
            if $0.totalPoints == $1.totalPoints {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            return $0.totalPoints > $1.totalPoints
        }
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
