
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var trainingStore: TrainingStore

    private var dayGroups: [DayTrainingGroup] {
        TrainingAnalysisEngine.groupedByDay(sessions: trainingStore.sessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Training History")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .padding(.horizontal)
                    .padding(.top)

                if dayGroups.isEmpty {
                    emptyState
                } else {
                    ForEach(dayGroups) { group in
                        NavigationLink {
                            DayDetailView(dayGroup: group)
                        } label: {
                            dayCard(for: group)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.appBackground)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No saved history yet.")
                .font(.headline)
                .foregroundColor(.primaryText)
            Text("Completed and incomplete sets will appear here after training is saved.")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func dayCard(for group: DayTrainingGroup) -> some View {
        let summary = TrainingAnalysisEngine.daySummary(for: group.sessions)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(dateString(group.date))
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
            }

            HStack(spacing: 12) {
                metricPill(title: "Sets", value: "\(summary.totalSets)")
                metricPill(title: "Completed", value: "\(summary.completedSets)")
                metricPill(title: "Avg Score", value: "\(summary.averageScore)", score: summary.averageScore)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func metricPill(title: String, value: String, score: Int? = nil) -> some View {
        let textColor: Color = {
            guard let score else { return .brandBlue }
            return ScoreVisuals.color(for: score)
        }()
        let background: Color = {
            guard let score else { return .lightBlueCard }
            return ScoreVisuals.background(for: score)
        }()

        return VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(textColor)
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

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject(TrainingStore())
    }
}
