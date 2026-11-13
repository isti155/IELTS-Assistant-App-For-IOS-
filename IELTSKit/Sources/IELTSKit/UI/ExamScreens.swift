import SwiftUI

// MARK: - Question types (for the mistake tracker)

enum QuestionTypes {
    static let listening = ["Form / note / table completion", "Multiple choice", "Map / plan labelling", "Matching",
                            "Sentence completion", "Short answer"]
    static let reading = ["True / False / Not Given", "Yes / No / Not Given", "Matching headings", "Matching information",
                          "Matching features", "Matching sentence endings", "Multiple choice", "Summary / note completion",
                          "Sentence completion", "Diagram labelling", "Short answer"]

    /// The tutor lesson that teaches each question type.
    static func lesson(for type: String) -> String? {
        switch type {
        case "True / False / Not Given", "Yes / No / Not Given": return "r-tfng"
        case "Matching headings": return "r-headings"
        case "Matching information", "Matching features", "Matching sentence endings": return "r-matching"
        case "Summary / note completion", "Sentence completion", "Diagram labelling", "Short answer": return "r-completion"
        case "Multiple choice": return "r-mcq"
        case "Form / note / table completion": return "l-forms"
        case "Map / plan labelling": return "l-maps"
        default: return "l-distractors"
        }
    }
}

// MARK: - Hub

struct ExamHub: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var library = ReadingLibrary.shared

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        IconTile(symbol: "doc.text.magnifyingglass", color: Theme.accent, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exam practice").font(.title3.weight(.bold))
                            Text("Full papers in the real format, and a companion for the Cambridge IELTS books.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

            Section {
                NavigationLink {
                    CambridgeShelf()
                } label: {
                    RowLabel(title: "Cambridge IELTS book companion", subtitle: "Answer sheets, marking and bands for books 1–21",
                             icon: IconTile(symbol: "books.vertical.fill", color: .red, size: 40)) {
                        let done = (store.learning.sheets ?? [:]).values.filter { $0.finished != nil }.count
                        if done > 0 { Tag(text: "\(done) done", color: .red) }
                    }
                }
            } header: {
                Text("Your books")
            } footer: {
                Text("Work from your own copy of the book; the app times, marks and tracks you. The books' content is not included in the app.")
            }

            Section {
                NavigationLink {
                    ReadingPaperList()
                } label: {
                    RowLabel(title: "Reading papers", subtitle: "\(ReadingPapers.papers(library.tests ?? []).count) papers · 3 passages · 40 questions · 60 min",
                             icon: IconTile(symbol: "doc.on.doc.fill", color: Skill.reading.color, size: 40))
                }
                NavigationLink {
                    WritingPaperList()
                } label: {
                    RowLabel(title: "Writing papers", subtitle: "\(WritingPapers.count) papers · Task 1 + Task 2 · 60 min",
                             icon: IconTile(symbol: "square.and.pencil", color: Skill.writing.color, size: 40))
                }
                NavigationLink {
                    SpeakingTestView(script: nil)
                } label: {
                    RowLabel(title: "Speaking test", subtitle: "All three parts, new questions each time",
                             icon: IconTile(symbol: "person.wave.2.fill", color: Skill.speaking.color, size: 40))
                }
            } header: {
                Text("Full practice papers")
            } footer: {
                Text("Reading papers are built from the IELTS-style passage bank (13 + 13 + 14 questions) and scored on the 40-question band scale.")
            }

            let weak = WeakTypes.top(store)
            if !weak.isEmpty {
                Section {
                    ForEach(weak, id: \.type) { item in
                        NavigationLink {
                            if let id = QuestionTypes.lesson(for: item.type), let lesson = Library.courseLessons.first(where: { $0.id == id }) {
                                LessonPlayer(lesson: lesson)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.type).font(.subheadline.weight(.semibold))
                                    Text("\(item.count) mistake\(item.count == 1 ? "" : "s") · open the lesson").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "graduationcap.fill").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                } header: {
                    Text("Your weakest question types")
                } footer: {
                    Text("From the mistakes you tagged when marking your book tests.")
                }
            }
        }
        .groupedList()
        .navigationTitle("Exam Practice")
        .inlineTitle()
        .task { await library.load() }
    }
}

enum WeakTypes {
    @MainActor static func top(_ store: AppStore) -> [(type: String, count: Int)] {
        var counts: [String: Int] = [:]
        for sheet in (store.learning.sheets ?? [:]).values {
            for index in 0..<40 where sheet.isCorrect(index) == false {
                if let type = sheet.types[index] { counts[type, default: 0] += 1 }
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(4).map { ($0.key, $0.value) }
    }
}

// MARK: - Reading papers

enum ReadingPapers {
    /// Two 13-question tests and one 14-question test make a 40-question paper; easier passages first.
    static func papers(_ tests: [BankTest]) -> [[BankTest]] {
        let thirteen = tests.filter { $0.questionCount == 13 }.sorted { (!$0.hard ? 0 : 1, $0.id) < (!$1.hard ? 0 : 1, $1.id) }
        let fourteen = tests.filter { $0.questionCount == 14 }.sorted { ($0.hard ? 0 : 1, $0.id) < ($1.hard ? 0 : 1, $1.id) }
        let count = min(thirteen.count / 2, fourteen.count)
        // Interleave so each paper mixes subject areas.
        return (0..<count).map { index in [thirteen[index], thirteen[count + index], fourteen[index]] }
    }

    /// The test's groups renumbered to continue from `start` (instructions, gaps and summaries too).
    static func renumbered(_ test: BankTest, from start: Int) -> [BankGroup] {
        var next = start
        return test.groups.map { group in
            var map: [Int: Int] = [:]
            var copy = group
            copy.questions = group.questions.map { question in
                var q = question
                map[q.n] = next
                q.n = next
                next += 1
                return q
            }
            func fix(_ text: String) -> String {
                var result = text
                for (old, new) in map.sorted(by: { $0.key > $1.key }) {
                    result = result.replacingOccurrences(of: "[\(old)]", with: "[\(new)]")
                }
                return result
            }
            copy.questions = copy.questions.map { var q = $0; q.q = fix(q.q); return q }
            copy.summary = group.summary.map(fix)
            if let first = copy.questions.first?.n, let last = copy.questions.last?.n {
                copy.instructions = group.instructions.replacingOccurrences(
                    of: #"Questions?\s+\d+\s*[–-]\s*\d+"#, with: "Questions \(first)–\(last)", options: .regularExpression)
            }
            return copy
        }
    }
}

struct ReadingPaperList: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var library = ReadingLibrary.shared

    var body: some View {
        let papers = ReadingPapers.papers(library.tests ?? [])
        List {
            if library.tests == nil {
                HStack { ProgressView(); Text("Loading papers…").foregroundStyle(.secondary) }
            }
            ForEach(Array(papers.enumerated()), id: \.offset) { index, paper in
                NavigationLink {
                    ReadingPaperView(number: index + 1, tests: paper)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Skill.reading.color)
                            .frame(width: 40, height: 40)
                            .background(Skill.reading.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reading paper \(index + 1)").font(.subheadline.weight(.semibold))
                            Text(paper.map(\.title).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        if let attempt = store.lastAttempt(matching: "Reading paper \(index + 1)") {
                            BandPill(band: attempt.band, color: Skill.reading.color)
                        }
                    }
                }
            }
        }
        .groupedList()
        .navigationTitle("Reading papers")
        .inlineTitle()
        .task { await library.load() }
    }
}

struct ReadingPaperView: View {
    @EnvironmentObject private var store: AppStore
    let number: Int
    let tests: [BankTest]

    @State private var pane = 0   // 0, 1, 2 = passages; 3 = questions
    @State private var answers: [Int: String] = [:]
    @State private var submitted = false
    @State private var confirm = false
    @State private var start = Date()

    private var groups: [[BankGroup]] {
        var next = 1
        return tests.map { test in
            let groups = ReadingPapers.renumbered(test, from: next)
            next += test.questionCount
            return groups
        }
    }
    private var questions: [Question] { groups.flatMap { $0.flatMap { BankConvert.questions($0) } } }
    private var correct: Int { Marking.score(questions, answers: answers) }
    private var answered: Int { questions.filter { !(answers[$0.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count }
    private var band: Double { BandMath.academicReadingBand(raw: correct) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if pane < 3 {
                        passage(tests[pane], index: pane)
                    } else {
                        if submitted {
                            ScoreSummary(correct: correct, total: questions.count, band: band, color: Skill.reading.color)
                        }
                        ForEach(Array(groups.enumerated()), id: \.offset) { index, passageGroups in
                            Text("Passage \(index + 1) · Questions \(passageRange(index))")
                                .font(.title3.weight(.bold)).padding(.top, 6).id("p\(index)")
                            ForEach(Array(passageGroups.enumerated()), id: \.offset) { _, group in
                                BankGroupView(group: group, answers: $answers, submitted: submitted)
                            }
                        }
                    }
                }
                .padding(16)
                .id(pane)
            }
            .dismissKeyboardOnScroll()
            .onChange(of: pane) { proxy.scrollTo(pane, anchor: .top) }
        }
        .screenBackground()
        .safeAreaInset(edge: .top) {
            Picker("Part", selection: $pane) {
                Text("Passage 1").tag(0)
                Text("2").tag(1)
                Text("3").tag(2)
                Text("Questions").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .safeAreaInset(edge: .bottom) {
            if !submitted {
                ActionBar {
                    Text("\(answered) of \(questions.count) answered").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    Spacer()
                    Button {
                        if answered < questions.count { confirm = true } else { submit() }
                    } label: {
                        Text("Submit Paper").font(.headline).padding(.horizontal, 6)
                    }
                    .primaryAction(Skill.reading.color)
                }
            }
        }
        .navigationTitle("Reading paper \(number)")
        .inlineTitle()
        .toolbar {
            if !submitted {
                ToolbarItem(placement: .primaryAction) { TimerLabel(start: start, minutes: 60) }
            }
        }
        .confirmationDialog("Submit with \(questions.count - answered) unanswered?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Submit") { submit() }
            Button("Keep Working", role: .cancel) {}
        } message: {
            Text("There is no penalty for wrong answers, so it is worth guessing.")
        }
        .sensoryFeedback(.success, trigger: submitted)
    }

    private func passageRange(_ index: Int) -> String {
        let numbers = groups[index].flatMap { $0.questions.map(\.n) }
        return "\(numbers.min() ?? 0)–\(numbers.max() ?? 0)"
    }

    private func passage(_ test: BankTest, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("READING PASSAGE \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(Skill.reading.color)
            Text("You should spend about 20 minutes on Questions \(passageRange(index)).").font(.footnote).foregroundStyle(.secondary)
            Text(test.title).font(.title2.weight(.bold))
            if !test.subtitle.isEmpty { Text(test.subtitle).font(.subheadline).italic().foregroundStyle(.secondary) }
            ForEach(test.paragraphs, id: \.label) { paragraph in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(paragraph.label).font(.subheadline.weight(.bold)).foregroundStyle(Skill.reading.color).frame(width: 18)
                    Text(paragraph.text).lineSpacing(5).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                withAnimation { pane = index < 2 ? index + 1 : 3 }
            } label: {
                Label(index < 2 ? "Next passage" : "Go to questions", systemImage: "arrow.right")
            }
            .buttonStyle(.bordered)
            .tint(Skill.reading.color)
        }
    }

    private func submit() {
        withAnimation {
            submitted = true
            pane = 3
        }
        store.record(Attempt(skill: .reading, title: "Reading paper \(number)", prompt: "Reading paper \(number)", response: "",
                             band: band, rawScore: correct, total: questions.count))
    }
}

// MARK: - Writing papers

enum WritingPapers {
    static var count: Int { min(Library.writing.task1.count, Library.writing.task2.count) }

    static func tasks(_ number: Int) -> (WritingTask, WritingTask) {
        let one = Library.writing.task1[(number - 1) % max(Library.writing.task1.count, 1)]
        let withSamples = Library.writing.task2.filter { $0.sample != nil }
        let pool = withSamples.isEmpty ? Library.writing.task2 : withSamples
        let two = pool[((number - 1) * 7) % max(pool.count, 1)]
        return (WritingTask(taskNumber: 1, prompt: one.prompt, chart: nil, image: one.image, sample: one.sample, sampleBand: one.band, visualKind: one.kind),
                WritingTask(taskNumber: 2, prompt: two.prompt, chart: nil, sample: two.sample, sampleBand: two.band))
    }
}

struct WritingPaperList: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List(1...max(WritingPapers.count, 1), id: \.self) { number in
            let (one, two) = WritingPapers.tasks(number)
            NavigationLink {
                WritingPaperView(number: number)
            } label: {
                HStack(spacing: 12) {
                    Text("\(number)").font(.headline.monospacedDigit()).foregroundStyle(Skill.writing.color)
                        .frame(width: 40, height: 40)
                        .background(Skill.writing.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Writing paper \(number) · \(one.visualKind ?? "Task 1")").font(.subheadline.weight(.semibold))
                        Text(two.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    if let band = WritingPaperView.band(store: store, number: number) {
                        BandPill(band: band, color: Skill.writing.color)
                    }
                }
            }
        }
        .groupedList()
        .navigationTitle("Writing papers")
        .inlineTitle()
    }
}

struct WritingPaperView: View {
    @EnvironmentObject private var store: AppStore
    let number: Int
    @State private var start = Date()

    /// Paper band from the latest marked attempt at each task (Task 2 counts double).
    @MainActor static func band(store: AppStore, number: Int) -> Double? {
        let (one, two) = WritingPapers.tasks(number)
        let first = store.lastAttempt(matching: one.prompt)?.band
        let second = store.lastAttempt(matching: two.prompt)?.band
        guard let first, let second else { return nil }
        return BandMath.writing(task1: first, task2: second)
    }

    var body: some View {
        let (one, two) = WritingPapers.tasks(number)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Academic Writing · 60 minutes").font(.headline)
                        Text("Spend about 20 minutes on Task 1 and 40 minutes on Task 2. Task 2 counts twice as much.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let band = Self.band(store: store, number: number) {
                        BandRing(band: band, color: Skill.writing.color, size: 70, lineWidth: 8, caption: "Paper")
                    }
                }
                .cardStyle()
                taskCard(one, minutes: 20)
                taskCard(two, minutes: 40)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Writing paper \(number)")
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) { TimerLabel(start: start, minutes: 60) }
        }
    }

    private func taskCard(_ task: WritingTask, minutes: Int) -> some View {
        NavigationLink {
            WritingEditor(task: task)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Tag(text: "Task \(task.taskNumber)", color: Skill.writing.color)
                    Tag(text: "\(minutes) min", symbol: "clock")
                    Spacer()
                    if let attempt = store.lastAttempt(matching: task.prompt) {
                        BandPill(band: attempt.band, color: Skill.writing.color)
                    } else {
                        Text("Start").font(.subheadline.weight(.semibold)).foregroundStyle(Skill.writing.color)
                    }
                }
                if let image = task.image { Task1Image(name: image).frame(maxWidth: .infinity, maxHeight: 200) }
                Text(task.prompt).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(6)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cambridge IELTS book companion

enum CambridgeBooks {
    static let numbers = Array((1...21).reversed())

    static func id(book: Int, test: Int, skill: Skill) -> String { "c\(book)-t\(test)-\(skill.rawValue)" }
    static func title(book: Int, test: Int, skill: Skill, task: Int? = nil) -> String {
        "Cambridge \(book) · Test \(test) · \(skill.title)" + (task.map { " Task \($0)" } ?? "")
    }

    static func color(_ book: Int) -> Color {
        [Color.red, .blue, .teal, .orange, .indigo, .green, .pink, .purple, .cyan, .brown][book % 10]
    }

    /// Bands for one test, from saved sheets and recorded attempts.
    @MainActor static func bands(store: AppStore, book: Int, test: Int) -> [Skill: Double] {
        var result: [Skill: Double] = [:]
        for skill in [Skill.listening, .reading] {
            if let sheet = store.sheet(id(book: book, test: test, skill: skill)), sheet.finished != nil {
                result[skill] = skill == .listening ? BandMath.listeningBand(raw: sheet.score) : BandMath.academicReadingBand(raw: sheet.score)
            }
        }
        let one = store.lastAttempt(matching: title(book: book, test: test, skill: .writing, task: 1))?.band
        let two = store.lastAttempt(matching: title(book: book, test: test, skill: .writing, task: 2))?.band
        if let one, let two { result[.writing] = BandMath.writing(task1: one, task2: two) } else if let any = two ?? one { result[.writing] = any }
        if let speaking = store.lastAttempt(matching: title(book: book, test: test, skill: .speaking))?.band { result[.speaking] = speaking }
        return result
    }
}

struct CambridgeShelf: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("How it works", systemImage: "info.circle.fill").font(.headline).foregroundStyle(.red)
                    step("1", "Open a test in your own Cambridge IELTS book and start the timer here.")
                    step("2", "Write your answers on the app's answer sheet.")
                    step("3", "Type the answers from the book's key once. The app marks this and every retake.")
                    step("4", "Tag your mistakes by question type to find what to practise.")
                }
                .cardStyle()

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(CambridgeBooks.numbers, id: \.self) { book in
                        NavigationLink {
                            BookView(book: book)
                        } label: {
                            BookCover(book: book, done: (1...4).filter { !CambridgeBooks.bands(store: store, book: book, test: $0).isEmpty }.count)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Cambridge IELTS books are published by Cambridge University Press & Assessment. This companion contains none of their content; use it with your own copy.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Cambridge IELTS")
        .inlineTitle()
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number).font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Color.red, in: Circle())
            Text(text).font(.subheadline)
        }
    }
}

struct BookCover: View {
    let book: Int
    let done: Int
    /// A small cover for headers: just the series name and number.
    var compact = false

    var body: some View {
        let color = CambridgeBooks.color(book)
        if compact {
            VStack(spacing: 0) {
                Text("IELTS").font(.system(size: 9, weight: .heavy))
                Text("\(book)").font(.system(size: 24, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 50, height: 66)
            .background(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
        } else {
            full(color)
        }
    }

    private func full(_ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CAMBRIDGE").font(.system(size: 9, weight: .heavy)).opacity(0.85)
            Text("IELTS").font(.system(size: 13, weight: .heavy))
            Spacer()
            Text("\(book)").font(.system(size: 38, weight: .heavy, design: .rounded))
            Text("Academic").font(.system(size: 10, weight: .semibold)).opacity(0.9)
            HStack(spacing: 3) {
                ForEach(1...4, id: \.self) { index in
                    Capsule().fill(index <= done ? Color.white : Color.white.opacity(0.3)).frame(height: 4)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: color.opacity(0.3), radius: 6, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cambridge IELTS \(book), \(done) of 4 tests started")
    }
}

struct BookView: View {
    @EnvironmentObject private var store: AppStore
    let book: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(1...4, id: \.self) { test in
                    testCard(test)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Cambridge IELTS \(book)")
        .inlineTitle()
    }

    private func testCard(_ test: Int) -> some View {
        let bands = CambridgeBooks.bands(store: store, book: book, test: test)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Test \(test)").font(.title3.weight(.bold))
                Spacer()
                if bands.count == 4 {
                    BandRing(band: BandMath.overall(Array(bands.values)), color: CambridgeBooks.color(book), size: 56, lineWidth: 6, caption: "Overall")
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                skillButton(.listening, test: test, band: bands[.listening]) { AnswerSheetView(book: book, test: test, skill: .listening) }
                skillButton(.reading, test: test, band: bands[.reading]) { AnswerSheetView(book: book, test: test, skill: .reading) }
                skillButton(.writing, test: test, band: bands[.writing]) { BookWritingSetup(book: book, test: test) }
                skillButton(.speaking, test: test, band: bands[.speaking]) { BookSpeakingSetup(book: book, test: test) }
            }
        }
        .cardStyle()
    }

    private func skillButton<Destination: View>(_ skill: Skill, test: Int, band: Double?, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 8) {
                SkillIcon(skill: skill, size: 28)
                Text(skill.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
                if let band {
                    Text(bandText(band)).font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(skill.color)
                } else {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .background(skill.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Answer sheet

struct AnswerSheetView: View {
    @EnvironmentObject private var store: AppStore
    let book: Int
    let test: Int
    let skill: Skill

    private enum Phase { case answering, marking, result }
    @State private var sheet = BookSheet()
    @State private var phase = Phase.answering
    @State private var start = Date()
    @State private var loaded = false
    @FocusState private var focus: Int?

    private var id: String { CambridgeBooks.id(book: book, test: test, skill: skill) }
    private var minutes: Int { skill == .listening ? 30 : 60 }
    private var band: Double { skill == .listening ? BandMath.listeningBand(raw: sheet.score) : BandMath.academicReadingBand(raw: sheet.score) }
    private var parts: [(String, Range<Int>)] {
        skill == .listening
            ? [("Part 1", 0..<10), ("Part 2", 10..<20), ("Part 3", 20..<30), ("Part 4", 30..<40)]
            : [("Passage 1", 0..<13), ("Passage 2", 13..<26), ("Passage 3", 26..<40)]
    }
    private var types: [String] { skill == .listening ? QuestionTypes.listening : QuestionTypes.reading }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                switch phase {
                case .answering: answering
                case .marking: marking
                case .result: result
                }
            }
            .padding(16)
        }
        .dismissKeyboardOnScroll()
        .screenBackground()
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Test \(test) · \(skill.title)")
        .inlineTitle()
        .toolbar {
            if phase == .answering {
                ToolbarItem(placement: .primaryAction) { TimerLabel(start: start, minutes: minutes) }
            }
        }
        .onAppear(perform: load)
        .onDisappear { store.saveSheet(id, sheet) }
        .sensoryFeedback(.success, trigger: phase == .result)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BookCover(book: book, done: 0, compact: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Cambridge IELTS \(book) · Test \(test)").font(.headline)
                Text(phaseHelp).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var phaseHelp: String {
        switch phase {
        case .answering:
            return skill == .listening
                ? "Play the recording from your book's audio. Type each answer as you hear it — 30 minutes."
                : "Read the passages in your book and answer here — 60 minutes, no extra time."
        case .marking:
            return "Type the answer from your book's key next to each question. Matches are marked automatically; tap a mark to change it."
        case .result:
            return "Your key is saved, so a retake is marked automatically."
        }
    }

    // MARK: Answering

    private var answering: some View {
        ForEach(parts, id: \.0) { title, range in
            VStack(alignment: .leading, spacing: 8) {
                Text("\(title) · Questions \(range.lowerBound + 1)–\(range.upperBound)").font(.headline)
                VStack(spacing: 0) {
                    ForEach(range, id: \.self) { index in
                        if index != range.lowerBound { Divider().padding(.leading, 52) }
                        HStack(spacing: 12) {
                            numberBadge(index, color: skill.color)
                            TextField("Answer", text: $sheet.answers[index])
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($focus, equals: index)
                                .submitLabel(index < 39 ? .next : .done)
                                .onSubmit { focus = index < 39 ? index + 1 : nil }
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
    }

    // MARK: Marking

    private var marking: some View {
        ForEach(parts, id: \.0) { title, range in
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                VStack(spacing: 0) {
                    ForEach(range, id: \.self) { index in
                        if index != range.lowerBound { Divider() }
                        markRow(index)
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
    }

    private func markRow(_ index: Int) -> some View {
        let state = sheet.isCorrect(index)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                numberBadge(index, color: state == true ? Theme.success : state == false ? Theme.failure : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sheet.answers[index].isEmpty ? "(blank)" : sheet.answers[index])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sheet.answers[index].isEmpty ? Color.secondary : Color.primary)
                    TextField("Answer from the book's key", text: $sheet.key[index])
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Button {
                    cycleMark(index)
                } label: {
                    Image(systemName: state == true ? "checkmark.circle.fill" : state == false ? "xmark.circle.fill" : "questionmark.circle")
                        .font(.title2)
                        .foregroundStyle(state == true ? Theme.success : state == false ? Theme.failure : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(state == true ? "Marked correct" : state == false ? "Marked wrong" : "Not marked")
                .accessibilityHint("Changes the mark")
            }
            if state == false {
                Menu {
                    ForEach(types, id: \.self) { type in
                        Button(type) { sheet.types[index] = type }
                    }
                } label: {
                    Label(sheet.types[index] ?? "Tag question type", systemImage: "tag")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(sheet.types[index] == nil ? Color.secondary : Theme.failure)
                }
                .padding(.leading, 40)
            }
        }
        .padding(.vertical, 10)
    }

    private func cycleMark(_ index: Int) {
        switch sheet.marks[index] {
        case nil: sheet.marks[index] = !(sheet.isCorrect(index) ?? false)
        case true?: sheet.marks[index] = false
        case false?: sheet.marks[index] = nil
        }
    }

    // MARK: Result

    private var result: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                BandRing(band: band, color: skill.color, size: 104, lineWidth: 11, caption: "Band")
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(sheet.score) of 40 correct").font(.title3.weight(.bold))
                    Text("Converted with the standard \(skill == .listening ? "Listening" : "Academic Reading") band table. Time: \(sheet.seconds / 60) min.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .cardStyle()

            let wrong = (0..<40).filter { sheet.isCorrect($0) == false }
            if !wrong.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mistakes").font(.headline)
                    ForEach(wrong, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)").font(.subheadline.weight(.bold)).monospacedDigit().frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sheet.answers[index].isEmpty ? "(blank)" : sheet.answers[index]).strikethrough().foregroundStyle(Theme.failure)
                                Text(sheet.key[index]).fontWeight(.semibold).foregroundStyle(Theme.success)
                                if let type = sheet.types[index] { Text(type).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: Bottom bar

    @ViewBuilder private var bottomBar: some View {
        switch phase {
        case .answering:
            ActionBar {
                Text("\(sheet.answered)/40 answered").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button {
                    focus = nil
                    sheet.seconds = Int(Date().timeIntervalSince(start))
                    store.saveSheet(id, sheet)
                    withAnimation { phase = .marking }
                } label: {
                    Text("Finish & Mark").font(.headline).padding(.horizontal, 6)
                }
                .primaryAction(skill.color)
            }
        case .marking:
            ActionBar {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sheet.score)/40 · band \(bandText(band))").font(.subheadline.weight(.semibold)).monospacedDigit()
                    Text("\(sheet.marked) of 40 marked").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    save()
                } label: {
                    Text("Save Result").font(.headline).padding(.horizontal, 6)
                }
                .primaryAction(skill.color)
                .disabled(sheet.marked < 40)
            }
        case .result:
            ActionBar {
                Button {
                    withAnimation { phase = .marking }
                } label: {
                    Text("Review Marking").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
                Button {
                    sheet.answers = Array(repeating: "", count: 40)
                    sheet.marks = Array(repeating: nil, count: 40)
                    sheet.finished = nil
                    start = Date()
                    withAnimation { phase = .answering }
                } label: {
                    Text("Retake").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(skill.color)
            }
        }
    }

    private func numberBadge(_ index: Int, color: Color) -> some View {
        Text("\(index + 1)")
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.12), in: Circle())
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let saved = store.sheet(id) {
            sheet = saved
            phase = saved.finished != nil ? .result : (saved.answered > 0 && saved.marked > 0 ? .marking : .answering)
        }
    }

    private func save() {
        sheet.finished = Date()
        sheet.attempts += 1
        store.saveSheet(id, sheet)
        let title = CambridgeBooks.title(book: book, test: test, skill: skill)
        store.record(Attempt(skill: skill, title: title, prompt: title, response: "", band: band, rawScore: sheet.score, total: 40))
        withAnimation { phase = .result }
    }
}

// MARK: - Book writing and speaking

struct BookWritingSetup: View {
    let book: Int
    let test: Int
    @State private var taskNumber = 2
    @State private var question = ""

    var body: some View {
        Form {
            Section {
                Picker("Task", selection: $taskNumber) {
                    Text("Task 1").tag(1)
                    Text("Task 2").tag(2)
                }
                .pickerStyle(.segmented)
                TextField("Type the question from the book", text: $question, axis: .vertical)
                    .lineLimit(4...10)
            } header: {
                Text("Cambridge IELTS \(book) · Test \(test)")
            } footer: {
                Text(taskNumber == 1
                     ? "Type the question; keep the book open to look at the visual while you write. The app cannot see the chart, so it cannot check your figures."
                     : "Type the question exactly as it appears, including every part you must answer.")
            }
            Section {
                NavigationLink {
                    WritingEditor(task: WritingTask(taskNumber: taskNumber, prompt: question.trimmingCharacters(in: .whitespacesAndNewlines), chart: nil),
                                  attemptTitle: CambridgeBooks.title(book: book, test: test, skill: .writing, task: taskNumber))
                } label: {
                    Label("Start Writing", systemImage: "pencil").font(.headline)
                }
                .disabled(question.split(separator: " ").count < 6)
            }
        }
        .navigationTitle("Writing")
        .inlineTitle()
    }
}

struct BookSpeakingSetup: View {
    let book: Int
    let test: Int
    @State private var part1 = ""
    @State private var topic = ""
    @State private var bullets = ""
    @State private var part3 = ""

    private func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section {
                TextField("Part 1 questions, one per line (optional)", text: $part1, axis: .vertical).lineLimit(3...8)
            } header: {
                Text("Part 1")
            }
            Section {
                TextField("Describe…", text: $topic, axis: .vertical).lineLimit(1...3)
                TextField("Bullet points, one per line", text: $bullets, axis: .vertical).lineLimit(3...6)
            } header: {
                Text("Part 2 cue card")
            }
            Section {
                TextField("Part 3 questions, one per line (optional)", text: $part3, axis: .vertical).lineLimit(3...8)
            } header: {
                Text("Part 3")
            } footer: {
                Text("If you leave Part 3 empty, the examiner asks related discussion questions from the app's bank.")
            }
            Section {
                NavigationLink {
                    let card = BankCueCard(topic: topic, bullets: lines(bullets), theme: nil)
                    SpeakingTestView(
                        script: SpeakingScript(part1: lines(part1), cueCard: CueCard(topic: topic, bullets: lines(bullets)),
                                               roundingOff: "", part3: lines(part3).isEmpty ? SpeakingContent.part3(for: card) : lines(part3)),
                        attemptTitle: CambridgeBooks.title(book: book, test: test, skill: .speaking))
                } label: {
                    Label("Start Speaking Test", systemImage: "mic.fill").font(.headline)
                }
                .disabled(topic.split(separator: " ").count < 2)
            }
        }
        .navigationTitle("Speaking")
        .inlineTitle()
    }
}
