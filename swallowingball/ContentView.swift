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
    
    var body: some View {
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
        .environmentObject(settings)
        .environmentObject(bluetoothManager)
        .environmentObject(trainingStore)
    }
}

#Preview {
    ContentView()
}
