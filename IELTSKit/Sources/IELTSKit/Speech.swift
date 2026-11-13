import AVFoundation
import Foundation
import Speech

/// One recognised word (or short run of words) with timing and recogniser confidence.
public struct SpokenSegment: Hashable {
    public var text: String
    public var start: Double
    public var duration: Double
    public var confidence: Double
}

public enum SpeechAnalysis {
    static let fillerWords: Set<String> = ["um", "uh", "er", "erm", "hmm", "uhm", "ah"]

    /// Delivery measurements passed to the AI examiner alongside the transcript.
    public static func metrics(segments: [SpokenSegment], transcript: String, seconds: Double) -> SpeechMetrics {
        let words = Marking.wordCount(transcript)
        var pauses = 0
        for (previous, next) in zip(segments, segments.dropFirst()) {
            if next.start - (previous.start + previous.duration) > 1.0 { pauses += 1 }
        }
        let tokens = transcript.lowercased().split { !$0.isLetter }.map(String.init)
        let fillers = tokens.filter { fillerWords.contains($0) }.count
        let scored = segments.filter { $0.confidence > 0 }
        let mean = scored.isEmpty ? nil : scored.map(\.confidence).reduce(0, +) / Double(scored.count)
        let low = scored.filter { $0.confidence < 0.5 }.map(\.text)
        return SpeechMetrics(
            words: words,
            seconds: seconds,
            wordsPerMinute: seconds > 0 ? Double(words) / seconds * 60 : 0,
            longPauses: pauses,
            fillers: fillers,
            meanConfidence: mean,
            lowConfidenceWords: Array(low.prefix(15))
        )
    }
}

public struct SpokenAnswer {
    public var transcript: String
    public var metrics: SpeechMetrics
}

public enum SpeechError: LocalizedError {
    case notAuthorized, unavailable
    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Allow microphone and speech recognition access in Settings to use speaking practice."
        case .unavailable: return "Speech recognition is not available on this device right now."
        }
    }
}

/// Live speech-to-text for the candidate's answers.
/// Recognition tasks can end on their own at a long pause, so finished pieces are
/// accumulated and a new task is started for as long as recording continues.
@MainActor
public final class SpeechTranscriber: ObservableObject {
    @Published public private(set) var transcript = ""
    @Published public private(set) var isRecording = false

    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let audioTarget = AudioTarget()
    private var task: SFSpeechRecognitionTask?
    private var committedText = ""
    private var committedSegments: [SpokenSegment] = []
    private var liveText = ""
    private var liveSegments: [SpokenSegment] = []
    private var startedAt = Date()
    private var taskOffset: Double = 0

    public init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    public func start() async throws {
        guard !isRecording else { return }
        guard await Self.requestPermissions() else { throw SpeechError.notAuthorized }
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }

        AudioSession.configure()
        committedText = ""
        committedSegments = []
        liveText = ""
        liveSegments = []
        transcript = ""
        startedAt = Date()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.appendAudio(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
        beginTask()
    }

    /// Stops recording and returns the transcript with delivery measurements.
    public func stop() async -> SpokenAnswer {
        guard isRecording else {
            return SpokenAnswer(transcript: "", metrics: SpeechAnalysis.metrics(segments: [], transcript: "", seconds: 0))
        }
        let seconds = Date().timeIntervalSince(startedAt)
        isRecording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // Give the recogniser a moment to deliver its final result, which carries confidences.
        for _ in 0..<15 where task != nil {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        task?.cancel()
        task = nil
        request = nil
        audioTarget.set(nil)
        commitLive()
        let text = committedText.trimmingCharacters(in: .whitespaces)
        return SpokenAnswer(
            transcript: text,
            metrics: SpeechAnalysis.metrics(segments: committedSegments, transcript: text, seconds: seconds)
        )
    }

    // The audio tap runs on a real-time thread, so it reaches the current request
    // through a lock instead of hopping to the main actor.
    nonisolated private func appendAudio(_ buffer: AVAudioPCMBuffer) {
        audioTarget.append(buffer)
    }

    private func beginTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device recognition has no one-minute limit and keeps audio off the network.
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request
        audioTarget.set(request)
        taskOffset = Date().timeIntervalSince(startedAt)
        let offset = taskOffset
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let segments = result?.bestTranscription.segments.map {
                SpokenSegment(text: $0.substring, start: $0.timestamp + offset,
                              duration: $0.duration, confidence: Double($0.confidence))
            }
            let finished = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in
                guard let self else { return }
                if let text, let segments {
                    self.liveText = text
                    self.liveSegments = segments
                    self.transcript = (self.committedText + " " + text).trimmingCharacters(in: .whitespaces)
                }
                if finished {
                    self.commitLive()
                    self.task = nil
                    if self.isRecording { self.beginTask() }
                }
            }
        }
    }

    private func commitLive() {
        guard !liveText.isEmpty else { return }
        committedText = (committedText + " " + liveText).trimmingCharacters(in: .whitespaces)
        committedSegments += liveSegments
        liveText = ""
        liveSegments = []
    }

    private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        #else
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }
}

/// Lock-protected handle to the recognition request currently receiving audio.
private final class AudioTarget: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        request?.append(buffer)
        lock.unlock()
    }
}

enum AudioSession {
    /// One session for both the examiner's voice and the microphone.
    static func configure() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? session.setActive(true)
        #endif
    }
}

/// Text-to-speech for the examiner and for listening recordings.
@MainActor
public final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published public private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var current: ObjectIdentifier?
    /// IELTS recordings use a mix of accents; speakers are assigned voices in this order.
    private static let accents = ["en-GB", "en-AU", "en-US", "en-IE"]

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Best installed voice for an accent (enhanced voices sound far more natural
    /// and can be downloaded in iOS Settings › Accessibility › Spoken Content › Voices).
    private static func voice(_ index: Int) -> AVSpeechSynthesisVoice? {
        let language = accents[index % accents.count]
        let installed = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        let ranked = installed.sorted { $0.quality.rawValue > $1.quality.rawValue }
        // Different speakers with the same accent get different voices where possible.
        let pick = ranked.isEmpty ? nil : ranked[(index / accents.count) % ranked.count]
        return pick ?? AVSpeechSynthesisVoice(language: language)
    }

    /// Speaks the text and returns when it has finished.
    public func speak(_ text: String, voice index: Int = 0) async {
        stop()
        AudioSession.configure()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(index)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.postUtteranceDelay = 0.25
        isSpeaking = true
        current = ObjectIdentifier(utterance)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
        isSpeaking = false
    }

    public func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        finish()
    }

    private func finish() {
        current = nil
        continuation?.resume()
        continuation = nil
    }

    /// Late callbacks for an utterance that was already stopped must not end the next one.
    private func finish(ifCurrent id: ObjectIdentifier) {
        if current == id { finish() }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(ifCurrent: id) }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(ifCurrent: id) }
    }
}
