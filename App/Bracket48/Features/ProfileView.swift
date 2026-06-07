import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var appModel
    @State private var profileDisplayName = ""
    @State private var isShowingSignOutConfirmation = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        @Bindable var appModel = appModel

        List {
            Section("Account") {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .frame(width: 28, height: 28)
                        .foregroundStyle(appModel.primaryAccentColor.color)

                    Text("Display Name")
                        .font(.headline)

                    TextField("Name", text: $profileDisplayName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .disabled(appModel.isBackendBusy)
                        .onSubmit {
                            saveDisplayNameIfNeeded()
                        }
                }

                if shouldShowSaveDisplayName {
                    Button {
                        saveDisplayNameIfNeeded()
                    } label: {
                        AccountActionRow(
                            icon: "checkmark.circle",
                            title: "Save Display Name",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveDisplayName)
                }

                Button {
                    isShowingSignOutConfirmation = true
                } label: {
                    AccountActionRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)
                .disabled(appModel.isBackendBusy)

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    AccountActionRow(
                        icon: "trash",
                        title: "Delete Account",
                        tint: .red
                    )
                }
                .buttonStyle(.plain)
                .disabled(appModel.isBackendBusy)

                if let backendStatusMessage = appModel.backendStatusMessage {
                    Text(backendStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primary Color")
                        .font(.headline)

                    HStack(spacing: 14) {
                        ForEach(AppAccentColor.allCases) { color in
                            Button {
                                Task {
                                    await appModel.updatePrimaryColorRemotely(color)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 34, height: 34)

                                    if appModel.primaryAccentColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(color == .yellow ? .black : .white)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .strokeBorder(appModel.primaryAccentColor == color ? Color.primary : Color.secondary.opacity(0.35), lineWidth: 2)
                                )
                                .accessibilityLabel(color.name)
                                .accessibilityValue(appModel.primaryAccentColor == color ? "Selected" : "")
                            }
                            .buttonStyle(.plain)
                            .disabled(appModel.isBackendBusy)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("About") {
                InfoLine(title: "App", value: AppBrand.name)
                InfoLine(title: "Purpose", value: "For fun with friends")

                Text(AppBrand.legalDisclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
        .scrollContentBackground(.hidden)
        .background(AppBackground(accentColor: appModel.primaryAccentColor.color))
        .onAppear {
            syncProfileDisplayName(from: appModel.displayName)
        }
        .onChange(of: appModel.displayName) { _, newValue in
            syncProfileDisplayName(from: newValue)
        }
        .alert("Sign out of \(AppBrand.name)?", isPresented: $isShowingSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Sign Out") {
                Task {
                    await appModel.signOutRemotely()
                }
            }
        } message: {
            Text("Your submitted brackets and groups stay saved in your account.")
        }
        .alert("Delete your account?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Delete Account", role: .destructive) {
                Task {
                    await appModel.deleteAccountRemotely()
                }
            }
        } message: {
            Text("This permanently deletes your account, brackets, groups you own, and saved entries.")
        }
    }

    private var normalizedProfileDisplayName: String {
        profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowSaveDisplayName: Bool {
        normalizedProfileDisplayName != appModel.displayName
    }

    private var canSaveDisplayName: Bool {
        !normalizedProfileDisplayName.isEmpty && shouldShowSaveDisplayName && !appModel.isBackendBusy
    }

    private func saveDisplayNameIfNeeded() {
        guard canSaveDisplayName else {
            return
        }

        Task {
            await appModel.updateDisplayNameRemotely(normalizedProfileDisplayName)
        }
    }

    private func syncProfileDisplayName(from displayName: String) {
        guard profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) != displayName else {
            return
        }

        profileDisplayName = displayName
    }
}

private struct AccountActionRow: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(tint)

            Text(title)
                .font(.headline)
                .foregroundStyle(tint)

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
