import SwiftUI

struct GroupsTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        switch appModel.step {
        case .group:
            CreateGroupView()
        default:
            GroupsDashboardView()
        }
    }
}

private struct GroupsDashboardView: View {
    @Environment(AppModel.self) private var appModel
    @State private var inviteText = ""
    @State private var joinMessage: String?

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
                            entryStatus: appModel.isBracketLocked ? "Bracket ready" : "No bracket yet"
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

                Button {
                    Task {
                        let joined = await appModel.joinGroupRemotely(inviteText: inviteText)
                        joinMessage = appModel.backendStatusMessage ?? (joined ? "Group joined." : "That invite is already in your groups.")
                        inviteText = ""
                    }
                } label: {
                    Text(appModel.isBackendBusy ? "Joining Group" : "Join Group")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(inviteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isBackendBusy)

                if let joinMessage {
                    Text(joinMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let backendStatusMessage = appModel.backendStatusMessage, backendStatusMessage != joinMessage {
                    Text(backendStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Groups")
        .task {
            await appModel.refreshBackendState()
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
    }
}

private struct GroupMembershipRow: View {
    let group: JoinedGroup
    let entryStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: group.isOwner ? "person.2.fill" : "person.2.badge.plus")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.green)

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
            }

            InfoLine(title: "Invite Code", value: group.inviteCode)

            if let inviteURL = group.inviteURL {
                Text(inviteURL.absoluteString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                ShareLink(item: inviteURL) {
                    Text("Share Invite Link")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.vertical, 6)
    }
}
