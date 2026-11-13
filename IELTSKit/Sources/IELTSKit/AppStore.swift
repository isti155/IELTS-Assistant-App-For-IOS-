import Foundation

/// App state: profile and attempt history, saved as JSON in Application Support.
/// Everything runs and stays on the device; there are no network calls.
@MainActor
public final class AppStore: ObservableObject {
    private struct Saved: Codable {
        var profile = Profile()
        var attempts: [Attempt] = []
        /// Optional so state saved before the learning modules existed still decodes.
        var learning: LearningState?
    }

    @Published public var profile: Profile { didSet { save() } }
    @Published public var attempts: [Attempt] { didSet { save() } }
    @Published public var learning: LearningState { didSet { save() } }

    public let examiner = LocalExaminer()
    /// On-device language model for the tutor and conversation replies; nil when not installed.
    public let generator: TextGenerator?

    /// Nil for a store that is never saved (used for screenshots).
    private let fileURL: URL?

    public init(generator: TextGenerator? = nil, persistent: Bool = true) {
        self.generator = generator
        if persistent {
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("IELTSAssistant", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            fileURL = folder.appendingPathComponent("state.json")
        } else {
            fileURL = nil
        }
        let saved = fileURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
        profile = saved.profile
        attempts = saved.attempts
        learning = saved.learning ?? LearningState()
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(Saved(profile: profile, attempts: attempts, learning: learning)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public var isOnboarded: Bool {
        get { profile.onboarded ?? false }
        set { profile.onboarded = newValue }
    }

    /// Most recent attempt at a particular test or question (matched by title or prompt).
    public func lastAttempt(matching key: String) -> Attempt? {
        attempts.first { $0.title == key || $0.prompt == key }
    }

    public func lastAttempt(for skill: Skill) -> Attempt? {
        attempts.first { $0.skill == skill }
    }

    public func deleteAllAttempts() {
        attempts.removeAll()
    }

    public func record(_ attempt: Attempt) {
        attempts.insert(attempt, at: 0)
        award(50)
    }

    /// Current estimate for a skill: mean of the three most recent attempts,
    /// so one lucky or unlucky session does not swing the number.
    public func estimate(for skill: Skill) -> Double? {
        let recent = attempts.filter { $0.skill == skill }.prefix(3).map(\.band)
        guard !recent.isEmpty else { return nil }
        return BandMath.overall(Array(recent))
    }

    /// Overall estimate, available only once all four skills have been attempted.
    public var overallEstimate: Double? {
        let bands = Skill.allCases.compactMap { estimate(for: $0) }
        guard bands.count == Skill.allCases.count else { return nil }
        return BandMath.overall(bands)
    }

    public var profileNote: String {
        var note = "Target band \(profile.targetBand)."
        if let date = profile.examDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            note += " Exam in \(max(days, 0)) days."
        }
        for skill in Skill.allCases {
            if let band = estimate(for: skill) {
                note += " Recent \(skill.title) practice estimate: \(band)."
            }
        }
        return note
    }
}
