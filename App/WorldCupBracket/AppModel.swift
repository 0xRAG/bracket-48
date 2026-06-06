import Foundation
import Observation
import WorldCupBracketCore

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

    var step: Step = .signUp
    var selectedTab: AppTab = .home
    var backendStatusMessage: String?
    var isBackendBusy = false
    var displayName = ""
    var groupName = ""
    var selectedGroupID: String?
    var predictions: [GroupStagePredictionDraft]
    var joinedGroups: [JoinedGroup]
    var backendBrackets: [BackendBracketSummary]
    var submittedEntry: SubmittedEntry?
    var knockoutPicks: [KnockoutPickDraft]
    var submittedKnockoutEntry: SubmittedKnockoutEntry?

    let tournament: Tournament
    let groups: [AppGroup]
    let knockoutBracket: AppKnockoutBracket

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
        knockoutBracket = TournamentFixtures.appKnockoutBracket(from: tournament)
        predictions = Self.defaultPredictions(groups: groups)
        joinedGroups = []
        backendBrackets = []
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

        selectedTab = .home
        step = .home
        persist()
    }

    @MainActor
    func refreshBackendState() async {
        await runBackendOperation(successMessage: nil) {
            let pools = try await services.pools.listPools()
            joinedGroups = pools.map(JoinedGroup.init(summary:))

            let brackets = try await services.brackets.listBrackets()
            applyBackendBrackets(brackets)
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
        guard let inviteCode = normalizedInviteCode(from: inviteText) else {
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
            didJoin = true
            persist()
        }
        return didJoin
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
        groupName = ""
        selectedGroupID = nil
        predictions = Self.defaultPredictions(groups: groups)
        joinedGroups = []
        backendBrackets = []
        submittedEntry = nil
        knockoutPicks = []
        submittedKnockoutEntry = nil
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

    private func normalizedInviteCode(from inviteText: String) -> String? {
        let trimmed = inviteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String

        if let url = URL(string: trimmed),
           let lastPathComponent = url.pathComponents.last,
           lastPathComponent != "/"
        {
            candidate = lastPathComponent
        } else {
            candidate = trimmed
        }

        let code = candidate.uppercased().filter { character in
            character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        }

        guard !code.isEmpty else {
            return nil
        }

        return String(code.prefix(8))
    }

    #if DEBUG
    private func applyScreenshotFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-WCBUseScreenshotFixtures") else {
            return
        }

        displayName = "Ryan"
        groupName = ""
        selectedGroupID = "screenshot-group-1"
        joinedGroups = [
            JoinedGroup(id: "screenshot-group-1", name: "Saturday Crew", inviteCode: "BRKT48", isOwner: true),
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
        knockoutPicks = []
        submittedKnockoutEntry = nil
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
            )
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

    var inviteURL: URL? {
        URL(string: "https://worldcupbracket.app/join/\(inviteCode)")
    }

    var localGroup: LocalJoinedGroup {
        LocalJoinedGroup(id: id, name: name, inviteCode: inviteCode, isOwner: isOwner)
    }

    init(id: String, name: String, inviteCode: String, isOwner: Bool) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.isOwner = isOwner
    }

    init(localGroup: LocalJoinedGroup) {
        id = localGroup.id
        name = localGroup.name
        inviteCode = localGroup.inviteCode
        isOwner = localGroup.isOwner
    }

    init(summary: BackendPoolSummary) {
        id = summary.id.uuidString
        name = summary.name
        inviteCode = summary.inviteCode
        isOwner = summary.role == .owner
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

    static func appKnockoutBracket(from tournament: Tournament) -> AppKnockoutBracket {
        let teamsByID = Dictionary(uniqueKeysWithValues: appGroups(from: tournament).flatMap(\.teams).map { ($0.id, $0) })
        let seededTeamIDs = seededTeams.flatMap(\.teams).map(\.id)
        let roundOf32Teams = seededTeamIDs.prefix(32).compactMap { teamsByID[$0] }

        let roundOf32 = (0..<16).map { index in
            AppKnockoutMatch(
                id: "r32-\(index + 1)",
                round: .roundOf32,
                label: "Round of 32 \(index + 1)",
                sourceMatchIDs: [],
                homeTeam: roundOf32Teams[index],
                awayTeam: roundOf32Teams[31 - index]
            )
        }
        let roundOf16 = (0..<8).map { index in
            AppKnockoutMatch(
                id: "r16-\(index + 1)",
                round: .roundOf16,
                label: "Round of 16 \(index + 1)",
                sourceMatchIDs: ["r32-\((index * 2) + 1)", "r32-\((index * 2) + 2)"],
                homeTeam: nil,
                awayTeam: nil
            )
        }
        let quarterfinals = (0..<4).map { index in
            AppKnockoutMatch(
                id: "qf-\(index + 1)",
                round: .quarterfinal,
                label: "Quarterfinal \(index + 1)",
                sourceMatchIDs: ["r16-\((index * 2) + 1)", "r16-\((index * 2) + 2)"],
                homeTeam: nil,
                awayTeam: nil
            )
        }
        let semifinals = (0..<2).map { index in
            AppKnockoutMatch(
                id: "sf-\(index + 1)",
                round: .semifinal,
                label: "Semifinal \(index + 1)",
                sourceMatchIDs: ["qf-\((index * 2) + 1)", "qf-\((index * 2) + 2)"],
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

    private static let teams: [Team] = seededTeams.flatMap { group in
        group.teams.map { team in
            Team(
                id: TeamID(team.id),
                name: team.name,
                countryCode: team.countryCode,
                fifaCode: team.fifaCode,
                seed: team.seed,
                providerReferences: [
                    ProviderReference(providerName: "WorldCupBracket", providerID: ProviderID("team-\(team.id)"))
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
                ProviderReference(providerName: "WorldCupBracket", providerID: ProviderID("match-\(index + 1)"))
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

        for index in 1...16 {
            let groupIndex = min(index, 12) - 1
            let groupID = GroupID(seededTeams[groupIndex].id)
            slots.append(
                KnockoutSlot(
                    id: "r32-\(index)-home",
                    round: .roundOf32,
                    matchID: MatchID("r32-\(index)"),
                    side: .home,
                    source: .groupPlacement(groupID: groupID, position: 1)
                )
            )
            slots.append(
                KnockoutSlot(
                    id: "r32-\(index)-away",
                    round: .roundOf32,
                    matchID: MatchID("r32-\(index)"),
                    side: .away,
                    source: index <= 8
                        ? .bestThirdPlace(rank: index)
                        : .groupPlacement(groupID: GroupID(seededTeams[index - 9].id), position: 2)
                )
            )
        }

        for index in 1...8 {
            slots.append(
                KnockoutSlot(
                    id: "r16-\(index)-home",
                    round: .roundOf16,
                    matchID: MatchID("r16-\(index)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("r32-\((index * 2) - 1)"))
                )
            )
        }

        for index in 1...4 {
            slots.append(
                KnockoutSlot(
                    id: "qf-\(index)-home",
                    round: .quarterfinal,
                    matchID: MatchID("qf-\(index)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("r16-\((index * 2) - 1)"))
                )
            )
        }

        for index in 1...2 {
            slots.append(
                KnockoutSlot(
                    id: "sf-\(index)-home",
                    round: .semifinal,
                    matchID: MatchID("sf-\(index)"),
                    side: .home,
                    source: .matchWinner(matchID: MatchID("qf-\((index * 2) - 1)"))
                )
            )
        }

        slots.append(
            KnockoutSlot(id: "final-home", round: .final, matchID: "final", side: .home, source: .matchWinner(matchID: "sf-1"))
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
