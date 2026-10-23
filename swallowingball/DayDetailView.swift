
import SwiftUI

struct DayDetailView: View {
    let dayGroup: DayTrainingGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                daySummaryCard

                ForEach(dayGroup.sessions) { session in
                    NavigationLink {
                        ReportDetailView(session: session)
                    } label: {
                        sessionCard(session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var daySummaryCard: some View {
        let summary = TrainingAnalysisEngine.daySummary(for: dayGroup.sessions)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Day Summary")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            HStack(spacing: 12) {
                summaryBox(title: "Sets", value: "\(summary.totalSets)")
                summaryBox(title: "Completed", value: "\(summary.completedSets)")
                summaryBox(title: "Avg Score", value: "\(summary.averageScore)", score: summary.averageScore)
            }
        }
        .padding()
        .background(Color.lightBlueCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func sessionCard(_ session: TrainingSession) -> some View {
        let metrics = TrainingAnalysisEngine.metrics(for: session)
        let score = TrainingAnalysisEngine.sessionScore(for: session)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(timeString(session.startedAt))
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Spacer()
                StatusBadge(
                    text: session.isComplete ? "Complete" : "Incomplete",
                    style: session.isComplete ? .positive : .attention
                )
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
            }

            Text(session.mode.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.brandBlue)

            HStack(spacing: 12) {
                summaryBox(title: "Score", value: "\(score)", score: score)
                summaryBox(title: "Cycles", value: "\(metrics.completedCycles)/\(metrics.targetReps)")
                if session.mode == .dynamic {
                    summaryBox(title: "Avg Peak", value: "\(format(metrics.avgPeakForce, decimals: 1)) N")
                } else {
                    summaryBox(title: "Avg Hold", value: "\(format(metrics.avgHoldTime, decimals: 1)) s")
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func summaryBox(title: String, value: String, score: Int? = nil) -> some View {
        let textColor: Color = {
            guard let score else { return .brandBlue }
            return ScoreVisuals.color(for: score)
        }()
        let background: Color = {
            guard let score else { return Color.white.opacity(0.82) }
            return ScoreVisuals.background(for: score)
        }()

        return VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(score == nil ? Color.clear : textColor.opacity(0.16), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dayGroup.date)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.*f", decimals, value)
    }
}

#Preview {
    NavigationStack {
        let session = TrainingSession(
            startedAt: Date(),
            endedAt: Date(),
            mode: .dynamic,
            targetReps: 6,
            staticHoldTargetSec: nil,
            exitReason: .completed,
            isComplete: true,
            attempts: []
        )
        DayDetailView(dayGroup: DayTrainingGroup(id: "preview", date: Date(), sessions: [session]))
    }
}
