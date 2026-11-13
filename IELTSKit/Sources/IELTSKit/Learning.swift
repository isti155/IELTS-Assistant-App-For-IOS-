import Foundation
import SwiftUI

/// Everything the learning modules remember: XP, daily activity, vocabulary review
/// schedule, grammar results and finished lessons. Saved with the rest of the app state.
public struct LearningState: Codable, Hashable {
    var xpByDay: [String: Int] = [:]
    var reviewsByDay: [String: Int] = [:]
    var cards: [String: CardState] = [:]
    var grammar: [String: ExerciseScore] = [:]
    /// Finished items: "grammar:9:3" (chapter 9, section 3), "course:r-tfng", "reading:b001_01".
    var done: [String: Date] = [:]
    var dailyGoal: Int = 100
    /// Answer sheets for tests done from the learner's own Cambridge IELTS books.
    /// Optional so state saved before this existed still decodes.
    var sheets: [String: BookSheet]?
    /// Grammar course questions answered wrongly ("unitID#index"), for the mistakes review.
    var mistakes: [String]?

    var totalXP: Int { xpByDay.values.reduce(0, +) }
}

/// A 40-question answer sheet for one Listening or Reading test from a book.
struct BookSheet: Codable, Hashable {
    var answers: [String] = Array(repeating: "", count: 40)
    /// The answers from the book's key, typed in once by the learner and reused for retakes.
    var key: [String] = Array(repeating: "", count: 40)
    /// Manual marks override the key ("I checked it myself").
    var marks: [Bool?] = Array(repeating: nil, count: 40)
    /// Question type of each item, so mistakes can be grouped by type.
    var types: [String?] = Array(repeating: nil, count: 40)
    var seconds: Int = 0
    var finished: Date?
    var attempts: Int = 0

    func isCorrect(_ index: Int) -> Bool? {
        if let mark = marks[index] { return mark }
        let expected = key[index].trimmingCharacters(in: .whitespaces)
        guard !expected.isEmpty else { return nil }
        return BookSheet.alternatives(expected).contains { AnswerCheck.matches(answers[index], $0) }
    }

    /// "(the) castle" accepts "castle" and "the castle"; "/" separates alternatives.
    static func alternatives(_ key: String) -> [String] {
        key.split(separator: "/").flatMap { part -> [String] in
            let text = String(part).trimmingCharacters(in: .whitespaces)
            let without = text.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            let with = text.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            return [without, with]
        }
    }

    var marked: Int { (0..<40).filter { isCorrect($0) != nil }.count }
    var score: Int { (0..<40).filter { isCorrect($0) == true }.count }
    var answered: Int { answers.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count }
}

struct CardState: Codable, Hashable {
    /// Leitner box 0–6: the higher the box, the longer until the word comes back.
    var box: Int = 0
    var due: Date = Date()
    var seen: Int = 0
    var correct: Int = 0

    static let intervals: [Double] = [0, 1, 2, 4, 8, 16, 32]  // days
    var learned: Bool { box >= 3 }
    var mastered: Bool { box >= 5 }
}

struct ExerciseScore: Codable, Hashable {
    var correct: Int
    var total: Int
    var date: Date
    var fraction: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

enum Day {
    static func key(_ date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

extension AppStore {
    // MARK: XP and streak

    func award(_ xp: Int) {
        learning.xpByDay[Day.key(), default: 0] += xp
    }

    var todayXP: Int { learning.xpByDay[Day.key()] ?? 0 }

    /// Consecutive days with any XP, counting today if active, otherwise ending yesterday.
    var streak: Int {
        var count = 0
        var date = Date()
        if (learning.xpByDay[Day.key(date)] ?? 0) == 0 {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        while (learning.xpByDay[Day.key(date)] ?? 0) > 0 {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return count
    }

    func isDone(_ key: String) -> Bool { learning.done[key] != nil }

    func sheet(_ id: String) -> BookSheet? { learning.sheets?[id] }

    func saveSheet(_ id: String, _ sheet: BookSheet) {
        if learning.sheets == nil { learning.sheets = [:] }
        learning.sheets?[id] = sheet
    }

    func markDone(_ key: String, xp: Int = 0) {
        if learning.done[key] == nil, xp > 0 { award(xp) }
        learning.done[key] = Date()
    }

    func doneToday(prefix: String) -> Bool {
        let today = Day.key()
        return learning.done.contains { $0.key.hasPrefix(prefix) && Day.key($0.value) == today }
    }

    // MARK: Vocabulary review (spaced repetition)

    func card(_ word: VocabWord) -> CardState? { learning.cards[word.id] }

    func review(_ word: VocabWord, correct: Bool) {
        var card = learning.cards[word.id] ?? CardState()
        card.seen += 1
        if correct {
            card.correct += 1
            card.box = min(card.box + 1, CardState.intervals.count - 1)
        } else {
            card.box = 0
        }
        let days = CardState.intervals[card.box]
        card.due = days == 0 ? Date().addingTimeInterval(600) : Calendar.current.date(byAdding: .day, value: Int(days), to: Date()) ?? Date()
        learning.cards[word.id] = card
        learning.reviewsByDay[Day.key(), default: 0] += 1
        award(correct ? 5 : 1)
    }

    var dueWords: [VocabWord] {
        let now = Date()
        return learning.cards.filter { $0.value.due <= now }
            .sorted { $0.value.due < $1.value.due }
            .compactMap { Library.vocabularyByID[$0.key] }
    }

    var learnedWordCount: Int { learning.cards.values.filter(\.learned).count }
    var reviewsToday: Int { learning.reviewsByDay[Day.key()] ?? 0 }

    /// Words not yet studied, easiest useful level first, with IELTS-frequent words before rare ones.
    func newWords(in pool: [VocabWord], count: Int) -> [VocabWord] {
        Array(pool.filter { learning.cards[$0.id] == nil }.prefix(count))
    }

    // MARK: Grammar

    func recordGrammar(_ exercise: String, correct: Int, total: Int) {
        let score = ExerciseScore(correct: correct, total: total, date: Date())
        if let old = learning.grammar[exercise], old.fraction > score.fraction {
            learning.grammar[exercise]?.date = Date()
        } else {
            learning.grammar[exercise] = score
        }
        award(correct * 4 + 10)
    }

    func chapterProgress(_ chapter: GrammarChapter) -> Double {
        let lessons = chapter.sections.indices.filter { isDone("grammar:\(chapter.id):\($0)") }.count
        let exercises = chapter.exercises.filter { learning.grammar["\($0.id)"] != nil }.count
        let total = chapter.sections.count + chapter.exercises.count
        return total == 0 ? 0 : Double(lessons + exercises) / Double(total)
    }
}

// MARK: - Study plan (the tutor's daily schedule)

enum StudyPhase: String {
    case foundation = "Foundation"
    case skills = "Skills building"
    case exam = "Exam practice"

    var detail: String {
        switch self {
        case .foundation: return "Learn the test format and question types, build grammar and vocabulary, and practise every skill once a week."
        case .skills: return "Practise question types against the clock and focus extra time on your weakest skill."
        case .exam: return "Timed practice under exam conditions. Review your error list every day and keep vocabulary reviews short."
        }
    }

    var symbol: String {
        switch self {
        case .foundation: return "building.columns.fill"
        case .skills: return "figure.strengthtraining.traditional"
        case .exam: return "flag.checkered"
        }
    }
}

struct PlanTask: Identifiable {
    enum Destination: Hashable {
        case vocabulary
        case grammar(Int)
        case grammarUnit(String)
        case lesson(String)
        case practice(Skill)
    }

    var id: String
    var title: String
    var detail: String
    var symbol: String
    var color: Color
    var minutes: Int
    var destination: Destination
    var done: Bool
}

@MainActor
struct StudyPlan {
    let store: AppStore

    var daysLeft: Int? {
        guard let date = store.profile.examDate else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                      to: Calendar.current.startOfDay(for: date)).day ?? 0)
    }

    var phase: StudyPhase {
        guard let days = daysLeft else {
            return Library.courseLessons.filter { store.isDone("course:\($0.id)") }.count < 8 ? .foundation : .skills
        }
        if days <= 14 { return .exam }
        if days <= 42 { return .skills }
        return .foundation
    }

    /// Skills ordered from weakest (or never practised) to strongest.
    var focus: [Skill] {
        Skill.allCases.sorted { (store.estimate(for: $0) ?? 0) < (store.estimate(for: $1) ?? 0) }
    }

    var nextLesson: CourseLesson? {
        // Prefer the weakest skill's unit once the "Start here" unit is finished.
        let units = Library.course.units
        if let start = units.first, let lesson = start.lessons.first(where: { !store.isDone("course:\($0.id)") }) {
            return lesson
        }
        for skill in focus {
            if let unit = units.first(where: { $0.skillValue == skill }),
               let lesson = unit.lessons.first(where: { !store.isDone("course:\($0.id)") }) {
                return lesson
            }
        }
        return nil
    }

    var nextGrammarChapter: GrammarChapter? {
        Library.grammar.chapters.first { store.chapterProgress($0) < 1 }
    }

    /// The practice skill for today: the weakest skill on most days, the others in rotation.
    var practiceSkill: Skill {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let weights = focus.enumerated().flatMap { index, skill in Array(repeating: skill, count: max(1, 3 - index)) }
        return weights.isEmpty ? .reading : weights[day % weights.count]
    }

    var tasks: [PlanTask] {
        var list: [PlanTask] = []
        let due = store.dueWords.count
        let reviewTarget = phase == .exam ? 15 : 20
        list.append(PlanTask(
            id: "vocab", title: due > 0 ? "Review \(min(due, reviewTarget)) words" : "Learn 10 new words",
            detail: due > 0 ? "\(due) words are due for review" : "Academic words from IELTS reading passages",
            symbol: "character.book.closed.fill", color: .purple, minutes: 8, destination: .vocabulary,
            done: store.reviewsToday >= 10))
        if let lesson = nextLesson {
            list.append(PlanTask(
                id: "lesson", title: lesson.title, detail: "Tutor lesson · \(lesson.minutes) min",
                symbol: "graduationcap.fill", color: Theme.accent, minutes: lesson.minutes,
                destination: .lesson(lesson.id), done: store.doneToday(prefix: "course:")))
        }
        if let unit = store.nextGrammarUnit {
            list.append(PlanTask(
                id: "grammar", title: "Grammar: \(unit.title)", detail: "\(unit.priority.label) · learn and practise",
                symbol: "text.book.closed.fill", color: .blue, minutes: 12,
                destination: .grammarUnit(unit.id),
                done: store.doneToday(prefix: "gunit:") || store.doneToday(prefix: "grammar:") || store.learning.grammar.values.contains { Day.key($0.date) == Day.key() }))
        }
        let skill = practiceSkill
        let practiced = store.attempts.contains { $0.skill == skill && Calendar.current.isDateInToday($0.date) }
        let practice: (String, String, Int) = {
            switch skill {
            case .reading: return ("Reading passage", "13 questions with explanations", 20)
            case .listening: return ("Listening practice", "A recording or a lecture", 15)
            case .writing: return (phase == .foundation ? "Writing Task 1 report" : "Writing Task 2 essay", "Marked on your iPhone", phase == .foundation ? 20 : 40)
            case .speaking: return ("Speaking practice", "Part 2 long turn or a full test", 12)
            }
        }()
        list.append(PlanTask(
            id: "practice", title: practice.0,
            detail: store.estimate(for: skill) == nil ? "\(practice.1) · not practised yet" : "\(practice.1) · your \(skill == focus.first ? "weakest" : "next") skill",
            symbol: skill.symbol, color: skill.color, minutes: practice.2, destination: .practice(skill), done: practiced))
        return list
    }
}
