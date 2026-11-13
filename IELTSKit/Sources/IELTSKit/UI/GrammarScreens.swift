import SwiftUI

extension GrammarChapter {
    var color: Color {
        let palette: [Color] = [.blue, .indigo, .teal, .orange, .pink, .purple, .green, .mint, .cyan, .red, .brown]
        return palette[(id - 1) % palette.count]
    }

    var questionCount: Int {
        exercises.reduce(0) { $0 + ($1.items?.count ?? $1.passage?.filter { $0.gap != nil }.count ?? 0) }
    }
}

// MARK: - Book

struct MentorsBookContent: View {
    @EnvironmentObject private var store: AppStore
    private let chapters = Library.grammar.chapters

    private var overall: Double {
        chapters.isEmpty ? 0 : chapters.map { store.chapterProgress($0) }.reduce(0, +) / Double(chapters.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    BandRingProgress(value: overall, color: .blue, size: 84, label: "done")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Foundation Grammar & Writing").font(.headline)
                        Text("\(chapters.count) chapters · \(chapters.reduce(0) { $0 + $1.sections.count }) lesson cards · \(chapters.reduce(0) { $0 + $1.questionCount }) practice questions")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("From the Mentors' grammar book").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .cardStyle()

                if let next = chapters.first(where: { store.chapterProgress($0) < 1 }) {
                    NavigationLink {
                        GrammarChapterView(chapter: next)
                    } label: {
                        RowLabel(title: "Continue: \(next.title)", subtitle: "Chapter \(next.id) · \(Int(store.chapterProgress(next) * 100))% complete",
                                 icon: IconTile(symbol: next.symbol, color: next.color, size: 44)) {
                            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(next.color)
                        }
                        .cardStyle(padding: 14)
                    }
                    .buttonStyle(.plain)
                }

                SectionHeader(title: "Chapters")
                LazyVStack(spacing: 10) {
                    ForEach(chapters) { chapter in
                        NavigationLink {
                            GrammarChapterView(chapter: chapter)
                        } label: {
                            ChapterRow(chapter: chapter, progress: store.chapterProgress(chapter))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
    }
}

/// Circular progress (0–1) with a percentage in the middle.
struct BandRingProgress: View {
    let value: Double
    var color: Color
    var size: CGFloat = 60
    var label: String?

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.16), lineWidth: size * 0.1)
            Circle().trim(from: 0, to: value)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let label {
                    Text(label).font(.system(size: size * 0.13)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(value * 100)) percent \(label ?? "")")
    }
}

struct ChapterRow: View {
    let chapter: GrammarChapter
    let progress: Double

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: chapter.symbol, color: chapter.color, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Chapter \(chapter.id)").font(.caption.weight(.semibold)).foregroundStyle(chapter.color)
                Text(chapter.title).font(.headline).foregroundStyle(.primary)
                Text("\(chapter.sections.count) lessons · \(chapter.exercises.count) exercises")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if progress >= 1 {
                Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Theme.success)
            } else {
                BandRingProgress(value: progress, color: chapter.color, size: 44)
            }
        }
        .cardStyle(padding: 14)
    }
}

// MARK: - Chapter

struct GrammarChapterView: View {
    @EnvironmentObject private var store: AppStore
    let chapter: GrammarChapter
    @State private var tab = 0

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        IconTile(symbol: chapter.symbol, color: chapter.color, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chapter \(chapter.id)").font(.subheadline.weight(.semibold)).foregroundStyle(chapter.color)
                            Text(chapter.title).font(.title2.weight(.bold))
                        }
                    }
                    if !chapter.summary.isEmpty {
                        Text(chapter.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                    }
                    Picker("Section", selection: $tab) {
                        Text("Learn").tag(0)
                        Text("Practise").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

            if tab == 0 {
                Section {
                    ForEach(Array(chapter.sections.enumerated()), id: \.offset) { index, section in
                        NavigationLink {
                            LessonReader(chapter: chapter, start: index)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: store.isDone("grammar:\(chapter.id):\(index)") ? "checkmark.circle.fill" : "\(min(index + 1, 50)).circle")
                                    .font(.title3)
                                    .foregroundStyle(store.isDone("grammar:\(chapter.id):\(index)") ? Theme.success : chapter.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(section.title).font(.body)
                                    Text(sectionSummary(section)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Lesson cards")
                } footer: {
                    Text("Swipe through the cards. Tap the speaker to hear any example sentence.")
                }
            } else {
                Section {
                    ForEach(chapter.exercises) { exercise in
                        NavigationLink {
                            GrammarExerciseView(chapter: chapter, exercise: exercise)
                        } label: {
                            ExerciseRow(exercise: exercise, color: chapter.color, score: store.learning.grammar[exercise.id])
                        }
                    }
                } header: {
                    Text("Exercises from the book")
                } footer: {
                    Text("Answers are checked against the book's answer key.")
                }
            }
        }
        .groupedList()
        .navigationTitle(chapter.title)
        .inlineTitle()
    }

    private func sectionSummary(_ section: GrammarSection) -> String {
        let examples = section.blocks.filter { $0.type == "examples" }.reduce(0) { $0 + ($1.items?.count ?? 0) }
        let formulas = section.blocks.filter { $0.type == "formula" }.count
        var parts: [String] = []
        if formulas > 0 { parts.append("\(formulas) structure\(formulas == 1 ? "" : "s")") }
        if examples > 0 { parts.append("\(examples) examples") }
        return parts.isEmpty ? "Explanation" : parts.joined(separator: " · ")
    }
}

struct ExerciseRow: View {
    let exercise: GrammarExercise
    let color: Color
    let score: ExerciseScore?

    private var detail: String {
        switch exercise.kind {
        case "items": return "\(exercise.items?.count ?? 0) questions · interactive"
        case "passage": return "\(exercise.passage?.filter { $0.gap != nil }.count ?? 0) gaps in a text"
        default: return "Self-check with the answer key"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(exercise.id)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: 44, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.instructions).font(.subheadline).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let score {
                Text("\(Int((score.fraction * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(score.fraction >= 0.8 ? Theme.success : Theme.warning)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((score.fraction >= 0.8 ? Theme.success : Theme.warning).opacity(0.14), in: Capsule())
            }
        }
    }
}

// MARK: - Lesson reader

struct LessonReader: View {
    @EnvironmentObject private var store: AppStore
    let chapter: GrammarChapter
    @State private var page: Int
    @StateObject private var speaker = Speaker()

    init(chapter: GrammarChapter, start: Int) {
        self.chapter = chapter
        _page = State(initialValue: start)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(chapter.sections.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? chapter.color : chapter.color.opacity(0.18))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            TabView(selection: $page) {
                ForEach(Array(chapter.sections.enumerated()), id: \.offset) { index, section in
                    ScrollView {
                        LessonCard(section: section, color: chapter.color, speaker: speaker)
                            .padding(16)
                    }
                    .tag(index)
                }
            }
            .pagedTabs()
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                Button {
                    withAnimation { page = max(0, page - 1) }
                } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(page == 0)
                Spacer()
                Text("\(page + 1) of \(chapter.sections.count)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                if page + 1 < chapter.sections.count {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Next").font(.headline).padding(.horizontal, 10)
                    }
                    .primaryAction(chapter.color)
                } else {
                    NavigationLink {
                        GrammarChapterPractice(chapter: chapter)
                    } label: {
                        Text("Practise").font(.headline).padding(.horizontal, 10)
                    }
                    .primaryAction(chapter.color)
                }
            }
        }
        .navigationTitle(chapter.title)
        .inlineTitle()
        .onAppear { markRead(page) }
        .onChange(of: page) { markRead(page) }
        .onDisappear { speaker.stop() }
    }

    private func markRead(_ index: Int) {
        store.markDone("grammar:\(chapter.id):\(index)", xp: 5)
    }
}

/// Exercise list reached from the end of the lesson cards.
struct GrammarChapterPractice: View {
    @EnvironmentObject private var store: AppStore
    let chapter: GrammarChapter

    var body: some View {
        List {
            Section {
                ForEach(chapter.exercises) { exercise in
                    NavigationLink {
                        GrammarExerciseView(chapter: chapter, exercise: exercise)
                    } label: {
                        ExerciseRow(exercise: exercise, color: chapter.color, score: store.learning.grammar[exercise.id])
                    }
                }
            } header: {
                Text("Exercises from the book")
            }
        }
        .groupedList()
        .navigationTitle("Practise")
        .inlineTitle()
    }
}

struct LessonCard: View {
    let section: GrammarSection
    let color: Color
    @ObservedObject var speaker: Speaker

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title).font(.title2.weight(.bold))
            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    @ViewBuilder private func blockView(_ block: GrammarBlock) -> some View {
        switch block.type {
        case "formula":
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "function").foregroundStyle(color)
                Text(formula(block.text ?? ""))
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case "rule":
            VStack(alignment: .leading, spacing: 4) {
                Text(block.label ?? "").font(.headline).foregroundStyle(color)
                if let text = block.text, !text.isEmpty {
                    Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
                }
            }
        case "examples":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(block.items ?? [], id: \.self) { example in
                    Button {
                        Task { await speaker.speak(example) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Capsule().fill(color).frame(width: 3)
                            Text(example).font(.body).italic().foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "speaker.wave.2").font(.footnote).foregroundStyle(color)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Plays the example aloud")
                }
            }
            .padding(12)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        default:
            Text(block.text ?? "").font(.body).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Colours the "+" joins in a sentence formula.
    private func formula(_ text: String) -> AttributedString {
        var result = AttributedString()
        let parts = text.components(separatedBy: " + ")
        for (index, part) in parts.enumerated() {
            if index > 0 {
                var plus = AttributedString("  +  ")
                plus.foregroundColor = color
                result += plus
            }
            result += AttributedString(part)
        }
        return result
    }
}

extension View {
    @ViewBuilder func pagedTabs() -> some View {
        #if os(iOS)
        self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self
        #endif
    }
}

// MARK: - Exercises

struct GrammarExerciseView: View {
    @EnvironmentObject private var store: AppStore
    let chapter: GrammarChapter
    let exercise: GrammarExercise

    var body: some View {
        if exercise.kind == "reveal" {
            RevealExercise(chapter: chapter, exercise: exercise)
        } else {
            QuizRunner(title: "Exercise \(exercise.id)", color: chapter.color, items: Self.items(for: exercise)) { correct, total in
                store.recordGrammar(exercise.id, correct: correct, total: total)
            }
        }
    }

    static func items(for exercise: GrammarExercise) -> [QuizItem] {
        if let items = exercise.items {
            return items.map { item in
                let explanation = item.full.map { "Full sentence: \($0)" }
                switch item.kind {
                case "choice":
                    return QuizItem(prompt: item.prompt, instruction: exercise.instructions,
                                    kind: .choice(options: item.options ?? [], answer: item.answers.first ?? ""), explanation: explanation)
                case "gap":
                    if let options = item.options, item.answers.count == 1 {
                        return QuizItem(prompt: item.prompt, instruction: exercise.instructions,
                                        kind: .choice(options: options, answer: item.answers[0]), explanation: explanation)
                    }
                    return QuizItem(prompt: item.prompt, instruction: exercise.instructions,
                                    kind: .typed(answers: item.answers, hints: item.hints ?? []), explanation: explanation)
                case "build":
                    return QuizItem(prompt: item.prompt, instruction: exercise.instructions + " Tap the words in order.",
                                    kind: .build(answer: item.answers.first ?? ""))
                case "capitalize":
                    return QuizItem(prompt: "Tap every word that needs a capital letter.", instruction: exercise.instructions,
                                    kind: .capitalize(words: item.words ?? [], targets: Set(item.targets ?? [])))
                case "punctuate":
                    return QuizItem(prompt: "Tap each word that should be followed by a comma.", instruction: exercise.instructions,
                                    kind: .punctuate(words: item.words ?? [], targets: Set(item.targets ?? [])))
                default:
                    return QuizItem(prompt: item.prompt, instruction: exercise.instructions,
                                    kind: .reveal(answer: item.answers.first ?? ""))
                }
            }
        }
        // A passage becomes one question per gap, shown with the words around it.
        let segments = exercise.passage ?? []
        return segments.indices.compactMap { index in
            let segment = segments[index]
            guard segment.gap != nil, let answers = segment.answers, let answer = answers.first else { return nil }
            let before = index > 0 ? (segments[index - 1].text ?? "") : ""
            let after = index + 1 < segments.count ? (segments[index + 1].text ?? "") : ""
            let prompt = (Self.tail(before) + " ________ " + Self.head(after)).trimmingCharacters(in: .whitespaces)
            if let options = segment.options {
                return QuizItem(prompt: prompt, instruction: exercise.instructions,
                                kind: .choice(options: options, answer: options.first { AnswerCheck.matches($0, answer) } ?? answer))
            }
            return QuizItem(prompt: prompt, instruction: exercise.instructions,
                            kind: .typed(answers: [answers.joined(separator: "/")], hints: [segment.hint]))
        }
    }

    /// The end of the sentence before a gap.
    private static func tail(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let range = trimmed.range(of: #"[.!?]\s+(?=[A-Z"'])"#, options: [.regularExpression, .backwards]) else {
            return String(trimmed.suffix(140))
        }
        return String(trimmed[range.upperBound...].suffix(140))
    }

    /// The start of the text after a gap, up to the end of the sentence.
    private static func head(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let range = trimmed.range(of: #"[.!?](\s|$)"#, options: .regularExpression) else {
            return String(trimmed.prefix(140))
        }
        return String(trimmed[..<range.upperBound].prefix(160)).trimmingCharacters(in: .whitespaces)
    }
}

/// Exercises the app cannot mark automatically: read, answer, then compare with the book's key.
struct RevealExercise: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let chapter: GrammarChapter
    let exercise: GrammarExercise
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.instructions).font(.headline)
                Text(exercise.text ?? "").font(.body).fixedSize(horizontal: false, vertical: true).cardStyle()
                if revealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Answer key", systemImage: "key.fill").font(.headline).foregroundStyle(chapter.color)
                        Text(exercise.key ?? "The book gives no answer for this exercise.")
                            .font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                    .cardStyle()
                    .transition(.opacity)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                if revealed {
                    Button("Need More Practice") { finish(0.4) }
                        .buttonStyle(.bordered).controlSize(.large).tint(Theme.warning)
                    Spacer()
                    Button("Mostly Right") { finish(0.9) }
                        .primaryAction(Theme.success)
                } else {
                    Button {
                        withAnimation { revealed = true }
                    } label: {
                        Text("Show Answer Key").font(.headline).frame(maxWidth: .infinity)
                    }
                    .primaryAction(chapter.color)
                }
            }
        }
        .navigationTitle("Exercise \(exercise.id)")
        .inlineTitle()
    }

    private func finish(_ fraction: Double) {
        store.recordGrammar(exercise.id, correct: Int(fraction * 10), total: 10)
        dismiss()
    }
}
