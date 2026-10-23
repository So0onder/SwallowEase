import SwiftUI

struct LiveTrainingView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var trainingStore: TrainingStore
    @Environment(\.dismiss) private var dismiss

    private let timerInterval: Double = 0.05

    // Latest confirmed thresholds / display settings
    private let dynamicTargetThresholdN: Double = 13.0
    private let staticTargetThresholdN: Double = 13.0
    private let cycleThresholdN: Double = 2.0
    private let liveChartDisplayMaxForceN: Double = 18.0

    @State private var pressurePoints: [Double] = Array(repeating: 0, count: 50)
    @State private var currentPressureDisplay: Double = 0
    @State private var progress: Double = 0

    @State private var completedCycles: Int = 0
    @State private var currentValidHoldTimeSec: Double = 0

    @State private var coachingText: String = "Begin the next repetition"
    @State private var coachingColor: Color = .successGreen
    @State private var coachingBackground: Color = .successGreenBg

    @State private var timer: Timer?
    @State private var elapsedSessionTime: Double = 0

    @State private var sessionStartTime: Date = Date()
    @State private var sessionSaved = false

    @State private var isInAttempt = false
    @State private var attemptStartTime: Date?
    @State private var attemptPeakForceN: Double = 0
    @State private var attemptValidHoldTimeSec: Double = 0
    @State private var attemptReachedDynamicTarget = false
    @State private var attemptReachedStaticThreshold = false
    @State private var attemptSamples: [Double] = []

    @State private var recordedAttempts: [TrainingAttempt] = []

    // Completion / navigation flow
    @State private var completedSession: TrainingSession?
    @State private var showCompletionOverlay = false
    @State private var showReportSheet = false
    @State private var dismissAfterReport = false
    @State private var autoDismissWorkItem: DispatchWorkItem?

    private var totalTargetCycles: Int { max(settings.repsPerSet, 1) }
    private var currentHoldSecondsDisplay: Int { Int(attemptValidHoldTimeSec.rounded(.down)) }
    private var isUsingRealDeviceData: Bool { bluetoothManager.isConnected }
    private var modeTitle: String { settings.trainingMode == .dynamic ? "Dynamic Squeeze" : "Static Hold" }
    private var thresholdRatio: Double { min(dynamicTargetThresholdN / liveChartDisplayMaxForceN, 1.0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Live Training")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                    .foregroundColor(.primaryText)

                Text(coachingText)
                    .font(.headline)
                    .foregroundColor(coachingColor)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(coachingBackground)
                    .cornerRadius(22)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Pressure")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text(modeTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }

                    LivePressureChart(
                        data: pressurePoints,
                        thresholdRatio: thresholdRatio
                    )
                    .frame(height: 240)

                    HStack {
                        Text(String(format: "Current pressure: %.2f N", currentPressureDisplay))
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(String(format: "Target: %.1f N", dynamicTargetThresholdN))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 12) {
                    if settings.trainingMode == .dynamic {
                        Text("Current repetitions: \(completedCycles) / \(totalTargetCycles)")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                    } else {
                        Text("Current valid hold time: \(currentHoldSecondsDisplay) s")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                    }

                    Text("Current Training Progress")
                        .font(.headline)
                        .foregroundColor(.primaryText)

                    ProgressBar(progress: progress)
                        .frame(height: 16)

                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.brandBlue)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
        .background(Color.appBackground)
        .navigationTitle("Live Training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startTraining() }
        .onDisappear { handleViewDisappear() }
        .sheet(isPresented: $showReportSheet, onDismiss: handleReportDismiss) {
            if let session = completedSession {
                NavigationStack {
                    ReportDetailView(session: session)
                }
            }
        }
        .overlay {
            if showCompletionOverlay, let session = completedSession {
                completionOverlay(session: session)
            }
        }
    }
}

// MARK: - Session lifecycle
extension LiveTrainingView {
    private func startTraining() {
        stopTraining()
        autoDismissWorkItem?.cancel()
        dismissAfterReport = false
        showReportSheet = false
        showCompletionOverlay = false
        completedSession = nil
        resetSessionState()

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            updateFrame()
        }
    }

    private func stopTraining() {
        timer?.invalidate()
        timer = nil
    }

    private func resetSessionState() {
        pressurePoints = Array(repeating: 0, count: 50)
        currentPressureDisplay = 0
        progress = 0
        completedCycles = 0
        currentValidHoldTimeSec = 0
        recordedAttempts = []
        elapsedSessionTime = 0
        sessionStartTime = Date()
        sessionSaved = false

        resetAttemptState()
        updateCoachingText(for: 0)
    }

    private func handleViewDisappear() {
        stopTraining()
        autoDismissWorkItem?.cancel()
        guard !sessionSaved else { return }
        saveSession(exitReason: .userExited, isComplete: false)
    }

    private func handleReportDismiss() {
        if dismissAfterReport {
            dismissAfterReport = false
            dismiss()
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            if showCompletionOverlay {
                dismiss()
            }
        }
        autoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: workItem)
    }

    private func updateFrame() {
        elapsedSessionTime += timerInterval
        let pressureN = isUsingRealDeviceData
            ? Double(bluetoothManager.currentPressureN)
            : simulatedPressureValue(at: elapsedSessionTime)
        processPressureSample(pressureN)
    }
}

// MARK: - Pressure processing
extension LiveTrainingView {
    private func appendPressurePoint(_ value: Double) {
        let normalized = max(0, min(value, 1))
        pressurePoints.append(normalized)
        let maxCount = 50
        if pressurePoints.count > maxCount {
            pressurePoints.removeFirst(pressurePoints.count - maxCount)
        }
    }

    private func processPressureSample(_ pressureN: Double) {
        let clampedPressure = max(0, pressureN)
        currentPressureDisplay = clampedPressure
        appendPressurePoint(min(clampedPressure / liveChartDisplayMaxForceN, 1.0))

        guard !showCompletionOverlay else { return }

        if !isInAttempt, clampedPressure >= cycleThresholdN {
            beginAttempt()
        }

        if isInAttempt {
            updateAttemptMetrics(with: clampedPressure)
            if clampedPressure <= cycleThresholdN {
                finishAttempt()
            }
        }

        progress = min(Double(completedCycles) / Double(totalTargetCycles), 1.0)
        updateCoachingText(for: clampedPressure)
    }

    private func beginAttempt() {
        isInAttempt = true
        attemptStartTime = Date()
        attemptPeakForceN = 0
        attemptValidHoldTimeSec = 0
        attemptReachedDynamicTarget = false
        attemptReachedStaticThreshold = false
        attemptSamples = []
        currentValidHoldTimeSec = 0
    }

    private func updateAttemptMetrics(with pressureN: Double) {
        attemptPeakForceN = max(attemptPeakForceN, pressureN)
        attemptSamples.append(pressureN)

        switch settings.trainingMode {
        case .dynamic:
            if pressureN >= dynamicTargetThresholdN {
                attemptReachedDynamicTarget = true
            }
            currentValidHoldTimeSec = 0
        case .staticHold:
            if pressureN >= staticTargetThresholdN {
                attemptReachedStaticThreshold = true
                attemptValidHoldTimeSec += timerInterval
            }
            currentValidHoldTimeSec = attemptValidHoldTimeSec
        }
    }

    private func finishAttempt() {
        guard let startTime = attemptStartTime else {
            resetAttemptState()
            return
        }

        let endTime = Date()
        let duration = max(endTime.timeIntervalSince(startTime), 0)
        let reachedTargetHoldDuration = attemptValidHoldTimeSec >= Double(settings.staticHoldDurationSec)
        let peakCount = countLocalPeaks(in: attemptSamples)

        let attempt = TrainingAttempt(
            mode: settings.trainingMode,
            startTime: startTime,
            endTime: endTime,
            durationSec: duration,
            peakForceN: attemptPeakForceN,
            holdTimeAboveThresholdSec: attemptValidHoldTimeSec,
            reachedDynamicTarget: attemptReachedDynamicTarget,
            reachedStaticThreshold: attemptReachedStaticThreshold,
            reachedTargetHoldDuration: reachedTargetHoldDuration,
            peakCount: peakCount
        )

        recordedAttempts.append(attempt)
        completedCycles = recordedAttempts.count
        progress = min(Double(completedCycles) / Double(totalTargetCycles), 1.0)

        resetAttemptState()

        if completedCycles >= totalTargetCycles {
            progress = 1
            stopTraining()
            if let session = saveSession(exitReason: .completed, isComplete: true) {
                completedSession = session
                showCompletionOverlay = true
                coachingText = "Session completed"
                coachingColor = .brandBlue
                coachingBackground = .neutralBlueBg
                scheduleAutoDismiss()
            }
        }
    }

    private func resetAttemptState() {
        isInAttempt = false
        attemptStartTime = nil
        attemptPeakForceN = 0
        attemptValidHoldTimeSec = 0
        attemptReachedDynamicTarget = false
        attemptReachedStaticThreshold = false
        attemptSamples = []
        currentValidHoldTimeSec = 0
    }

    private func countLocalPeaks(in samples: [Double]) -> Int {
        guard samples.count >= 5 else { return samples.max() ?? 0 > 0 ? 1 : 0 }

        let smoothed = movingAverage(samples, windowSize: 3)
        let prominenceThreshold = max(0.3, (smoothed.max() ?? 0) * 0.08)
        let minimumSeparation = 2

        var peaks: [Int] = []
        for index in 1..<(smoothed.count - 1) {
            let previous = smoothed[index - 1]
            let current = smoothed[index]
            let next = smoothed[index + 1]

            let isPeak = current > previous && current >= next
            let prominence = current - max(previous, next)
            guard isPeak, prominence >= prominenceThreshold else { continue }

            if let last = peaks.last, index - last < minimumSeparation {
                if current > smoothed[last] {
                    peaks[peaks.count - 1] = index
                }
            } else {
                peaks.append(index)
            }
        }

        return max(peaks.count, (smoothed.max() ?? 0) > cycleThresholdN ? 1 : 0)
    }

    private func movingAverage(_ values: [Double], windowSize: Int) -> [Double] {
        guard windowSize > 1, values.count > 2 else { return values }
        return values.indices.map { index in
            let start = max(0, index - windowSize / 2)
            let end = min(values.count - 1, index + windowSize / 2)
            let window = values[start...end]
            return window.reduce(0, +) / Double(window.count)
        }
    }
}

// MARK: - Save session
extension LiveTrainingView {
    @discardableResult
    private func saveSession(exitReason: SessionExitReason, isComplete: Bool) -> TrainingSession? {
        guard !sessionSaved else { return nil }

        let session = TrainingSession(
            startedAt: sessionStartTime,
            endedAt: Date(),
            mode: settings.trainingMode,
            targetReps: settings.repsPerSet,
            staticHoldTargetSec: settings.trainingMode == .staticHold ? settings.staticHoldDurationSec : nil,
            exitReason: exitReason,
            isComplete: isComplete,
            attempts: recordedAttempts
        )

        trainingStore.addSession(session)
        sessionSaved = true
        return session
    }
}

// MARK: - Coaching text
extension LiveTrainingView {
    private func updateCoachingText(for pressureN: Double) {
        if completedCycles >= totalTargetCycles {
            coachingText = "Session completed"
            coachingColor = .brandBlue
            coachingBackground = .neutralBlueBg
            return
        }

        switch settings.trainingMode {
        case .dynamic:
            if !isInAttempt {
                coachingText = "Start the next squeeze"
                coachingColor = .brandBlue
                coachingBackground = .neutralBlueBg
            } else if pressureN >= dynamicTargetThresholdN {
                coachingText = "Target reached for this repetition"
                coachingColor = .successGreen
                coachingBackground = .successGreenBg
            } else {
                coachingText = "Continue squeezing to reach the target"
                coachingColor = .warningAmber
                coachingBackground = .warningAmberBg
            }
        case .staticHold:
            let target = settings.staticHoldDurationSec
            if !isInAttempt {
                coachingText = "Start the next hold"
                coachingColor = .brandBlue
                coachingBackground = .neutralBlueBg
            } else if pressureN >= staticTargetThresholdN {
                if currentHoldSecondsDisplay >= target {
                    coachingText = "Target hold duration reached"
                } else {
                    coachingText = "Keep holding above the threshold"
                }
                coachingColor = .successGreen
                coachingBackground = .successGreenBg
            } else {
                coachingText = currentHoldSecondsDisplay > 0
                    ? "Lift pressure again to continue building hold time"
                    : "Increase pressure to begin the hold"
                coachingColor = .warningAmber
                coachingBackground = .warningAmberBg
            }
        }
    }
}

// MARK: - Simulated data
extension LiveTrainingView {
    private func simulatedPressureValue(at elapsed: Double) -> Double {
        switch settings.trainingMode {
        case .dynamic:
            let cycleDuration = 2.4
            let local = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration

            if local < 0.15 {
                return 0
            } else if local < 0.42 {
                return ((local - 0.15) / 0.27) * 14.0
            } else if local < 0.64 {
                return 11.8 + Double.random(in: -1.2...1.9)
            } else if local < 0.88 {
                return max(0, (1.0 - (local - 0.64) / 0.24) * 11.5)
            } else {
                return 0
            }
        case .staticHold:
            let cycleDuration = 8.0
            let local = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration

            if local < 0.12 {
                return 0
            } else if local < 0.24 {
                return ((local - 0.12) / 0.12) * 11.2
            } else if local < 0.70 {
                let base = 9.4 + Double.random(in: -1.1...1.4)
                if Int(elapsed * 10).isMultiple(of: 17) {
                    return max(6.4, base - 1.9)
                }
                return base
            } else if local < 0.86 {
                return max(0, (1.0 - (local - 0.70) / 0.16) * 10.5)
            } else {
                return 0
            }
        }
    }
}

// MARK: - Completion overlay
extension LiveTrainingView {
    private func completionOverlay(session: TrainingSession) -> some View {
        let score = TrainingAnalysisEngine.sessionScore(for: session)

        return ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Session Complete")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)

                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(ScoreVisuals.color(for: score))

                Text("\(completedCycles) / \(totalTargetCycles) cycles completed")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                HStack(spacing: 12) {
                    Button {
                        autoDismissWorkItem?.cancel()
                        dismissAfterReport = true
                        showReportSheet = true
                    } label: {
                        Text("View Report")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.brandBlue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button {
                        autoDismissWorkItem?.cancel()
                        dismiss()
                    } label: {
                        Text("Home")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cardBackground)
                            .foregroundColor(.brandBlue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.lineSoft, lineWidth: 1)
                            )
                            .cornerRadius(14)
                    }
                }

                Text("Returning to Home automatically…")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(Color.cardBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 24)
        }
    }
}

struct LivePressureChart: View {
    let data: [Double]
    let thresholdRatio: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)

                let left: CGFloat = 18
                let right: CGFloat = geo.size.width - 18
                let top: CGFloat = 18
                let bottom: CGFloat = geo.size.height - 18

                Path { path in
                    path.move(to: CGPoint(x: left, y: bottom))
                    path.addLine(to: CGPoint(x: right, y: bottom))
                }
                .stroke(Color.lineSoft, lineWidth: 1)

                Path { path in
                    let y = bottom - (bottom - top) * CGFloat(max(0, min(thresholdRatio, 1)))
                    path.move(to: CGPoint(x: left, y: y))
                    path.addLine(to: CGPoint(x: right, y: y))
                }
                .stroke(Color.successGreen.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                areaPath(in: geo.size, data: data)
                    .fill(Color.brandBlue.opacity(0.08))

                smoothPath(in: geo.size, data: data)
                    .stroke(Color.brandBlue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .animation(.linear(duration: 0.08), value: data)
            }
        }
    }

    private func areaPath(in size: CGSize, data: [Double]) -> Path {
        var path = smoothPath(in: size, data: data)
        guard data.count > 1 else { return path }

        let left: CGFloat = 18
        let right: CGFloat = size.width - 18
        let bottom: CGFloat = size.height - 18

        path.addLine(to: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.closeSubpath()
        return path
    }

    private func smoothPath(in size: CGSize, data: [Double]) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }

        let left: CGFloat = 18
        let right: CGFloat = size.width - 18
        let top: CGFloat = 18
        let bottom: CGFloat = size.height - 18
        let chartWidth = right - left
        let chartHeight = bottom - top

        let points: [CGPoint] = data.indices.map { index in
            let x = left + chartWidth * CGFloat(index) / CGFloat(max(data.count - 1, 1))
            let y = bottom - chartHeight * CGFloat(data[index])
            return CGPoint(x: x, y: y)
        }

        guard let first = points.first else { return path }
        path.move(to: first)

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midPoint = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: midPoint, control: controlPoint(for: midPoint, previous: previous))
            path.addQuadCurve(to: current, control: controlPoint(for: midPoint, previous: current))
        }

        return path
    }

    private func controlPoint(for midPoint: CGPoint, previous: CGPoint) -> CGPoint {
        var control = midPoint
        let diffY = abs(previous.y - control.y)
        if previous.y < control.y {
            control.y += diffY
        } else if previous.y > control.y {
            control.y -= diffY
        }
        return control
    }
}

struct ProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.lineSoft.opacity(0.8))
                    .frame(width: width, height: height)

                Capsule()
                    .fill(Color.brandBlue)
                    .frame(width: width * max(0, min(progress, 1)), height: height)
            }
        }
    }
}
