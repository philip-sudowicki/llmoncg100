import AVFoundation
import Observation

/// Measures how loud a place is for ten seconds.
///
/// Privacy: audio buffers are read in memory by an input tap to compute their mean square, then
/// dropped. Nothing is written to disk, kept or sent. Only the final decibel number survives.
@MainActor
@Observable
final class SoundMeter {
    enum Phase: Equatable {
        case idle
        case measuring
        case finished
        case denied
        case unavailable
    }

    static let duration: Duration = .seconds(10)

    private(set) var phase: Phase = .idle
    /// Approximate dB SPL over the last fraction of a second, while measuring.
    private(set) var liveDecibels: Double?
    /// Approximate dB SPL averaged over the whole reading.
    private(set) var result: Double?
    private(set) var secondsLeft = 10

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        task = Task { await measure() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        stopEngine()
        if phase == .measuring {
            phase = .idle
        }
    }

    func reset() {
        cancel()
        result = nil
        liveDecibels = nil
        phase = .idle
    }

    private func measure() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            phase = .denied
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
        } catch {
            phase = .unavailable
            return
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            deactivate(session)
            phase = .unavailable
            return
        }

        let accumulator = LevelAccumulator()
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.makeTap(accumulator))
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            deactivate(session)
            phase = .unavailable
            return
        }
        self.engine = engine

        result = nil
        liveDecibels = nil
        secondsLeft = 10
        phase = .measuring
        let clock = ContinuousClock()
        let start = clock.now
        while clock.now - start < Self.duration, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            let elapsed = clock.now - start
            secondsLeft = max(0, 10 - Int(elapsed.components.seconds))
            if let recent = accumulator.takeRecentMeanSquare() {
                liveDecibels = SoundLevel.decibels(meanSquare: recent)
            }
        }

        stopEngine()
        guard !Task.isCancelled else { return }
        if let average = accumulator.averageMeanSquare {
            result = SoundLevel.decibels(meanSquare: average)
            phase = .finished
        } else {
            phase = .unavailable
        }
    }

    private func stopEngine() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        deactivate(AVAudioSession.sharedInstance())
    }

    private func deactivate(_ session: AVAudioSession) {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor: the tap runs on the audio thread.
    nonisolated private static func makeTap(_ accumulator: LevelAccumulator) -> AVAudioNodeTapBlock {
        { buffer, _ in
            accumulator.add(buffer)
        }
    }
}

/// Running sums of squared samples, shared between the audio thread and the main actor.
/// Holds numbers only, never samples.
private final class LevelAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var totalSquares = 0.0
    private var totalCount = 0
    private var recentSquares = 0.0
    private var recentCount = 0

    func add(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var squares = 0.0
        for index in 0..<frames {
            let sample = Double(channel[index])
            squares += sample * sample
        }
        lock.lock()
        totalSquares += squares
        totalCount += frames
        recentSquares += squares
        recentCount += frames
        lock.unlock()
    }

    /// Mean square since the last call, for the live meter.
    func takeRecentMeanSquare() -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard recentCount > 0 else { return nil }
        let value = recentSquares / Double(recentCount)
        recentSquares = 0
        recentCount = 0
        return value
    }

    /// Mean square over the whole reading (an energy average, like Leq).
    var averageMeanSquare: Double? {
        lock.lock()
        defer { lock.unlock() }
        return totalCount > 0 ? totalSquares / Double(totalCount) : nil
    }
}
