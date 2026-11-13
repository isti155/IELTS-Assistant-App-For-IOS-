import Foundation

// MARK: - Grammar (from the Mentors' Foundation Grammar & Writing book)

struct GrammarBook: Decodable {
    var source: String
    var chapters: [GrammarChapter]
}

struct GrammarChapter: Decodable, Identifiable, Hashable {
    var id: Int
    var title: String
    var symbol: String
    var summary: String
    var sections: [GrammarSection]
    var exercises: [GrammarExercise]
}

struct GrammarSection: Decodable, Hashable {
    var title: String
    var blocks: [GrammarBlock]
}

struct GrammarBlock: Decodable, Hashable {
    /// "text", "rule", "formula" or "examples"
    var type: String
    var text: String?
    var label: String?
    var items: [String]?
}

struct GrammarExercise: Decodable, Identifiable, Hashable {
    var id: String
    var instructions: String
    /// "items", "passage" or "reveal"
    var kind: String
    var items: [GrammarItem]?
    var passage: [PassageSegment]?
    var text: String?
    var key: String?
}

struct GrammarItem: Decodable, Hashable {
    /// "choice", "gap", "build", "capitalize", "punctuate" or "self"
    var kind: String
    var prompt: String
    var options: [String]?
    var answers: [String]
    var hints: [String?]?
    var full: String?
    var words: [String]?
    var targets: [Int]?
}

struct PassageSegment: Decodable, Hashable {
    var text: String?
    var gap: Int?
    var hint: String?
    var options: [String]?
    var answers: [String]?
}

// MARK: - Vocabulary

struct VocabWord: Decodable, Identifiable, Hashable {
    /// word, part of speech, CEFR level, definition
    var w: String
    var p: String
    var l: String
    var d: String
    /// examples, synonyms, antonyms, word family, topic, IPA, frequency in reading passages, in the grammar book
    var e: [String]?
    var s: [String]?
    var a: [String]?
    var f: [String]?
    var t: String?
    var i: String?
    var n: Int?
    var b: Int?

    var id: String { w + "|" + p }
    var word: String { w }
    var definition: String { d }
    var level: String { l }
    var partOfSpeech: String { p }
    var examples: [String] { e ?? [] }
    var synonyms: [String] { s ?? [] }
    var topic: String { t ?? "General" }
}

private struct VocabularyFile: Decodable {
    var words: [VocabWord]
}

// MARK: - Reading bank (1,051 IELTS-style tests)

struct BankTest: Decodable, Identifiable, Hashable {
    var id: String
    var area: String
    var topic: String
    var hard: Bool
    var title: String
    var subtitle: String
    var paragraphs: [BankParagraph]
    var groups: [BankGroup]
    var paraphrases: [Paraphrase]

    var questionCount: Int { groups.reduce(0) { $0 + $1.questions.count } }
}

struct BankParagraph: Decodable, Hashable {
    var label: String
    var text: String
}

struct BankOption: Decodable, Hashable {
    var label: String
    var text: String
}

struct BankGroup: Decodable, Hashable {
    var type: String
    var instructions: String
    var options: [BankOption]
    var summary: String?
    var questions: [BankQuestion]
}

struct BankQuestion: Decodable, Hashable, Identifiable {
    var n: Int
    var q: String
    var options: [BankOption]
    var a: String
    var ev: String?
    var p: String?
    var x: String?
    var dn: String?
    var id: Int { n }
}

struct Paraphrase: Decodable, Hashable {
    var passage: String
    var question: String
}

// MARK: - Speaking and writing banks

struct SpeakingBank: Decodable {
    var part1: [TopicQuestions]
    var cueCards: [BankCueCard]
    var part3: [TopicQuestions]
    var samples: [SpeakingSample]
}

struct TopicQuestions: Decodable, Hashable {
    var topic: String
    var questions: [String]
}

struct BankCueCard: Decodable, Hashable, Identifiable {
    var topic: String
    var bullets: [String]
    var theme: String?
    var id: String { topic }
}

struct SpeakingSample: Decodable, Hashable, Identifiable {
    var band: Double
    var turns: [SampleTurn]
    var id: String { "\(band)-\(turns.first?.text.prefix(40) ?? "")" }
}

struct SampleTurn: Decodable, Hashable {
    var who: String
    var text: String
}

struct WritingBank: Decodable {
    var task1: [Task1Item]
    var task2: [Task2Item]
}

struct Task1Item: Decodable, Hashable {
    var kind: String
    var prompt: String
    var image: String
    var sample: String
    var band: Double
}

struct Task2Item: Decodable, Hashable {
    var prompt: String
    var sample: String?
    var band: Double?
}

// MARK: - IELTS course (the tutor)

struct Course: Decodable {
    var units: [CourseUnit]
}

struct CourseUnit: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var skill: String?
    var lessons: [CourseLesson]

    var skillValue: Skill? { skill.flatMap(Skill.init(rawValue:)) }
}

struct CourseLesson: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var minutes: Int
    var summary: String
    var steps: [CourseStep]
}

struct CourseStep: Decodable, Hashable {
    /// "explain", "example", "tip" or "quiz"
    var kind: String
    var title: String?
    var body: String?
    var question: String?
    var options: [String]?
    var answer: String?
    var why: String?
}

// MARK: - Loading

/// Bundled learning content. Each file is decoded once, the first time it is used.
enum Library {
    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) -> T? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Could not decode \(name).json: \(error)")
            return nil
        }
    }

    static let grammar: GrammarBook = load("grammar") ?? GrammarBook(source: "", chapters: [])
    static let vocabulary: [VocabWord] = load("vocabulary", as: VocabularyFile.self)?.words ?? []
    static let vocabularyByID: [String: VocabWord] = Dictionary(vocabulary.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    static let course: Course = load("course") ?? Course(units: [])
    static let speaking: SpeakingBank = load("speaking_bank") ?? SpeakingBank(part1: [], cueCards: [], part3: [], samples: [])
    static let writing: WritingBank = load("writing_bank") ?? WritingBank(task1: [], task2: [])
    /// About 15 MB; first use should happen off the main thread (see `ReadingLibrary`).
    static let readingBank: [BankTest] = load("reading_bank") ?? []

    static func task1Image(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Task1")
            ?? Bundle.module.url(forResource: (name as NSString).deletingPathExtension, withExtension: "jpg")
    }

    static var courseLessons: [CourseLesson] { course.units.flatMap(\.lessons) }

    /// Decodes the bundled content in the background at launch so no screen waits for it.
    static func warmUp() {
        Task.detached(priority: .userInitiated) {
            _ = vocabularyByID
            _ = grammar
            _ = course
            _ = speaking
            _ = writing
        }
        Task { await ReadingLibrary.shared.load() }
    }
}

/// Loads the large reading bank in the background so screens stay responsive.
@MainActor
final class ReadingLibrary: ObservableObject {
    static let shared = ReadingLibrary()
    @Published private(set) var tests: [BankTest]?

    func load() async {
        guard tests == nil else { return }
        let loaded = await Task.detached(priority: .userInitiated) { Library.readingBank }.value
        tests = loaded
    }
}

// MARK: - Answer checking shared by grammar, vocabulary and reading

enum AnswerCheck {
    /// Lowercase, straight apostrophes, punctuation removed, single spaces. Articles are kept.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        let kept = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "'" ? Character(scalar) : " "
        }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    static let noArticle: Set<String> = ["", "x", "no article", "none", "nothing"]

    /// True when `given` matches any alternative of `expected` ("could/might").
    static func matches(_ given: String, _ expected: String) -> Bool {
        let answer = normalize(given)
        let options = expected.split(separator: "/").map { normalize(String($0)) }
        if options.contains(answer) { return true }
        if normalize(expected).isEmpty { return noArticle.contains(answer) }
        // Accept contracted and full forms ("doesn't" vs "does not").
        let expand: (String) -> String = {
            $0.replacingOccurrences(of: "n't", with: " not").replacingOccurrences(of: "'s", with: " is")
                .replacingOccurrences(of: "'re", with: " are").replacingOccurrences(of: "'ll", with: " will")
        }
        return options.map(expand).contains(expand(answer))
    }
}
