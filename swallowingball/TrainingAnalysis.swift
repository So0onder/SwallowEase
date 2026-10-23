import SwiftUI
import Foundation

struct SessionScoreBreakdown {
    let completion: Int
    let targetAchievement: Int
    let consistencyOrStability: Int
    let validityControl: Int

    var total: Int {
        completion + targetAchievement + consistencyOrStability + validityControl
    }
}

struct SessionMetrics {
    let mode: TrainingMode
    let completedCycles: Int
    let targetReps: Int
    let completionRate: Double
    let avgPeakForce: Double
    let bestPeakForce: Double
    let avgHoldTime: Double
    let longestHoldTime: Double
    let goalReachedCount: Int
    let goalReachedRate: Double
    let coefficientOfVariation: Double
    let primaryValueForComparison: Double
}

struct DaySummaryMetrics {
    let totalSets: Int
    let completedSets: Int
    let averageScore: Int
}

enum TrainingAnalysisEngine {
    private static let dynamicIntegrityMinDurationSec: Double = 0.25
    private static let dynamicIntegrityMinPeakForceN: Double = 1.5
    private static let dynamicIntegrityMultiPeakThreshold: Int = 3

    static func metrics(for session: TrainingSession) -> SessionMetrics {
        let peaks = session.attempts.map { $0.peakForceN }
        let holds = session.attempts.map { $0.holdTimeAboveThresholdSec }
        let avgPeak = average(peaks)
        let bestPeak = peaks.max() ?? 0
        let avgHold = average(holds)
        let longestHold = holds.max() ?? 0
        let cvBase = session.mode == .dynamic ? avgPeak : avgHold
        let cvSource = session.mode == .dynamic ? peaks : holds
        let cv = coefficientOfVariation(values: cvSource, mean: cvBase)
        let completed = session.completedCycles
        let target = max(session.targetReps, 1)
        let goalReached = session.goalReachedCount
        let goalRate = Double(goalReached) / Double(target)

        return SessionMetrics(
            mode: session.mode,
            completedCycles: completed,
            targetReps: target,
            completionRate: Double(completed) / Double(target),
            avgPeakForce: avgPeak,
            bestPeakForce: bestPeak,
            avgHoldTime: avgHold,
            longestHoldTime: longestHold,
            goalReachedCount: goalReached,
            goalReachedRate: goalRate,
            coefficientOfVariation: cv,
            primaryValueForComparison: session.mode == .dynamic ? avgPeak : avgHold
        )
    }

    static func scoreBreakdown(for session: TrainingSession) -> SessionScoreBreakdown {
        let sessionMetrics = metrics(for: session)

        let completion: Int
        switch sessionMetrics.completionRate {
        case 1.0...: completion = 40
        case 0.8..<1.0: completion = 34
        case 0.6..<0.8: completion = 26
        case 0.4..<0.6: completion = 18
        default: completion = 10
        }

        let achievement: Int
        switch sessionMetrics.goalReachedRate {
        case 0.9...: achievement = 25
        case 0.7..<0.9: achievement = 20
        case 0.5..<0.7: achievement = 15
        case 0.3..<0.5: achievement = 10
        default: achievement = 5
        }

        let consistency: Int
        switch sessionMetrics.coefficientOfVariation {
        case ..<0.10: consistency = 20
        case 0.10..<0.20: consistency = 14
        default: consistency = 8
        }

        let validityIssues = validityIssueCount(for: session)
        let validityControl: Int
        switch validityIssues {
        case 0: validityControl = 15
        case 1...2: validityControl = 10
        default: validityControl = 5
        }

        return SessionScoreBreakdown(
            completion: completion,
            targetAchievement: achievement,
            consistencyOrStability: consistency,
            validityControl: validityControl
        )
    }

    static func sessionScore(for session: TrainingSession) -> Int {
        scoreBreakdown(for: session).total
    }

    static func homeSummary(for session: TrainingSession, previousSameMode: TrainingSession?) -> [String] {
        let sessionMetrics = metrics(for: session)
        var lines: [String] = []

        switch session.mode {
        case .dynamic:
            lines.append("Completed \(sessionMetrics.completedCycles) of \(sessionMetrics.targetReps) repetitions. Average peak force was \(format(sessionMetrics.avgPeakForce, decimals: 1)) N.")
            lines.append("\(sessionMetrics.goalReachedCount) repetitions reached the 10 N target, with \(consistencyPhrase(from: sessionMetrics.coefficientOfVariation)).")
        case .staticHold:
            let targetSec = session.staticHoldTargetSec ?? 0
            lines.append("Completed \(sessionMetrics.completedCycles) of \(sessionMetrics.targetReps) holds. Average effective hold time was \(format(sessionMetrics.avgHoldTime, decimals: 1)) s.")
            lines.append("\(sessionMetrics.goalReachedCount) holds reached the \(targetSec) s target, with \(stabilityPhrase(from: sessionMetrics.coefficientOfVariation)).")
        }

        if let previousSameMode {
            let previousMetrics = metrics(for: previousSameMode)
            let delta = comparisonDelta(current: sessionMetrics.primaryValueForComparison, previous: previousMetrics.primaryValueForComparison)
            lines.append(comparisonSentence(mode: session.mode, delta: delta))
        } else {
            lines.append("No previous session available for comparison.")
        }

        return lines
    }

    static func reportSummary(for session: TrainingSession, recentSameMode: [TrainingSession]) -> [String] {
        let sessionMetrics = metrics(for: session)
        var lines: [String] = []

        switch session.mode {
        case .dynamic:
            lines.append("This session included \(sessionMetrics.completedCycles) repetitions out of \(sessionMetrics.targetReps). Best peak force was \(format(sessionMetrics.bestPeakForce, decimals: 1)) N.")
            lines.append("Average peak force was \(format(sessionMetrics.avgPeakForce, decimals: 1)) N, and \(sessionMetrics.goalReachedCount) repetitions reached the 10 N target.")
            lines.append("Peak force was \(consistencyPhrase(from: sessionMetrics.coefficientOfVariation)). \(dynamicValiditySentence(for: session))")
        case .staticHold:
            let targetSec = session.staticHoldTargetSec ?? 0
            lines.append("This session included \(sessionMetrics.completedCycles) holds out of \(sessionMetrics.targetReps). Longest effective hold time was \(format(sessionMetrics.longestHoldTime, decimals: 1)) s.")
            lines.append("Average effective hold time was \(format(sessionMetrics.avgHoldTime, decimals: 1)) s, and \(sessionMetrics.goalReachedCount) holds reached the \(targetSec) s target.")
            lines.append("Hold stability was \(stabilityPhrase(from: sessionMetrics.coefficientOfVariation)). \(staticValiditySentence(for: session))")
        }

        let recent = recentSameMode.filter { $0.id != session.id }
        if !recent.isEmpty {
            let avgRecentPrimary = average(recent.map { metrics(for: $0).primaryValueForComparison })
            let delta = comparisonDelta(current: sessionMetrics.primaryValueForComparison, previous: avgRecentPrimary)
            lines.append(recentComparisonSentence(mode: session.mode, count: recent.count, delta: delta))
        }

        return lines
    }

    static func daySummary(for sessions: [TrainingSession]) -> DaySummaryMetrics {
        let total = sessions.count
        let completed = sessions.filter { $0.isComplete }.count
        let scores = sessions.map { Double(sessionScore(for: $0)) }
        let averageScore = Int(average(scores).rounded())
        return DaySummaryMetrics(totalSets: total, completedSets: completed, averageScore: averageScore)
    }

    static func groupedByDay(sessions: [TrainingSession]) -> [DayTrainingGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { day in
            let daySessions = (grouped[day] ?? []).sorted { $0.startedAt > $1.startedAt }
            let id = ISO8601DateFormatter().string(from: day)
            return DayTrainingGroup(id: id, date: day, sessions: daySessions)
        }
    }

    static func previousSameModeSession(for session: TrainingSession, in sessions: [TrainingSession]) -> TrainingSession? {
        sessions
            .filter { $0.mode == session.mode && $0.startedAt < session.startedAt }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    static func recentSameModeSessions(for session: TrainingSession, in sessions: [TrainingSession], limit: Int = 3) -> [TrainingSession] {
        sessions
            .filter { $0.mode == session.mode && $0.id != session.id && $0.startedAt < session.startedAt }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(limit)
            .map { $0 }
    }

    private static func validityIssueCount(for session: TrainingSession) -> Int {
        switch session.mode {
        case .dynamic:
            return session.attempts.filter { attempt in
                dynamicAttemptHasValidityIssue(attempt)
            }.count
        case .staticHold:
            return session.attempts.filter { attempt in
                !attempt.reachedStaticThreshold || (attempt.reachedStaticThreshold && !attempt.reachedTargetHoldDuration)
            }.count
        }
    }

    private static func dynamicAttemptHasValidityIssue(_ attempt: TrainingAttempt) -> Bool {
        let abnormallyShort = attempt.durationSec < dynamicIntegrityMinDurationSec
        let multiPeak = attempt.peakCount >= dynamicIntegrityMultiPeakThreshold
        let noClearPeak = attempt.peakForceN < dynamicIntegrityMinPeakForceN
        return abnormallyShort || multiPeak || noClearPeak
    }

    private static func dynamicValiditySentence(for session: TrainingSession) -> String {
        let issueCount = validityIssueCount(for: session)
        switch issueCount {
        case 0:
            return "No obvious action-integrity issues were detected."
        case 1...2:
            return "A small number of repetitions showed reduced action clarity."
        default:
            return "Several repetitions showed reduced action clarity."
        }
    }

    private static func staticValiditySentence(for session: TrainingSession) -> String {
        let issueCount = validityIssueCount(for: session)
        switch issueCount {
        case 0:
            return "All repetitions reached the minimum hold threshold and target hold duration."
        case 1...2:
            return "A small number of repetitions did not reach the minimum hold threshold or target hold duration."
        default:
            return "Several repetitions did not reach the minimum hold threshold or target hold duration."
        }
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func coefficientOfVariation(values: [Double], mean: Double) -> Double {
        guard values.count > 1, mean > 0 else { return 0 }
        let variance = values.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(values.count)
        let sd = sqrt(variance)
        return sd / mean
    }

    private static func consistencyPhrase(from cv: Double) -> String {
        switch cv {
        case ..<0.10: return "relatively consistent peak force"
        case 0.10..<0.20: return "mild variation across repetitions"
        default: return "more variation across repetitions"
        }
    }

    private static func stabilityPhrase(from cv: Double) -> String {
        switch cv {
        case ..<0.10: return "relatively stable hold control"
        case 0.10..<0.20: return "mild variation during holds"
        default: return "more variation during holds"
        }
    }

    private static func comparisonDelta(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return (current - previous) / previous
    }

    private static func comparisonSentence(mode: TrainingMode, delta: Double) -> String {
        let subject = mode == .dynamic ? "Average peak force" : "Average effective hold time"
        switch delta {
        case let d where d >= 0.10:
            return "\(subject) was higher than the previous session."
        case let d where d <= -0.10:
            return "\(subject) was lower than the previous session."
        default:
            return "\(subject) was similar to the previous session."
        }
    }

    private static func recentComparisonSentence(mode: TrainingMode, count: Int, delta: Double) -> String {
        let subject = mode == .dynamic ? "Average peak force" : "Average effective hold time"
        let recentLabel = count == 1 ? "the previous same-mode session" : "the recent \(count) same-mode sessions"
        switch delta {
        case let d where d >= 0.10:
            return "\(subject) was higher than \(recentLabel)."
        case let d where d <= -0.10:
            return "\(subject) was lower than \(recentLabel)."
        default:
            return "\(subject) was similar to \(recentLabel)."
        }
    }

    private static func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.*f", decimals, value)
    }
}
