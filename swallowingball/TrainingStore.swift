import Foundation
import Combine

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var sessions: [TrainingSession] = []
    
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(filename: String = "training_sessions.json") {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = documentsURL.appendingPathComponent(filename)
        
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        loadSessions()
    }
    
    func addSession(_ session: TrainingSession) {
        sessions.append(session)
        sessions.sort { $0.startedAt > $1.startedAt }
        persistSessions()
    }
    
    func replaceSession(_ session: TrainingSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            sessions.sort { $0.startedAt > $1.startedAt }
            persistSessions()
        }
    }
    
    func latestSession(for mode: TrainingMode? = nil) -> TrainingSession? {
        if let mode {
            return sessions.first(where: { $0.mode == mode })
        }
        return sessions.first
    }
    
    func previousSession(before session: TrainingSession) -> TrainingSession? {
        sessions
            .filter { $0.mode == session.mode && $0.startedAt < session.startedAt }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }
    
    func recentSessions(for mode: TrainingMode, before session: TrainingSession, limit: Int) -> [TrainingSession] {
        Array(
            sessions
                .filter { $0.mode == mode && $0.startedAt < session.startedAt }
                .sorted { $0.startedAt > $1.startedAt }
                .prefix(limit)
        )
    }
    
    func groupedByDay() -> [DayTrainingGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }
        
        return grouped
            .map { key, value in
                DayTrainingGroup(
                    id: dayKey(for: key),
                    date: key,
                    sessions: value.sorted { $0.startedAt > $1.startedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }
    
    private func loadSessions() {
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try decoder.decode([TrainingSession].self, from: data)
                .sorted { $0.startedAt > $1.startedAt }
        } catch {
            sessions = []
        }
    }
    
    private func persistSessions() {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to persist training sessions: \(error.localizedDescription)")
        }
    }
    
    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
//
//  TrainingStores.swift
//  swallowingball
//
//  Created by Jingwen Liu on 2026/3/16.
//

