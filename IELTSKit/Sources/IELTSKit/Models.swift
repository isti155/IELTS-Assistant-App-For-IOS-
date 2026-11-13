import Foundation

public enum Skill: String, Codable, CaseIterable, Identifiable {
    case listening, reading, writing, speaking
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .listening: return "headphones"
        case .reading: return "book.fill"
        case .writing: return "pencil"
        case .speaking: return "mic.fill"
        }
    }
}

// MARK: - Examiner evaluation (Writing & Speaking)

public struct CriterionScore: Codable, Hashable, Identifiable {
    public var name: String
    /// Whole band 0–9. IELTS examiners award whole bands per criterion.
    public var band: Double
    public var justification: String
    /// Verbatim quotes from the candidate's response that support the band.
    public var evidence: [String]
    public var id: String { name }
}

public struct Correction: Codable, Hashable, Identifiable {
    public var original: String
    public var corrected: String
    public var explanation: String
    public var category: String
    public var id: String { original + corrected }
}

public struct Evaluation: Codable, Hashable {
    public var criteria: [CriterionScore]
    public var summary: String
    public var strengths: [String]
    public var improvements: [String]
    public var corrections: [Correction]
    /// Limits on how far this score can be trusted (e.g. pronunciation is estimated).
    public var caveats: [String]
    /// Overall band from the trained model's overall output, when there is one.
    public var overallBand: Double?

    /// The overall band if the model gave one; otherwise the mean of the criteria,
    /// rounded down to the nearest half band.
    public var band: Double { overallBand ?? BandMath.taskBand(criteria.map(\.band)) }

    /// Clamp model output to valid whole bands.
    public func sanitized() -> Evaluation {
        var copy = self
        copy.criteria = criteria.map {
            var c = $0
            c.band = min(9, max(0, c.band.rounded()))
            return c
        }
        return copy
    }
}

// MARK: - Tasks and tests

public struct ChartSeries: Codable, Hashable {
    public var name: String
    public var values: [Double]
}

public struct ChartSpec: Codable, Hashable {
    /// "bar", "line", "pie" or "table"
    public var kind: String
    public var title: String
    public var xLabel: String
    public var yLabel: String
    public var categories: [String]
    public var series: [ChartSeries]
}

public struct WritingTask: Codable, Hashable, Identifiable {
    /// 1 or 2
    public var taskNumber: Int
    public var prompt: String
    public var chart: ChartSpec?
    /// Image file in Resources/Task1 (exam-style visuals from the dataset).
    public var image: String? = nil
    /// A high-scoring answer to compare with after marking.
    public var sample: String? = nil
    public var sampleBand: Double? = nil
    public var visualKind: String? = nil
    public var id: String { prompt }
    public var minimumWords: Int { taskNumber == 1 ? 150 : 250 }
    public var minutes: Int { taskNumber == 1 ? 20 : 40 }
}

public struct Question: Codable, Hashable, Identifiable {
    public var id: Int
    /// "true_false_not_given", "multiple_choice", "matching", "completion"
    public var kind: String
    public var prompt: String
    /// Empty for completion questions (free-text answer).
    public var options: [String]
    public var answer: String
    /// Other answers that are also marked correct (spelling variants, digits vs words).
    public var accepted: [String]
    public var explanation: String
}

public struct ReadingTest: Codable, Hashable, Identifiable {
    public var title: String
    public var passage: String
    public var questions: [Question]
    public var id: String { title }
}

public struct ListeningSegment: Codable, Hashable {
    public var speaker: String
    public var text: String
}

public struct ListeningTest: Codable, Hashable, Identifiable {
    public var title: String
    public var context: String
    public var segments: [ListeningSegment]
    public var questions: [Question]
    public var id: String { title }
}

public struct CueCard: Codable, Hashable {
    public var topic: String
    public var bullets: [String]
}

public struct SpeakingScript: Codable, Hashable {
    public var part1: [String]
    public var cueCard: CueCard
    public var roundingOff: String
    public var part3: [String]
}

public struct SpeechMetrics: Codable, Hashable {
    public var words: Int
    public var seconds: Double
    public var wordsPerMinute: Double
    /// Silences longer than one second between recognised words.
    public var longPauses: Int
    public var fillers: Int
    /// Mean speech-recogniser confidence, 0–1. Nil when the recogniser gave none.
    public var meanConfidence: Double?
    public var lowConfidenceWords: [String]
}

public struct SpeakingTurn: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var part: Int
    public var question: String
    public var transcript: String
    public var metrics: SpeechMetrics
}

// MARK: - Persistence

public struct Attempt: Codable, Identifiable, Hashable {
    public var id = UUID()
    public var date = Date()
    public var skill: Skill
    public var title: String
    public var prompt: String
    public var response: String
    public var band: Double
    public var evaluation: Evaluation?
    public var rawScore: Int?
    public var total: Int?
    /// True when the band comes from a short practice set scaled to 40 questions.
    public var estimated: Bool = false
}

public struct Profile: Codable, Hashable {
    public var targetBand: Double = 7.0
    public var examDate: Date?
    /// Optional so state saved before this field existed still decodes.
    public var onboarded: Bool?
}

public struct ChatMessage: Codable, Identifiable, Hashable {
    public var id = UUID()
    /// "user" or "assistant"
    public var role: String
    public var text: String
    public init(role: String, text: String) {
        self.role = role
        self.text = text
    }
}
