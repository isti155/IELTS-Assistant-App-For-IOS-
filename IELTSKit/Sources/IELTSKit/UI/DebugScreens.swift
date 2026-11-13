#if DEBUG
import SwiftUI

/// Debug builds only: `-screen <name>` at launch opens one screen with sample progress,
/// so screenshots can be taken in the simulator. Never compiled into the installed app.
enum DebugScreens {
    static var requested: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screen"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    @MainActor static func sampleStore() -> AppStore {
        let store = AppStore(persistent: false)
        store.profile.targetBand = 7
        store.profile.examDate = Calendar.current.date(byAdding: .day, value: 34, to: Date())
        store.profile.onboarded = true
        let bands: [(Skill, String, Double, Double)] = [
            (.writing, "Writing Task 2", 6.5, 0.1), (.reading, "The Late Shift of Adolescence", 7, 1), (.speaking, "Speaking mock test", 6, 2),
            (.listening, "Nature Reserve Welcome Talk", 7.5, 3), (.writing, "Writing Task 1", 6, 5), (.reading, "The Clockmaker and the Sea", 6, 8),
        ]
        store.attempts = bands.map { Attempt(date: Date().addingTimeInterval(-$0.3 * 86400), skill: $0.0, title: $0.1, prompt: $0.1, response: "", band: $0.2) }
        for (index, word) in WordPools.academic.prefix(40).enumerated() {
            store.learning.cards[word.id] = CardState(box: index % 6, due: Date().addingTimeInterval(index < 12 ? -60 : 86400), seen: 3, correct: 2)
        }
        for day in 0..<5 {
            store.learning.xpByDay[Day.key(Calendar.current.date(byAdding: .day, value: -day, to: Date())!)] = 60 + day * 10
        }
        store.learning.reviewsByDay[Day.key()] = 12
        for lesson in Library.courseLessons.prefix(4) { store.learning.done["course:\(lesson.id)"] = Date() }
        for index in 0..<5 { store.learning.done["grammar:9:\(index)"] = Date() }
        store.learning.grammar["9.1"] = ExerciseScore(correct: 18, total: 21, date: Date())
        for unit in GrammarCourse.units.prefix(6) { store.learning.done["gunit:\(unit.id)"] = Date() }
        for (index, unit) in GrammarCourse.units.prefix(4).enumerated() {
            store.learning.grammar["course:\(unit.id)"] = ExerciseScore(correct: 6 + index, total: 9, date: Date())
        }
        store.learning.mistakes = ["articles-basic#2", "subject-verb-agreement#3", "present-perfect#5"]
        // A part-marked Listening sheet (invented sample answers) and a finished Reading sheet.
        var sheet = BookSheet()
        let sample = ["Harper", "9.30", "library", "bicycle", "£15", "Tuesday", "parking", "garden", "maps", "15th May",
                      "B", "C", "A", "river", "bridge", "E", "G", "D", "café", "lift"]
        for (index, answer) in sample.enumerated() {
            sheet.answers[index] = answer
            sheet.key[index] = index == 4 ? "£50" : index == 9 ? "(the) 15th May" : answer
        }
        sheet.types[4] = "Form / note / table completion"
        store.saveSheet(CambridgeBooks.id(book: 18, test: 1, skill: .listening), sheet)
        var reading = BookSheet()
        for index in 0..<40 {
            reading.answers[index] = "x"
            reading.key[index] = index % 6 == 0 ? "y" : "x"
            if index % 6 == 0 { reading.types[index] = index < 20 ? "True / False / Not Given" : "Matching headings" }
        }
        reading.finished = Date()
        reading.seconds = 3420
        store.saveSheet(CambridgeBooks.id(book: 18, test: 1, skill: .reading), reading)
        return store
    }

    @MainActor @ViewBuilder static func view(_ name: String) -> some View {
        let grammar = Library.grammar.chapters
        switch name {
        case "learn": LearnScreen()
        case "grammar": GrammarHome()
        case "chapter": GrammarChapterView(chapter: grammar[8])
        case "lesson": LessonReader(chapter: grammar[8], start: 3)
        case "exercise": GrammarExerciseView(chapter: grammar[8], exercise: grammar[8].exercises[0])
        case "capitals": GrammarExerciseView(chapter: grammar[3], exercise: grammar[3].exercises[1])
        case "build": GrammarExerciseView(chapter: grammar[4], exercise: grammar[4].exercises.first { $0.items?.first?.kind == "build" } ?? grammar[4].exercises[0])
        case "vocab": VocabularyHome()
        case "set": WordSetView(title: "IELTS academic words", words: WordPools.academic, color: .purple)
        case "word": WordDetail(word: WordPools.academic[3])
        case "flashcards": FlashcardDeck(title: "Flashcards", words: Array(WordPools.academic.prefix(10)), color: .purple)
        case "vquiz": VocabQuizSession(title: "Quiz", words: Array(WordPools.academic.dropFirst(2).prefix(10)), color: .purple)
        case "match": MatchGame(words: Array(WordPools.academic.prefix(6)), color: .purple)
        case "tutor": TutorScreen()
        case "course": LessonPlayer(lesson: Library.courseLessons[4], color: Skill.reading.color)
        case "reading": ReadingHub()
        case "readtest": BankTestView(test: Library.readingBank[0])
        case "listening": ListeningHub()
        case "writing": WritingHub()
        case "task1": Task1List(kind: "Map", items: Library.writing.task1.filter { $0.kind == "Map" })
        case "speaking": SpeakingHub()
        case "transcript": SampleTranscript(sample: Library.speaking.samples[0])
        case "home": HomeScreen()
        case "gcourse": GrammarHome()
        case "gunit": GrammarUnitView(unit: GrammarCourse.unit("present-perfect")!)
        case "gcards": UnitCardsReader(unit: GrammarCourse.unit("present-perfect")!, color: .blue)
        case "gerror": QuizRunner(title: "Subject–verb agreement", color: .green,
                                  items: GrammarCourse.quiz(for: GrammarCourse.unit("subject-verb-agreement")!, indices: [3, 4])) { _, _ in }
        case "gsection": GrammarSectionView(section: GrammarCourse.sections[0])
        case "exam": ExamHub()
        case "shelf": CambridgeShelf()
        case "book": BookView(book: 18)
        case "sheet": AnswerSheetView(book: 18, test: 1, skill: .listening)
        case "sheetresult": AnswerSheetView(book: 18, test: 1, skill: .reading)
        case "paper": ReadingPaperView(number: 1, tests: ReadingPapers.papers(Library.readingBank)[0])
        case "wpaper": WritingPaperView(number: 3)
        default: MainTabs()
        }
    }
}

struct DebugRoot: View {
    let name: String
    @StateObject private var store = DebugScreens.sampleStore()

    var body: some View {
        Group {
            if name == "tabs" {
                MainTabs()
            } else {
                NavigationStack { DebugScreens.view(name) }
            }
        }
        .environmentObject(store)
        .tint(Theme.accent)
    }
}
#endif
