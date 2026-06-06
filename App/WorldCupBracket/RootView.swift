import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        if appModel.step == .signUp {
            NavigationStack {
                SignUpView()
            }
        } else {
            TabView(selection: $appModel.selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppModel.AppTab.home)

                BracketsTabView()
                .tabItem {
                    Label("Brackets", systemImage: "square.grid.3x3.fill")
                }
                .tag(AppModel.AppTab.brackets)

                NavigationStack {
                    GroupsTabView()
                }
                .tabItem {
                    Label("Groups", systemImage: "person.2.fill")
                }
                .tag(AppModel.AppTab.groups)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(AppModel.AppTab.profile)
            }
        }
    }
}
