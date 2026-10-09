import AVFoundation
import Observation

/// Measures how loud a place is for ten seconds.
///
/// Audio is only ever held in memory long enough to compute its RMS level inside the input tap.
/// Nothing is written to disk, kept or sent. Only the resulting number survives.
@MainActor
@Observable
final class SoundMeter {
    enum Phase: Equatable {
        case idle
        case measuring(secondsLeft: Int)
        case finished(decibels: Double)
        case denied
        case failed
    }

    static let duration = 10

    /// Maps dBFS (decibels relative to the microphone's full scale) to approximate dB SPL.
    ///
    /// iPhone microphones are not calibrated sound level meters. With the session in
    /// `.measurement` mode (no automatic gain), a quiet room reads around -60 dBFS and normal
    /// conversation around -40 dBFS on recent iPhones, so +100 dB puts those near 40 and 60 dB SPL.
    /// Readings are rough, roughly ±5–10 dB. To calibrate a device, compare a steady sound with a
    /// reference meter and adjust this value.
    static let calibrationOffset = 100.0

    private(set) var phase: Phase = .idle
    /// The most recent short-term level while measuring.
    private(set) var liveDecibels: Double?

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let accumulator = LevelAccumulator()

    var isMeasuring: Bool {
        if case .measuring = phase { return true }
        return false
    }

    func start() {
        guard task == nil else { return }
        task = Task {
            await measure()
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        stopEngine()
        if isMeasuring { phase = .idle }
    }

    private func measure() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            phase = .denied
            return
        }
        do {
            try startEngine()
        } catch {
            stopEngine()
            phase = .failed
            return
        }

        let ticksPerSecond = 4
        for tick in 0..<(Self.duration * ticksPerSecond) {
            phase = .measuring(secondsLeft: Self.duration - tick / ticksPerSecond)
            do {
                try await Task.sleep(for: .milliseconds(1000 / ticksPerSecond))
            } catch {
                stopEngine()
                return
            }
            let level = accumulator.levels()
            if level.latest > 0 {
                liveDecibels = SoundLevel.decibels(fromRMS: level.latest, calibrationOffset: Self.calibrationOffset)
            }
        }

        let average = accumulator.levels().average
        stopEngine()
        phase = average > 0
            ? .finished(decibels: SoundLevel.decibels(fromRMS: average, calibrationOffset: Self.calibrationOffset))
            : .failed
    }

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw SoundMeterError.noInput }

        accumulator.reset()
        liveDecibels = nil
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.makeTap(accumulator))
        try engine.start()
        self.engine = engine
    }

    private func stopEngine() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor: the tap runs on an audio thread.
    private nonisolated static func makeTap(_ accumulator: LevelAccumulator) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sumOfSquares = 0.0
            for index in 0..<count {
                let sample = Double(samples[index])
                sumOfSquares += sample * sample
            }
            accumulator.add(sumOfSquares: sumOfSquares, count: count)
            // The buffer is released when this block returns. No audio is copied or kept.
        }
    }
}

enum SoundMeterError: Error {
    case noInput
}

/// Running RMS totals, shared between the audio thread and the main actor.
final class LevelAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var sumOfSquares = 0.0
    private var sampleCount = 0
    private var latestRMS = 0.0

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        sumOfSquares = 0
        sampleCount = 0
        latestRMS = 0
    }

    func add(sumOfSquares bufferSum: Double, count: Int) {
        guard count > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        sumOfSquares += bufferSum
        sampleCount += count
        latestRMS = (bufferSum / Double(count)).squareRoot()
    }

    /// The RMS over everything so far, and over the latest buffer.
    func levels() -> (average: Double, latest: Double) {
        lock.lock()
        defer { lock.unlock() }
        let average = sampleCount > 0 ? (sumOfSquares / Double(sampleCount)).squareRoot() : 0
        return (average, latestRMS)
    }
}
