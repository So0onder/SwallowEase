import Foundation

enum SessionExitReason: String, Codable {
    case completed
    case userExited
}

struct TrainingAttempt: Identifiable, Codable, Hashable {
    let id: UUID
    let mode: TrainingMode
    let startTime: Date
    let endTime: Date
    let durationSec: TimeInterval
    let peakForceN: Double
    let holdTimeAboveThresholdSec: Double
    let reachedDynamicTarget: Bool
    let reachedStaticThreshold: Bool
    let reachedTargetHoldDuration: Bool
    let peakCount: Int

    init(
        id: UUID = UUID(),
        mode: TrainingMode,
        startTime: Date,
        endTime: Date,
        durationSec: TimeInterval,
        peakForceN: Double,
        holdTimeAboveThresholdSec: Double,
        reachedDynamicTarget: Bool,
        reachedStaticThreshold: Bool,
        reachedTargetHoldDuration: Bool,
        peakCount: Int = 1
    ) {
        self.id = id
        self.mode = mode
        self.startTime = startTime
        self.endTime = endTime
        self.durationSec = durationSec
        self.peakForceN = peakForceN
        self.holdTimeAboveThresholdSec = holdTimeAboveThresholdSec
        self.reachedDynamicTarget = reachedDynamicTarget
        self.reachedStaticThreshold = reachedStaticThreshold
        self.reachedTargetHoldDuration = reachedTargetHoldDuration
        self.peakCount = max(peakCount, 1)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case mode
        case startTime
        case endTime
        case durationSec
        case peakForceN
        case holdTimeAboveThresholdSec
        case reachedDynamicTarget
        case reachedStaticThreshold
        case reachedTargetHoldDuration
        case peakCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mode = try container.decode(TrainingMode.self, forKey: .mode)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        durationSec = try container.decode(TimeInterval.self, forKey: .durationSec)
        peakForceN = try container.decode(Double.self, forKey: .peakForceN)
        holdTimeAboveThresholdSec = try container.decode(Double.self, forKey: .holdTimeAboveThresholdSec)
        reachedDynamicTarget = try container.decode(Bool.self, forKey: .reachedDynamicTarget)
        reachedStaticThreshold = try container.decode(Bool.self, forKey: .reachedStaticThreshold)
        reachedTargetHoldDuration = try container.decode(Bool.self, forKey: .reachedTargetHoldDuration)
        peakCount = max((try? container.decode(Int.self, forKey: .peakCount)) ?? 1, 1)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mode, forKey: .mode)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(durationSec, forKey: .durationSec)
        try container.encode(peakForceN, forKey: .peakForceN)
        try container.encode(holdTimeAboveThresholdSec, forKey: .holdTimeAboveThresholdSec)
        try container.encode(reachedDynamicTarget, forKey: .reachedDynamicTarget)
        try container.encode(reachedStaticThreshold, forKey: .reachedStaticThreshold)
        try container.encode(reachedTargetHoldDuration, forKey: .reachedTargetHoldDuration)
        try container.encode(peakCount, forKey: .peakCount)
    }

    var cycleCount: Int { 1 }

    var metPrimaryGoal: Bool {
        switch mode {
        case .dynamic:
            return reachedDynamicTarget
        case .staticHold:
            return reachedTargetHoldDuration
        }
    }
}

struct TrainingSession: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let mode: TrainingMode
    let targetReps: Int
    let staticHoldTargetSec: Int?
    let exitReason: SessionExitReason
    let isComplete: Bool
    let attempts: [TrainingAttempt]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        mode: TrainingMode,
        targetReps: Int,
        staticHoldTargetSec: Int?,
        exitReason: SessionExitReason,
        isComplete: Bool,
        attempts: [TrainingAttempt]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.targetReps = targetReps
        self.staticHoldTargetSec = staticHoldTargetSec
        self.exitReason = exitReason
        self.isComplete = isComplete
        self.attempts = attempts
    }

    var completedCycles: Int {
        attempts.count
    }

    var sessionDurationSec: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    var targetGoalCount: Int {
        targetReps
    }

    var goalReachedCount: Int {
        attempts.filter(\.metPrimaryGoal).count
    }
}

struct DayTrainingGroup: Identifiable, Hashable {
    let id: String
    let date: Date
    let sessions: [TrainingSession]

    var completedCount: Int {
        sessions.filter(\.isComplete).count
    }

    var averageCompletedCycles: Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + $1.completedCycles }
        return Double(total) / Double(sessions.count)
    }
}
