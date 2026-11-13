import SwiftUI

enum WordPools {
    static let all = Library.vocabulary
    /// Words a learner already meets at A1–B1 in some other use (e.g. "far" as an adverb).
    static let basic: Set<String> = Set(all.filter { ["A1", "A2", "B1"].contains($0.l) }.map { $0.w.lowercased() })
    /// Upper-intermediate and advanced words that appear often in the IELTS-style reading passages.
    static let academic: [VocabWord] = all.filter { ["B2", "C1", "C2"].contains($0.l) && ($0.n ?? 0) >= 12 && !isBasicForm($0.w) }
        .sorted { ($0.n ?? 0) > ($1.n ?? 0) }

    /// True for a basic word or an inflected form of one ("known", "means", "growing").
    static func isBasicForm(_ word: String) -> Bool {
        let lower = word.lowercased()
        if basic.contains(lower) { return true }
        let irregular: Set<String> = ["found", "will", "though", "bound", "felt", "held", "led", "left", "lay", "saw", "rose", "spoke", "stood", "lain", "worn", "drawn"]
        if irregular.contains(lower) { return true }
        for suffix in ["ing", "ed", "es", "s", "er", "est", "n", "d"] where lower.hasSuffix(suffix) && lower.count > suffix.count + 2 {
            let stem = String(lower.dropLast(suffix.count))
            if basic.contains(stem) || basic.contains(stem + "e") { return true }
            if let last = stem.last, stem.dropLast().last == last, basic.contains(String(stem.dropLast())) { return true }
            if stem.hasSuffix("i"), basic.contains(String(stem.dropLast()) + "y") { return true }
        }
        return false
    }
    static let book: [VocabWord] = all.filter { $0.b == 1 }
    static let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
    static let topics: [(name: String, count: Int)] = Dictionary(grouping: all, by: \.topic)
        .map { ($0.key, $0.value.count) }.filter { $0.name != "General" }.sorted { $0.count > $1.count }

    static func level(_ level: String) -> [VocabWord] { all.filter { $0.l == level } }
    static func topic(_ topic: String) -> [VocabWord] {
        all.filter { $0.topic == topic }.sorted { (levels.firstIndex(of: $0.l) ?? 0, $0.w) < (levels.firstIndex(of: $1.l) ?? 0, $1.w) }
    }

    static func levelName(_ level: String) -> String {
        switch level {
        case "A1": return "Beginner"
        case "A2": return "Elementary"
        case "B1": return "Intermediate"
        case "B2": return "Upper-intermediate"
        case "C1": return "Advanced"
        default: return "Proficient"
        }
    }

    static func levelColor(_ level: String) -> Color {
        switch level {
        case "A1": return .green
        case "A2": return .mint
        case "B1": return .teal
        case "B2": return .blue
        case "C1": return .indigo
        default: return .purple
        }
    }

    static var wordOfTheDay: VocabWord? {
        guard !academic.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return academic[day % academic.count]
    }
}

// MARK: - Home

struct VocabularyHome: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var speaker = Speaker()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                if let word = WordPools.wordOfTheDay { wordOfTheDay(word) }

                SectionHeader(title: "Word sets")
                VStack(spacing: 10) {
                    setLink("IELTS academic words", "Most frequent B2–C2 words in IELTS-style reading", WordPools.academic, "graduationcap.fill", .purple)
                    setLink("Grammar book wordlist", "Words from the Mentors' Foundation Grammar & Writing book", WordPools.book, "text.book.closed.fill", .blue)
                    NavigationLink {
                        WordSearch()
                    } label: {
                        RowLabel(title: "All \(WordPools.all.count.formatted()) words", subtitle: "Search the whole dictionary",
                                 icon: IconTile(symbol: "magnifyingglass", color: .gray, size: 40)) {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .cardStyle(padding: 14)
                    }
                    .buttonStyle(.plain)
                }

                SectionHeader(title: "By level", subtitle: "CEFR levels; IELTS band 6–7 needs B2 and C1 words")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(WordPools.levels, id: \.self) { level in
                        let words = WordPools.level(level)
                        NavigationLink {
                            WordSetView(title: "\(level) · \(WordPools.levelName(level))", words: words, color: WordPools.levelColor(level))
                        } label: {
                            LevelTile(level: level, total: words.count,
                                      learned: words.filter { store.card($0)?.learned == true }.count)
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionHeader(title: "By topic")
                VStack(spacing: 0) {
                    ForEach(Array(WordPools.topics.enumerated()), id: \.element.name) { index, topic in
                        if index > 0 { Divider().padding(.leading, 54) }
                        NavigationLink {
                            WordSetView(title: topic.name, words: WordPools.topic(topic.name), color: topicColor(index))
                        } label: {
                            RowLabel(title: topic.name, subtitle: "\(topic.count) words",
                                     icon: IconTile(symbol: topicSymbol(topic.name), color: topicColor(index), size: 34)) {
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                Text("Word data: English CEFR Wordlist (CEFR-J and Octanove), Princeton WordNet, CMU Pronouncing Dictionary. Example sentences come from IELTS-style reading passages.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Vocabulary")
        .onDisappear { speaker.stop() }
    }

    private var summary: some View {
        let due = store.dueWords
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                stat("\(store.learnedWordCount)", "learned", .purple)
                Divider().frame(height: 36)
                stat("\(due.count)", "due now", due.isEmpty ? .secondary : .orange)
                Divider().frame(height: 36)
                stat("\(store.reviewsToday)", "reviewed today", .teal)
            }
            HStack(spacing: 10) {
                NavigationLink {
                    VocabQuizSession(title: "Review", words: Array(due.prefix(20)), color: .orange)
                } label: {
                    Label(due.isEmpty ? "Nothing due" : "Review \(min(due.count, 20))", systemImage: "arrow.clockwise")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(.orange)
                .disabled(due.isEmpty)
                NavigationLink {
                    FlashcardDeck(title: "New words", words: store.newWords(in: WordPools.academic, count: 10), color: .purple, learning: true)
                } label: {
                    Label("Learn 10 new", systemImage: "plus").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(.purple)
            }
        }
        .cardStyle()
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit().foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func wordOfTheDay(_ word: VocabWord) -> some View {
        NavigationLink {
            WordDetail(word: word)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Word of the day", systemImage: "sun.max.fill").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    Spacer()
                    Tag(text: word.l, color: WordPools.levelColor(word.l))
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word.w).font(.title.weight(.bold)).foregroundStyle(.primary)
                    if let ipa = word.i { Text(ipa).font(.subheadline).foregroundStyle(.secondary) }
                    Spacer()
                    Button {
                        Task { await speaker.speak(word.w) }
                    } label: {
                        Image(systemName: "speaker.wave.2.fill").foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pronounce \(word.w)")
                }
                Text("\(word.p) · \(word.d)").font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                if let example = word.examples.last {
                    Text("“\(example)”").font(.footnote).italic().foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func setLink(_ title: String, _ subtitle: String, _ words: [VocabWord], _ symbol: String, _ color: Color) -> some View {
        NavigationLink {
            WordSetView(title: title, words: words, color: color)
        } label: {
            let learned = words.filter { store.card($0)?.learned == true }.count
            RowLabel(title: title, subtitle: "\(words.count) words · \(learned) learned", icon: IconTile(symbol: symbol, color: color, size: 40)) {
                BandRingProgress(value: words.isEmpty ? 0 : Double(learned) / Double(words.count), color: color, size: 40)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private func topicColor(_ index: Int) -> Color {
        [.green, .blue, .orange, .pink, .purple, .teal, .indigo, .red, .mint, .cyan, .brown][index % 11]
    }

    private func topicSymbol(_ topic: String) -> String {
        switch topic {
        case "Health & body": return "heart.fill"
        case "Food & drink": return "fork.knife"
        case "Nature & environment": return "leaf.fill"
        case "Science & technology": return "atom"
        case "Media & communication": return "bubble.left.and.bubble.right.fill"
        case "Education & thinking": return "brain.head.profile"
        case "Feelings & personality": return "face.smiling"
        case "Money & work": return "briefcase.fill"
        case "Society & government": return "building.columns.fill"
        case "People & relationships": return "person.2.fill"
        case "Places & travel": return "airplane"
        case "Time & change": return "clock.fill"
        case "Arts & culture": return "paintpalette.fill"
        case "Sport & leisure": return "figure.run"
        case "Describing actions": return "bolt.fill"
        case "Everyday actions": return "hand.tap.fill"
        default: return "textformat.abc"
        }
    }
}

struct LevelTile: View {
    let level: String
    let total: Int
    let learned: Int

    var body: some View {
        let color = WordPools.levelColor(level)
        VStack(alignment: .leading, spacing: 6) {
            Text(level).font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(color)
            Text(WordPools.levelName(level)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            ProgressView(value: Double(learned), total: Double(max(total, 1))).tint(color)
            Text("\(learned)/\(total)").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
        .cardStyle(padding: 12)
    }
}

// MARK: - A set of words

struct WordSetView: View {
    @EnvironmentObject private var store: AppStore
    let title: String
    let words: [VocabWord]
    let color: Color
    @State private var query = ""

    private var shown: [VocabWord] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.isEmpty ? words : words.filter { $0.w.lowercased().contains(trimmed) || $0.d.lowercased().contains(trimmed) }
    }

    /// Words to study next: due first, then never seen, then the rest.
    private func studyOrder(_ count: Int) -> [VocabWord] {
        let now = Date()
        let due = words.filter { (store.card($0)?.due ?? .distantFuture) <= now }
        let fresh = words.filter { store.card($0) == nil }
        let rest = words.filter { store.card($0) != nil && !due.contains($0) }.sorted { (store.card($0)?.box ?? 0) < (store.card($1)?.box ?? 0) }
        return Array((due + fresh + rest).prefix(count))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    let learned = words.filter { store.card($0)?.learned == true }.count
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(learned) of \(words.count) learned").font(.headline)
                            Text("A word counts as learned after three correct reviews on different days.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        BandRingProgress(value: words.isEmpty ? 0 : Double(learned) / Double(words.count), color: color, size: 52)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        mode("Flashcards", "rectangle.on.rectangle.angled", .purple) {
                            FlashcardDeck(title: "Flashcards", words: studyOrder(20), color: color, learning: true)
                        }
                        mode("Quiz", "checklist", .blue) {
                            VocabQuizSession(title: "Quiz", words: studyOrder(10), color: color)
                        }
                        mode("Listen & spell", "ear.fill", .orange) {
                            VocabQuizSession(title: "Listen & spell", words: studyOrder(10), color: color, spellingOnly: true)
                        }
                        mode("Match", "square.grid.2x2.fill", .green) {
                            MatchGame(words: Array(studyOrder(30).shuffled().prefix(6)), color: color)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            Section("\(shown.count) words") {
                ForEach(shown.prefix(400)) { word in
                    NavigationLink {
                        WordDetail(word: word)
                    } label: {
                        WordRow(word: word, card: store.card(word))
                    }
                }
                if shown.count > 400 {
                    Text("Showing the first 400 — search to find others.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .groupedList()
        .searchable(text: $query, prompt: "Search \(title)")
        .navigationTitle(title)
        .inlineTitle()
    }

    private func mode<Destination: View>(_ title: String, _ symbol: String, _ tint: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(words.isEmpty)
    }
}

struct WordRow: View {
    let word: VocabWord
    let card: CardState?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(word.w).font(.body.weight(.semibold))
                    Text(word.p).font(.caption).foregroundStyle(.secondary)
                }
                Text(word.d).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            MasteryDots(box: card?.box)
            Text(word.l).font(.caption2.weight(.bold)).foregroundStyle(WordPools.levelColor(word.l))
                .frame(width: 26)
        }
    }
}

/// Five dots showing how well a word is known.
struct MasteryDots: View {
    let box: Int?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(box.map { $0 >= index } == true ? Color.green : Color.secondary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel(box == nil ? "Not studied" : "Mastery \(min(box ?? 0, 5)) of 5")
    }
}

struct WordSearch: View {
    @State private var query = ""

    private var results: [VocabWord] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return [] }
        let starts = WordPools.all.filter { $0.w.lowercased().hasPrefix(trimmed) }
        let contains = WordPools.all.filter { !$0.w.lowercased().hasPrefix(trimmed) && $0.w.lowercased().contains(trimmed) }
        return Array((starts + contains).prefix(80))
    }

    var body: some View {
        List(results) { word in
            NavigationLink {
                WordDetail(word: word)
            } label: {
                WordRow(word: word, card: nil)
            }
        }
        .groupedList()
        .overlay {
            if results.isEmpty {
                ContentUnavailableView("Search \(WordPools.all.count.formatted()) words",
                                       systemImage: "character.book.closed",
                                       description: Text("Type at least two letters."))
            }
        }
        .searchable(text: $query, prompt: "Word")
        .navigationTitle("Dictionary")
        .inlineTitle()
    }
}

// MARK: - Word detail

struct WordDetail: View {
    @EnvironmentObject private var store: AppStore
    let word: VocabWord
    @StateObject private var speaker = Speaker()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Tag(text: word.l + " · " + WordPools.levelName(word.l), color: WordPools.levelColor(word.l))
                        Tag(text: word.p)
                        if word.b == 1 { Tag(text: "Grammar book", symbol: "text.book.closed", color: .blue) }
                    }
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.w).font(.largeTitle.weight(.bold))
                            if let ipa = word.i { Text(ipa).font(.title3).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button {
                            Task { await speaker.speak(word.w) }
                        } label: {
                            Image(systemName: "speaker.wave.2.fill").font(.title2).foregroundStyle(.white)
                                .frame(width: 56, height: 56).background(Color.purple.gradient, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pronounce")
                    }
                    Text(word.d).font(.title3)
                }
                .cardStyle(padding: 20)

                if !word.examples.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Examples").font(.headline)
                        ForEach(word.examples, id: \.self) { example in
                            Button {
                                Task { await speaker.speak(example) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Capsule().fill(Color.purple).frame(width: 3)
                                    Text(highlight(example)).italic().multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "speaker.wave.2").font(.footnote).foregroundStyle(.purple)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cardStyle()
                }

                if !word.synonyms.isEmpty || !(word.a ?? []).isEmpty || !(word.f ?? []).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        chips("Similar", word.synonyms, .green)
                        chips("Opposite", word.a ?? [], .red)
                        chips("Word family", word.f ?? [], .blue)
                    }
                    .cardStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your progress").font(.headline)
                    if let card = store.card(word) {
                        HStack {
                            MasteryDots(box: card.box)
                            Text(card.mastered ? "Mastered" : card.learned ? "Learned" : "Learning").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Next review \(card.due.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(card.correct) correct of \(card.seen) reviews").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Not studied yet.").font(.subheadline).foregroundStyle(.secondary)
                        Button("Add to My Reviews") { store.review(word, correct: false) }
                            .buttonStyle(.bordered).tint(.purple)
                    }
                    if let topic = word.t, let count = word.n, count > 0 {
                        Text("Appears \(count) times in the IELTS-style reading passages · \(topic)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .cardStyle()
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(word.w)
        .inlineTitle()
        .onDisappear { speaker.stop() }
    }

    @ViewBuilder private func chips(_ title: String, _ items: [String], _ color: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { Tag(text: $0, color: color) }
                }
            }
        }
    }

    private func highlight(_ sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        if let range = text.range(of: word.w, options: .caseInsensitive) {
            text[range].foregroundColor = .purple
            text[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return text
    }
}

// MARK: - Flashcards

struct FlashcardDeck: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let words: [VocabWord]
    let color: Color
    /// New words: "I know it" schedules the first review for tomorrow.
    var learning = false

    @State private var index = 0
    @State private var flipped = false
    @State private var drag: CGSize = .zero
    @State private var known = 0
    @StateObject private var speaker = Speaker()

    var body: some View {
        VStack(spacing: 16) {
            if index < words.count {
                ProgressView(value: Double(index), total: Double(words.count)).tint(color).padding(.horizontal, 20)
                card(words[index])
                    .offset(x: drag.width)
                    .rotationEffect(.degrees(Double(drag.width) / 22))
                    .gesture(
                        DragGesture()
                            .onChanged { drag = $0.translation }
                            .onEnded { value in
                                if value.translation.width > 110 { answer(true) } else if value.translation.width < -110 { answer(false) } else { withAnimation(.snappy) { drag = .zero } }
                            }
                    )
                    .padding(.horizontal, 20)
                HStack(spacing: 14) {
                    Button { answer(false) } label: {
                        Label("Still learning", systemImage: "arrow.uturn.left").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large).tint(.orange)
                    Button { answer(true) } label: {
                        Label("I know it", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity)
                    }
                    .primaryAction(.green)
                }
                .padding(.horizontal, 20)
                Text("Tap the card to flip it · swipe right if you know it").font(.caption).foregroundStyle(.secondary)
            } else {
                finished
            }
        }
        .padding(.vertical, 12)
        .screenBackground()
        .navigationTitle(title)
        .inlineTitle()
        .onDisappear { speaker.stop() }
        .overlay {
            if words.isEmpty {
                ContentUnavailableView("No words here yet", systemImage: "checkmark.seal", description: Text("You have studied every word in this set."))
            }
        }
    }

    private func card(_ word: VocabWord) -> some View {
        ZStack {
            front(word).opacity(flipped ? 0 : 1)
            back(word).opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(drag.width > 40 ? Color.green : drag.width < -40 ? Color.orange : color.opacity(0.25), lineWidth: 2)
        )
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .onTapGesture {
            withAnimation(.spring(duration: 0.45)) { flipped.toggle() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to flip")
    }

    private func front(_ word: VocabWord) -> some View {
        VStack(spacing: 14) {
            Tag(text: word.l + " · " + word.p, color: WordPools.levelColor(word.l))
            Text(word.w).font(.system(size: 40, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if let ipa = word.i { Text(ipa).font(.title3).foregroundStyle(.secondary) }
            Button {
                Task { await speaker.speak(word.w) }
            } label: {
                Image(systemName: "speaker.wave.2.fill").font(.title2).foregroundStyle(color)
                    .frame(width: 56, height: 56).background(color.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pronounce")
        }
        .padding(24)
    }

    private func back(_ word: VocabWord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(word.w).font(.title2.weight(.bold))
                Text(word.d).font(.title3)
                if let example = word.examples.last {
                    Text("“\(example)”").font(.body).italic().foregroundStyle(.secondary)
                }
                if !word.synonyms.isEmpty {
                    Text("Similar: " + word.synonyms.joined(separator: ", ")).font(.subheadline).foregroundStyle(.green)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(.green)
            Text("Deck complete").font(.title.weight(.bold))
            Text("\(known) of \(words.count) known. The rest will come back sooner.").foregroundStyle(.secondary)
            if !words.isEmpty {
                NavigationLink {
                    VocabQuizSession(title: "Test yourself", words: words, color: color)
                } label: {
                    Text("Test Yourself on These Words").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(color)
                .padding(.horizontal, 20)
            }
            Button("Done") { dismiss() }.padding(.top, 4)
            Spacer()
        }
        .overlay { if known * 5 >= words.count * 4 { Confetti() } }
    }

    private func answer(_ knows: Bool) {
        guard index < words.count else { return }
        store.review(words[index], correct: knows)
        if knows { known += 1 }
        withAnimation(.snappy) {
            drag = .zero
            flipped = false
            index += 1
        }
    }
}

// MARK: - Quiz

struct VocabQuizSession: View {
    @EnvironmentObject private var store: AppStore
    let title: String
    let words: [VocabWord]
    let color: Color
    var spellingOnly = false

    var body: some View {
        QuizRunner(title: title, color: color, items: VocabQuiz.items(for: words, spellingOnly: spellingOnly)) { item, correct in
            if let id = item.tag, let word = Library.vocabularyByID[id] {
                store.review(word, correct: correct)
            }
        } onFinish: { _, _ in }
    }
}

enum VocabQuiz {
    static func items(for words: [VocabWord], spellingOnly: Bool = false) -> [QuizItem] {
        words.enumerated().map { index, word in
            if spellingOnly { return spelling(word) }
            switch index % 4 {
            case 0: return meaningToWord(word)
            case 1: return wordToMeaning(word)
            case 2: return cloze(word) ?? meaningToWord(word)
            default: return spelling(word)
            }
        }
    }

    private static func distractors(for word: VocabWord, count: Int = 3) -> [VocabWord] {
        let same = WordPools.all.filter { $0.p == word.p && $0.l == word.l && $0.w != word.w }
        let pool = same.count >= count ? same : WordPools.all.filter { $0.w != word.w }
        return Array(pool.shuffled().prefix(count))
    }

    static func meaningToWord(_ word: VocabWord) -> QuizItem {
        let options = (distractors(for: word).map(\.w) + [word.w]).shuffled()
        return QuizItem(prompt: word.d, instruction: "Which word means this? (\(word.p))",
                        kind: .choice(options: options, answer: word.w), explanation: word.examples.last, tag: word.id)
    }

    static func wordToMeaning(_ word: VocabWord) -> QuizItem {
        let options = (distractors(for: word).map(\.d) + [word.d]).shuffled()
        return QuizItem(prompt: word.w, instruction: "Choose the meaning", kind: .choice(options: options, answer: word.d),
                        explanation: word.examples.last, speak: word.w, tag: word.id)
    }

    static func cloze(_ word: VocabWord) -> QuizItem? {
        guard let sentence = word.examples.last(where: { $0.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word.w))\\b", options: [.regularExpression, .caseInsensitive]) != nil }),
              sentence.split(separator: " ").count >= 6 else { return nil }
        let gapped = sentence.replacingOccurrences(of: "\\b\(NSRegularExpression.escapedPattern(for: word.w))\\b", with: "________",
                                                    options: [.regularExpression, .caseInsensitive])
        let options = (distractors(for: word).map(\.w) + [word.w]).shuffled()
        return QuizItem(prompt: gapped, instruction: "Complete the sentence from an IELTS-style passage",
                        kind: .choice(options: options, answer: word.w), explanation: "\(word.w): \(word.d)", tag: word.id)
    }

    static func spelling(_ word: VocabWord) -> QuizItem {
        QuizItem(prompt: "Listen and type the word.", instruction: "Hint: \(word.d)",
                 kind: .typed(answers: [word.w], hints: [nil]), explanation: word.i.map { "\(word.w) \($0)" }, speak: word.w, tag: word.id)
    }
}

// MARK: - Matching game

struct MatchGame: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let words: [VocabWord]
    let color: Color

    @State private var left: [VocabWord] = []
    @State private var right: [VocabWord] = []
    @State private var selected: VocabWord?
    @State private var matched: Set<String> = []
    @State private var wrong: String?
    @State private var mistakes = 0
    @State private var start = Date()
    @State private var finishedAt: Date?

    var body: some View {
        ScrollView {
            if let finishedAt {
                VStack(spacing: 14) {
                    Image(systemName: "trophy.fill").font(.system(size: 60)).foregroundStyle(.yellow).padding(.top, 40)
                    Text("All matched!").font(.title.weight(.bold))
                    Text("\(Int(finishedAt.timeIntervalSince(start))) seconds · \(mistakes) mistake\(mistakes == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                    Button("Play Again") { setUp() }.primaryAction(color)
                    Button("Done") { dismiss() }
                }
                .frame(maxWidth: .infinity)
                .overlay { if mistakes <= 1 { Confetti() } }
            } else {
                VStack(spacing: 12) {
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        Label("\(Int(context.date.timeIntervalSince(start)))s · \(matched.count)/\(words.count) pairs", systemImage: "timer")
                            .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 10) {
                            ForEach(left) { word in tile(word.w, word: word, isWord: true) }
                        }
                        VStack(spacing: 10) {
                            ForEach(right) { word in tile(word.d, word: word, isWord: false) }
                        }
                    }
                }
                .padding(16)
            }
        }
        .screenBackground()
        .navigationTitle("Match")
        .inlineTitle()
        .onAppear { if left.isEmpty { setUp() } }
        .sensoryFeedback(.success, trigger: matched.count)
        .sensoryFeedback(.error, trigger: mistakes)
    }

    private func tile(_ text: String, word: VocabWord, isWord: Bool) -> some View {
        let done = matched.contains(word.id)
        let isSelected = selected == word && isWord
        let isWrong = wrong == word.id && !isWord
        return Button {
            tap(word, isWord: isWord)
        } label: {
            Text(text)
                .font(isWord ? .headline : .caption)
                .multilineTextAlignment(.center)
                .lineLimit(isWord ? 2 : 4)
                .foregroundStyle(done ? Color.secondary : Color.primary)
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(done ? Color.green.opacity(0.15) : isSelected ? color.opacity(0.2) : isWrong ? Color.red.opacity(0.18) : Theme.card,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isSelected ? color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(done)
        .opacity(done ? 0.5 : 1)
        .animation(.snappy, value: done)
    }

    private func tap(_ word: VocabWord, isWord: Bool) {
        if isWord {
            selected = word
            return
        }
        guard let chosen = selected else { return }
        if chosen == word {
            matched.insert(word.id)
            store.review(word, correct: true)
            selected = nil
            if matched.count == words.count {
                finishedAt = Date()
                store.award(15)
            }
        } else {
            mistakes += 1
            wrong = word.id
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { wrong = nil }
            }
        }
    }

    private func setUp() {
        left = words.shuffled()
        right = words.shuffled()
        matched = []
        selected = nil
        mistakes = 0
        start = Date()
        finishedAt = nil
    }
}
