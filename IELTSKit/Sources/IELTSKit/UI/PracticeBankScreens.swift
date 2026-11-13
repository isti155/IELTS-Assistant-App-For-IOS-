import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Reading hub

struct ReadingHub: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var library = ReadingLibrary.shared
    @State private var query = ""
    @State private var filter = 0

    private var shown: [BankTest] {
        let tests = library.tests ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return tests.filter { test in
            (trimmed.isEmpty || test.title.lowercased().contains(trimmed) || test.area.lowercased().contains(trimmed) || test.topic.lowercased().contains(trimmed))
                && (filter == 0 || (filter == 1 && store.lastAttempt(matching: test.title) == nil) || (filter == 2 && test.hard))
        }
    }

    var body: some View {
        List {
            Section {
                SkillHeader(skill: .reading)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section("Quick start") {
                if let tests = library.tests, let pick = tests.filter({ store.lastAttempt(matching: $0.title) == nil }).randomElement() ?? tests.randomElement() {
                    NavigationLink {
                        BankTestView(test: pick)
                    } label: {
                        RowLabel(title: "Random test", subtitle: "13–14 questions · 20 minutes",
                                 icon: IconTile(symbol: "shuffle", color: Skill.reading.color))
                    }
                }
                ForEach(SeedContent.readings) { test in
                    NavigationLink {
                        ReadingTestView(test: test)
                    } label: {
                        RowLabel(title: test.title, subtitle: "\(test.questions.count) questions · starter passage",
                                 icon: IconTile(symbol: "doc.text.fill", color: Skill.reading.color)) {
                            if let attempt = store.lastAttempt(matching: test.title) { BandPill(band: attempt.band, color: Skill.reading.color) }
                        }
                    }
                }
            }

            Section {
                Picker("Show", selection: $filter) {
                    Text("All").tag(0)
                    Text("Not done").tag(1)
                    Text("Hard").tag(2)
                }
                .pickerStyle(.segmented)
                if library.tests == nil {
                    HStack { ProgressView(); Text("Loading tests…").foregroundStyle(.secondary) }
                }
                ForEach(shown.prefix(300)) { test in
                    NavigationLink {
                        BankTestView(test: test)
                    } label: {
                        BankTestRow(test: test, band: store.lastAttempt(matching: test.title)?.band)
                    }
                }
                if shown.count > 300 {
                    Text("Showing 300 of \(shown.count). Search by topic to find more.").font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("\((library.tests?.count ?? 0).formatted()) practice tests")
            } footer: {
                Text("IELTS-style Passage 3 tests (synthetic, MIT licence; not official IELTS material). Each answer comes with the evidence from the text and an explanation.")
            }
        }
        .groupedList()
        .searchable(text: $query, prompt: "Topic, e.g. sleep, climate, language")
        .navigationTitle("Reading")
        .task { await library.load() }
    }
}

struct BankTestRow: View {
    let test: BankTest
    let band: Double?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(test.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(test.area.capitalized(with: nil)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Tag(text: "\(test.questionCount) Qs")
                    if test.hard { Tag(text: "Hard", color: .red) }
                }
            }
            Spacer(minLength: 6)
            if let band { BandPill(band: band, color: Skill.reading.color) }
        }
    }
}

// MARK: - A reading bank test

struct BankTestView: View {
    @EnvironmentObject private var store: AppStore
    let test: BankTest

    private enum Pane: String, CaseIterable { case passage = "Passage", questions = "Questions" }
    @State private var pane = Pane.passage
    @State private var answers: [Int: String] = [:]
    @State private var submitted = false
    @State private var confirm = false
    @State private var start = Date()

    private var questions: [Question] { test.groups.flatMap { BankConvert.questions($0) } }
    private var correct: Int { Marking.score(questions, answers: answers) }
    private var answered: Int { questions.filter { !(answers[$0.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count }
    private var band: Double { BandMath.academicReadingBand(raw: BandMath.scaledRaw(correct: correct, total: questions.count)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if pane == .passage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(test.title).font(.title2.weight(.bold))
                        if !test.subtitle.isEmpty { Text(test.subtitle).font(.subheadline).italic().foregroundStyle(.secondary) }
                    }
                    ForEach(test.paragraphs, id: \.label) { paragraph in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(paragraph.label).font(.subheadline.weight(.bold)).foregroundStyle(Skill.reading.color).frame(width: 18)
                            Text(paragraph.text).lineSpacing(5).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    if submitted {
                        ScoreSummary(correct: correct, total: questions.count, band: band, color: Skill.reading.color)
                    }
                    ForEach(Array(test.groups.enumerated()), id: \.offset) { _, group in
                        BankGroupView(group: group, answers: $answers, submitted: submitted)
                    }
                    if submitted && !test.paraphrases.isEmpty { paraphraseCard }
                }
            }
            .padding(16)
        }
        .dismissKeyboardOnScroll()
        .screenBackground()
        .safeAreaInset(edge: .top) {
            Picker("View", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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
                        Text("Submit").font(.headline).padding(.horizontal, 8)
                    }
                    .primaryAction(Skill.reading.color)
                }
            }
        }
        .navigationTitle("Reading")
        .inlineTitle()
        .toolbar {
            if !submitted {
                ToolbarItem(placement: .primaryAction) { TimerLabel(start: start, minutes: 20) }
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

    private var paraphraseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How the questions paraphrased the passage", systemImage: "arrow.left.arrow.right").font(.headline)
            ForEach(test.paraphrases, id: \.self) { pair in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Passage: “\(pair.passage)”").font(.subheadline)
                    Text("Question: “\(pair.question)”").font(.subheadline).foregroundStyle(Skill.reading.color)
                }
            }
            Text("Learning these pairs is the fastest way to improve at Reading.").font(.caption).foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func submit() {
        withAnimation {
            submitted = true
            pane = .questions
        }
        store.record(Attempt(skill: .reading, title: test.title, prompt: test.title, response: "",
                             band: band, rawScore: correct, total: questions.count, estimated: true))
        store.markDone("reading:\(test.id)")
    }
}

/// One question group: its instructions, the option box or summary, then the questions.
struct BankGroupView: View {
    let group: BankGroup
    @Binding var answers: [Int: String]
    let submitted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.instructions).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            if !group.options.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.options, id: \.label) { option in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(option.label).font(.subheadline.weight(.bold)).foregroundStyle(Skill.reading.color).frame(width: 20)
                            Text(option.text).font(.subheadline)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Skill.reading.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let summary = group.summary, !summary.isEmpty {
                Text(BankConvert.gapped(summary))
                    .font(.callout)
                    .lineSpacing(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            ForEach(BankConvert.questions(group)) { question in
                QuestionCard(question: question, answer: binding(question.id), submitted: submitted, color: Skill.reading.color)
            }
        }
    }

    private func binding(_ id: Int) -> Binding<String> {
        Binding(get: { answers[id] ?? "" }, set: { answers[id] = $0 })
    }
}

enum BankConvert {
    /// "[37]" gap markers become blanks.
    static func gapped(_ text: String) -> String {
        text.replacingOccurrences(of: #"\[(\d+)\]"#, with: "($1) ______", options: .regularExpression)
    }

    static func explanation(_ q: BankQuestion) -> String {
        var parts: [String] = []
        if let x = q.x { parts.append(x) }
        if let ev = q.ev { parts.append("Evidence\(q.p.map { " (paragraph \($0))" } ?? ""): “\(ev)”") }
        if let dn = q.dn { parts.append(dn) }
        return parts.joined(separator: "\n")
    }

    static func questions(_ group: BankGroup) -> [Question] {
        group.questions.map { q in
            let prompt = gapped(q.q)
            switch group.type {
            case "true_false_not_given":
                return Question(id: q.n, kind: "true_false_not_given", prompt: prompt, options: ["TRUE", "FALSE", "NOT GIVEN"],
                                answer: q.a, accepted: [], explanation: explanation(q))
            case "yes_no_not_given":
                return Question(id: q.n, kind: "true_false_not_given", prompt: prompt, options: ["YES", "NO", "NOT GIVEN"],
                                answer: q.a, accepted: [], explanation: explanation(q))
            case "multiple_choice":
                let options = q.options.map { "\($0.label)  \($0.text)" }
                let answer = q.options.first { $0.label == q.a }.map { "\($0.label)  \($0.text)" } ?? q.a
                return Question(id: q.n, kind: "multiple_choice", prompt: prompt, options: options,
                                answer: answer, accepted: [], explanation: explanation(q))
            default:
                if !group.options.isEmpty {
                    return Question(id: q.n, kind: "matching", prompt: prompt, options: group.options.map(\.label),
                                    answer: q.a, accepted: [], explanation: explanation(q))
                }
                return Question(id: q.n, kind: "completion", prompt: prompt, options: [],
                                answer: q.a, accepted: q.a.contains("/") ? q.a.components(separatedBy: "/") : [], explanation: explanation(q))
            }
        }
    }

    /// A lecture for Listening practice: the passage read aloud with its completion and multiple-choice questions.
    static func lecture(_ test: BankTest) -> ListeningTest? {
        var questions: [Question] = []
        for group in test.groups where ["sentence_completion", "summary_completion", "multiple_choice"].contains(group.type) {
            for q in group.questions {
                let number = questions.count + 1
                if group.type == "multiple_choice" {
                    let answer = q.options.first { $0.label == q.a }?.text ?? q.a
                    questions.append(Question(id: number, kind: "multiple_choice", prompt: gapped(q.q), options: q.options.map(\.text),
                                              answer: answer, accepted: [], explanation: q.x ?? ""))
                } else if !group.options.isEmpty, let text = group.options.first(where: { $0.label == q.a })?.text {
                    questions.append(Question(id: number, kind: "multiple_choice", prompt: gapped(q.q),
                                              options: group.options.map(\.text), answer: text, accepted: [], explanation: q.x ?? ""))
                } else {
                    questions.append(Question(id: number, kind: "completion", prompt: gapped(q.q), options: [],
                                              answer: q.a, accepted: [], explanation: q.x ?? ""))
                }
            }
        }
        guard questions.count >= 5 else { return nil }
        return ListeningTest(
            title: test.title,
            context: "You will hear a lecture about \(test.topic). Answer the questions as you listen.",
            segments: test.paragraphs.map { ListeningSegment(speaker: "Lecturer", text: $0.text) },
            questions: Array(questions.prefix(10))
        )
    }
}

// MARK: - Listening hub

struct ListeningHub: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var library = ReadingLibrary.shared
    @State private var query = ""

    private var lectures: [(BankTest, ListeningTest)] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return (library.tests ?? []).lazy
            .filter { trimmed.isEmpty || $0.title.lowercased().contains(trimmed) || $0.area.lowercased().contains(trimmed) }
            .prefix(250)
            .compactMap { test in BankConvert.lecture(test).map { (test, $0) } }
    }

    var body: some View {
        List {
            Section {
                SkillHeader(skill: .listening)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                ForEach(SeedContent.listenings) { test in
                    NavigationLink {
                        ListeningTestView(test: test)
                    } label: {
                        RowLabel(title: test.title, subtitle: "\(test.questions.count) questions · everyday conversation",
                                 icon: IconTile(symbol: "person.2.wave.2.fill", color: Skill.listening.color)) {
                            if let attempt = store.lastAttempt(matching: test.title) { BandPill(band: attempt.band, color: Skill.listening.color) }
                        }
                    }
                }
            } header: {
                Text("Sections 1–2 · conversations and talks")
            }

            Section {
                if library.tests == nil {
                    HStack { ProgressView(); Text("Loading lectures…").foregroundStyle(.secondary) }
                }
                ForEach(lectures, id: \.0.id) { pair in
                    NavigationLink {
                        ListeningTestView(test: pair.1)
                    } label: {
                        RowLabel(title: pair.1.title, subtitle: "\(pair.1.questions.count) questions · \(pair.0.area)",
                                 icon: IconTile(symbol: "building.columns.fill", color: Skill.listening.color)) {
                            if let attempt = store.lastAttempt(matching: pair.1.title) { BandPill(band: attempt.band, color: Skill.listening.color) }
                        }
                    }
                }
            } header: {
                Text("Section 4 · academic lectures")
            } footer: {
                Text("Lectures are built from the reading-bank passages and read by the iPhone's voice, about 6 minutes each. For more natural voices, download Enhanced English voices in Settings › Accessibility › Spoken Content › Voices.")
            }
        }
        .groupedList()
        .searchable(text: $query, prompt: "Lecture topic")
        .navigationTitle("Listening")
        .task { await library.load() }
    }
}

// MARK: - Writing hub

struct WritingHub: View {
    @EnvironmentObject private var store: AppStore

    private var task1Kinds: [(String, [Task1Item])] {
        Dictionary(grouping: Library.writing.task1, by: \.kind).sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            Section {
                SkillHeader(skill: .writing)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                ForEach(task1Kinds, id: \.0) { kind, items in
                    NavigationLink {
                        Task1List(kind: kind, items: items)
                    } label: {
                        RowLabel(title: kind, subtitle: "\(items.count) questions with band 8+ sample answers",
                                 icon: IconTile(symbol: task1Symbol(kind), color: Skill.writing.color))
                    }
                }
                ForEach(SeedContent.allTask1) { task in
                    NavigationLink {
                        WritingEditor(task: task)
                    } label: {
                        RowLabel(title: firstLine(task.prompt), subtitle: "Interactive chart",
                                 icon: IconTile(symbol: task1Symbol(task.chart?.kind ?? ""), color: Skill.writing.color)) {
                            if let attempt = store.lastAttempt(matching: task.prompt) { BandPill(band: attempt.band, color: Skill.writing.color) }
                        }
                    }
                }
            } header: {
                Text("Task 1 · Describe a visual")
            } footer: {
                Text("20 minutes, at least 150 words.")
            }

            Section {
                NavigationLink {
                    WritingEditor(task: nil)
                } label: {
                    RowLabel(title: "Random question", subtitle: "From \(Library.writing.task2.count) questions",
                             icon: IconTile(symbol: "shuffle", color: Skill.writing.color))
                }
                NavigationLink {
                    Task2List()
                } label: {
                    RowLabel(title: "Browse all questions", subtitle: "\(Library.writing.task2.filter { $0.sample != nil }.count) with a band 7+ sample essay",
                             icon: IconTile(symbol: "list.bullet.rectangle.fill", color: Skill.writing.color))
                }
            } header: {
                Text("Task 2 · Essay")
            } footer: {
                Text("40 minutes, at least 250 words. Task 2 counts twice as much as Task 1.")
            }
        }
        .groupedList()
        .navigationTitle("Writing")
    }

    private func firstLine(_ text: String) -> String {
        (text.components(separatedBy: "\n").first ?? text).trimmingCharacters(in: .whitespaces)
    }

    func task1Symbol(_ kind: String) -> String {
        let lower = kind.lowercased()
        if lower.contains("line") { return "chart.xyaxis.line" }
        if lower.contains("pie") { return "chart.pie.fill" }
        if lower.contains("table") { return "tablecells" }
        if lower.contains("map") { return "map.fill" }
        if lower.contains("process") { return "arrow.triangle.2.circlepath" }
        if lower.contains("multiple") { return "square.grid.2x2.fill" }
        return "chart.bar.fill"
    }
}

/// A bundled Task 1 image.
struct Task1Image: View {
    let name: String

    var body: some View {
        if let url = Library.task1Image(name), let image = PlatformImage.load(url) {
            image.resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Label("Image unavailable", systemImage: "photo").foregroundStyle(.secondary)
        }
    }
}

enum PlatformImage {
    static func load(_ url: URL) -> Image? {
        #if canImport(UIKit)
        return UIImage(contentsOfFile: url.path).map(Image.init(uiImage:))
        #elseif canImport(AppKit)
        return NSImage(contentsOf: url).map(Image.init(nsImage:))
        #else
        return nil
        #endif
    }
}

struct Task1List: View {
    @EnvironmentObject private var store: AppStore
    let kind: String
    let items: [Task1Item]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items, id: \.image) { item in
                    NavigationLink {
                        WritingEditor(task: WritingTask(taskNumber: 1, prompt: item.prompt, chart: nil, image: item.image,
                                                        sample: item.sample, sampleBand: item.band, visualKind: item.kind))
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Task1Image(name: item.image).frame(maxWidth: .infinity, maxHeight: 180)
                            Text(item.prompt).font(.subheadline).foregroundStyle(.primary).lineLimit(3).multilineTextAlignment(.leading)
                            if let attempt = store.lastAttempt(matching: item.prompt) {
                                BandPill(band: attempt.band, color: Skill.writing.color)
                            }
                        }
                        .cardStyle(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(kind)
        .inlineTitle()
    }
}

struct Task2List: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""

    private var shown: [Task2Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.isEmpty ? Library.writing.task2 : Library.writing.task2.filter { $0.prompt.lowercased().contains(trimmed) }
    }

    var body: some View {
        List(shown, id: \.prompt) { item in
            NavigationLink {
                WritingEditor(task: WritingTask(taskNumber: 2, prompt: item.prompt, chart: nil, sample: item.sample, sampleBand: item.band))
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.prompt).font(.subheadline).lineLimit(3)
                    HStack(spacing: 6) {
                        if let band = item.band { Tag(text: "Band \(bandText(band)) sample", symbol: "doc.text", color: .green) }
                        if let attempt = store.lastAttempt(matching: item.prompt) { BandPill(band: attempt.band, color: Skill.writing.color) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .groupedList()
        .searchable(text: $query, prompt: "Topic, e.g. technology, education")
        .navigationTitle("Task 2 questions")
        .inlineTitle()
    }
}

// MARK: - Speaking hub

struct SpeakingHub: View {
    var body: some View {
        List {
            Section {
                SkillHeader(skill: .speaking)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                NavigationLink {
                    SpeakingTestView(script: nil)
                } label: {
                    RowLabel(title: "Full mock test", subtitle: "All three parts with new questions each time",
                             icon: IconTile(symbol: "person.wave.2.fill", color: Skill.speaking.color))
                }
                NavigationLink {
                    PartnerView()
                } label: {
                    RowLabel(title: "Conversation practice", subtitle: "Talk freely, get corrections and a band estimate",
                             icon: IconTile(symbol: "bubble.left.and.bubble.right.fill", color: Skill.speaking.color))
                }
            } header: {
                Text("Practise speaking")
            } footer: {
                Text("About 12 minutes. The examiner reads the questions aloud and moves on when time is up, as in the real test.")
            }

            Section("Practise one part") {
                NavigationLink {
                    CueCardList()
                } label: {
                    RowLabel(title: "Part 2 cue cards", subtitle: "\(Library.speaking.cueCards.count) topics · 1 minute to prepare, 2 to speak",
                             icon: IconTile(symbol: "rectangle.and.pencil.and.ellipsis", color: .orange))
                }
                NavigationLink {
                    Part1TopicList()
                } label: {
                    RowLabel(title: "Part 1 topics", subtitle: "\(Library.speaking.part1.count) topics · short questions about you",
                             icon: IconTile(symbol: "person.fill.questionmark", color: .teal))
                }
            }

            Section {
                NavigationLink {
                    SampleList()
                } label: {
                    RowLabel(title: "Real test transcripts", subtitle: "\(Library.speaking.samples.count) recorded tests from band 3.5 to 9",
                             icon: IconTile(symbol: "text.bubble.fill", color: .indigo))
                }
            } header: {
                Text("Learn from others")
            } footer: {
                Text("Read how candidates at your target band answer, and notice what changes between bands.")
            }
        }
        .groupedList()
        .navigationTitle("Speaking")
    }
}

struct CueCardList: View {
    @State private var query = ""

    private var shown: [BankCueCard] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.isEmpty ? Library.speaking.cueCards : Library.speaking.cueCards.filter { $0.topic.lowercased().contains(trimmed) }
    }

    var body: some View {
        List(shown) { card in
            NavigationLink {
                SpeakingTestView(script: SpeakingScript(part1: [], cueCard: CueCard(topic: card.topic, bullets: card.bullets),
                                                        roundingOff: "", part3: SpeakingContent.part3(for: card)))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.topic).font(.subheadline.weight(.semibold))
                    Text(card.bullets.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .padding(.vertical, 2)
            }
        }
        .groupedList()
        .searchable(text: $query, prompt: "Describe a…")
        .navigationTitle("Part 2 cue cards")
        .inlineTitle()
    }
}

struct Part1TopicList: View {
    var body: some View {
        List(Library.speaking.part1, id: \.topic) { topic in
            NavigationLink {
                SpeakingTestView(script: SpeakingScript(part1: Array(topic.questions.prefix(6)), cueCard: CueCard(topic: "", bullets: []),
                                                        roundingOff: "", part3: []))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.topic).font(.subheadline.weight(.semibold))
                    Text(topic.questions.first ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .groupedList()
        .navigationTitle("Part 1 topics")
        .inlineTitle()
    }
}

struct SampleList: View {
    private var groups: [(Double, [SpeakingSample])] {
        Dictionary(grouping: Library.speaking.samples, by: \.band).sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.0) { band, samples in
                Section("Band \(bandText(band))") {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                        NavigationLink {
                            SampleTranscript(sample: sample)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Test \(index + 1) · \(sample.turns.count) turns").font(.subheadline.weight(.semibold))
                                Text(sample.turns.first { $0.who == "Candidate" && $0.text.count > 40 }?.text ?? "")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .groupedList()
        .navigationTitle("Transcripts")
        .inlineTitle()
    }
}

struct SampleTranscript: View {
    let sample: SpeakingSample
    @StateObject private var speaker = Speaker()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BandRing(band: sample.band, color: Skill.speaking.color, size: 64, lineWidth: 7, caption: "Band")
                    Text("A transcript of a recorded speaking test, with the band it was given. Tap a candidate answer to hear it.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .cardStyle()
                ForEach(Array(sample.turns.enumerated()), id: \.offset) { _, turn in
                    if turn.who == "Candidate" {
                        Button {
                            Task { await speaker.speak(turn.text) }
                        } label: {
                            ChatBubble(text: turn.text, isUser: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ChatBubble(text: turn.text, isUser: false)
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Band \(bandText(sample.band))")
        .inlineTitle()
        .onDisappear { speaker.stop() }
    }
}
