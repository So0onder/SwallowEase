
import SwiftUI

struct ReportDetailView: View {
    let session: TrainingSession
    @EnvironmentObject var trainingStore: TrainingStore

    private var metrics: SessionMetrics {
        TrainingAnalysisEngine.metrics(for: session)
    }

    private var score: Int {
        TrainingAnalysisEngine.sessionScore(for: session)
    }

    private var breakdown: SessionScoreBreakdown {
        TrainingAnalysisEngine.scoreBreakdown(for: session)
    }

    private var recentSameMode: [TrainingSession] {
        TrainingAnalysisEngine.recentSameModeSessions(for: session, in: trainingStore.sessions, limit: 3)
    }

    private var summaryLines: [String] {
        TrainingAnalysisEngine.reportSummary(for: session, recentSameMode: recentSameMode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                metricsCard
                chartCard
                scoreCard
                interpretationCard
                footerCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Summary")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            HStack(alignment: .top, spacing: 14) {
                scoreBadge

                VStack(alignment: .leading, spacing: 8) {
                    metricLabelValue("Mode", session.mode.rawValue)
                    metricLabelValue("Time", dateTimeString(session.startedAt))
                    HStack {
                        Text("Status")
                            .foregroundColor(.primaryText)
                        Spacer()
                        StatusBadge(
                            text: session.isComplete ? "Complete" : "Incomplete",
                            style: session.isComplete ? .positive : .attention
                        )
                    }
                    metricLabelValue("Duration", "\(format(session.sessionDurationSec, decimals: 1)) s")
                }
            }
        }
        .modifier(ReportCardStyle())
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            Group {
                metricRow(title: "Completed Cycles", value: "\(metrics.completedCycles) / \(metrics.targetReps)")
                metricRow(title: "Goal-Reaching Cycles", value: "\(metrics.goalReachedCount)")
                if session.mode == .dynamic {
                    metricRow(title: "Average Peak Force", value: "\(format(metrics.avgPeakForce, decimals: 1)) N")
                    metricRow(title: "Best Peak Force", value: "\(format(metrics.bestPeakForce, decimals: 1)) N")
                } else {
                    metricRow(title: "Average Effective Hold Time", value: "\(format(metrics.avgHoldTime, decimals: 1)) s")
                    metricRow(title: "Longest Effective Hold Time", value: "\(format(metrics.longestHoldTime, decimals: 1)) s")
                    metricRow(title: "Target Hold Duration", value: "\(session.staticHoldTargetSec ?? 0) s")
                }
                metricRow(title: "CV", value: "\(format(metrics.coefficientOfVariation, decimals: 2))")
            }
        }
        .modifier(ReportCardStyle())
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attempt Overview")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            if session.attempts.isEmpty {
                Text("No attempt data was recorded for this set.")
                    .foregroundColor(.secondaryText)
            } else {
                ForEach(Array(session.attempts.enumerated()), id: \.element.id) { index, attempt in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cycle \(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            Spacer()
                            StatusBadge(
                                text: attempt.metPrimaryGoal ? "Goal reached" : "Below target",
                                style: attempt.metPrimaryGoal ? .positive : .attention
                            )
                        }

                        AttemptBar(
                            value: normalizedValue(for: attempt),
                            color: attemptBarColor(for: attempt),
                            trackColor: .lineSoft.opacity(0.85)
                        )

                        Text(detailText(for: attempt))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }

                    if index < session.attempts.count - 1 {
                        Divider().padding(.vertical, 4)
                    }
                }
            }
        }
        .modifier(ReportCardStyle())
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            scoreRow(title: "Completion", value: breakdown.completion, max: 40)
            scoreRow(title: session.mode == .dynamic ? "Target Achievement" : "Hold Achievement", value: breakdown.targetAchievement, max: 25)
            scoreRow(title: session.mode == .dynamic ? "Consistency" : "Stability", value: breakdown.consistencyOrStability, max: 20)
            scoreRow(title: "Validity Control", value: breakdown.validityControl, max: 15)
        }
        .modifier(ReportCardStyle())
    }

    private var interpretationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report Interpretation")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            ForEach(summaryLines, id: \.self) { line in
                Text("• \(line)")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
        }
        .modifier(ReportCardStyle())
    }

    private var footerCard: some View {
        Text("This report summarizes training performance in this session and should be interpreted together with professional guidance when needed.")
            .font(.footnote)
            .foregroundColor(.secondaryText)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var scoreBadge: some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ScoreVisuals.color(for: score))
            Text("Score")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(width: 88, height: 88)
        .background(ScoreVisuals.background(for: score))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(ScoreVisuals.color(for: score).opacity(0.18), lineWidth: 1)
        )
        .cornerRadius(18)
    }

    private func metricLabelValue(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundColor(.primaryText)
            Spacer()
            Text(value)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primaryText)
            Spacer()
            Text(value)
                .foregroundColor(.secondaryText)
        }
    }

    private func scoreRow(title: String, value: Int, max: Int) -> some View {
        let ratio = max > 0 ? Double(value) / Double(max) : 0
        let color = RatioVisuals.color(for: ratio)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundColor(.primaryText)
                Spacer()
                Text("\(value) / \(max)")
                    .foregroundColor(color)
                    .fontWeight(.semibold)
            }

            AttemptBar(
                value: ratio,
                color: color,
                trackColor: .lineSoft.opacity(0.85)
            )
        }
    }

    private func normalizedValue(for attempt: TrainingAttempt) -> Double {
        switch session.mode {
        case .dynamic:
            return min(max(attempt.peakForceN / 17.0, 0), 1)
        case .staticHold:
            let target = Double(session.staticHoldTargetSec ?? 1)
            return min(max(attempt.holdTimeAboveThresholdSec / max(target, 1), 0), 1)
        }
    }

    private func detailText(for attempt: TrainingAttempt) -> String {
        switch session.mode {
        case .dynamic:
            return "Peak force: \(format(attempt.peakForceN, decimals: 1)) N"
        case .staticHold:
            return "Effective hold time: \(format(attempt.holdTimeAboveThresholdSec, decimals: 1)) s"
        }
    }

    private func attemptBarColor(for attempt: TrainingAttempt) -> Color {
        attempt.metPrimaryGoal ? .successGreen : .warningAmber
    }

    private func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.*f", decimals, value)
    }
}

private struct ReportCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct AttemptBar: View {
    let value: Double
    var color: Color = .brandBlue
    var trackColor: Color = .lineSoft.opacity(0.85)

    var body: some View {
        GeometryReader { geometry in
            let progress = max(0, min(value, 1))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 12)
    }
}

#Preview {
    NavigationStack {
        let attempt1 = TrainingAttempt(
            mode: .dynamic,
            startTime: Date(),
            endTime: Date(),
            durationSec: 1.2,
            peakForceN: 13.8,
            holdTimeAboveThresholdSec: 0,
            reachedDynamicTarget: true,
            reachedStaticThreshold: false,
            reachedTargetHoldDuration: false,
            peakCount: 1
        )

        let session = TrainingSession(
            startedAt: Date(),
            endedAt: Date(),
            mode: .dynamic,
            targetReps: 6,
            staticHoldTargetSec: nil,
            exitReason: .completed,
            isComplete: true,
            attempts: [attempt1]
        )

        ReportDetailView(session: session)
            .environmentObject(TrainingStore())
    }
}
