import Foundation
import Observation
import Bracket48Core

@Observable
final class AppModel {
    enum Step {
        case signUp
        case home
        case bracket
        case group
        case knockout
        case submitted
    }

    enum AppTab: Hashable {
        case home
        case brackets
        case groups
        case profile
    }

    @ObservationIgnored private let localStore: DraftStateStore
    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private var hasHydratedAuthenticatedSession = false

    var step: Step = .signUp
    var selectedTab: AppTab = .home
    var backendStatusMessage: String?
    var isBackendBusy = false
    var displayName = ""
    var primaryColorID = AppAccentColor.green.rawValue
    var groupName = ""
    var selectedGroupID: String?
    var predictions: [GroupStagePredictionDraft]
    var joinedGroups: [JoinedGroup]
    var backendBrackets: [BackendBracketSummary]
    var tournamentMatches: [BackendTournamentMatch]
    var groupStandings: [BackendGroupStanding]
    var leaderboardsByGroupID: [String: [BackendLeaderboardEntry]]
    var groupParticipantsByGroupID: [String: [BackendGroupParticipant]]
    var groupBracketEntriesByGroupID: [String: [BackendGroupBracketEntry]]
    var submittedEntry: SubmittedEntry?
    var knockoutPicks: [KnockoutPickDraft]
    var submittedKnockoutEntry: SubmittedKnockoutEntry?
    var pendingInvite: PendingInvite?

    let tournament: Tournament
    let groups: [AppGroup]

    var knockoutBracket: AppKnockoutBracket {
        TournamentFixtures.appKnockoutBracket(
            from: tournament,
            groupStagePredictions: submittedEntry?.predictions ?? predictions
        )
    }

    init(localStore: DraftStateStore = DraftStateStore()) {
        self.localStore = localStore
        let configuration = AppConfiguration.main
        if configuration.isSupabaseConfigured,
           let liveServices = try? AppServices.live(configuration: configuration)
        {
            services = liveServices
        } else {
            services = .unconfigured
        }
        tournament = TournamentFixtures.tournament
        groups = TournamentFixtures.appGroups(from: tournament)
        predictions = Self.defaultPredictions(groups: groups)
        joinedGroups = []
        backendBrackets = []
        tournamentMatches = []
        groupStandings = []
        leaderboardsByGroupID = [:]
        groupParticipantsByGroupID = [:]
        groupBracketEntriesByGroupID = [:]
        knockoutPicks = []

        if let restoredState = localStore.load(),
           restoredState.schemaVersion == LocalDraftState.currentSchemaVersion
        {
            restore(restoredState)
        }

        #if DEBUG
        applyScreenshotFixtureIfRequested()
        #endif
    }

    var localState: LocalDraftState {
        LocalDraftState(
            currentScreen: step.localScreen,
            displayName: displayName,
            primaryColorID: primaryColorID,
            groupName: groupName,
            selectedGroupID: selectedGroupID,
            groupStagePredictions: predictions.map(\.localPrediction),
            knockoutPicks: knockoutPicks.map(\.localPick),
            joinedGroups: joinedGroups.map(\.localGroup),
            submittedEntry: submittedEntry.map { entry in
                LocalSubmittedEntry(
                    groupName: entry.groupName,
                    displayName: entry.displayName,
                    groupStagePredictions: entry.predictions.map(\.localPrediction)
                )
            },
            submittedKnockoutEntry: submittedKnockoutEntry.map { entry in
                LocalSubmittedKnockoutEntry(
                    groupName: entry.groupName,
                    displayName: entry.displayName,
                    picks: entry.picks.map(\.localPick)
                )
            }
        )
    }

    private static func defaultPredictions(groups: [AppGroup]) -> [GroupStagePredictionDraft] {
        groups.enumerated().map { index, group in
            GroupStagePredictionDraft(
                groupID: group.id,
                orderedTeams: group.teams,
                predictedThirdPlaceAdvances: index < AdvancementRules.worldCup2026.bestThirdPlaceAdvancers
            )
        }
    }

    var firstName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed.components(separatedBy: " ").first ?? trimmed
    }

    var primaryAccentColor: AppAccentColor {
        AppAccentColor.normalized(primaryColorID)
    }

    var canContinueFromSignUp: Bool {
        true
    }

    var canSubmitBracket: Bool {
        groupStageValidation.isComplete && hasRequiredThirdPlaceAdvancers && canEditGroupStageBracket && !isBackendBusy
    }

    var canStartGroupCreation: Bool {
        true
    }

    var canCreateGroup: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBackendBusy
    }

    var bracketProgressText: String {
        if isBracketLocked || !groupStageBrackets.isEmpty {
            "Saved"
        } else if hasGroupStageDraftChanges {
            "In Progress"
        } else {
            "Not Started"
        }
    }

    var maxThirdPlaceAdvancers: Int {
        tournament.advancementRules.bestThirdPlaceAdvancers
    }

    var selectedThirdPlaceAdvancersCount: Int {
        predictions.filter(\.predictedThirdPlaceAdvances).count
    }

    var hasRequiredThirdPlaceAdvancers: Bool {
        selectedThirdPlaceAdvancersCount == maxThirdPlaceAdvancers
    }

    var isBracketLocked: Bool {
        submittedEntry != nil
    }

    var isEditingSavedGroupStageBracket: Bool {
        submittedEntry?.backendID != nil
    }

    var canEditGroupStageBracket: Bool {
        guard let groupStageBracketID = submittedEntry?.backendID else {
            return true
        }

        return !knockoutBrackets.contains { $0.groupStageBracketID == groupStageBracketID }
    }

    var isKnockoutBracketLocked: Bool {
        submittedKnockoutEntry != nil
    }

    var isKnockoutBracketOpen: Bool {
        submittedEntry != nil || !groupStageBrackets.isEmpty
    }

    var groupStageBrackets: [BackendBracketSummary] {
        backendBrackets.filter { $0.phase == .groupStage }
    }

    var knockoutBrackets: [BackendBracketSummary] {
        backendBrackets.filter { $0.phase == .knockout }
    }

    var bracketUnits: [BracketUnit] {
        groupStageBrackets.map { groupBracket in
            BracketUnit(
                id: groupBracket.id,
                groupBracket: groupBracket,
                knockoutBracket: knockoutBrackets.first { $0.groupStageBracketID == groupBracket.id }
            )
        }
    }

    var unpairedKnockoutBrackets: [BackendBracketSummary] {
        knockoutBrackets.filter { $0.groupStageBracketID == nil || !groupStageBrackets.map(\.id).contains($0.groupStageBracketID!) }
    }

    var primaryBracketUnit: BracketUnit? {
        bracketUnits.first
    }

    var groupStageValidation: GroupStagePickValidation {
        GroupStagePickValidator.validate(
            predictions: predictions.map(\.corePrediction),
            expectedGroupIDs: groups.map { GroupID($0.id) }
        )
    }

    var hasGroupStageDraftChanges: Bool {
        predictions != Self.defaultPredictions(groups: groups)
    }

    var knockoutValidation: KnockoutPickValidation {
        KnockoutPickValidator.validate(
            picks: knockoutPicks.map(\.corePick),
            expectedMatchIDs: knockoutBracket.matches.map { MatchID($0.id) }
        )
    }

    var canSubmitKnockoutBracket: Bool {
        isKnockoutBracketOpen && knockoutValidation.isComplete && !isKnockoutBracketLocked && !isBackendBusy
    }

    var isLiveBackendConfigured: Bool {
        AppConfiguration.main.isSupabaseConfigured
    }

    var primaryGroupInviteCode: String {
        primaryJoinedGroup?.inviteCode ?? "WORLD26"
    }

    var primaryGroupInviteURL: URL? {
        primaryJoinedGroup?.inviteURL
    }

    var primaryJoinedGroup: JoinedGroup? {
        if let selectedGroupID,
           let group = joinedGroups.first(where: { $0.id == selectedGroupID })
        {
            return group
        }

        return joinedGroups.first
    }

    func completeSignUp() {
        guard canContinueFromSignUp else {
            return
        }

        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = "Player"
        }

        selectedTab = pendingInvite == nil ? .home : .groups
        step = .home
        persist()
    }

    @MainActor
    func hydrateAuthenticatedSession() async {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("-WCBUseScreenshotFixtures") else {
            return
        }
        #endif

        guard isLiveBackendConfigured else {
            return
        }

        guard !hasHydratedAuthenticatedSession else {
            return
        }
        hasHydratedAuthenticatedSession = true

        do {
            guard let profile = try await services.auth.currentUser() else {
                if step != .signUp {
                    resetForSignedOutUser()
                }
                return
            }

            let localDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteDisplayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            if remoteDisplayName == "Player",
               !localDisplayName.isEmpty,
               localDisplayName != "Player"
            {
                let repairedProfile = try await services.auth.updateDisplayName(localDisplayName)
                displayName = repairedProfile.displayName
                primaryColorID = repairedProfile.primaryColorID
            } else {
                displayName = profile.displayName
                primaryColorID = profile.primaryColorID
            }

            if step == .signUp {
                selectedTab = pendingInvite == nil ? .home : .groups
                step = .home
            }

            persist()

            if pendingInvite != nil {
                await refreshPendingInvitePreview()
            }

            await refreshBackendState()
        } catch {
            backendStatusMessage = "Could not refresh your profile. \(error.localizedDescription)"
        }
    }

    @MainActor
    func refreshBackendState() async {
        await runBackendOperation(successMessage: nil) {
            let pools = try await services.pools.listPools()
            joinedGroups = pools.map(JoinedGroup.init(summary:))

            let brackets = try await services.brackets.listBrackets()
            applyBackendBrackets(brackets)

            tournamentMatches = try await services.results.listTournamentMatches()
            groupStandings = try await services.results.listGroupStandings()
            leaderboardsByGroupID = try await Self.loadLeaderboards(for: joinedGroups, resultsService: services.results)
            groupParticipantsByGroupID = try await Self.loadParticipants(for: joinedGroups, poolService: services.pools)
            groupBracketEntriesByGroupID = try await Self.loadBracketEntries(for: joinedGroups, poolService: services.pools)
            persist()
        }
    }

    func showHome() {
        selectedTab = .home
        step = .home
        persist()
    }

    func showBracketsHome() {
        selectedTab = .brackets
        step = .home
        persist()
    }

    func startNewGroupStageBracket() {
        selectedTab = .brackets
        predictions = Self.defaultPredictions(groups: groups)
        knockoutPicks = []
        submittedEntry = nil
        submittedKnockoutEntry = nil
        step = .bracket
        persist()
    }

    func startNewKnockoutBracket() {
        selectedTab = .brackets
        guard isKnockoutBracketOpen else {
            return
        }

        knockoutPicks = []
        submittedKnockoutEntry = nil
        step = .knockout
        persist()
    }

    func viewBracket(_ bracket: BackendBracketSummary) {
        selectedTab = .brackets

        switch bracket.phase {
        case .groupStage:
            applyGroupStageBracket(bracket)
            step = .bracket
        case .knockout:
            if submittedEntry == nil, let latestGroupStage = groupStageBrackets.first {
                applyGroupStageBracket(latestGroupStage)
            }
            applyKnockoutBracket(bracket)
            step = .knockout
        }

        persist()
    }

    func showBracket() {
        selectedTab = .brackets
        step = .bracket
        persist()
    }

    func showGroup() {
        selectedTab = .groups
        step = .group
        persist()
    }

    @MainActor
    func enterPrimaryBracketUnitRemotely(in group: JoinedGroup) async {
        guard let poolID = UUID(uuidString: group.id),
              let bracketUnit = primaryBracketUnit
        else {
            backendStatusMessage = "Create a bracket before entering a group."
            return
        }

        await runBackendOperation(successMessage: "Bracket entered in group.") {
            if !bracketUnit.groupBracket.linkedPoolIDs.contains(poolID) {
                try await services.brackets.enterBracket(
                    bracketID: bracketUnit.groupBracket.id,
                    poolID: poolID,
                    phase: .groupStage
                )
            }

            if let knockoutBracket = bracketUnit.knockoutBracket,
               !knockoutBracket.linkedPoolIDs.contains(poolID)
            {
                try await services.brackets.enterBracket(
                    bracketID: knockoutBracket.id,
                    poolID: poolID,
                    phase: .knockout
                )
            }

            let pools = try await services.pools.listPools()
            joinedGroups = pools.map(JoinedGroup.init(summary:))
            let brackets = try await services.brackets.listBrackets()
            applyBackendBrackets(brackets)
            leaderboardsByGroupID = try await Self.loadLeaderboards(for: joinedGroups, resultsService: services.results)
            groupParticipantsByGroupID = try await Self.loadParticipants(for: joinedGroups, poolService: services.pools)
            groupBracketEntriesByGroupID = try await Self.loadBracketEntries(for: joinedGroups, poolService: services.pools)
            persist()
        }
    }

    func showKnockout() {
        selectedTab = .brackets
        guard isKnockoutBracketOpen else {
            return
        }

        step = .knockout
        persist()
    }

    func moveTeam(groupID: String, from source: IndexSet, to destination: Int) {
        guard canEditGroupStageBracket else {
            return
        }

        guard let index = predictions.firstIndex(where: { $0.groupID == groupID }) else {
            return
        }

        predictions[index].orderedTeams.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func setThirdPlaceAdvances(groupID: String, advances: Bool) {
        guard canEditGroupStageBracket else {
            return
        }

        guard let index = predictions.firstIndex(where: { $0.groupID == groupID }) else {
            return
        }

        if advances,
           !predictions[index].predictedThirdPlaceAdvances,
           selectedThirdPlaceAdvancersCount >= maxThirdPlaceAdvancers
        {
            return
        }

        predictions[index].predictedThirdPlaceAdvances = advances
        persist()
    }

    @MainActor
    func createGroupRemotely() async {
        guard canCreateGroup else {
            return
        }

        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        await runBackendOperation(successMessage: "Group created.") {
            let summary = try await services.pools.createPool(
                CreatePoolRequest(name: trimmedGroupName, type: .fullTournament)
            )
            let newGroup = JoinedGroup(summary: summary)
            joinedGroups.removeAll { $0.id == newGroup.id }
            joinedGroups.append(newGroup)
            selectedGroupID = newGroup.id
            groupName = ""
            selectedTab = .groups
            step = .home
            persist()
        }
    }

    @MainActor
    func submitGroupStageBracketRemotelyAndShowKnockout() async {
        guard canSubmitBracket else {
            return
        }

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        await runBackendOperation(successMessage: nil) {
            let submission = GroupStageBracketSubmission(displayName: trimmedDisplayName, predictions: predictions)
            let summary: BackendBracketSummary
            if let groupStageBracketID = submittedEntry?.backendID {
                summary = try await services.brackets.updateGroupStageBracket(id: groupStageBracketID, submission)
            } else {
                summary = try await services.brackets.submitGroupStageBracket(submission)
            }
            submittedEntry = SubmittedEntry(
                backendID: summary.id,
                groupName: SubmittedEntry.standaloneGroupName,
                displayName: trimmedDisplayName,
                predictions: predictions
            )
            upsertBackendBracket(summary)
            selectedTab = .brackets
            step = .knockout
            persist()
        }
    }

    func cancelGroupCreation() {
        groupName = ""
        selectedTab = .groups
        step = .home
        persist()
    }

    @MainActor
    @discardableResult
    func joinGroupRemotely(inviteText: String) async -> Bool {
        guard let inviteCode = InviteCodeNormalizer.normalizedInviteCode(from: inviteText) else {
            backendStatusMessage = "Enter a valid invite code or link."
            return false
        }

        if let existingGroup = joinedGroups.first(where: { $0.inviteCode == inviteCode }) {
            selectedGroupID = existingGroup.id
            persist()
            backendStatusMessage = "That invite is already in your groups."
            return false
        }

        var didJoin = false
        await runBackendOperation(successMessage: "Group joined.") {
            let summary = try await services.pools.joinPool(inviteCode: inviteCode)
            let joinedGroup = JoinedGroup(summary: summary)
            joinedGroups.removeAll { $0.id == joinedGroup.id }
            joinedGroups.append(joinedGroup)
            selectedGroupID = joinedGroup.id
            selectedTab = .groups
            step = .home
            if pendingInvite?.inviteCode == inviteCode {
                pendingInvite = nil
            }
            didJoin = true
            persist()
        }
        return didJoin
    }

    @MainActor
    func handleIncomingURL(_ url: URL) {
        guard let inviteCode = InviteCodeNormalizer.normalizedInviteCode(from: url.absoluteString) else {
            backendStatusMessage = "That invite link is not valid."
            return
        }

        selectedTab = .groups
        pendingInvite = PendingInvite(inviteCode: inviteCode, preview: nil, errorMessage: nil)

        if step == .signUp {
            backendStatusMessage = "Sign in to join this group."
        } else {
            step = .home
            Task { @MainActor [weak self] in
                await self?.refreshPendingInvitePreview()
            }
        }

        persist()
    }

    @MainActor
    func refreshPendingInvitePreview() async {
        guard let inviteCode = pendingInvite?.inviteCode else {
            return
        }

        if let existingGroup = joinedGroups.first(where: { $0.inviteCode == inviteCode }) {
            selectedGroupID = existingGroup.id
            pendingInvite = nil
            selectedTab = .groups
            backendStatusMessage = "That invite is already in your groups."
            persist()
            return
        }

        isBackendBusy = true
        backendStatusMessage = nil
        defer {
            isBackendBusy = false
        }

        do {
            guard let preview = try await services.pools.previewInvite(inviteCode: inviteCode) else {
                pendingInvite = PendingInvite(
                    inviteCode: inviteCode,
                    preview: nil,
                    errorMessage: "This invite is invalid or no longer open."
                )
                persist()
                return
            }

            pendingInvite = PendingInvite(inviteCode: inviteCode, preview: preview, errorMessage: nil)
            selectedTab = .groups
            persist()
        } catch {
            pendingInvite = PendingInvite(
                inviteCode: inviteCode,
                preview: nil,
                errorMessage: "Could not load this invite. \(error.localizedDescription)"
            )
            persist()
        }
    }

    @MainActor
    @discardableResult
    func acceptPendingInvite() async -> Bool {
        guard let inviteCode = pendingInvite?.inviteCode else {
            return false
        }

        return await joinGroupRemotely(inviteText: inviteCode)
    }

    func clearPendingInvite() {
        pendingInvite = nil
        backendStatusMessage = nil
        persist()
    }

    func pickKnockoutWinner(matchID: String, round: KnockoutRound, team: AppTeam) {
        guard !isKnockoutBracketLocked else {
            return
        }

        knockoutPicks.removeAll { pick in
            pick.matchID == matchID || knockoutBracket.downstreamMatchIDs(after: matchID).contains(pick.matchID)
        }
        knockoutPicks.append(KnockoutPickDraft(matchID: matchID, round: round, pickedWinner: team))
        persist()
    }

    func winner(for matchID: String) -> AppTeam? {
        knockoutPicks.first { $0.matchID == matchID }?.pickedWinner
    }

    func teams(for match: AppKnockoutMatch) -> [AppTeam?] {
        if match.round == .roundOf32 {
            return [match.homeTeam, match.awayTeam]
        }

        return match.sourceMatchIDs.map { winner(for: $0) }
    }

    @MainActor
    @discardableResult
    func submitKnockoutBracketRemotely() async -> Bool {
        guard canSubmitKnockoutBracket else {
            return false
        }

        var didSubmit = false
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        await runBackendOperation(successMessage: "Knockout bracket saved.") {
            let summary = try await services.brackets.submitKnockoutBracket(
                KnockoutBracketSubmission(
                    displayName: trimmedDisplayName,
                    groupStageBracketID: submittedEntry?.backendID,
                    picks: knockoutPicks
                )
            )
            submittedKnockoutEntry = SubmittedKnockoutEntry(
                backendID: summary.id,
                groupName: "Knockout Pool",
                displayName: trimmedDisplayName,
                picks: knockoutPicks
            )
            upsertBackendBracket(summary)
            selectedTab = .brackets
            step = .submitted
            didSubmit = true
            persist()
        }
        return didSubmit
    }

    @MainActor
    func deleteBracketRemotely(_ bracket: BackendBracketSummary) async {
        guard bracket.linkedPoolIDs.isEmpty else {
            backendStatusMessage = "Withdraw this bracket from its group before deleting it."
            return
        }

        await runBackendOperation(successMessage: "Bracket deleted.") {
            try await services.brackets.deleteBracket(id: bracket.id)
            backendBrackets.removeAll { $0.id == bracket.id }

            if submittedEntry?.backendID == bracket.id {
                submittedEntry = nil
                predictions = Self.defaultPredictions(groups: groups)
            }

            if submittedKnockoutEntry?.backendID == bracket.id {
                submittedKnockoutEntry = nil
                knockoutPicks = []
            }

            persist()
        }
    }

    @MainActor
    func updateDisplayNameRemotely(_ proposedDisplayName: String) async {
        let trimmedName = proposedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            backendStatusMessage = "Enter a display name."
            return
        }

        await runBackendOperation(successMessage: "Display name saved.") {
            let profile = try await services.auth.updateDisplayName(trimmedName)
            displayName = profile.displayName
            primaryColorID = profile.primaryColorID
            persist()
        }
    }

    @MainActor
    func updatePrimaryColorRemotely(_ color: AppAccentColor) async {
        primaryColorID = color.rawValue
        persist()

        await runBackendOperation(successMessage: nil) {
            let profile = try await services.auth.updatePrimaryColor(color.rawValue)
            primaryColorID = profile.primaryColorID
            persist()
        }
    }

    @MainActor
    func signOutRemotely() async {
        await runAccountExitOperation {
            try await services.auth.signOut()
        }
    }

    @MainActor
    func deleteAccountRemotely() async {
        await runAccountExitOperation {
            try await services.auth.deleteAccount()
        }
    }

    private func restore(_ state: LocalDraftState) {
        displayName = state.displayName
        primaryColorID = state.primaryColorID
        groupName = state.submittedEntry == nil ? state.groupName : ""
        selectedGroupID = state.selectedGroupID
        predictions = restoredPredictions(from: state.groupStagePredictions)
        knockoutPicks = restoredKnockoutPicks(from: state.knockoutPicks)
        joinedGroups = restoredJoinedGroups(from: state)
            submittedEntry = state.submittedEntry.map { entry in
                SubmittedEntry(
                    backendID: nil,
                    groupName: entry.groupName,
                    displayName: entry.displayName,
                    predictions: restoredPredictions(from: entry.groupStagePredictions)
            )
        }
            submittedKnockoutEntry = state.submittedKnockoutEntry.map { entry in
                SubmittedKnockoutEntry(
                    backendID: nil,
                    groupName: entry.groupName,
                    displayName: entry.displayName,
                    picks: restoredKnockoutPicks(from: entry.picks)
            )
        }
        step = Step(localScreen: state.currentScreen, hasSubmittedEntry: submittedEntry != nil)
        selectedTab = AppTab(step: step)
    }

    private func restoredPredictions(from localPredictions: [LocalGroupStagePrediction]) -> [GroupStagePredictionDraft] {
        guard !localPredictions.isEmpty else {
            return Self.defaultPredictions(groups: groups)
        }

        let teamsByID = Dictionary(uniqueKeysWithValues: groups.flatMap(\.teams).map { ($0.id, $0) })

        var restored: [GroupStagePredictionDraft] = localPredictions.compactMap { localPrediction in
            let orderedTeams = localPrediction.orderedTeamIDs.compactMap { teamsByID[$0.rawValue] }
            guard orderedTeams.count == localPrediction.orderedTeamIDs.count else {
                return nil
            }

            return GroupStagePredictionDraft(
                groupID: localPrediction.groupID.rawValue,
                orderedTeams: orderedTeams,
                predictedThirdPlaceAdvances: localPrediction.predictedThirdPlaceAdvances
            )
        }

        trimExcessThirdPlaceAdvancers(in: &restored)
        return restored
    }

    private func trimExcessThirdPlaceAdvancers(in predictions: inout [GroupStagePredictionDraft]) {
        var selectedCount = 0
        for index in predictions.indices {
            guard predictions[index].predictedThirdPlaceAdvances else {
                continue
            }

            selectedCount += 1
            if selectedCount > maxThirdPlaceAdvancers {
                predictions[index].predictedThirdPlaceAdvances = false
            }
        }
    }

    private func persist() {
        localStore.save(localState)
    }

    @MainActor
    private func runBackendOperation(successMessage: String?, operation: () async throws -> Void) async {
        isBackendBusy = true
        backendStatusMessage = nil
        defer {
            isBackendBusy = false
        }

        do {
            try await operation()
            backendStatusMessage = successMessage
        } catch {
            backendStatusMessage = "Backend request failed. \(error.localizedDescription)"
        }
    }

    @MainActor
    private func runAccountExitOperation(operation: () async throws -> Void) async {
        isBackendBusy = true
        backendStatusMessage = nil
        defer {
            isBackendBusy = false
        }

        do {
            try await operation()
            resetForSignedOutUser()
        } catch {
            backendStatusMessage = "Account request failed. \(error.localizedDescription)"
        }
    }

    private func resetForSignedOutUser() {
        displayName = ""
        primaryColorID = AppAccentColor.green.rawValue
        groupName = ""
        selectedGroupID = nil
        predictions = Self.defaultPredictions(groups: groups)
        joinedGroups = []
        backendBrackets = []
        tournamentMatches = []
        groupStandings = []
        leaderboardsByGroupID = [:]
        groupParticipantsByGroupID = [:]
        groupBracketEntriesByGroupID = [:]
        submittedEntry = nil
        knockoutPicks = []
        submittedKnockoutEntry = nil
        pendingInvite = nil
        selectedTab = .home
        step = .signUp
        backendStatusMessage = nil
        localStore.reset()
    }

    private func applyBackendBrackets(_ brackets: [BackendBracketSummary]) {
        backendBrackets = brackets

        if let groupStageBracket = brackets.first(where: { $0.phase == .groupStage }) {
            applyGroupStageBracket(groupStageBracket)
        } else {
            submittedEntry = nil
        }

        if let knockoutBracket = brackets.first(where: { $0.phase == .knockout }) {
            applyKnockoutBracket(knockoutBracket)
        } else {
            submittedKnockoutEntry = nil
        }
    }

    private func applyGroupStageBracket(_ bracket: BackendBracketSummary) {
        let backendPredictions = restoredPredictions(from: bracket.groupStagePredictions)
        if !backendPredictions.isEmpty {
            predictions = backendPredictions
        }

        submittedEntry = SubmittedEntry(
            backendID: bracket.id,
            groupName: bracket.linkedPoolIDs.isEmpty ? SubmittedEntry.standaloneGroupName : "Linked Group Bracket",
            displayName: bracket.displayName,
            predictions: backendPredictions.isEmpty ? predictions : backendPredictions
        )
    }

    private func applyKnockoutBracket(_ bracket: BackendBracketSummary) {
        let backendPicks = restoredKnockoutPicks(from: bracket.knockoutPicks)
        if !backendPicks.isEmpty {
            knockoutPicks = backendPicks
        }

        submittedKnockoutEntry = SubmittedKnockoutEntry(
            backendID: bracket.id,
            groupName: bracket.linkedPoolIDs.isEmpty ? "Standalone Knockout" : "Linked Knockout",
            displayName: bracket.displayName,
            picks: backendPicks.isEmpty ? knockoutPicks : backendPicks
        )
    }

    private func upsertBackendBracket(_ bracket: BackendBracketSummary) {
        backendBrackets.removeAll { $0.id == bracket.id }
        backendBrackets.insert(bracket, at: 0)
    }

    private static func loadLeaderboards(
        for groups: [JoinedGroup],
        resultsService: any ResultsServicing
    ) async throws -> [String: [BackendLeaderboardEntry]] {
        var leaderboards: [String: [BackendLeaderboardEntry]] = [:]
        for group in groups {
            guard let poolID = UUID(uuidString: group.id) else {
                continue
            }

            leaderboards[group.id] = try await resultsService.listLeaderboard(poolID: poolID)
        }

        return leaderboards
    }

    private static func loadParticipants(
        for groups: [JoinedGroup],
        poolService: any PoolServicing
    ) async throws -> [String: [BackendGroupParticipant]] {
        var participantsByGroupID: [String: [BackendGroupParticipant]] = [:]
        for group in groups {
            guard let poolID = UUID(uuidString: group.id) else {
                continue
            }

            participantsByGroupID[group.id] = try await poolService.listParticipants(poolID: poolID)
        }

        return participantsByGroupID
    }

    private static func loadBracketEntries(
        for groups: [JoinedGroup],
        poolService: any PoolServicing
    ) async throws -> [String: [BackendGroupBracketEntry]] {
        var entriesByGroupID: [String: [BackendGroupBracketEntry]] = [:]
        for group in groups {
            guard let poolID = UUID(uuidString: group.id) else {
                continue
            }

            entriesByGroupID[group.id] = try await poolService.listBracketEntries(poolID: poolID)
        }

        return entriesByGroupID
    }

    private func restoredJoinedGroups(from state: LocalDraftState) -> [JoinedGroup] {
        if !state.joinedGroups.isEmpty {
            return state.joinedGroups.map(JoinedGroup.init(localGroup:))
        }

        guard let entry = state.submittedEntry else {
            return []
        }

        guard entry.groupName != SubmittedEntry.standaloneGroupName else {
            return []
        }

        return [
            JoinedGroup(
                id: state.selectedGroupID ?? UUID().uuidString,
                name: entry.groupName,
                inviteCode: inviteCode(for: entry.groupName),
                isOwner: true
            )
        ]
    }

    private func restoredKnockoutPicks(from localPicks: [LocalKnockoutPick]) -> [KnockoutPickDraft] {
        let teamsByID = Dictionary(uniqueKeysWithValues: groups.flatMap(\.teams).map { ($0.id, $0) })

        return localPicks.compactMap { pick in
            guard let team = teamsByID[pick.pickedWinnerTeamID.rawValue] else {
                return nil
            }

            return KnockoutPickDraft(matchID: pick.matchID.rawValue, round: pick.round, pickedWinner: team)
        }
    }

    private func restoredPredictions(from backendPredictions: [BackendGroupStagePrediction]) -> [GroupStagePredictionDraft] {
        guard !backendPredictions.isEmpty else {
            return []
        }

        let teamsByID = Dictionary(uniqueKeysWithValues: groups.flatMap(\.teams).map { ($0.id, $0) })
        var restored: [GroupStagePredictionDraft] = backendPredictions.compactMap { backendPrediction in
            let orderedTeams = backendPrediction.orderedTeamIDs.compactMap { teamsByID[$0] }
            guard orderedTeams.count == backendPrediction.orderedTeamIDs.count else {
                return nil
            }

            return GroupStagePredictionDraft(
                groupID: backendPrediction.groupID,
                orderedTeams: orderedTeams,
                predictedThirdPlaceAdvances: backendPrediction.predictedThirdPlaceAdvances
            )
        }

        trimExcessThirdPlaceAdvancers(in: &restored)
        return restored
    }

    private func restoredKnockoutPicks(from backendPicks: [BackendKnockoutPick]) -> [KnockoutPickDraft] {
        let teamsByID = Dictionary(uniqueKeysWithValues: groups.flatMap(\.teams).map { ($0.id, $0) })

        return backendPicks.compactMap { pick in
            guard let team = teamsByID[pick.pickedWinnerTeamID] else {
                return nil
            }

            return KnockoutPickDraft(matchID: pick.matchID, round: pick.round, pickedWinner: team)
        }
    }

    private func inviteCode(for name: String) -> String {
        let normalizedName = name.uppercased().filter { character in
            character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        }
        let baseCode = String(normalizedName.prefix(6)).isEmpty ? "WORLD" : String(normalizedName.prefix(6))
        var code = baseCode
        var suffix = 2

        while joinedGroups.contains(where: { $0.inviteCode == code }) {
            code = "\(baseCode)\(suffix)"
            suffix += 1
        }

        return String(code.prefix(8))
    }

    #if DEBUG
    private func applyScreenshotFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-WCBUseScreenshotFixtures") else {
            return
        }

        displayName = "Ryan"
        primaryColorID = AppAccentColor.green.rawValue
        groupName = ""
        selectedGroupID = "screenshot-group-1"
        joinedGroups = [
            JoinedGroup(id: "screenshot-group-1", name: "Saturday Crew", inviteCode: "BRKT48", isOwner: true, entryPhases: [.groupStage, .knockout]),
            JoinedGroup(id: "screenshot-group-2", name: "Office Picks", inviteCode: "OFFICE", isOwner: false)
        ]
        predictions = Self.defaultPredictions(groups: groups).map { prediction in
            var updatedPrediction = prediction
            if prediction.groupID == "A" {
                updatedPrediction.orderedTeams = Array(prediction.orderedTeams.reversed())
            }
            return updatedPrediction
        }
        submittedEntry = SubmittedEntry(
            backendID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            groupName: SubmittedEntry.standaloneGroupName,
            displayName: displayName,
            predictions: predictions
        )
        let screenshotWinner = groups.first?.teams.first
        let screenshotKnockoutPicks = knockoutBracket.matches.compactMap { match -> BackendKnockoutPick? in
            guard let screenshotWinner else {
                return nil
            }

            return BackendKnockoutPick(
                matchID: match.id,
                round: match.round,
                pickedWinnerTeamID: screenshotWinner.id
            )
        }
        knockoutPicks = screenshotKnockoutPicks.compactMap { pick in
            guard let team = screenshotWinner else {
                return nil
            }

            return KnockoutPickDraft(matchID: pick.matchID, round: pick.round, pickedWinner: team)
        }
        submittedKnockoutEntry = SubmittedKnockoutEntry(
            backendID: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
            groupName: SubmittedEntry.standaloneGroupName,
            displayName: displayName,
            picks: knockoutPicks
        )
        backendBrackets = [
            BackendBracketSummary(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                phase: .groupStage,
                displayName: displayName,
                submittedAt: Date(timeIntervalSince1970: 1_780_876_800),
                groupStageBracketID: nil,
                linkedPoolIDs: [],
                groupStagePredictions: predictions.map {
                    BackendGroupStagePrediction(
                        groupID: $0.groupID,
                        orderedTeamIDs: $0.orderedTeams.map(\.id),
                        predictedThirdPlaceAdvances: $0.predictedThirdPlaceAdvances
                    )
                },
                knockoutPicks: []
            ),
            BackendBracketSummary(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                phase: .knockout,
                displayName: displayName,
                submittedAt: Date(timeIntervalSince1970: 1_780_880_400),
                groupStageBracketID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
                linkedPoolIDs: [],
                groupStagePredictions: [],
                knockoutPicks: screenshotKnockoutPicks
            )
        ]
        leaderboardsByGroupID = [
            "screenshot-group-1": [
                BackendLeaderboardEntry(
                    id: UUID(uuidString: "aaaaaaaa-1111-1111-1111-111111111111")!,
                    poolID: UUID(uuidString: "99999999-1111-1111-1111-111111111111")!,
                    bracketID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    userID: UUID(uuidString: "88888888-1111-1111-1111-111111111111")!,
                    displayName: "Ryan",
                    phase: .groupStage,
                    groupStagePoints: 132,
                    knockoutPoints: 0,
                    totalPoints: 132,
                    maxPoints: 168,
                    possiblePointsRemaining: 0,
                    calculatedAt: Date(timeIntervalSince1970: 1_785_024_000)
                ),
                BackendLeaderboardEntry(
                    id: UUID(uuidString: "aaaaaaaa-2222-2222-2222-222222222222")!,
                    poolID: UUID(uuidString: "99999999-1111-1111-1111-111111111111")!,
                    bracketID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    userID: UUID(uuidString: "88888888-1111-1111-1111-111111111111")!,
                    displayName: "Ryan",
                    phase: .knockout,
                    groupStagePoints: 0,
                    knockoutPoints: 84,
                    totalPoints: 84,
                    maxPoints: 100,
                    possiblePointsRemaining: 0,
                    calculatedAt: Date(timeIntervalSince1970: 1_785_024_000)
                ),
                BackendLeaderboardEntry(
                    id: UUID(uuidString: "bbbbbbbb-1111-1111-1111-111111111111")!,
                    poolID: UUID(uuidString: "99999999-1111-1111-1111-111111111111")!,
                    bracketID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    userID: UUID(uuidString: "77777777-1111-1111-1111-111111111111")!,
                    displayName: "Maya",
                    phase: .groupStage,
                    groupStagePoints: 128,
                    knockoutPoints: 0,
                    totalPoints: 128,
                    maxPoints: 168,
                    possiblePointsRemaining: 0,
                    calculatedAt: Date(timeIntervalSince1970: 1_785_024_000)
                ),
                BackendLeaderboardEntry(
                    id: UUID(uuidString: "bbbbbbbb-2222-2222-2222-222222222222")!,
                    poolID: UUID(uuidString: "99999999-1111-1111-1111-111111111111")!,
                    bracketID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    userID: UUID(uuidString: "77777777-1111-1111-1111-111111111111")!,
                    displayName: "Maya",
                    phase: .knockout,
                    groupStagePoints: 0,
                    knockoutPoints: 70,
                    totalPoints: 70,
                    maxPoints: 100,
                    possiblePointsRemaining: 0,
                    calculatedAt: Date(timeIntervalSince1970: 1_785_024_000)
                )
            ]
        ]
        groupParticipantsByGroupID = [
            "screenshot-group-1": [
                BackendGroupParticipant(
                    id: UUID(uuidString: "88888888-1111-1111-1111-111111111111")!,
                    displayName: "Ryan",
                    role: .owner,
                    joinedAt: Date(timeIntervalSince1970: 1_780_876_800)
                ),
                BackendGroupParticipant(
                    id: UUID(uuidString: "77777777-1111-1111-1111-111111111111")!,
                    displayName: "Maya",
                    role: .member,
                    joinedAt: Date(timeIntervalSince1970: 1_780_876_800)
                )
            ]
        ]
        groupBracketEntriesByGroupID = [
            "screenshot-group-1": [
                BackendGroupBracketEntry(
                    id: UUID(uuidString: "66666666-1111-1111-1111-111111111111")!,
                    poolID: UUID(uuidString: "99999999-1111-1111-1111-111111111111")!,
                    userID: UUID(uuidString: "88888888-1111-1111-1111-111111111111")!,
                    participantDisplayName: "Ryan",
                    bracket: backendBrackets[0],
                    submittedAt: Date(timeIntervalSince1970: 1_780_876_800)
                ),
                BackendGroupBracketEntry(
                    id: UUID(uuidString: "66666666-2222-2222-2222-222222222222")!,
                    poolID: UUID(uuidString: "99999999-1111-1111-1111-111111111111")!,
                    userID: UUID(uuidString: "88888888-1111-1111-1111-111111111111")!,
                    participantDisplayName: "Ryan",
                    bracket: backendBrackets[1],
                    submittedAt: Date(timeIntervalSince1970: 1_780_880_400)
                )
            ]
        ]

        selectedTab = .home
        step = .home

        if let screenshotScreenIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-WCBScreenshotScreen"),
           ProcessInfo.processInfo.arguments.indices.contains(screenshotScreenIndex + 1)
        {
            switch ProcessInfo.processInfo.arguments[screenshotScreenIndex + 1] {
            case "brackets":
                selectedTab = .brackets
                step = .home
            case "groups":
                selectedTab = .groups
                step = .home
            case "winner":
                selectedTab = .groups
                step = .home
            case "profile":
                selectedTab = .profile
                step = .home
            case "group-bracket":
                selectedTab = .brackets
                step = .bracket
            default:
                selectedTab = .home
                step = .home
            }
        }
    }
    #endif
}

struct PendingInvite: Equatable, Sendable {
    let inviteCode: String
    let preview: BackendInvitePreview?
    let errorMessage: String?
}

struct AppGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let teams: [AppTeam]
}

struct AppTeam: Identifiable, Hashable {
    let id: String
    let name: String
    let flagEmoji: String
    let code: String
    let colorHex: String
}

struct GroupStagePredictionDraft: Identifiable, Hashable {
    var id: String {
        groupID
    }

    let groupID: String
    var orderedTeams: [AppTeam]
    var predictedThirdPlaceAdvances: Bool

    var corePrediction: GroupStagePrediction {
        GroupStagePrediction(
            groupID: GroupID(groupID),
            orderedTeamIDs: orderedTeams.map { TeamID($0.id) },
            predictedThirdPlaceAdvances: predictedThirdPlaceAdvances
        )
    }

    var localPrediction: LocalGroupStagePrediction {
        LocalGroupStagePrediction(
            groupID: GroupID(groupID),
            orderedTeamIDs: orderedTeams.map { TeamID($0.id) },
            predictedThirdPlaceAdvances: predictedThirdPlaceAdvances
        )
    }
}

struct SubmittedEntry: Hashable {
    static let standaloneGroupName = "Standalone Bracket"

    let backendID: UUID?
    let groupName: String
    let displayName: String
    let predictions: [GroupStagePredictionDraft]

    var isStandalone: Bool {
        groupName == Self.standaloneGroupName
    }
}

struct JoinedGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let inviteCode: String
    let isOwner: Bool
    let entryPhases: Set<BracketPhase>

    var hasGroupStageEntry: Bool {
        entryPhases.contains(.groupStage)
    }

    var hasKnockoutEntry: Bool {
        entryPhases.contains(.knockout)
    }

    var inviteURL: URL? {
        URL(string: "https://bracket48.app/join/?code=\(inviteCode)")
    }

    var localGroup: LocalJoinedGroup {
        LocalJoinedGroup(id: id, name: name, inviteCode: inviteCode, isOwner: isOwner)
    }

    init(id: String, name: String, inviteCode: String, isOwner: Bool, entryPhases: Set<BracketPhase> = []) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.isOwner = isOwner
        self.entryPhases = entryPhases
    }

    init(localGroup: LocalJoinedGroup) {
        id = localGroup.id
        name = localGroup.name
        inviteCode = localGroup.inviteCode
        isOwner = localGroup.isOwner
        entryPhases = []
    }

    init(summary: BackendPoolSummary) {
        id = summary.id.uuidString
        name = summary.name
        inviteCode = summary.inviteCode
        isOwner = summary.role == .owner
        entryPhases = summary.entryPhases
    }
}

struct KnockoutPickDraft: Identifiable, Hashable {
    var id: String {
        matchID
    }

    let matchID: String
    let round: KnockoutRound
    let pickedWinner: AppTeam

    var corePick: KnockoutPick {
        KnockoutPick(matchID: MatchID(matchID), round: round, pickedWinnerTeamID: TeamID(pickedWinner.id))
    }

    var localPick: LocalKnockoutPick {
        LocalKnockoutPick(matchID: MatchID(matchID), round: round, pickedWinnerTeamID: TeamID(pickedWinner.id))
    }
}

struct SubmittedKnockoutEntry: Hashable {
    let backendID: UUID?
    let groupName: String
    let displayName: String
    let picks: [KnockoutPickDraft]
}

struct BracketUnit: Identifiable {
    let id: UUID
    let groupBracket: BackendBracketSummary
    let knockoutBracket: BackendBracketSummary?

    var isEnteredInGroup: Bool {
        !groupBracket.linkedPoolIDs.isEmpty || knockoutBracket?.linkedPoolIDs.isEmpty == false
    }
}

struct AppKnockoutMatch: Identifiable, Hashable {
    let id: String
    let round: KnockoutRound
    let label: String
    let sourceMatchIDs: [String]
    let homeTeam: AppTeam?
    let awayTeam: AppTeam?
}

struct AppKnockoutBracket: Hashable {
    let matches: [AppKnockoutMatch]

    func matches(in round: KnockoutRound) -> [AppKnockoutMatch] {
        matches.filter { $0.round == round }
    }

    func downstreamMatchIDs(after matchID: String) -> [String] {
        let direct = matches.filter { $0.sourceMatchIDs.contains(matchID) }.map(\.id)
        return direct + direct.flatMap { downstreamMatchIDs(after: $0) }
    }
}

private struct RoundOf32Fixture {
    let home: KnockoutTeamSource
    let away: KnockoutTeamSource
}

private enum KnockoutTeamSource {
    case groupPlacement(groupID: GroupID, position: Int)
    case thirdPlaceOpponent(forGroupID: GroupID)
}

private extension AppModel.Step {
    init(localScreen: LocalAppScreen, hasSubmittedEntry: Bool) {
        switch localScreen {
        case .signUp:
            self = .signUp
        case .home:
            self = .home
        case .bracket:
            self = .bracket
        case .group:
            self = .group
        case .knockout:
            self = .knockout
        case .submitted:
            self = hasSubmittedEntry ? .submitted : .home
        }
    }

    var localScreen: LocalAppScreen {
        switch self {
        case .signUp:
            .signUp
        case .home:
            .home
        case .bracket:
            .bracket
        case .group:
            .group
        case .knockout:
            .knockout
        case .submitted:
            .submitted
        }
    }
}

private extension AppModel.AppTab {
    init(step: AppModel.Step) {
        switch step {
        case .signUp, .home:
            self = .home
        case .bracket, .knockout, .submitted:
            self = .brackets
        case .group:
            self = .groups
        }
    }
}

enum TournamentFixtures {
    static let tournament = Tournament(
        id: "world-cup-2026",
        name: "World Cup 2026",
        year: 2026,
        phase: .groupStageOpen,
        teams: teams,
        groups: groups,
        matches: matches,
        knockoutSlots: knockoutSlots
    )

    static func appGroups(from tournament: Tournament) -> [AppGroup] {
        let teamsByID = Dictionary(uniqueKeysWithValues: tournament.teams.map { ($0.id, $0) })

        return tournament.groups.map { group in
            AppGroup(
                id: group.id.rawValue,
                name: group.name,
                teams: group.teamIDs.compactMap { teamID in
                    guard let team = teamsByID[teamID] else {
                        return nil
                    }

                    return AppTeam(
                        id: team.id.rawValue,
                        name: team.name,
                        flagEmoji: flagEmoji(for: team.countryCode),
                        code: team.fifaCode,
                        colorHex: colorHex(for: team.fifaCode)
                    )
                }
            )
        }
    }

    static func appKnockoutBracket(
        from tournament: Tournament,
        groupStagePredictions: [GroupStagePredictionDraft] = []
    ) -> AppKnockoutBracket {
        let teamsByID = Dictionary(uniqueKeysWithValues: appGroups(from: tournament).flatMap(\.teams).map { ($0.id, $0) })
        let predictionsByGroupID = Dictionary(uniqueKeysWithValues: groupStagePredictions.map { (GroupID($0.groupID), $0) })
        let thirdPlaceAssignments = thirdPlaceAssignments(from: groupStagePredictions)

        let roundOf32 = roundOf32Fixtures.enumerated().map { index, fixture in
            AppKnockoutMatch(
                id: "r32-\(index + 1)",
                round: .roundOf32,
                label: "Round of 32 Game \(index + 1)",
                sourceMatchIDs: [],
                homeTeam: appTeam(
                    for: fixture.home,
                    predictionsByGroupID: predictionsByGroupID,
                    thirdPlaceAssignments: thirdPlaceAssignments,
                    teamsByID: teamsByID
                ),
                awayTeam: appTeam(
                    for: fixture.away,
                    predictionsByGroupID: predictionsByGroupID,
                    thirdPlaceAssignments: thirdPlaceAssignments,
                    teamsByID: teamsByID
                )
            )
        }
        let roundOf16Sources = [
            ["r32-2", "r32-5"], ["r32-1", "r32-3"], ["r32-4", "r32-6"], ["r32-7", "r32-8"],
            ["r32-11", "r32-12"], ["r32-9", "r32-10"], ["r32-14", "r32-16"], ["r32-13", "r32-15"]
        ]
        let roundOf16 = roundOf16Sources.enumerated().map { index, sources in
            AppKnockoutMatch(
                id: "r16-\(index + 1)",
                round: .roundOf16,
                label: "Round of 16 Game \(index + 1)",
                sourceMatchIDs: sources,
                homeTeam: nil,
                awayTeam: nil
            )
        }
        let quarterfinalSources = [
            ["r16-1", "r16-2"], ["r16-5", "r16-6"], ["r16-3", "r16-4"], ["r16-7", "r16-8"]
        ]
        let quarterfinals = quarterfinalSources.enumerated().map { index, sources in
            AppKnockoutMatch(
                id: "qf-\(index + 1)",
                round: .quarterfinal,
                label: "Quarterfinal Game \(index + 1)",
                sourceMatchIDs: sources,
                homeTeam: nil,
                awayTeam: nil
            )
        }
        let semifinalSources = [["qf-1", "qf-2"], ["qf-3", "qf-4"]]
        let semifinals = semifinalSources.enumerated().map { index, sources in
            AppKnockoutMatch(
                id: "sf-\(index + 1)",
                round: .semifinal,
                label: "Semifinal Game \(index + 1)",
                sourceMatchIDs: sources,
                homeTeam: nil,
                awayTeam: nil
            )
        }
        let final = [
            AppKnockoutMatch(
                id: "final",
                round: .final,
                label: "Final",
                sourceMatchIDs: ["sf-1", "sf-2"],
                homeTeam: nil,
                awayTeam: nil
            )
        ]

        return AppKnockoutBracket(matches: roundOf32 + roundOf16 + quarterfinals + semifinals + final)
    }

    private static func appTeam(
        for source: KnockoutTeamSource,
        predictionsByGroupID: [GroupID: GroupStagePredictionDraft],
        thirdPlaceAssignments: [GroupID: GroupID],
        teamsByID: [String: AppTeam]
    ) -> AppTeam? {
        switch source {
        case let .groupPlacement(groupID, position):
            let team = predictionsByGroupID[groupID]?.orderedTeams[safe: position - 1]
                ?? defaultTeam(groupID: groupID, position: position)
            return team.flatMap { teamsByID[$0.id] }
        case let .thirdPlaceOpponent(forGroupID):
            guard let thirdPlaceGroupID = thirdPlaceAssignments[forGroupID] else {
                return nil
            }

            let team = predictionsByGroupID[thirdPlaceGroupID]?.orderedTeams[safe: 2]
                ?? defaultTeam(groupID: thirdPlaceGroupID, position: 3)
            return team.flatMap { teamsByID[$0.id] }
        }
    }

    private static func defaultTeam(groupID: GroupID, position: Int) -> AppTeam? {
        guard let group = seededTeams.first(where: { $0.id == groupID.rawValue }),
              let team = group.teams[safe: position - 1]
        else {
            return nil
        }

        return AppTeam(
            id: team.id,
            name: team.name,
            flagEmoji: flagEmoji(for: team.countryCode),
            code: team.fifaCode,
            colorHex: colorHex(for: team.fifaCode)
        )
    }

    private static func thirdPlaceAssignments(from predictions: [GroupStagePredictionDraft]) -> [GroupID: GroupID] {
        let advancingGroups = advancingThirdPlaceGroupIDs(from: predictions)
        guard let assignmentString = thirdPlaceAssignmentMap[thirdPlaceKey(for: advancingGroups)] else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: zip(thirdPlaceAssignmentSlots, assignmentString).map { slotGroupID, thirdPlaceCharacter in
            (slotGroupID, GroupID(String(thirdPlaceCharacter)))
        })
    }

    private static func advancingThirdPlaceGroupIDs(from predictions: [GroupStagePredictionDraft]) -> [GroupID] {
        let predictionsByGroupID = Dictionary(uniqueKeysWithValues: predictions.map { (GroupID($0.groupID), $0) })
        let groupOrder = seededTeams.map { GroupID($0.id) }
        guard !predictions.isEmpty else {
            return Array(groupOrder.prefix(8))
        }

        let predictedAdvancers = groupOrder.filter { predictionsByGroupID[$0]?.predictedThirdPlaceAdvances == true }
        let remaining = groupOrder.filter { !predictedAdvancers.contains($0) }
        return Array((predictedAdvancers + remaining).prefix(8))
    }

    private static func thirdPlaceKey(for groups: [GroupID]) -> String {
        groups.map(\.rawValue).sorted().joined()
    }

    private static func knockoutSlotSource(for source: KnockoutTeamSource) -> KnockoutSlotSource {
        switch source {
        case let .groupPlacement(groupID, position):
            .groupPlacement(groupID: groupID, position: position)
        case let .thirdPlaceOpponent(forGroupID):
            .bestThirdPlace(rank: thirdPlaceAssignmentSlots.firstIndex(of: forGroupID).map { $0 + 1 } ?? 0)
        }
    }

    private static let thirdPlaceAssignmentSlots: [GroupID] = ["A", "B", "D", "E", "G", "I", "K", "L"]

    private static let thirdPlaceAssignmentMap: [String: String] = {
        Dictionary(uniqueKeysWithValues: thirdPlaceAssignmentsData.split(separator: ";").compactMap { entry in
            let parts = entry.split(separator: "=")
            guard parts.count == 2 else {
                return nil
            }

            return (String(parts[0]), String(parts[1]))
        })
    }()

    private static let thirdPlaceAssignmentsData = "EFGHIJKL=EJIFHGLK;DFGHIJKL=HGIDJFLK;DEGHIJKL=EJIDHGLK;DEFHIJKL=EJIDHFLK;DEFGIJKL=EGIDJFLK;DEFGHJKL=EGJDHFLK;DEFGHIKL=EGIDHFLK;DEFGHIJL=EGJDHFLI;DEFGHIJK=EGJDHFIK;CFGHIJKL=HGICJFLK;CEGHIJKL=EJICHGLK;CEFHIJKL=EJICHFLK;CEFGIJKL=EGICJFLK;CEFGHJKL=EGJCHFLK;CEFGHIKL=EGICHFLK;CEFGHIJL=EGJCHFLI;CEFGHIJK=EGJCHFIK;CDGHIJKL=HGICJDLK;CDFHIJKL=CJIDHFLK;CDFGIJKL=CGIDJFLK;CDFGHJKL=CGJDHFLK;CDFGHIKL=CGIDHFLK;CDFGHIJL=CGJDHFLI;CDFGHIJK=CGJDHFIK;CDEHIJKL=EJICHDLK;CDEGIJKL=EGICJDLK;CDEGHJKL=EGJCHDLK;CDEGHIKL=EGICHDLK;CDEGHIJL=EGJCHDLI;CDEGHIJK=EGJCHDIK;CDEFIJKL=CJEDIFLK;CDEFHJKL=CJEDHFLK;CDEFHIKL=CEIDHFLK;CDEFHIJL=CJEDHFLI;CDEFHIJK=CJEDHFIK;CDEFGJKL=CGEDJFLK;CDEFGIKL=CGEDIFLK;CDEFGIJL=CGEDJFLI;CDEFGIJK=CGEDJFIK;CDEFGHKL=CGEDHFLK;CDEFGHJL=CGJDHFLE;CDEFGHJK=CGJDHFEK;CDEFGHIL=CGEDHFLI;CDEFGHIK=CGEDHFIK;CDEFGHIJ=CGJDHFEI;BFGHIJKL=HJBFIGLK;BEGHIJKL=EJIBHGLK;BEFHIJKL=EJBFIHLK;BEFGIJKL=EJBFIGLK;BEFGHJKL=EJBFHGLK;BEFGHIKL=EGBFIHLK;BEFGHIJL=EJBFHGLI;BEFGHIJK=EJBFHGIK;BDGHIJKL=HJBDIGLK;BDFHIJKL=HJBDIFLK;BDFGIJKL=IGBDJFLK;BDFGHJKL=HGBDJFLK;BDFGHIKL=HGBDIFLK;BDFGHIJL=HGBDJFLI;BDFGHIJK=HGBDJFIK;BDEHIJKL=EJBDIHLK;BDEGIJKL=EJBDIGLK;BDEGHJKL=EJBDHGLK;BDEGHIKL=EGBDIHLK;BDEGHIJL=EJBDHGLI;BDEGHIJK=EJBDHGIK;BDEFIJKL=EJBDIFLK;BDEFHJKL=EJBDHFLK;BDEFHIKL=EIBDHFLK;BDEFHIJL=EJBDHFLI;BDEFHIJK=EJBDHFIK;BDEFGJKL=EGBDJFLK;BDEFGIKL=EGBDIFLK;BDEFGIJL=EGBDJFLI;BDEFGIJK=EGBDJFIK;BDEFGHKL=EGBDHFLK;BDEFGHJL=HGBDJFLE;BDEFGHJK=HGBDJFEK;BDEFGHIL=EGBDHFLI;BDEFGHIK=EGBDHFIK;BDEFGHIJ=HGBDJFEI;BCGHIJKL=HJBCIGLK;BCFHIJKL=HJBCIFLK;BCFGIJKL=IGBCJFLK;BCFGHJKL=HGBCJFLK;BCFGHIKL=HGBCIFLK;BCFGHIJL=HGBCJFLI;BCFGHIJK=HGBCJFIK;BCEHIJKL=EJBCIHLK;BCEGIJKL=EJBCIGLK;BCEGHJKL=EJBCHGLK;BCEGHIKL=EGBCIHLK;BCEGHIJL=EJBCHGLI;BCEGHIJK=EJBCHGIK;BCEFIJKL=EJBCIFLK;BCEFHJKL=EJBCHFLK;BCEFHIKL=EIBCHFLK;BCEFHIJL=EJBCHFLI;BCEFHIJK=EJBCHFIK;BCEFGJKL=EGBCJFLK;BCEFGIKL=EGBCIFLK;BCEFGIJL=EGBCJFLI;BCEFGIJK=EGBCJFIK;BCEFGHKL=EGBCHFLK;BCEFGHJL=HGBCJFLE;BCEFGHJK=HGBCJFEK;BCEFGHIL=EGBCHFLI;BCEFGHIK=EGBCHFIK;BCEFGHIJ=HGBCJFEI;BCDHIJKL=HJBCIDLK;BCDGIJKL=IGBCJDLK;BCDGHJKL=HGBCJDLK;BCDGHIKL=HGBCIDLK;BCDGHIJL=HGBCJDLI;BCDGHIJK=HGBCJDIK;BCDFIJKL=CJBDIFLK;BCDFHJKL=CJBDHFLK;BCDFHIKL=CIBDHFLK;BCDFHIJL=CJBDHFLI;BCDFHIJK=CJBDHFIK;BCDFGJKL=CGBDJFLK;BCDFGIKL=CGBDIFLK;BCDFGIJL=CGBDJFLI;BCDFGIJK=CGBDJFIK;BCDFGHKL=CGBDHFLK;BCDFGHJL=CGBDHFLJ;BCDFGHJK=HGBCJFDK;BCDFGHIL=CGBDHFLI;BCDFGHIK=CGBDHFIK;BCDFGHIJ=HGBCJFDI;BCDEIJKL=EJBCIDLK;BCDEHJKL=EJBCHDLK;BCDEHIKL=EIBCHDLK;BCDEHIJL=EJBCHDLI;BCDEHIJK=EJBCHDIK;BCDEGJKL=EGBCJDLK;BCDEGIKL=EGBCIDLK;BCDEGIJL=EGBCJDLI;BCDEGIJK=EGBCJDIK;BCDEGHKL=EGBCHDLK;BCDEGHJL=HGBCJDLE;BCDEGHJK=HGBCJDEK;BCDEGHIL=EGBCHDLI;BCDEGHIK=EGBCHDIK;BCDEGHIJ=HGBCJDEI;BCDEFJKL=CJBDEFLK;BCDEFIKL=CEBDIFLK;BCDEFIJL=CJBDEFLI;BCDEFIJK=CJBDEFIK;BCDEFHKL=CEBDHFLK;BCDEFHJL=CJBDHFLE;BCDEFHJK=CJBDHFEK;BCDEFHIL=CEBDHFLI;BCDEFHIK=CEBDHFIK;BCDEFHIJ=CJBDHFEI;BCDEFGKL=CGBDEFLK;BCDEFGJL=CGBDJFLE;BCDEFGJK=CGBDJFEK;BCDEFGIL=CGBDEFLI;BCDEFGIK=CGBDEFIK;BCDEFGIJ=CGBDJFEI;BCDEFGHL=CGBDHFLE;BCDEFGHK=CGBDHFEK;BCDEFGHJ=HGBCJFDE;BCDEFGHI=CGBDHFEI;AFGHIJKL=HJIFAGLK;AEGHIJKL=EJIAHGLK;AEFHIJKL=EJIFAHLK;AEFGIJKL=EJIFAGLK;AEFGHJKL=EGJFAHLK;AEFGHIKL=EGIFAHLK;AEFGHIJL=EGJFAHLI;AEFGHIJK=EGJFAHIK;ADGHIJKL=HJIDAGLK;ADFHIJKL=HJIDAFLK;ADFGIJKL=IGJDAFLK;ADFGHJKL=HGJDAFLK;ADFGHIKL=HGIDAFLK;ADFGHIJL=HGJDAFLI;ADFGHIJK=HGJDAFIK;ADEHIJKL=EJIDAHLK;ADEGIJKL=EJIDAGLK;ADEGHJKL=EGJDAHLK;ADEGHIKL=EGIDAHLK;ADEGHIJL=EGJDAHLI;ADEGHIJK=EGJDAHIK;ADEFIJKL=EJIDAFLK;ADEFHJKL=HJEDAFLK;ADEFHIKL=HEIDAFLK;ADEFHIJL=HJEDAFLI;ADEFHIJK=HJEDAFIK;ADEFGJKL=EGJDAFLK;ADEFGIKL=EGIDAFLK;ADEFGIJL=EGJDAFLI;ADEFGIJK=EGJDAFIK;ADEFGHKL=HGEDAFLK;ADEFGHJL=HGJDAFLE;ADEFGHJK=HGJDAFEK;ADEFGHIL=HGEDAFLI;ADEFGHIK=HGEDAFIK;ADEFGHIJ=HGJDAFEI;ACGHIJKL=HJICAGLK;ACFHIJKL=HJICAFLK;ACFGIJKL=IGJCAFLK;ACFGHJKL=HGJCAFLK;ACFGHIKL=HGICAFLK;ACFGHIJL=HGJCAFLI;ACFGHIJK=HGJCAFIK;ACEHIJKL=EJICAHLK;ACEGIJKL=EJICAGLK;ACEGHJKL=EGJCAHLK;ACEGHIKL=EGICAHLK;ACEGHIJL=EGJCAHLI;ACEGHIJK=EGJCAHIK;ACEFIJKL=EJICAFLK;ACEFHJKL=HJECAFLK;ACEFHIKL=HEICAFLK;ACEFHIJL=HJECAFLI;ACEFHIJK=HJECAFIK;ACEFGJKL=EGJCAFLK;ACEFGIKL=EGICAFLK;ACEFGIJL=EGJCAFLI;ACEFGIJK=EGJCAFIK;ACEFGHKL=HGECAFLK;ACEFGHJL=HGJCAFLE;ACEFGHJK=HGJCAFEK;ACEFGHIL=HGECAFLI;ACEFGHIK=HGECAFIK;ACEFGHIJ=HGJCAFEI;ACDHIJKL=HJICADLK;ACDGIJKL=IGJCADLK;ACDGHJKL=HGJCADLK;ACDGHIKL=HGICADLK;ACDGHIJL=HGJCADLI;ACDGHIJK=HGJCADIK;ACDFIJKL=CJIDAFLK;ACDFHJKL=HJFCADLK;ACDFHIKL=HFICADLK;ACDFHIJL=HJFCADLI;ACDFHIJK=HJFCADIK;ACDFGJKL=CGJDAFLK;ACDFGIKL=CGIDAFLK;ACDFGIJL=CGJDAFLI;ACDFGIJK=CGJDAFIK;ACDFGHKL=HGFCADLK;ACDFGHJL=CGJDAFLH;ACDFGHJK=HGJCAFDK;ACDFGHIL=HGFCADLI;ACDFGHIK=HGFCADIK;ACDFGHIJ=HGJCAFDI;ACDEIJKL=EJICADLK;ACDEHJKL=HJECADLK;ACDEHIKL=HEICADLK;ACDEHIJL=HJECADLI;ACDEHIJK=HJECADIK;ACDEGJKL=EGJCADLK;ACDEGIKL=EGICADLK;ACDEGIJL=EGJCADLI;ACDEGIJK=EGJCADIK;ACDEGHKL=HGECADLK;ACDEGHJL=HGJCADLE;ACDEGHJK=HGJCADEK;ACDEGHIL=HGECADLI;ACDEGHIK=HGECADIK;ACDEGHIJ=HGJCADEI;ACDEFJKL=CJEDAFLK;ACDEFIKL=CEIDAFLK;ACDEFIJL=CJEDAFLI;ACDEFIJK=CJEDAFIK;ACDEFHKL=HEFCADLK;ACDEFHJL=HJFCADLE;ACDEFHJK=HJECAFDK;ACDEFHIL=HEFCADLI;ACDEFHIK=HEFCADIK;ACDEFHIJ=HJECAFDI;ACDEFGKL=CGEDAFLK;ACDEFGJL=CGJDAFLE;ACDEFGJK=CGJDAFEK;ACDEFGIL=CGEDAFLI;ACDEFGIK=CGEDAFIK;ACDEFGIJ=CGJDAFEI;ACDEFGHL=HGFCADLE;ACDEFGHK=HGECAFDK;ACDEFGHJ=HGJCAFDE;ACDEFGHI=HGECAFDI;ABGHIJKL=HJBAIGLK;ABFHIJKL=HJBAIFLK;ABFGIJKL=IJBFAGLK;ABFGHJKL=HJBFAGLK;ABFGHIKL=HGBAIFLK;ABFGHIJL=HJBFAGLI;ABFGHIJK=HJBFAGIK;ABEHIJKL=EJBAIHLK;ABEGIJKL=EJBAIGLK;ABEGHJKL=EJBAHGLK;ABEGHIKL=EGBAIHLK;ABEGHIJL=EJBAHGLI;ABEGHIJK=EJBAHGIK;ABEFIJKL=EJBAIFLK;ABEFHJKL=EJBFAHLK;ABEFHIKL=EIBFAHLK;ABEFHIJL=EJBFAHLI;ABEFHIJK=EJBFAHIK;ABEFGJKL=EJBFAGLK;ABEFGIKL=EGBAIFLK;ABEFGIJL=EJBFAGLI;ABEFGIJK=EJBFAGIK;ABEFGHKL=EGBFAHLK;ABEFGHJL=HJBFAGLE;ABEFGHJK=HJBFAGEK;ABEFGHIL=EGBFAHLI;ABEFGHIK=EGBFAHIK;ABEFGHIJ=HJBFAGEI;ABDHIJKL=IJBDAHLK;ABDGIJKL=IJBDAGLK;ABDGHJKL=HJBDAGLK;ABDGHIKL=IGBDAHLK;ABDGHIJL=HJBDAGLI;ABDGHIJK=HJBDAGIK;ABDFIJKL=IJBDAFLK;ABDFHJKL=HJBDAFLK;ABDFHIKL=HIBDAFLK;ABDFHIJL=HJBDAFLI;ABDFHIJK=HJBDAFIK;ABDFGJKL=FJBDAGLK;ABDFGIKL=IGBDAFLK;ABDFGIJL=FJBDAGLI;ABDFGIJK=FJBDAGIK;ABDFGHKL=HGBDAFLK;ABDFGHJL=HGBDAFLJ;ABDFGHJK=HGBDAFJK;ABDFGHIL=HGBDAFLI;ABDFGHIK=HGBDAFIK;ABDFGHIJ=HGBDAFIJ;ABDEIJKL=EJBAIDLK;ABDEHJKL=EJBDAHLK;ABDEHIKL=EIBDAHLK;ABDEHIJL=EJBDAHLI;ABDEHIJK=EJBDAHIK;ABDEGJKL=EJBDAGLK;ABDEGIKL=EGBAIDLK;ABDEGIJL=EJBDAGLI;ABDEGIJK=EJBDAGIK;ABDEGHKL=EGBDAHLK;ABDEGHJL=HJBDAGLE;ABDEGHJK=HJBDAGEK;ABDEGHIL=EGBDAHLI;ABDEGHIK=EGBDAHIK;ABDEGHIJ=HJBDAGEI;ABDEFJKL=EJBDAFLK;ABDEFIKL=EIBDAFLK;ABDEFIJL=EJBDAFLI;ABDEFIJK=EJBDAFIK;ABDEFHKL=HEBDAFLK;ABDEFHJL=HJBDAFLE;ABDEFHJK=HJBDAFEK;ABDEFHIL=HEBDAFLI;ABDEFHIK=HEBDAFIK;ABDEFHIJ=HJBDAFEI;ABDEFGKL=EGBDAFLK;ABDEFGJL=EGBDAFLJ;ABDEFGJK=EGBDAFJK;ABDEFGIL=EGBDAFLI;ABDEFGIK=EGBDAFIK;ABDEFGIJ=EGBDAFIJ;ABDEFGHL=HGBDAFLE;ABDEFGHK=HGBDAFEK;ABDEFGHJ=HGBDAFEJ;ABDEFGHI=HGBDAFEI;ABCHIJKL=IJBCAHLK;ABCGIJKL=IJBCAGLK;ABCGHJKL=HJBCAGLK;ABCGHIKL=IGBCAHLK;ABCGHIJL=HJBCAGLI;ABCGHIJK=HJBCAGIK;ABCFIJKL=IJBCAFLK;ABCFHJKL=HJBCAFLK;ABCFHIKL=HIBCAFLK;ABCFHIJL=HJBCAFLI;ABCFHIJK=HJBCAFIK;ABCFGJKL=CJBFAGLK;ABCFGIKL=IGBCAFLK;ABCFGIJL=CJBFAGLI;ABCFGIJK=CJBFAGIK;ABCFGHKL=HGBCAFLK;ABCFGHJL=HGBCAFLJ;ABCFGHJK=HGBCAFJK;ABCFGHIL=HGBCAFLI;ABCFGHIK=HGBCAFIK;ABCFGHIJ=HGBCAFIJ;ABCEIJKL=EJBAICLK;ABCEHJKL=EJBCAHLK;ABCEHIKL=EIBCAHLK;ABCEHIJL=EJBCAHLI;ABCEHIJK=EJBCAHIK;ABCEGJKL=EJBCAGLK;ABCEGIKL=EGBAICLK;ABCEGIJL=EJBCAGLI;ABCEGIJK=EJBCAGIK;ABCEGHKL=EGBCAHLK;ABCEGHJL=HJBCAGLE;ABCEGHJK=HJBCAGEK;ABCEGHIL=EGBCAHLI;ABCEGHIK=EGBCAHIK;ABCEGHIJ=HJBCAGEI;ABCEFJKL=EJBCAFLK;ABCEFIKL=EIBCAFLK;ABCEFIJL=EJBCAFLI;ABCEFIJK=EJBCAFIK;ABCEFHKL=HEBCAFLK;ABCEFHJL=HJBCAFLE;ABCEFHJK=HJBCAFEK;ABCEFHIL=HEBCAFLI;ABCEFHIK=HEBCAFIK;ABCEFHIJ=HJBCAFEI;ABCEFGKL=EGBCAFLK;ABCEFGJL=EGBCAFLJ;ABCEFGJK=EGBCAFJK;ABCEFGIL=EGBCAFLI;ABCEFGIK=EGBCAFIK;ABCEFGIJ=EGBCAFIJ;ABCEFGHL=HGBCAFLE;ABCEFGHK=HGBCAFEK;ABCEFGHJ=HGBCAFEJ;ABCEFGHI=HGBCAFEI;ABCDIJKL=IJBCADLK;ABCDHJKL=HJBCADLK;ABCDHIKL=HIBCADLK;ABCDHIJL=HJBCADLI;ABCDHIJK=HJBCADIK;ABCDGJKL=CJBDAGLK;ABCDGIKL=IGBCADLK;ABCDGIJL=CJBDAGLI;ABCDGIJK=CJBDAGIK;ABCDGHKL=HGBCADLK;ABCDGHJL=HGBCADLJ;ABCDGHJK=HGBCADJK;ABCDGHIL=HGBCADLI;ABCDGHIK=HGBCADIK;ABCDGHIJ=HGBCADIJ;ABCDFJKL=CJBDAFLK;ABCDFIKL=CIBDAFLK;ABCDFIJL=CJBDAFLI;ABCDFIJK=CJBDAFIK;ABCDFHKL=HFBCADLK;ABCDFHJL=CJBDAFLH;ABCDFHJK=HJBCAFDK;ABCDFHIL=HFBCADLI;ABCDFHIK=HFBCADIK;ABCDFHIJ=HJBCAFDI;ABCDFGKL=CGBDAFLK;ABCDFGJL=CGBDAFLJ;ABCDFGJK=CGBDAFJK;ABCDFGIL=CGBDAFLI;ABCDFGIK=CGBDAFIK;ABCDFGIJ=CGBDAFIJ;ABCDFGHL=CGBDAFLH;ABCDFGHK=HGBCAFDK;ABCDFGHJ=HGBCAFDJ;ABCDFGHI=HGBCAFDI;ABCDEJKL=EJBCADLK;ABCDEIKL=EIBCADLK;ABCDEIJL=EJBCADLI;ABCDEIJK=EJBCADIK;ABCDEHKL=HEBCADLK;ABCDEHJL=HJBCADLE;ABCDEHJK=HJBCADEK;ABCDEHIL=HEBCADLI;ABCDEHIK=HEBCADIK;ABCDEHIJ=HJBCADEI;ABCDEGKL=EGBCADLK;ABCDEGJL=EGBCADLJ;ABCDEGJK=EGBCADJK;ABCDEGIL=EGBCADLI;ABCDEGIK=EGBCADIK;ABCDEGIJ=EGBCADIJ;ABCDEGHL=HGBCADLE;ABCDEGHK=HGBCADEK;ABCDEGHJ=HGBCADEJ;ABCDEGHI=HGBCADEI;ABCDEFKL=CEBDAFLK;ABCDEFJL=CJBDAFLE;ABCDEFJK=CJBDAFEK;ABCDEFIL=CEBDAFLI;ABCDEFIK=CEBDAFIK;ABCDEFIJ=CJBDAFEI;ABCDEFHL=HFBCADLE;ABCDEFHK=HEBCAFDK;ABCDEFHJ=HJBCAFDE;ABCDEFHI=HEBCAFDI;ABCDEFGL=CGBDAFLE;ABCDEFGK=CGBDAFEK;ABCDEFGJ=CGBDAFEJ;ABCDEFGI=CGBDAFEI;ABCDEFGH=HGBCAFDE"


    private static let roundOf32Fixtures: [RoundOf32Fixture] = [
        RoundOf32Fixture(home: .groupPlacement(groupID: "A", position: 2), away: .groupPlacement(groupID: "B", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "E", position: 1), away: .thirdPlaceOpponent(forGroupID: "E")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "F", position: 1), away: .groupPlacement(groupID: "C", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "C", position: 1), away: .groupPlacement(groupID: "F", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "I", position: 1), away: .thirdPlaceOpponent(forGroupID: "I")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "E", position: 2), away: .groupPlacement(groupID: "I", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "A", position: 1), away: .thirdPlaceOpponent(forGroupID: "A")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "L", position: 1), away: .thirdPlaceOpponent(forGroupID: "L")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "D", position: 1), away: .thirdPlaceOpponent(forGroupID: "D")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "G", position: 1), away: .thirdPlaceOpponent(forGroupID: "G")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "K", position: 2), away: .groupPlacement(groupID: "L", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "H", position: 1), away: .groupPlacement(groupID: "J", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "B", position: 1), away: .thirdPlaceOpponent(forGroupID: "B")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "J", position: 1), away: .groupPlacement(groupID: "H", position: 2)),
        RoundOf32Fixture(home: .groupPlacement(groupID: "K", position: 1), away: .thirdPlaceOpponent(forGroupID: "K")),
        RoundOf32Fixture(home: .groupPlacement(groupID: "D", position: 2), away: .groupPlacement(groupID: "G", position: 2))
    ]

    private static let teams: [Team] = seededTeams.flatMap { group in
        group.teams.map { team in
            Team(
                id: TeamID(team.id),
                name: team.name,
                countryCode: team.countryCode,
                fifaCode: team.fifaCode,
                seed: team.seed,
                providerReferences: [
                    ProviderReference(providerName: "Bracket48", providerID: ProviderID("team-\(team.id)"))
                ]
            )
        }
    }

    private static let groups: [TournamentGroup] = seededTeams.map { seededGroup in
        TournamentGroup(
            id: GroupID(seededGroup.id),
            name: "Group \(seededGroup.id)",
            teamIDs: seededGroup.teams.map { TeamID($0.id) }
        )
    }

    private static let matches: [TournamentMatch] = seededTeams.enumerated().map { index, seededGroup in
        TournamentMatch(
            id: MatchID("group-\(seededGroup.id.lowercased())-1"),
            phase: .groupStage,
            groupID: GroupID(seededGroup.id),
            homeTeamID: TeamID(seededGroup.teams[0].id),
            awayTeamID: TeamID(seededGroup.teams[1].id),
            status: .scheduled,
            providerReferences: [
                ProviderReference(providerName: "Bracket48", providerID: ProviderID("match-\(index + 1)"))
            ]
        )
    } + knockoutMatches

    private static let knockoutMatches: [TournamentMatch] = {
        let roundOf32 = (1...16).map { index in
            TournamentMatch(id: MatchID("r32-\(index)"), phase: .knockout, knockoutRound: .roundOf32, status: .scheduled)
        }
        let roundOf16 = (1...8).map { index in
            TournamentMatch(id: MatchID("r16-\(index)"), phase: .knockout, knockoutRound: .roundOf16, status: .scheduled)
        }
        let quarterfinals = (1...4).map { index in
            TournamentMatch(id: MatchID("qf-\(index)"), phase: .knockout, knockoutRound: .quarterfinal, status: .scheduled)
        }
        let semifinals = (1...2).map { index in
            TournamentMatch(id: MatchID("sf-\(index)"), phase: .knockout, knockoutRound: .semifinal, status: .scheduled)
        }
        return roundOf32 + roundOf16 + quarterfinals + semifinals + [
            TournamentMatch(id: "final", phase: .knockout, knockoutRound: .final, status: .scheduled)
        ]
    }()

    private static let knockoutSlots: [KnockoutSlot] = {
        var slots: [KnockoutSlot] = []

        for (index, match) in roundOf32Fixtures.enumerated() {
            let matchIndex = index + 1
            slots.append(
                KnockoutSlot(
                    id: "r32-\(matchIndex)-home",
                    round: .roundOf32,
                    matchID: MatchID("r32-\(matchIndex)"),
                    side: .home,
                    source: knockoutSlotSource(for: match.home)
                )
            )
            slots.append(
                KnockoutSlot(
                    id: "r32-\(matchIndex)-away",
                    round: .roundOf32,
                    matchID: MatchID("r32-\(matchIndex)"),
                    side: .away,
                    source: knockoutSlotSource(for: match.away)
                )
            )
        }

        let roundOf16Sources = [
            (2, 5), (1, 3), (4, 6), (7, 8), (11, 12), (9, 10), (14, 16), (13, 15)
        ]
        for (index, source) in roundOf16Sources.enumerated() {
            let matchIndex = index + 1
            slots.append(
                KnockoutSlot(
                    id: "r16-\(matchIndex)-home",
                    round: .roundOf16,
                    matchID: MatchID("r16-\(matchIndex)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("r32-\(source.0)"))
                )
            )
            slots.append(
                KnockoutSlot(
                    id: "r16-\(matchIndex)-away",
                    round: .roundOf16,
                    matchID: MatchID("r16-\(matchIndex)"),
                    side: .away,
                    source: .matchWinner(matchID: MatchID("r32-\(source.1)"))
                )
            )
        }

        let quarterfinalSources = [(1, 2), (5, 6), (3, 4), (7, 8)]
        for (index, source) in quarterfinalSources.enumerated() {
            let matchIndex = index + 1
            slots.append(
                KnockoutSlot(
                    id: "qf-\(matchIndex)-home",
                    round: .quarterfinal,
                    matchID: MatchID("qf-\(matchIndex)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("r16-\(source.0)"))
                )
            )
            slots.append(
                KnockoutSlot(
                    id: "qf-\(matchIndex)-away",
                    round: .quarterfinal,
                    matchID: MatchID("qf-\(matchIndex)"),
                    side: .away,
                    source: .matchWinner(matchID: MatchID("r16-\(source.1)"))
                )
            )
        }

        let semifinalSources = [(1, 2), (3, 4)]
        for (index, source) in semifinalSources.enumerated() {
            let matchIndex = index + 1
            slots.append(
                KnockoutSlot(
                    id: "sf-\(matchIndex)-home",
                    round: .semifinal,
                    matchID: MatchID("sf-\(matchIndex)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("qf-\(source.0)"))
                )
            )
            slots.append(
                KnockoutSlot(
                    id: "sf-\(matchIndex)-away",
                    round: .semifinal,
                    matchID: MatchID("sf-\(matchIndex)"),
                    side: .away,
                    source: .matchWinner(matchID: MatchID("qf-\(source.1)"))
                )
            )
        }

        slots.append(
            KnockoutSlot(id: "final-home", round: .final, matchID: "final", side: .home, source: .matchWinner(matchID: "sf-1"))
        )
        slots.append(
            KnockoutSlot(id: "final-away", round: .final, matchID: "final", side: .away, source: .matchWinner(matchID: "sf-2"))
        )

        return slots
    }()

    private static let seededTeams: [(id: String, teams: [(id: String, name: String, countryCode: String, fifaCode: String, seed: Int)])] = [
        ("A", [
            ("mex", "Mexico", "MX", "MEX", 1),
            ("kor", "Korea Republic", "KR", "KOR", 2),
            ("rsa", "South Africa", "ZA", "RSA", 3),
            ("cze", "Czechia", "CZ", "CZE", 4)
        ]),
        ("B", [
            ("can", "Canada", "CA", "CAN", 5),
            ("sui", "Switzerland", "CH", "SUI", 6),
            ("qat", "Qatar", "QA", "QAT", 7),
            ("bih", "Bosnia and Herzegovina", "BA", "BIH", 8)
        ]),
        ("C", [
            ("bra", "Brazil", "BR", "BRA", 9),
            ("mar", "Morocco", "MA", "MAR", 10),
            ("sco", "Scotland", "GB-SCT", "SCO", 11),
            ("hai", "Haiti", "HT", "HAI", 12)
        ]),
        ("D", [
            ("usa", "United States", "US", "USA", 13),
            ("par", "Paraguay", "PY", "PAR", 14),
            ("aus", "Australia", "AU", "AUS", 15),
            ("tur", "Türkiye", "TR", "TUR", 16)
        ]),
        ("E", [
            ("ger", "Germany", "DE", "GER", 17),
            ("ecu", "Ecuador", "EC", "ECU", 18),
            ("civ", "Côte d'Ivoire", "CI", "CIV", 19),
            ("cuw", "Curaçao", "CW", "CUW", 20)
        ]),
        ("F", [
            ("ned", "Netherlands", "NL", "NED", 21),
            ("jpn", "Japan", "JP", "JPN", 22),
            ("tun", "Tunisia", "TN", "TUN", 23),
            ("swe", "Sweden", "SE", "SWE", 24)
        ]),
        ("G", [
            ("bel", "Belgium", "BE", "BEL", 25),
            ("irn", "IR Iran", "IR", "IRN", 26),
            ("egy", "Egypt", "EG", "EGY", 27),
            ("nzl", "New Zealand", "NZ", "NZL", 28)
        ]),
        ("H", [
            ("esp", "Spain", "ES", "ESP", 29),
            ("uru", "Uruguay", "UY", "URU", 30),
            ("ksa", "Saudi Arabia", "SA", "KSA", 31),
            ("cpv", "Cape Verde", "CV", "CPV", 32)
        ]),
        ("I", [
            ("fra", "France", "FR", "FRA", 33),
            ("sen", "Senegal", "SN", "SEN", 34),
            ("nor", "Norway", "NO", "NOR", 35),
            ("irq", "Iraq", "IQ", "IRQ", 36)
        ]),
        ("J", [
            ("arg", "Argentina", "AR", "ARG", 37),
            ("aut", "Austria", "AT", "AUT", 38),
            ("alg", "Algeria", "DZ", "ALG", 39),
            ("jor", "Jordan", "JO", "JOR", 40)
        ]),
        ("K", [
            ("por", "Portugal", "PT", "POR", 41),
            ("col", "Colombia", "CO", "COL", 42),
            ("uzb", "Uzbekistan", "UZ", "UZB", 43),
            ("cod", "DR Congo", "CD", "COD", 44)
        ]),
        ("L", [
            ("eng", "England", "GB-ENG", "ENG", 45),
            ("cro", "Croatia", "HR", "CRO", 46),
            ("pan", "Panama", "PA", "PAN", 47),
            ("gha", "Ghana", "GH", "GHA", 48)
        ])
    ]

    private static func colorHex(for code: String) -> String {
        [
            "USA": "1D4ED8",
            "MEX": "15803D",
            "CAN": "DC2626",
            "ARG": "38BDF8",
            "BRA": "EAB308",
            "FRA": "1D4ED8",
            "ENG": "DC2626"
        ][code, default: "16A34A"]
    }

    private static func flagEmoji(for countryCode: String) -> String {
        switch countryCode {
        case "GB-ENG":
            return subdivisionFlagEmoji(for: "gbeng")
        case "GB-SCT":
            return subdivisionFlagEmoji(for: "gbsct")
        default:
            guard countryCode.count == 2 else {
                return "🏳️"
            }

            return countryCode
                .uppercased()
                .unicodeScalars
                .compactMap { UnicodeScalar(127_397 + $0.value) }
                .map(String.init)
                .joined()
        }
    }

    private static func subdivisionFlagEmoji(for subdivisionCode: String) -> String {
        let scalars = [UnicodeScalar(0x1F3F4)!]
            + subdivisionCode.unicodeScalars.compactMap { UnicodeScalar(0xE0000 + $0.value) }
            + [UnicodeScalar(0xE007F)!]

        return String(String.UnicodeScalarView(scalars))
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
