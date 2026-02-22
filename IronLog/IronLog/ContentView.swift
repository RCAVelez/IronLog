import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: Tab = .home

    enum Tab { case home, workout, progress, profile }

    var body: some View {
        if hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(Tab.home)
                .tabItem {
                    Label("Home", systemImage: selectedTab == .home
                          ? "house.fill" : "house")
                }

            WorkoutView()
                .tag(Tab.workout)
                .tabItem {
                    Label("Workout", systemImage: selectedTab == .workout
                          ? "bolt.fill" : "bolt")
                }

            IronProgressView()
                .tag(Tab.progress)
                .tabItem {
                    Label("Progress", systemImage: selectedTab == .progress
                          ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                }

            ProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label("Profile", systemImage: selectedTab == .profile
                          ? "person.fill" : "person")
                }
        }
        .tint(Color.ironBlue)
        .preferredColorScheme(.dark)
    }
}
