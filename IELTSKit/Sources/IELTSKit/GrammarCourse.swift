import Foundation
import SwiftUI

// MARK: - The grammar course (Resources/GrammarCourse/*.json, written for this app)

struct GrammarCourseSection: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var symbol: String
    var color: String
    var units: [GrammarUnit]

    var tint: Color {
        switch color {
        case "blue": return .blue
        case "indigo": return .indigo
        case "teal": return .teal
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        default: return Theme.accent
        }
    }
}

struct GrammarUnit: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var level: String
    /// 3 = essential for IELTS, 2 = important, 1 = useful.
    var ielts: Int
    var skills: [String]
    var summary: String
    var cards: [GrammarCard]
    var practice: [PracticeItem]
}

enum IELTSPriority: Int, CaseIterable {
    case useful = 1, important = 2, essential = 3

    var label: String {
        switch self {
        case .essential: return "IELTS essential"
        case .important: return "IELTS important"
        case .useful: return "Useful"
        }
    }

    var short: String {
        switch self {
        case .essential: return "Essential"
        case .important: return "Important"
        case .useful: return "Useful"
        }
    }

    var color: Color {
        switch self {
        case .essential: return .red
        case .important: return .orange
        case .useful: return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .essential: return "star.fill"
        case .important: return "star.leadinghalf.filled"
        case .useful: return "star"
        }
    }
}

extension GrammarUnit {
    var priority: IELTSPriority { IELTSPriority(rawValue: ielts) ?? .useful }
}

struct GrammarCard: Decodable, Hashable {
    /// "rule", "form", "mistakes" or "ielts"
    var kind: String
    var title: String?
    var body: String?
    var examples: [String]?
    /// Form tables: [label, value]
    var rows: [[String]]?
    /// Mistakes: [wrong, right, why]
    var items: [[String]]?
}

struct PracticeItem: Decodable, Hashable {
    /// "choice", "pick", "gap", "error", "build" or "punctuate"
    var t: String
    var q: String
    var o: [String]?
    /// One answer (choice, pick, build) or one per gap (gap).
    var a: [String]
    var x: String?
    /// The correction for an "error" item.
    var c: String?
    /// Words and comma positions for a "punctuate" item.
    var w: [String]?
    var targets: [Int]?

    enum CodingKeys: String, CodingKey { case t, q, o, a, x, c, w, targets }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        t = try container.decode(String.self, forKey: .t)
        q = try container.decode(String.self, forKey: .q)
        o = try container.decodeIfPresent([String].self, forKey: .o)
        if let many = try? container.decode([String].self, forKey: .a) {
            a = many
        } else if let one = try? container.decode(String.self, forKey: .a) {
            a = [one]
        } else {
            a = []
        }
        x = try container.decodeIfPresent(String.self, forKey: .x)
        c = try container.decodeIfPresent(String.self, forKey: .c)
        w = try container.decodeIfPresent([String].self, forKey: .w)
        targets = try container.decodeIfPresent([Int].self, forKey: .targets)
    }
}

enum GrammarCourse {
    static let sections: [GrammarCourseSection] = {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "GrammarCourse") ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            do {
                return try JSONDecoder().decode(GrammarCourseSection.self, from: data)
            } catch {
                print("Could not decode \(url.lastPathComponent): \(error)")
                return nil
            }
        }
    }()

    static var units: [GrammarUnit] { sections.flatMap(\.units) }
    static var essentials: [GrammarUnit] { units.filter { $0.priority == .essential } }

    static func section(of unit: GrammarUnit) -> GrammarCourseSection? {
        sections.first { $0.units.contains { $0.id == unit.id } }
    }

    static func unit(_ id: String) -> GrammarUnit? { units.first { $0.id == id } }

    /// Interactive questions for a unit. Each item's tag is "unitID#index" so mistakes can be reviewed later.
    static func quiz(for unit: GrammarUnit, indices: [Int]? = nil) -> [QuizItem] {
        (indices ?? Array(unit.practice.indices)).compactMap { index in
            guard unit.practice.indices.contains(index) else { return nil }
            var item = quizItem(unit.practice[index])
            item.tag = "\(unit.id)#\(index)"
            return item
        }
    }

    static func quizItem(_ item: PracticeItem) -> QuizItem {
        switch item.t {
        case "choice", "pick":
            return QuizItem(prompt: item.q, instruction: item.t == "pick" ? "Choose the correct sentence" : nil,
                            kind: .choice(options: item.o ?? [], answer: item.a.first ?? ""), explanation: item.x)
        case "gap":
            return QuizItem(prompt: item.q, instruction: "Complete the sentence",
                            kind: .typed(answers: item.a, hints: []), explanation: item.x)
        case "error":
            let (words, target) = errorTokens(item.q)
            return QuizItem(prompt: "Tap the mistake.", instruction: "Find the mistake",
                            kind: .findError(words: words, target: target, correction: item.c ?? ""), explanation: item.x)
        case "build":
            return QuizItem(prompt: item.q, instruction: "Build the sentence", kind: .build(answer: item.a.first ?? ""), explanation: item.x)
        case "punctuate":
            return QuizItem(prompt: item.q, instruction: "Punctuation",
                            kind: .punctuate(words: item.w ?? [], targets: Set(item.targets ?? [])), explanation: item.x)
        default:
            return QuizItem(prompt: item.q, kind: .reveal(answer: item.a.first ?? ""), explanation: item.x)
        }
    }

    /// Splits "He [have] two brothers." into tappable tokens; the bracketed phrase is one token.
    static func errorTokens(_ text: String) -> (words: [String], target: Int) {
        var words: [String] = []
        var target = -1
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "[") {
            words += rest[..<open].split(separator: " ").map(String.init)
            guard let close = rest[open...].firstIndex(of: "]") else { break }
            target = words.count
            var phrase = String(rest[rest.index(after: open)..<close])
            // Keep punctuation that follows the bracket attached to the phrase.
            var after = rest[rest.index(after: close)...]
            while let first = after.first, !first.isWhitespace {
                phrase.append(first)
                after = after.dropFirst()
            }
            words.append(phrase)
            rest = after
        }
        words += rest.split(separator: " ").map(String.init)
        return (words, target)
    }
}

// MARK: - Progress

extension AppStore {
    func unitRead(_ unit: GrammarUnit) -> Bool { isDone("gunit:\(unit.id)") }
    func unitScore(_ unit: GrammarUnit) -> ExerciseScore? { learning.grammar["course:\(unit.id)"] }

    /// Half for reading the cards, half for the best practice score.
    func unitProgress(_ unit: GrammarUnit) -> Double {
        (unitRead(unit) ? 0.5 : 0) + min(1, unitScore(unit)?.fraction ?? 0) * 0.5
    }

    func sectionProgress(_ section: GrammarCourseSection) -> Double {
        section.units.isEmpty ? 0 : section.units.map(unitProgress).reduce(0, +) / Double(section.units.count)
    }

    var courseProgress: Double {
        let units = GrammarCourse.units
        return units.isEmpty ? 0 : units.map(unitProgress).reduce(0, +) / Double(units.count)
    }

    var grammarMistakes: [String] { learning.mistakes ?? [] }

    /// Wrong answers are kept for review; a later correct answer removes them.
    func recordGrammarAnswer(_ tag: String?, correct: Bool) {
        guard let tag, tag.contains("#") else { return }
        var list = learning.mistakes ?? []
        if correct {
            list.removeAll { $0 == tag }
        } else if !list.contains(tag) {
            list.append(tag)
        }
        learning.mistakes = list
    }

    /// The next essential unit that is not finished, for the study plan.
    var nextGrammarUnit: GrammarUnit? {
        GrammarCourse.essentials.first { unitProgress($0) < 0.85 } ?? GrammarCourse.units.first { unitProgress($0) < 0.85 }
    }
}
