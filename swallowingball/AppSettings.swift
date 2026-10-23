import SwiftUI
import Combine

enum TrainingMode: String, CaseIterable, Identifiable, Codable {
    case dynamic = "Dynamic Squeeze"
    case staticHold = "Static Hold"
    
    var id: String { rawValue }
}

enum Weekday: String, CaseIterable, Identifiable, Codable {
    case monday = "Mon"
    case tuesday = "Tue"
    case wednesday = "Wed"
    case thursday = "Thu"
    case friday = "Fri"
    case saturday = "Sat"
    case sunday = "Sun"
    
    var id: String { rawValue }
}

final class AppSettings: ObservableObject {
    // MARK: - Personal Information
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var age: String = ""
    
    // MARK: - Training Plan
    @Published var trainingDays: Set<Weekday> = [.monday, .wednesday, .saturday]
    @Published var trainingMode: TrainingMode = .dynamic
    @Published var setsPerDay: Int = 1
    @Published var repsPerSet: Int = 10
    @Published var staticHoldDurationSec: Int = 10
    
    let staticHoldDurationOptions: [Int] = [5, 10, 15, 20]
    
    // MARK: - Device
    var trainingDaysText: String {
        if trainingDays.isEmpty {
            return "None"
        }
        
        let ordered = Weekday.allCases.filter { trainingDays.contains($0) }
        return ordered.map(\.rawValue).joined(separator: ", ")
    }
    
    var repOptions: [Int] {
        switch trainingMode {
        case .dynamic:
            return [10, 15, 20, 25, 30]
        case .staticHold:
            return Array(3...10)
        }
    }
    
    var todayGoalText: String {
        let today = currentWeekday()
        
        guard trainingDays.contains(today) else {
            return "No training scheduled for today"
        }
        
        switch trainingMode {
        case .dynamic:
            return "Dynamic Squeeze · \(setsPerDay) set(s) × \(repsPerSet) rep(s)"
        case .staticHold:
            return "Static Hold · \(setsPerDay) set(s) × \(repsPerSet) rep(s) · \(staticHoldDurationSec)s hold"
        }
    }
    
    func ensureValidReps() {
        if !repOptions.contains(repsPerSet) {
            repsPerSet = repOptions.first ?? 10
        }
    }
    
    private func currentWeekday() -> Weekday {
        let weekdayNumber = Calendar.current.component(.weekday, from: Date())
        
        switch weekdayNumber {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
    }
}
