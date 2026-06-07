import SwiftUI

struct CreateGroupView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Your Group")
                        .font(.title2.bold())
                    Text("Set up a private pool now, then invite friends and add brackets when picks are ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Group Details") {
                TextField("Group name", text: $appModel.groupName)
                    .textContentType(.organizationName)

                InfoLine(title: "Type", value: "Full tournament")
                InfoLine(title: "Entries", value: "One per user")
                InfoLine(title: "Scoring", value: "Default")
            }

            Section("Bracket Entry") {
                InfoLine(title: "Status", value: appModel.isBracketLocked ? "Ready to add" : "Can be added later")
                InfoLine(title: "Group-stage picks", value: appModel.isBracketLocked ? "Saved" : "Not required yet")
            }

            if let backendStatusMessage = appModel.backendStatusMessage {
                Section {
                    Text(backendStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Create Group")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    appModel.cancelGroupCreation()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    await appModel.createGroupRemotely()
                }
            } label: {
                Text(appModel.isBackendBusy ? "Creating Group" : "Create Group")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!appModel.canCreateGroup)
            .padding()
            .background(.regularMaterial)
        }
    }
}
