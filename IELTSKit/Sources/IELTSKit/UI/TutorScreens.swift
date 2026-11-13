import SwiftUI

// MARK: - Tutor tab

struct TutorScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let plan = StudyPlan(store: store)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                planCard(plan)
                SectionHeader(title: "Today's plan", subtitle: "About \(plan.tasks.reduce(0) { $0 + $1.minutes }) minutes")
                TaskList(tasks: plan.tasks)

                SectionHeader(title: "IELTS course", subtitle: "\(Library.courseLessons.filter { store.isDone("course:\($0.id)") }.count) of \(Library.courseLessons.count) lessons completed")
                ForEach(Library.course.units) { unit in
                    UnitCard(unit: unit)
                }

                SectionHeader(title: "Quick reference")
                VStack(spacing: 0) {
                    ForEach(Array(Guide.articles.enumerated()), id: \.element.id) { index, article in
                        if index > 0 { Divider().padding(.leading, 50) }
                        NavigationLink {
                            GuideDetail(article: article)
                        } label: {
                            RowLabel(title: article.title, icon: IconTile(symbol: article.skill?.symbol ?? "book.closed.fill",
                                                                         color: article.skill?.color ?? Theme.accent)) {
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Tutor")
    }

    private func planCard(_ plan: StudyPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconTile(symbol: plan.phase.symbol, color: Theme.accent, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase: \(plan.phase.rawValue)").font(.headline)
                    Text(plan.daysLeft.map { "\($0) days until your test" } ?? "No test date set").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                StreakBadge(days: store.streak)
            }
            Text(plan.phase.detail).font(.subheadline)
            HStack(spacing: 6) {
                Text("Focus:").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(plan.focus.prefix(2), id: \.self) { skill in
                    Tag(text: skill.title, symbol: skill.symbol, color: skill.color)
                }
                Spacer()
                DailyGoalRing(xp: store.todayXP, goal: store.learning.dailyGoal)
            }
        }
        .cardStyle()
    }
}

struct TaskList: View {
    @EnvironmentObject private var store: AppStore
    let tasks: [PlanTask]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 { Divider().padding(.leading, 56) }
                NavigationLink {
                    destination(task.destination)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(task.done ? Theme.success : task.color.opacity(0.14)).frame(width: 40, height: 40)
                            Image(systemName: task.done ? "checkmark" : task.symbol)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(task.done ? Color.white : task.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title).font(.subheadline.weight(.semibold)).strikethrough(task.done, color: .secondary)
                                .foregroundStyle(task.done ? Color.secondary : Color.primary)
                            Text(task.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text("\(task.minutes) min").font(.caption).foregroundStyle(.tertiary)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    @ViewBuilder private func destination(_ destination: PlanTask.Destination) -> some View {
        switch destination {
        case .vocabulary:
            VocabularyHome()
        case .grammar(let id):
            if let chapter = Library.grammar.chapters.first(where: { $0.id == id }) { GrammarChapterView(chapter: chapter) }
        case .grammarUnit(let id):
            if let unit = GrammarCourse.unit(id) { GrammarUnitView(unit: unit) }
        case .lesson(let id):
            if let lesson = Library.courseLessons.first(where: { $0.id == id }) { LessonPlayer(lesson: lesson) }
        case .practice(let skill):
            skill.hub
        }
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(days > 0 ? Color.orange : Color.secondary)
            Text("\(days)").font(.subheadline.weight(.bold)).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((days > 0 ? Color.orange : Color.secondary).opacity(0.14), in: Capsule())
        .accessibilityLabel("\(days)-day streak")
    }
}

struct DailyGoalRing: View {
    let xp: Int
    let goal: Int

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.orange.opacity(0.18), lineWidth: 4)
                Circle().trim(from: 0, to: min(1, CGFloat(xp) / CGFloat(max(goal, 1))))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            Text("\(xp)/\(goal) XP").font(.caption.weight(.semibold)).monospacedDigit()
        }
        .accessibilityLabel("\(xp) of \(goal) XP today")
    }
}

struct UnitCard: View {
    @EnvironmentObject private var store: AppStore
    let unit: CourseUnit

    var body: some View {
        let color = unit.skillValue?.color ?? Theme.accent
        let done = unit.lessons.filter { store.isDone("course:\($0.id)") }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconTile(symbol: unit.skillValue?.symbol ?? "flag.fill", color: color, size: 36)
                Text(unit.title).font(.headline)
                Spacer()
                Text("\(done)/\(unit.lessons.count)").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(color)
            }
            ProgressView(value: Double(done), total: Double(max(unit.lessons.count, 1))).tint(color)
            ForEach(unit.lessons) { lesson in
                NavigationLink {
                    LessonPlayer(lesson: lesson, color: color)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: store.isDone("course:\(lesson.id)") ? "checkmark.circle.fill" : "play.circle")
                            .font(.title3)
                            .foregroundStyle(store.isDone("course:\(lesson.id)") ? Theme.success : color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lesson.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                            Text(lesson.summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text("\(lesson.minutes) min").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
}

// MARK: - Lesson player

struct LessonPlayer: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let lesson: CourseLesson
    var color: Color = Theme.accent

    @State private var step = 0
    @State private var picked: [Int: String] = [:]
    @State private var finished = false

    private var current: CourseStep { lesson.steps[step] }
    private var quizScore: (Int, Int) {
        let quizzes = lesson.steps.enumerated().filter { $0.element.kind == "quiz" }
        return (quizzes.filter { picked[$0.offset] == $0.element.answer }.count, quizzes.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(lesson.steps.indices, id: \.self) { index in
                    Capsule().fill(index <= step || finished ? color : color.opacity(0.18)).frame(height: 5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                if finished {
                    completion
                } else {
                    stepView(current, index: step)
                        .padding(20)
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            ActionBar {
                if finished {
                    Button { dismiss() } label: { Text("Done").font(.headline).frame(maxWidth: .infinity) }
                        .primaryAction(color)
                } else {
                    if step > 0 {
                        Button { withAnimation(.snappy) { step -= 1 } } label: {
                            Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 36)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        advance()
                    } label: {
                        Text(step + 1 < lesson.steps.count ? "Continue" : "Finish Lesson").font(.headline).frame(maxWidth: .infinity)
                    }
                    .primaryAction(color)
                    .disabled(current.kind == "quiz" && picked[step] == nil)
                }
            }
        }
        .navigationTitle(lesson.title)
        .inlineTitle()
        .sensoryFeedback(.success, trigger: finished)
    }

    @ViewBuilder private func stepView(_ step: CourseStep, index: Int) -> some View {
        switch step.kind {
        case "quiz":
            VStack(alignment: .leading, spacing: 16) {
                Label("Quick check", systemImage: "questionmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(color)
                Text(step.question ?? "").font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                ForEach(step.options ?? [], id: \.self) { option in
                    let chosen = picked[index]
                    let isAnswer = option == step.answer
                    Button {
                        if chosen == nil { withAnimation(.snappy) { picked[index] = option } }
                    } label: {
                        HStack {
                            Text(option).multilineTextAlignment(.leading)
                            Spacer()
                            if chosen != nil && isAnswer {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                            } else if chosen == option {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.failure)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            chosen == nil ? Theme.card : isAnswer ? Theme.success.opacity(0.16) : chosen == option ? Theme.failure.opacity(0.16) : Theme.card,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if let chosen = picked[index] {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(chosen == step.answer ? "Correct!" : "Not quite").font(.headline)
                            .foregroundStyle(chosen == step.answer ? Theme.success : Theme.failure)
                        if let why = step.why { Text(why).font(.subheadline) }
                    }
                    .cardStyle()
                    .transition(.opacity)
                }
            }
            .sensoryFeedback(trigger: picked[index]) { _, value in
                value == nil ? nil : (value == step.answer ? .success : .error)
            }
        default:
            let style = cardStyle(step.kind)
            VStack(alignment: .leading, spacing: 14) {
                Label(style.label, systemImage: style.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(style.color)
                Text(step.title ?? "").font(.title2.weight(.bold))
                GuideText(text: step.body ?? "")
                    .font(step.kind == "example" ? .callout : .body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .leading) {
                if step.kind != "explain" {
                    UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20)
                        .fill(style.color).frame(width: 5)
                }
            }
        }
    }

    private func cardStyle(_ kind: String) -> (label: String, symbol: String, color: Color) {
        switch kind {
        case "tip": return ("Tip", "lightbulb.fill", .orange)
        case "example": return ("Example", "text.quote", .teal)
        default: return ("Lesson", "book.fill", color)
        }
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 72)).foregroundStyle(Theme.success).padding(.top, 40)
            Text("Lesson complete").font(.title.weight(.bold))
            Text(lesson.title).font(.headline).foregroundStyle(.secondary)
            let (right, total) = quizScore
            if total > 0 {
                Text("You answered \(right) of \(total) checks correctly.").font(.subheadline)
            }
            Tag(text: "+30 XP", symbol: "star.fill", color: .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .overlay { Confetti() }
    }

    private func advance() {
        if step + 1 < lesson.steps.count {
            withAnimation(.snappy) { step += 1 }
        } else {
            store.markDone("course:\(lesson.id)", xp: 30)
            withAnimation(.snappy) { finished = true }
        }
    }
}

// MARK: - Learn tab

struct LearnScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    StreakBadge(days: store.streak)
                    Spacer()
                    DailyGoalRing(xp: store.todayXP, goal: store.learning.dailyGoal)
                }

                NavigationLink {
                    GrammarHome()
                } label: {
                    HeroCard(title: "Grammar", subtitle: "A \(GrammarCourse.units.count)-unit IELTS grammar course from B1 to C1, plus the Mentors' grammar book",
                             symbol: "text.book.closed.fill", colors: [.blue, .indigo],
                             progress: store.courseProgress,
                             footer: "\(GrammarCourse.essentials.count) units marked essential for IELTS · \(GrammarCourse.units.reduce(0) { $0 + $1.practice.count } + Library.grammar.chapters.reduce(0) { $0 + $1.questionCount }) practice questions")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    VocabularyHome()
                } label: {
                    HeroCard(title: "Vocabulary", subtitle: "\(Library.vocabulary.count.formatted()) words from A1 to C2 with meanings, pronunciation and real examples",
                             symbol: "character.book.closed.fill", colors: [.purple, .pink],
                             progress: Library.vocabulary.isEmpty ? 0 : Double(store.learnedWordCount) / Double(Library.vocabulary.count),
                             footer: store.dueWords.isEmpty ? "\(store.learnedWordCount) words learned" : "\(store.dueWords.count) words due for review")
                }
                .buttonStyle(.plain)

                if let word = WordPools.wordOfTheDay {
                    NavigationLink {
                        WordDetail(word: word)
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(symbol: "sun.max.fill", color: .orange, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Word of the day").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                                Text(word.w).font(.headline)
                                Text(word.d).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .cardStyle(padding: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Learn")
    }

    private var grammarProgress: Double {
        let chapters = Library.grammar.chapters
        return chapters.isEmpty ? 0 : chapters.map { store.chapterProgress($0) }.reduce(0, +) / Double(chapters.count)
    }
}

struct HeroCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
    let progress: Double
    let footer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol).font(.system(size: 30, weight: .semibold))
                Spacer()
                Text("\(Int((progress * 100).rounded()))%").font(.headline).monospacedDigit()
            }
            Text(title).font(.title.weight(.bold))
            Text(subtitle).font(.subheadline).opacity(0.9).multilineTextAlignment(.leading)
            ProgressView(value: progress).tint(.white)
            Text(footer).font(.caption.weight(.semibold)).opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
