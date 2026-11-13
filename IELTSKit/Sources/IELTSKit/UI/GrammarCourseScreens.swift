import SwiftUI

// MARK: - Grammar home: course + Mentors' book

struct GrammarHome: View {
    @State private var tab = 0

    var body: some View {
        Group {
            if tab == 0 {
                GrammarCourseOverview()
            } else {
                MentorsBookContent()
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Grammar", selection: $tab) {
                Text("Grammar course").tag(0)
                Text("Mentors' book").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Grammar")
        .inlineTitle()
    }
}

struct PriorityBadge: View {
    let priority: IELTSPriority
    var compact = false

    var body: some View {
        Label(compact ? priority.short : priority.label, systemImage: priority.symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(priority.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(priority.color.opacity(0.12), in: Capsule())
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(priority.label)
    }
}

struct GrammarCourseOverview: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter: IELTSPriority?

    private var unitCount: Int { GrammarCourse.units.count }
    private var questionCount: Int { GrammarCourse.units.reduce(0) { $0 + $1.practice.count } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                actions
                SectionHeader(title: "Course", subtitle: "Stars show how much each unit matters for your IELTS band")
                filterBar
                ForEach(GrammarCourse.sections) { section in
                    let units = section.units.filter { filter == nil || $0.priority == filter }
                    if !units.isEmpty { sectionCard(section, units: units) }
                }
                Text("An original course written for this app, covering the grammar syllabus from B1 to C1 with an IELTS focus.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .screenBackground()
    }

    private var hero: some View {
        HStack(spacing: 16) {
            BandRingProgress(value: store.courseProgress, color: .blue, size: 84, label: "course")
            VStack(alignment: .leading, spacing: 6) {
                Text("IELTS Grammar Course").font(.headline)
                Text("\(unitCount) units · \(questionCount) practice questions · B1 to C1").font(.subheadline).foregroundStyle(.secondary)
                let essentials = GrammarCourse.essentials
                let done = essentials.filter { store.unitProgress($0) >= 0.85 }.count
                Label("\(done) of \(essentials.count) essential units mastered", systemImage: "star.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
        }
        .cardStyle()
    }

    private var actions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                GrammarCheck()
            } label: {
                actionTile("IELTS grammar check", "\(GrammarCourse.essentials.count) questions · find your weak units", "stethoscope", .red)
            }
            .buttonStyle(.plain)
            NavigationLink {
                MistakesReview()
            } label: {
                actionTile("Review mistakes", store.grammarMistakes.isEmpty ? "No mistakes saved yet" : "\(store.grammarMistakes.count) to fix", "arrow.uturn.backward.circle.fill", .orange)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionTile(_ title: String, _ detail: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(symbol: symbol, color: color, size: 36)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .cardStyle(padding: 14)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All units", nil, count: GrammarCourse.units.count)
                ForEach(IELTSPriority.allCases.reversed(), id: \.self) { priority in
                    chip(priority.short, priority, count: GrammarCourse.units.filter { $0.priority == priority }.count)
                }
            }
        }
    }

    private func chip(_ title: String, _ value: IELTSPriority?, count: Int) -> some View {
        let selected = filter == value
        let color = value?.color ?? Theme.accent
        return Button {
            withAnimation(.snappy) { filter = value }
        } label: {
            HStack(spacing: 5) {
                if let value { Image(systemName: value.symbol) }
                Text("\(title) \(count)")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.white : color)
            .background(selected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sectionCard(_ section: GrammarCourseSection, units: [GrammarUnit]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            NavigationLink {
                GrammarSectionView(section: section)
            } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: section.symbol, color: section.tint, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Text("\(section.units.count) units · section test").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    BandRingProgress(value: store.sectionProgress(section), color: section.tint, size: 40)
                }
                .padding(.bottom, 6)
            }
            .buttonStyle(.plain)
            ForEach(units) { unit in
                Divider().padding(.leading, 52)
                NavigationLink {
                    GrammarUnitView(unit: unit)
                } label: {
                    UnitRow(unit: unit, color: section.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle(padding: 14)
    }
}

struct UnitRow: View {
    @EnvironmentObject private var store: AppStore
    let unit: GrammarUnit
    let color: Color

    var body: some View {
        let progress = store.unitProgress(unit)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(color.opacity(0.18), lineWidth: 3)
                Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                if progress >= 0.85 {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(color)
                }
            }
            .frame(width: 28, height: 28)
            .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    PriorityBadge(priority: unit.priority, compact: true)
                    Text(unit.level).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    if let score = store.unitScore(unit) {
                        Text("\(Int((score.fraction * 100).rounded()))%").font(.caption2.weight(.bold))
                            .foregroundStyle(score.fraction >= 0.8 ? Theme.success : Theme.warning)
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Section

struct GrammarSectionView: View {
    @EnvironmentObject private var store: AppStore
    let section: GrammarCourseSection

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    IconTile(symbol: section.symbol, color: section.tint, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title).font(.title3.weight(.bold))
                        Text("\(section.units.count) units · \(section.units.filter { $0.priority == .essential }.count) essential for IELTS")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    BandRingProgress(value: store.sectionProgress(section), color: section.tint, size: 48)
                }
                .padding(.vertical, 6)
            }
            Section("Units") {
                ForEach(section.units) { unit in
                    NavigationLink {
                        GrammarUnitView(unit: unit)
                    } label: {
                        UnitRow(unit: unit, color: section.tint)
                    }
                }
            }
            Section {
                NavigationLink {
                    SectionTest(section: section)
                } label: {
                    RowLabel(title: "Section test", subtitle: "15 mixed questions from every unit",
                             icon: IconTile(symbol: "checklist", color: section.tint, size: 36)) {
                        if let score = store.learning.grammar["section:\(section.id)"] {
                            Text("\(Int((score.fraction * 100).rounded()))%").font(.subheadline.weight(.bold))
                                .foregroundStyle(score.fraction >= 0.8 ? Theme.success : Theme.warning)
                        }
                    }
                }
            }
        }
        .groupedList()
        .navigationTitle(section.title)
        .inlineTitle()
    }
}

struct SectionTest: View {
    @EnvironmentObject private var store: AppStore
    let section: GrammarCourseSection
    @State private var items: [QuizItem] = []

    var body: some View {
        QuizRunner(title: "Section test", color: section.tint, items: items) { item, correct in
            store.recordGrammarAnswer(item.tag, correct: correct)
        } onFinish: { correct, total in
            store.recordGrammar("section:\(section.id)", correct: correct, total: total)
        }
        .onAppear {
            if items.isEmpty {
                items = Array(section.units.flatMap { unit in
                    GrammarCourse.quiz(for: unit, indices: Array(unit.practice.indices.shuffled().prefix(2)))
                }.shuffled().prefix(15))
            }
        }
        .id(items.count)
    }
}

// MARK: - Unit

struct GrammarUnitView: View {
    @EnvironmentObject private var store: AppStore
    let unit: GrammarUnit

    private var section: GrammarCourseSection? { GrammarCourse.section(of: unit) }
    private var color: Color { section?.tint ?? Theme.accent }
    private var ieltsCard: GrammarCard? { unit.cards.first { $0.kind == "ielts" } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text(section?.title ?? "Grammar").font(.caption.weight(.semibold)).foregroundStyle(color)
                        Spacer()
                        Tag(text: unit.level, color: WordPools.levelColor(unit.level))
                    }
                    Text(unit.title).font(.title2.weight(.bold))
                    Text(unit.summary).font(.subheadline).foregroundStyle(.secondary)
                    PriorityBadge(priority: unit.priority)
                    FlowLayout(spacing: 6) {
                        ForEach(unit.skills, id: \.self) { Tag(text: $0, symbol: "target", color: color) }
                    }
                }
                .cardStyle()

                HStack(spacing: 12) {
                    NavigationLink {
                        UnitCardsReader(unit: unit, color: color)
                    } label: {
                        bigButton("Learn", "\(unit.cards.count) cards", "book.fill", color, done: store.unitRead(unit))
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        UnitPractice(unit: unit, color: color)
                    } label: {
                        bigButton("Practise", "\(unit.practice.count) questions", "pencil.and.list.clipboard", color,
                                  done: (store.unitScore(unit)?.fraction ?? 0) >= 0.8, score: store.unitScore(unit))
                    }
                    .buttonStyle(.plain)
                }

                if let ieltsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Why it matters for IELTS", systemImage: "star.fill").font(.headline).foregroundStyle(unit.priority.color == .secondary ? color : unit.priority.color)
                        Text(markdown(ieltsCard.body ?? "")).font(.subheadline)
                    }
                    .cardStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("In this unit").font(.headline)
                    ForEach(Array(unit.cards.enumerated()), id: \.offset) { index, card in
                        HStack(spacing: 10) {
                            Image(systemName: UnitCardView.symbol(card.kind)).foregroundStyle(color).frame(width: 22)
                            Text(UnitCardView.title(card)).font(.subheadline)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(unit.title)
        .inlineTitle()
    }

    private func bigButton(_ title: String, _ detail: String, _ symbol: String, _ color: Color, done: Bool, score: ExerciseScore? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol).font(.title2)
                Spacer()
                if done { Image(systemName: "checkmark.circle.fill").font(.title3) }
            }
            Text(title).font(.title3.weight(.bold))
            Text(score.map { "\(detail) · best \(Int(($0.fraction * 100).rounded()))%" } ?? detail).font(.caption).opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct UnitCardsReader: View {
    @EnvironmentObject private var store: AppStore
    let unit: GrammarUnit
    let color: Color
    @State private var page = 0
    @StateObject private var speaker = Speaker()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(unit.cards.indices, id: \.self) { index in
                    Capsule().fill(index <= page ? color : color.opacity(0.18)).frame(height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            TabView(selection: $page) {
                ForEach(Array(unit.cards.enumerated()), id: \.offset) { index, card in
                    ScrollView {
                        UnitCardView(card: card, color: color, speaker: speaker).padding(16)
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
                Text("\(page + 1) of \(unit.cards.count)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                if page + 1 < unit.cards.count {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Next").font(.headline).padding(.horizontal, 10)
                    }
                    .primaryAction(color)
                } else {
                    NavigationLink {
                        UnitPractice(unit: unit, color: color)
                    } label: {
                        Text("Practise").font(.headline).padding(.horizontal, 10)
                    }
                    .primaryAction(color)
                }
            }
        }
        .navigationTitle(unit.title)
        .inlineTitle()
        .onChange(of: page) {
            if page + 1 == unit.cards.count { store.markDone("gunit:\(unit.id)", xp: 10) }
        }
        .onAppear {
            if unit.cards.count == 1 { store.markDone("gunit:\(unit.id)", xp: 10) }
        }
        .onDisappear { speaker.stop() }
    }
}

struct UnitCardView: View {
    let card: GrammarCard
    let color: Color
    @ObservedObject var speaker: Speaker

    static func symbol(_ kind: String) -> String {
        switch kind {
        case "form": return "tablecells"
        case "mistakes": return "exclamationmark.triangle.fill"
        case "ielts": return "star.fill"
        default: return "lightbulb.fill"
        }
    }

    static func title(_ card: GrammarCard) -> String {
        switch card.kind {
        case "mistakes": return "Common mistakes"
        case "ielts": return card.title ?? "Use it in IELTS"
        default: return card.title ?? "Rule"
        }
    }

    var body: some View {
        let accent: Color = card.kind == "mistakes" ? .orange : card.kind == "ielts" ? .red : color
        VStack(alignment: .leading, spacing: 14) {
            Label(card.kind == "form" ? "Form" : card.kind == "mistakes" ? "Watch out" : card.kind == "ielts" ? "IELTS" : "Rule",
                  systemImage: Self.symbol(card.kind))
                .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            Text(Self.title(card)).font(.title2.weight(.bold))
            if let body = card.body, !body.isEmpty {
                GuideText(text: body)
            }
            if let rows = card.rows, !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider() }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.first ?? "").font(.subheadline.weight(.semibold)).foregroundStyle(color)
                                .frame(width: 110, alignment: .leading)
                            Text(row.dropFirst().joined(separator: " ")).font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 9)
                    }
                }
                .padding(.horizontal, 12)
                .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let items = card.items, !items.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(item.first ?? "", systemImage: "xmark.circle.fill")
                                .foregroundStyle(Theme.failure).font(.subheadline)
                            if item.count > 1 {
                                Label(item[1], systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.success).font(.subheadline.weight(.semibold))
                            }
                            if item.count > 2, item[2] != "—" {
                                Text(item[2]).font(.caption).foregroundStyle(.secondary).padding(.leading, 26)
                            }
                        }
                    }
                }
            }
            if let examples = card.examples, !examples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            Task { await speaker.speak(example) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Capsule().fill(accent).frame(width: 3)
                                Text(markdown(example)).italic().foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "speaker.wave.2").font(.footnote).foregroundStyle(accent)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
        .overlay(alignment: .top) {
            if card.kind == "ielts" {
                UnevenRoundedRectangle(topLeadingRadius: Theme.cornerRadius, topTrailingRadius: Theme.cornerRadius)
                    .fill(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 5)
            }
        }
    }
}

struct UnitPractice: View {
    @EnvironmentObject private var store: AppStore
    let unit: GrammarUnit
    let color: Color

    var body: some View {
        QuizRunner(title: unit.title, color: color, items: GrammarCourse.quiz(for: unit)) { item, correct in
            store.recordGrammarAnswer(item.tag, correct: correct)
        } onFinish: { correct, total in
            store.recordGrammar("course:\(unit.id)", correct: correct, total: total)
        }
    }
}

// MARK: - IELTS grammar check and mistakes review

struct GrammarCheck: View {
    @EnvironmentObject private var store: AppStore
    @State private var items: [QuizItem] = []
    @State private var wrong: [String] = []
    @State private var finished = false
    @State private var score = (0, 0)

    var body: some View {
        Group {
            if finished {
                results
            } else if !items.isEmpty {
                QuizRunner(title: "IELTS grammar check", color: .red, items: items) { item, correct in
                    if !correct, let unit = item.tag?.split(separator: "#").first { wrong.append(String(unit)) }
                    store.recordGrammarAnswer(item.tag, correct: correct)
                } onFinish: { correct, total in
                    score = (correct, total)
                    store.award(correct * 2 + 10)
                    finished = true
                }
            }
        }
        .onAppear {
            if items.isEmpty {
                items = GrammarCourse.essentials.compactMap { unit in
                    GrammarCourse.quiz(for: unit, indices: [unit.practice.indices.randomElement() ?? 0]).first
                }.shuffled()
            }
        }
    }

    private var results: some View {
        let weak = Array(Set(wrong)).compactMap(GrammarCourse.unit).sorted { $0.title < $1.title }
        return List {
            Section {
                HStack(spacing: 16) {
                    BandRingProgress(value: Double(score.0) / Double(max(score.1, 1)), color: .red, size: 76, label: "correct")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(score.0) of \(score.1) correct").font(.title3.weight(.bold))
                        Text(weak.isEmpty ? "No weak areas found in the essential units. Excellent." : "Start with the \(weak.count) unit\(weak.count == 1 ? "" : "s") below.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            if !weak.isEmpty {
                Section("Your study list") {
                    ForEach(weak) { unit in
                        NavigationLink {
                            GrammarUnitView(unit: unit)
                        } label: {
                            UnitRow(unit: unit, color: GrammarCourse.section(of: unit)?.tint ?? .red)
                        }
                    }
                }
            }
        }
        .groupedList()
        .navigationTitle("Your results")
        .inlineTitle()
        .overlay { if weak.isEmpty { Confetti() } }
    }
}

struct MistakesReview: View {
    @EnvironmentObject private var store: AppStore
    @State private var items: [QuizItem] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded && items.isEmpty {
                ContentUnavailableView("No mistakes to review", systemImage: "checkmark.seal",
                                       description: Text("Questions you answer wrongly in the grammar course are saved here until you get them right."))
                    .navigationTitle("Review mistakes")
                    .inlineTitle()
            } else if !items.isEmpty {
                QuizRunner(title: "Review mistakes", color: .orange, items: items) { item, correct in
                    store.recordGrammarAnswer(item.tag, correct: correct)
                } onFinish: { _, _ in }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            items = store.grammarMistakes.prefix(20).compactMap { tag in
                let parts = tag.split(separator: "#")
                guard parts.count == 2, let unit = GrammarCourse.unit(String(parts[0])), let index = Int(parts[1]) else { return nil }
                return GrammarCourse.quiz(for: unit, indices: [index]).first
            }
        }
    }
}
