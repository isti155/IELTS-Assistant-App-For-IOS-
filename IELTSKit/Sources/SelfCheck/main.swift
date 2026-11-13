import Foundation
@testable import IELTSKit

// Assertion-based checks that run with `swift run SelfCheck`, with or without Xcode.

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition {
        print("ok    \(label)")
    } else {
        failures += 1
        print("FAIL  \(label)")
    }
}

// MARK: Band arithmetic
check(BandMath.taskBand([7, 6, 7, 7]) == 6.5, "task band 6.75 rounds down to 6.5")
check(BandMath.taskBand([6, 6, 6, 7]) == 6.0, "task band 6.25 rounds down to 6.0")
check(BandMath.overall([6.5, 6.5, 5.0, 7.0]) == 6.5, "overall 6.25 rounds up to 6.5")
check(BandMath.overall([6.5, 6.5, 5.5, 6.0]) == 6.0, "overall 6.125 rounds to 6.0")
check(BandMath.overall([7.0, 7.0, 6.5, 6.5]) == 7.0, "overall 6.75 rounds up to 7.0")
check(BandMath.writing(task1: 6.0, task2: 7.0) == 6.5, "writing weights Task 2 double")
check(BandMath.listeningBand(raw: 40) == 9 && BandMath.listeningBand(raw: 30) == 7, "listening table")
check(BandMath.academicReadingBand(raw: 30) == 7 && BandMath.academicReadingBand(raw: 29) == 6.5, "reading table")
check(BandMath.scaledRaw(correct: 9, total: 12) == 30, "9 of 12 scales to 30 of 40")

// MARK: Marking
let priceQuestion = SeedContent.listening.questions[3]
check(Marking.isCorrect("95", for: priceQuestion) && Marking.isCorrect(" Ninety-Five ", for: priceQuestion), "digits and words accepted")
check(!Marking.isCorrect("120", for: priceQuestion) && !Marking.isCorrect("", for: priceQuestion), "distractor and blank rejected")
check(Marking.isCorrect("2:30", for: SeedContent.listeningReserve.questions[5]), "time formats accepted")

// MARK: Bundled content is self-consistent
for test in SeedContent.readings {
    for q in test.questions {
        check(Marking.isCorrect(q.answer, for: q), "\(test.title) Q\(q.id) key is markable")
        if !q.options.isEmpty { check(q.options.contains(q.answer), "\(test.title) Q\(q.id) key is an option") }
        if q.kind == "completion" {
            check(test.passage.lowercased().contains(q.answer.lowercased()), "\(test.title) Q\(q.id) answer is in the passage")
        }
    }
}
for test in SeedContent.listenings {
    let script = test.segments.map(\.text).joined(separator: " ").lowercased()
    for q in test.questions {
        check(Marking.isCorrect(q.answer, for: q), "\(test.title) Q\(q.id) key is markable")
        if !q.options.isEmpty { check(q.options.contains(q.answer), "\(test.title) Q\(q.id) key is an option") }
        if q.kind == "completion" {
            let heard = ([q.answer] + q.accepted).contains { script.contains($0.lowercased()) }
            check(heard, "\(test.title) Q\(q.id) answer is spoken in the recording")
        }
    }
}
for task in SeedContent.allTask1 {
    let chart = task.chart!
    check(chart.series.allSatisfy { $0.values.count == chart.categories.count }, "chart '\(chart.title)' series match categories")
}
check(QuestionBank.shared.task2.count >= 100, "question bank has \(QuestionBank.shared.task2.count) Task 2 questions")
check(SpeakingContent.randomScript().part1.count == 6, "random speaking script has six Part 1 questions")

// MARK: Speech metrics
let segments = [
    SpokenSegment(text: "I", start: 0.0, duration: 0.2, confidence: 0.9),
    SpokenSegment(text: "um", start: 0.3, duration: 0.2, confidence: 0.8),
    SpokenSegment(text: "live", start: 2.0, duration: 0.3, confidence: 0.3),
    SpokenSegment(text: "here", start: 2.4, duration: 0.3, confidence: 0.9),
]
let metrics = SpeechAnalysis.metrics(segments: segments, transcript: "I um live here", seconds: 6)
check(metrics.words == 4 && metrics.wordsPerMinute == 40 && metrics.longPauses == 1 && metrics.fillers == 1, "speech metrics")
check(metrics.lowConfidenceWords == ["live"], "low-confidence word listed")

// MARK: Essay analysis
let weak = """
Now a days many peoples think that informations from internet is more better than books. I am agree with this. \
However, however, there is many problems. People is using phones alot. He have no time.

In conclusion, i think technology are good.
"""
let analysis = WritingAnalysis(task: 2, text: weak)
let fixes = Set(analysis.corrections.map { $0.corrected.lowercased() })
for expected in ["people", "information", "better", "i agree", "nowadays", "a lot", "he has", "people are"] {
    check(fixes.contains(expected), "analysis corrects to '\(expected)'")
}
check(analysis.hasConclusion && analysis.hasOpinion, "analysis finds opinion and conclusion")
let clean = WritingAnalysis(task: 1, text: "Overall, a university in Europe reported that the figure rose to 45% in 2020, while it fell elsewhere.")
check(clean.corrections.filter { $0.category == "grammar" }.isEmpty, "no false grammar alarms on a correct sentence")
check(clean.hasOverview && clean.figureCount == 2, "analysis finds overview and figures")

// MARK: Examiner rules
let task2 = SeedContent.writingTask2[0]
let high = BandPrediction(overall: 7.6, task: 7.0, coherence: 7.2, lexical: 6.8, grammar: 6.6, truncated: false)
let short = LocalExaminer.buildWritingEvaluation(task: task2, response: weak, prediction: high)
check(short.criteria[0].band <= 4, "badly under-length essay caps Task Response at 4")
check(short.band <= BandMath.taskBand(short.criteria.map(\.band)), "overall never exceeds the criteria mean")
let longEssay = Array(repeating: "Although opinions differ, I believe that universities should balance employment and curiosity because both matter.", count: 22).joined(separator: " ")
let full = LocalExaminer.buildWritingEvaluation(task: task2, response: longEssay, prediction: high)
check(full.band == 7.5, "full-length essay keeps the model's overall band (7.6 → 7.5)")
check(full.criteria.allSatisfy { $0.band == $0.band.rounded() }, "criteria are whole bands")
let task1 = SeedContent.writingTask1[0]
let noOverview = Array(repeating: "The North had 32 percent in 2005 and 93 percent in 2025, which was higher than the South.", count: 12).joined(separator: " ")
check(LocalExaminer.buildWritingEvaluation(task: task1, response: noOverview, prediction: high).criteria[0].band <= 5, "Task 1 without an overview caps Task Achievement at 5")

let slowTurn = SpeakingTurn(part: 3, question: "Q", transcript: "I think it is good because people like it",
                            metrics: SpeechMetrics(words: 9, seconds: 12, wordsPerMinute: 45, longPauses: 3, fillers: 0, meanConfidence: 0.65, lowConfidenceWords: ["good"]))
let slow = LocalExaminer.buildSpeakingEvaluation(turns: [slowTurn], prediction: nil)
check(slow.criteria[0].band <= 4 && slow.criteria[3].band == 4, "slow, unclear speech scores low on fluency and pronunciation")
check(slow.caveats.contains { $0.contains("rough guide") }, "speaking report carries its caveat")

// MARK: Tutor retrieval: each question must reach the right guide
let retrieval: [(String, String)] = [
    ("How do I tell FALSE from NOT GIVEN?", "Reading: True / False / Not Given"),
    ("how many body paragraphs in task 2 essay", "Writing Task 2"),
    ("What words can I use to describe a graph that rises sharply?", "Writing Task 1: language for trends"),
    ("How is my overall band calculated?", "How bands are decided"),
    ("tips for matching headings", "Reading: matching headings"),
    ("What should I do in the one minute of preparation for the cue card?", "Speaking: Part 2 long turn (cue card)"),
    ("How long is the listening test?", "Test format and timing"),
    ("Make me a study plan for four weeks", "A four-week plan"),
    ("I keep making mistakes with articles and subject verb agreement", "Writing: grammar for band 7"),
]
for (question, expected) in retrieval {
    let found = Guide.relevant(to: question).first?.title ?? "nothing"
    check(found == expected, "tutor retrieval: '\(question)' → \(found)")
}
check(Guide.relevant(to: "What is the capital of France?").isEmpty, "tutor retrieval returns nothing for an unrelated question")
let facts = Prompts.feedbackFacts(full)
check(facts.contains("overall 7.5") && facts.contains("Task Response"), "feedback facts carry the decided bands")

// MARK: Learning content
let book = Library.grammar
check(book.chapters.count == 16, "grammar book has 16 chapters (\(book.chapters.count))")
var grammarQuestions = 0, grammarProblems: [String] = []
for chapter in book.chapters {
    for exercise in chapter.exercises where exercise.kind != "reveal" {
        let items = GrammarExerciseView.items(for: exercise)
        grammarQuestions += items.count
        if items.isEmpty { grammarProblems.append("\(exercise.id) has no questions") }
        for item in items {
            switch item.kind {
            case .choice(let options, let answer):
                if !options.contains(where: { AnswerCheck.matches($0, answer) }) { grammarProblems.append("\(exercise.id): answer '\(answer)' not among options") }
            case .typed(let answers, _):
                if answers.allSatisfy({ $0.isEmpty }) && !item.prompt.contains("__") { grammarProblems.append("\(exercise.id): empty typed answer") }
            case .capitalize(let words, let targets), .punctuate(let words, let targets):
                if targets.isEmpty || targets.contains(where: { $0 >= words.count }) { grammarProblems.append("\(exercise.id): bad targets") }
            default: break
            }
        }
    }
}
check(grammarProblems.isEmpty, "every grammar question is answerable (\(grammarQuestions) questions) \(grammarProblems.prefix(3))")
check(AnswerCheck.matches("doesn't", "does not") && AnswerCheck.matches("Could", "could/might") && AnswerCheck.matches("x", ""), "answer matching handles contractions, alternatives and 'no article'")
check(!AnswerCheck.matches("it's", "its"), "answer matching keeps its / it's apart")

check(Library.vocabulary.count > 9000, "vocabulary has \(Library.vocabulary.count) words")
check(WordPools.academic.count > 500 && WordPools.book.count > 200, "academic (\(WordPools.academic.count)) and book (\(WordPools.book.count)) word sets")
let vocabItems = VocabQuiz.items(for: Array(WordPools.academic.prefix(12)))
check(vocabItems.count == 12 && vocabItems.allSatisfy { item in
    if case .choice(let options, let answer) = item.kind { return options.contains(answer) && Set(options).count == options.count }
    return true
}, "vocabulary quiz questions contain their answer once")

let course = Library.course
check(course.units.count == 5 && Library.courseLessons.count >= 25, "course has \(Library.courseLessons.count) lessons")
check(Library.courseLessons.allSatisfy { $0.steps.allSatisfy { $0.kind != "quiz" || ($0.options ?? []).contains($0.answer ?? "") } }, "every course check has its answer among the options")

let reading = Library.readingBank
check(reading.count == 1051, "reading bank has \(reading.count) tests")
var readingProblems = 0, lectures = 0
for test in reading {
    for question in test.groups.flatMap({ BankConvert.questions($0) }) where !question.options.isEmpty {
        if !question.options.contains(question.answer) { readingProblems += 1 }
    }
    if BankConvert.lecture(test) != nil { lectures += 1 }
}
check(readingProblems == 0, "every reading choice answer is among its options (\(readingProblems) problems)")
check(lectures > 400, "\(lectures) listening lectures can be built from the passages")

check(Library.speaking.cueCards.count > 100 && Library.speaking.part1.count > 100 && Library.speaking.samples.count > 50,
      "speaking bank: \(Library.speaking.cueCards.count) cue cards, \(Library.speaking.part1.count) Part 1 topics, \(Library.speaking.samples.count) transcripts")
let script = SpeakingContent.randomScript()
check(script.part1.count >= 5 && script.cueCard.bullets.count >= 3 && !script.part3.isEmpty, "random speaking test is complete")
check(Library.writing.task1.count == 120 && Library.writing.task1.allSatisfy { Library.task1Image($0.image) != nil },
      "all \(Library.writing.task1.count) Task 1 images are bundled")
check(Library.writing.task2.count == 400, "writing bank has \(Library.writing.task2.count) Task 2 questions")

MainActor.assumeIsolated {
    let learningStore = AppStore(persistent: false)
    let plan = StudyPlan(store: learningStore)
    check(plan.tasks.count == 4 && plan.phase == .foundation, "a new learner gets a 4-task foundation plan")
    let firstWord = WordPools.academic[0]
    learningStore.review(firstWord, correct: true)
    learningStore.review(firstWord, correct: true)
    check(learningStore.card(firstWord)?.box == 2 && learningStore.todayXP == 10 && learningStore.streak == 1, "reviews move a word up the boxes and count towards XP and streak")
    learningStore.review(firstWord, correct: false)
    check(learningStore.card(firstWord)?.box == 0 && learningStore.dueWords.isEmpty, "a wrong answer resets the word and brings it back in 10 minutes")
}

// MARK: Exam practice
let papers = ReadingPapers.papers(reading)
check(papers.count == 263, "\(papers.count) full reading papers")
var paperProblems = 0
for paper in papers {
    var next = 1
    var numbers: [Int] = []
    for test in paper {
        let groups = ReadingPapers.renumbered(test, from: next)
        next += test.questionCount
        for group in groups {
            numbers += group.questions.map(\.n)
            // Every gap marker in a summary must point at one of this group's renumbered questions.
            if let summary = group.summary {
                let markers = summary.matches(of: #/\[(\d+)\]/#).compactMap { Int($0.output.1) }
                if !markers.allSatisfy({ marker in group.questions.contains { $0.n == marker } }) { paperProblems += 1 }
            }
        }
    }
    if numbers != Array(1...40) { paperProblems += 1 }
}
check(paperProblems == 0, "every paper is numbered 1–40 with matching summary gaps (\(paperProblems) problems)")
check(WritingPapers.count == 120, "\(WritingPapers.count) writing papers")

var sheet = BookSheet()
sheet.answers[0] = "quarter past eight"; sheet.key[0] = "8.15 / quarter past eight"
sheet.answers[1] = "castle"; sheet.key[1] = "(the) castle"
sheet.answers[2] = "the castle"; sheet.key[2] = "(the) castle"
sheet.answers[3] = "Tuesday"; sheet.key[3] = "Thursday"
sheet.answers[4] = "wrong"; sheet.key[4] = "right"; sheet.marks[4] = true
check(sheet.isCorrect(0) == true && sheet.isCorrect(1) == true && sheet.isCorrect(2) == true, "book keys accept alternatives and optional words")
check(sheet.isCorrect(3) == false && sheet.isCorrect(4) == true && sheet.isCorrect(5) == nil, "wrong answers, manual marks and unmarked rows")
for index in 5..<40 { sheet.answers[index] = "a"; sheet.key[index] = index < 30 ? "a" : "b" }
check(sheet.marked == 40 && sheet.score == 29 && BandMath.listeningBand(raw: sheet.score) == 6.5, "a 29/40 sheet is band 6.5 in Listening")

// MARK: Grammar course
check(GrammarCourse.sections.count == 7 && GrammarCourse.units.count == 61, "grammar course: \(GrammarCourse.sections.count) sections, \(GrammarCourse.units.count) units")
check(Set(GrammarCourse.units.map(\.id)).count == GrammarCourse.units.count, "grammar unit ids are unique")
var courseProblems: [String] = []
var courseQuestions = 0
for unit in GrammarCourse.units {
    if unit.cards.isEmpty || !unit.cards.contains(where: { $0.kind == "ielts" }) { courseProblems.append("\(unit.id): missing IELTS card") }
    for item in GrammarCourse.quiz(for: unit) {
        courseQuestions += 1
        switch item.kind {
        case .choice(let options, let answer):
            if !options.contains(answer) { courseProblems.append("\(unit.id): choice answer") }
        case .findError(let words, let target, let correction):
            if target < 0 || target >= words.count || correction.isEmpty { courseProblems.append("\(unit.id): error item") }
        case .typed(let answers, _):
            if answers.isEmpty || item.prompt.components(separatedBy: "___").count - 1 != answers.count { courseProblems.append("\(unit.id): gap count") }
        case .build(let answer):
            if answer.split(separator: " ").count < 3 { courseProblems.append("\(unit.id): build") }
        case .punctuate(let words, let targets):
            if targets.isEmpty || targets.contains(where: { $0 >= words.count }) { courseProblems.append("\(unit.id): punctuate") }
        default: break
        }
    }
}
check(courseProblems.isEmpty, "all \(courseQuestions) course questions are valid \(courseProblems.prefix(3))")
let tokens = GrammarCourse.errorTokens("I [am living] in this city since 2012.")
check(tokens.words == ["I", "am living", "in", "this", "city", "since", "2012."] && tokens.target == 1, "find-the-mistake splits the sentence and marks the bracketed phrase")
let punctuated = GrammarCourse.errorTokens("Many young [people,] prefer to rent.")
check(punctuated.words[punctuated.target] == "people,", "punctuation inside the brackets stays with the phrase")
check(GrammarCourse.essentials.count == 30, "\(GrammarCourse.essentials.count) units marked essential for IELTS")
MainActor.assumeIsolated {
    let courseStore = AppStore(persistent: false)
    courseStore.recordGrammarAnswer("articles-basic#2", correct: false)
    courseStore.recordGrammarAnswer("articles-basic#2", correct: false)
    check(courseStore.grammarMistakes == ["articles-basic#2"], "a wrong answer is saved once for review")
    courseStore.recordGrammarAnswer("articles-basic#2", correct: true)
    check(courseStore.grammarMistakes.isEmpty, "a later correct answer clears it")
    check(courseStore.nextGrammarUnit?.priority == .essential, "the study plan starts with an essential unit")
}

// MARK: Trained scorer (Core ML) against the PyTorch reference
struct ReferenceCase: Decodable {
    var task: Int
    var prompt: String
    var essay: String
    var label: Double
    var ids: [Int32]
    var torch: [Double]
}
if let url = Bundle.module.url(forResource: "scorer_reference", withExtension: "json"),
   let cases = try? JSONDecoder().decode([ReferenceCase].self, from: Data(contentsOf: url)) {
    do {
        let tokenizer = try BandScorer.shared.tokenizerForChecks()
        for (index, item) in cases.enumerated() {
            let encoded = tokenizer.encode(task: item.task, prompt: item.prompt, essay: item.essay)
            let ids = Array(encoded.ids.prefix(item.ids.count))
            check(ids == item.ids && encoded.mask.reduce(0, +) == Int32(item.ids.count), "case \(index): Swift tokenizer matches Python (\(item.ids.count) tokens)")
            let prediction = try BandScorer.shared.predict(task: item.task, prompt: item.prompt, essay: item.essay)
            let mine = [prediction.overall, prediction.task, prediction.coherence, prediction.lexical, prediction.grammar]
            let drift = zip(mine, item.torch).map { abs($0 - min(9, max(1, $1))) }.max() ?? 9
            check(drift < 0.2, String(format: "case \(index): Core ML band %.2f vs PyTorch %.2f (label %.1f)", prediction.overall, item.torch[0], item.label))
        }
    } catch {
        check(false, "scorer loads and runs: \(error)")
    }
} else {
    check(false, "scorer reference cases are bundled")
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) FAILED.")
exit(failures == 0 ? 0 : 1)
