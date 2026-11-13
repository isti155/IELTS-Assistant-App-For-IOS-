import Charts
import SwiftUI

/// Entry point used by the app target.
public struct RootView: View {
    @StateObject private var store: AppStore

    /// - Parameter generator: an on-device language model, if the app target provides one.
    public init(generator: TextGenerator? = nil) {
        _store = StateObject(wrappedValue: AppStore(generator: generator))
        Library.warmUp()
    }

    init(store: AppStore) {
        _store = StateObject(wrappedValue: store)
    }

    public var body: some View {
        #if DEBUG
        if let screen = DebugScreens.requested {
            DebugRoot(name: screen)
        } else {
            app
        }
        #else
        app
        #endif
    }

    private var app: some View {
        MainTabs()
            .environmentObject(store)
            .tint(Theme.accent)
            .sheet(isPresented: Binding(get: { !store.isOnboarded }, set: { _ in })) {
                OnboardingView()
                    .environmentObject(store)
                    .interactiveDismissDisabled()
            }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            NavigationStack { HomeScreen() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { PracticeScreen() }
                .tabItem { Label("Practice", systemImage: "square.grid.2x2.fill") }
            NavigationStack { LearnScreen() }
                .tabItem { Label("Learn", systemImage: "book.fill") }
            NavigationStack { TutorScreen() }
                .tabItem { Label("Tutor", systemImage: "graduationcap.fill") }
            NavigationStack { ProgressScreen() }
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

// MARK: - First launch

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var target = 7.0
    @State private var hasDate = false
    @State private var examDate = Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    AppMark(size: 84)
                    Text("Welcome to\nIELTS Assistant")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)

                VStack(alignment: .leading, spacing: 20) {
                    feature("square.grid.2x2.fill", .indigo, "All four skills",
                            "Listening, Reading, Writing and Speaking in the real test format.")
                    feature("checkmark.seal.fill", .green, "Marked on your iPhone",
                            "Bands and corrections from a model that runs on the device. Nothing is uploaded.")
                    feature("chart.line.uptrend.xyaxis", .orange, "See your progress",
                            "Track each skill against your target band.")
                }
                .padding(.horizontal, 8)

                VStack(spacing: 14) {
                    Text("What band are you aiming for?").font(.headline)
                    HStack(spacing: 24) {
                        stepButton("minus", enabled: target > 4) { target -= 0.5 }
                        Text(bandText(target))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: target))
                            .frame(minWidth: 100)
                        stepButton("plus", enabled: target < 9) { target += 0.5 }
                    }
                    Toggle("I have booked my test", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Test date", selection: $examDate, in: Date()..., displayedComponents: .date)
                    }
                }
                .frame(maxWidth: .infinity)
                .cardStyle(padding: 20)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            Button {
                store.profile.targetBand = target
                store.profile.examDate = hasDate ? examDate : nil
                store.isOnboarded = true
            } label: {
                Text("Get started").font(.headline).frame(maxWidth: .infinity)
            }
            .primaryAction()
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func feature(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 48, height: 48)
                .background(Theme.fill, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.accent : Color.secondary)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "Raise target" : "Lower target")
    }
}

// MARK: - Home

struct HomeScreen: View {
    @EnvironmentObject private var store: AppStore

    private var target: Double { store.profile.targetBand }

    private var daysToExam: Int? {
        guard let date = store.profile.examDate else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                      to: Calendar.current.startOfDay(for: date)).day ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    StreakBadge(days: store.streak)
                    Tag(text: "\(store.learning.totalXP) XP", symbol: "star.fill", color: .orange)
                    Spacer()
                    DailyGoalRing(xp: store.todayXP, goal: store.learning.dailyGoal)
                }
                summaryCard
                SectionHeader(title: "Today's plan", subtitle: StudyPlan(store: store).phase.rawValue + " phase")
                TaskList(tasks: StudyPlan(store: store).tasks)
                SectionHeader(title: "Skills")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Skill.allCases) { skill in
                        NavigationLink {
                            skill.hub
                        } label: {
                            SkillTile(skill: skill, band: store.estimate(for: skill), target: target,
                                      last: store.lastAttempt(for: skill)?.date)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !store.attempts.isEmpty {
                    SectionHeader(title: "Recent")
                    recent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            BandRing(band: store.overallEstimate, target: target, size: 108, lineWidth: 11, caption: "Overall")
            VStack(alignment: .leading, spacing: 8) {
                Text(statusTitle).font(.headline)
                Text(statusDetail).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Tag(text: "Target \(bandText(target))", symbol: "flag.fill", color: Theme.accent)
                    if let days = daysToExam {
                        Tag(text: days == 1 ? "1 day" : "\(days) days", symbol: "calendar", color: .secondary)
                    }
                }
            }
        }
        .cardStyle(padding: 18)
    }

    private var statusTitle: String {
        guard let overall = store.overallEstimate else {
            let done = Skill.allCases.filter { store.estimate(for: $0) != nil }.count
            return done == 0 ? "Find your level" : "\(done) of 4 skills practised"
        }
        let gap = target - overall
        if gap <= 0 { return "On target" }
        return "\(bandText(gap)) below target"
    }

    private var statusDetail: String {
        if store.overallEstimate == nil {
            return "Practise every skill once to see your overall band."
        }
        return "Averaged from your three most recent attempts in each skill."
    }

    private var recent: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.attempts.prefix(3).enumerated()), id: \.element.id) { index, attempt in
                if index > 0 { Divider().padding(.leading, 44) }
                NavigationLink {
                    AttemptDetail(attempt: attempt)
                } label: {
                    AttemptRow(attempt: attempt).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

struct SkillTile: View {
    let skill: Skill
    let band: Double?
    let target: Double
    let last: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                SkillIcon(skill: skill, size: 32)
                Spacer()
                Text(band.map(bandText) ?? "–")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(band == nil ? Color.secondary : Color.primary)
            }
            Text(skill.title).font(.subheadline.weight(.semibold))
            BandBar(band: band, target: target, color: skill.color)
            Text(last.map { "Last \($0.formatted(.relative(presentation: .named)))" } ?? "Not started")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct AttemptRow: View {
    let attempt: Attempt

    var body: some View {
        HStack(spacing: 12) {
            SkillIcon(skill: attempt.skill, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(attempt.title).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(attempt.date.formatted(.relative(presentation: .named)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            BandPill(band: attempt.band, color: attempt.skill.color)
        }
        .contentShape(Rectangle())
    }
}

extension Skill {
    @ViewBuilder var hub: some View {
        switch self {
        case .listening: ListeningHub()
        case .reading: ReadingHub()
        case .writing: WritingHub()
        case .speaking: SpeakingHub()
        }
    }
}

// MARK: - Practice

struct PracticeScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                ForEach(Skill.allCases) { skill in
                    NavigationLink {
                        skill.hub
                    } label: {
                        RowLabel(title: skill.title, subtitle: skill.tagline, icon: IconTile(symbol: skill.symbol, color: skill.color, size: 36)) {
                            if let band = store.estimate(for: skill) { BandPill(band: band, color: skill.color) }
                        }
                    }
                }
            } header: {
                Text("Skills")
            }

            Section {
                NavigationLink {
                    ExamHub()
                } label: {
                    RowLabel(title: "Exam practice", subtitle: "Cambridge book companion · full Reading and Writing papers",
                             icon: IconTile(symbol: "doc.text.magnifyingglass", color: .red, size: 36))
                }
            } header: {
                Text("Exams")
            }

            Section {
                NavigationLink {
                    WritingEditor(task: nil)
                } label: {
                    RowLabel(title: "Random Task 2 essay", subtitle: "\(QuestionBank.shared.task2.count) questions in the bank",
                             icon: IconTile(symbol: "shuffle", color: Skill.writing.color))
                }
                NavigationLink {
                    SpeakingTestView(script: nil)
                } label: {
                    RowLabel(title: "Speaking mock test", subtitle: "All three parts with random questions",
                             icon: IconTile(symbol: "person.wave.2.fill", color: Skill.speaking.color))
                }
                NavigationLink {
                    PartnerView()
                } label: {
                    RowLabel(title: "Conversation practice", subtitle: "Talk freely and get corrections",
                             icon: IconTile(symbol: "bubble.left.and.bubble.right.fill", color: Skill.speaking.color))
                }
            } header: {
                Text("Quick start")
            }
        }
        .groupedList()
        .navigationTitle("Practice")
    }
}

// MARK: - Tutor

struct GuideDetail: View {
    let article: GuideArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    IconTile(symbol: article.skill?.symbol ?? "book.closed.fill", color: article.skill?.color ?? Theme.accent, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.skill?.title ?? "Guide").font(.subheadline).foregroundStyle(.secondary)
                        Text(article.shortTitle).font(.title2.weight(.bold))
                    }
                }
                GuideText(text: article.body)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(article.shortTitle)
        .inlineTitle()
    }
}

// MARK: - Progress

struct ProgressScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter: Skill?

    private var shown: [Attempt] {
        store.attempts.filter { filter == nil || $0.skill == filter }
    }

    var body: some View {
        List {
            if !shown.isEmpty {
                Section {
                    stats
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Band over time") {
                    chart.padding(.vertical, 8)
                }
                Section("History") {
                    ForEach(shown) { attempt in
                        NavigationLink {
                            AttemptDetail(attempt: attempt)
                        } label: {
                            AttemptRow(attempt: attempt)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { shown[$0].id }
                        store.attempts.removeAll { ids.contains($0.id) }
                    }
                }
            }
        }
        .groupedList()
        .overlay {
            if shown.isEmpty {
                ContentUnavailableView(
                    filter.map { "No \($0.title) practice yet" } ?? "No practice yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Your bands appear here after each Listening, Reading, Writing or Speaking attempt.")
                )
            }
        }
        .navigationTitle("Progress")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Skill", selection: $filter) {
                        Label("All skills", systemImage: "square.grid.2x2").tag(Skill?.none)
                        ForEach(Skill.allCases) { skill in
                            Label(skill.title, systemImage: skill.symbol).tag(Skill?.some(skill))
                        }
                    }
                } label: {
                    Image(systemName: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filter by skill")
            }
        }
    }

    private var stats: some View {
        let bands = shown.map(\.band)
        let average = bands.reduce(0, +) / Double(max(bands.count, 1))
        return HStack(spacing: 12) {
            stat("\(shown.count)", "Attempts")
            stat(bandText((average * 2).rounded() / 2), "Average")
            stat(bandText(bands.max() ?? 0), "Best")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var chart: some View {
        Chart {
            ForEach(shown.reversed()) { attempt in
                LineMark(x: .value("Date", attempt.date), y: .value("Band", attempt.band))
                    .foregroundStyle(by: .value("Skill", attempt.skill.title))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", attempt.date), y: .value("Band", attempt.band))
                    .foregroundStyle(by: .value("Skill", attempt.skill.title))
            }
            RuleMark(y: .value("Target", store.profile.targetBand))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.secondary)
                .annotation(position: .top, alignment: .leading) {
                    Text("Target").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartForegroundStyleScale(domain: Skill.allCases.map(\.title), range: Skill.allCases.map(\.color))
        .chartYScale(domain: 3...9)
        .chartYAxis { AxisMarks(values: [3, 4, 5, 6, 7, 8, 9]) }
        .frame(height: 200)
    }
}

struct AttemptDetail: View {
    let attempt: Attempt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    SkillIcon(skill: attempt.skill, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attempt.title).font(.headline)
                        Text(attempt.date.formatted(date: .long, time: .shortened))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(attempt.prompt).font(.subheadline).cardStyle()
                if let raw = attempt.rawScore, let total = attempt.total {
                    ScoreSummary(correct: raw, total: total, band: attempt.band, color: attempt.skill.color)
                }
                if !attempt.response.isEmpty {
                    DisclosureGroup("Your answer") {
                        Text(attempt.response)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .font(.headline)
                    .cardStyle()
                }
                if let evaluation = attempt.evaluation {
                    EvaluationView(evaluation: evaluation, color: attempt.skill.color)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(attempt.skill.title)
        .inlineTitle()
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var confirmDelete = false

    private var bands: [Double] { stride(from: 4.0, through: 9.0, by: 0.5).map { $0 } }

    var body: some View {
        Form {
            Section("Goal") {
                Picker("Target band", selection: $store.profile.targetBand) {
                    ForEach(bands, id: \.self) { Text(bandText($0)).tag($0) }
                }
                Toggle("Test date booked", isOn: hasExamDate)
                if store.profile.examDate != nil {
                    DatePicker("Test date", selection: examDate, displayedComponents: .date)
                }
            }

            Section {
                status("Writing band model", installed: BandScorer.shared.isAvailable, symbol: "pencil", color: Skill.writing.color)
                status("Language model", installed: store.generator != nil, symbol: "cpu", color: Theme.accent)
            } header: {
                Text("On-device models")
            } footer: {
                Text("Marking, speech recognition and feedback all run on this iPhone. The app makes no network requests.")
            }

            Section {
                Button("Delete All Practice History", role: .destructive) { confirmDelete = true }
                    .disabled(store.attempts.isEmpty)
            } footer: {
                Text("\(store.attempts.count) attempts are stored on this iPhone.")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                Text("Practice estimates only. IELTS is a registered trademark of the British Council, IDP and Cambridge University Press & Assessment; this app is not affiliated with them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .inlineTitle()
        .confirmationDialog("Delete all practice history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { store.deleteAllAttempts() }
        } message: {
            Text("Your bands and reports will be removed from this iPhone. This cannot be undone.")
        }
    }

    private func status(_ name: String, installed: Bool, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            Text(name)
            Spacer()
            Text(installed ? "Installed" : "Not installed")
                .foregroundStyle(installed ? Theme.success : Color.secondary)
        }
    }

    private var hasExamDate: Binding<Bool> {
        Binding(
            get: { store.profile.examDate != nil },
            set: { on in
                store.profile.examDate = on ? Calendar.current.date(byAdding: .day, value: 30, to: Date()) : nil
            }
        )
    }

    private var examDate: Binding<Date> {
        Binding(get: { store.profile.examDate ?? Date() }, set: { store.profile.examDate = $0 })
    }
}
