import SwiftUI

enum AppTab {
    case history
    case home
    case account
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @StateObject private var settings = AppSettings()
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var trainingStore = TrainingStore()

    #if DEBUG
    private let showcaseScreen = ProcessInfo.processInfo.environment["SWALLOWEASE_SHOWCASE"] ?? ""
    #endif

    var body: some View {
        rootContent
            .environmentObject(settings)
            .environmentObject(bluetoothManager)
            .environmentObject(trainingStore)
            #if DEBUG
            .onAppear {
                guard !showcaseScreen.isEmpty else { return }
                settings.trainingDays = Set(Weekday.allCases)
                if trainingStore.sessions.isEmpty {
                    trainingStore.addSession(Self.showcaseSession)
                }
            }
            #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if showcaseScreen == "live" {
            NavigationStack {
                LiveTrainingView()
            }
        } else if showcaseScreen == "report" {
            NavigationStack {
                ReportDetailView(session: Self.showcaseSession)
            }
        } else {
            mainTabs
        }
        #else
        mainTabs
        #endif
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Image(systemName: "doc.text.magnifyingglass")
                Text("History")
            }
            .tag(AppTab.history)
            
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Image(systemName: "sportscourt")
                Text("Home")
            }
            .tag(AppTab.home)
            
            NavigationStack {
                AccountView()
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Account")
            }
            .tag(AppTab.account)
        }
    }

    #if DEBUG
    private static var showcaseSession: TrainingSession {
        let end = Date()
        let start = end.addingTimeInterval(-24.6)
        let peakForces = [14.8, 13.9, 15.4, 12.4, 14.6, 13.2, 15.0, 14.1, 12.7, 15.5]
        let attempts = peakForces.enumerated().map { index, peak in
            let attemptStart = start.addingTimeInterval(Double(index) * 1.8 + 0.2)
            return TrainingAttempt(
                mode: .dynamic,
                startTime: attemptStart,
                endTime: attemptStart.addingTimeInterval(0.95 + Double(index % 3) * 0.06),
                durationSec: 0.95 + Double(index % 3) * 0.06,
                peakForceN: peak,
                holdTimeAboveThresholdSec: 0,
                reachedDynamicTarget: peak >= 13.0,
                reachedStaticThreshold: false,
                reachedTargetHoldDuration: false,
                peakCount: 1
            )
        }

        return TrainingSession(
            startedAt: start,
            endedAt: end,
            mode: .dynamic,
            targetReps: peakForces.count,
            staticHoldTargetSec: nil,
            exitReason: .completed,
            isComplete: true,
            attempts: attempts
        )
    }
    #endif
}

#Preview {
    ContentView()
}
