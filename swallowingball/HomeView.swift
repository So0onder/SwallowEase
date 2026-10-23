
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore

    private var latestSession: TrainingSession? {
        trainingStore.sessions.sorted { $0.startedAt > $1.startedAt }.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                NavigationLink {
                    LiveTrainingView()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.brandBlue)
                            .frame(width: 260, height: 260)
                            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)

                        VStack(spacing: 6) {
                            Text("Start\nToday’s Training")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 40)

                goalCard
                analysisCard

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s training goal")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            Text(settings.todayGoalText)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(goalTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .padding()
        .background(Color.lightBlueCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Analysis")
                .font(.headline)
                .foregroundColor(.primaryText)

            Divider()

            if let session = latestSession {
                let score = TrainingAnalysisEngine.sessionScore(for: session)
                let previous = TrainingAnalysisEngine.previousSameModeSession(for: session, in: trainingStore.sessions)
                let lines = TrainingAnalysisEngine.homeSummary(for: session, previousSameMode: previous)

                HStack(spacing: 12) {
                    scoreBadge(score: score)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)

                        StatusBadge(
                            text: session.isComplete ? "Complete" : "Incomplete",
                            style: session.isComplete ? .positive : .attention
                        )
                    }

                    Spacer()
                }
                .padding(.bottom, 4)

                ForEach(lines, id: \.self) { line in
                    Text("• \(line)")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            } else {
                Text("No training session has been saved yet.")
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .background(Color.lightBlueCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func scoreBadge(score: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ScoreVisuals.color(for: score))
            Text("Score")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(width: 72, height: 72)
        .background(ScoreVisuals.background(for: score))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ScoreVisuals.color(for: score).opacity(0.18), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var goalTextColor: Color {
        settings.todayGoalText == "No training scheduled for today" ? .secondaryText : .successGreen
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppSettings())
            .environmentObject(TrainingStore())
    }
}
