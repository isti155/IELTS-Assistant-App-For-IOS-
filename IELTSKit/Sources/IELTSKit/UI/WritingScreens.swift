import SwiftUI

/// The skill's icon, description and real-test format, shown at the top of each skill screen.
struct SkillHeader: View {
    let skill: Skill

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SkillIcon(skill: skill, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.tagline).font(.subheadline)
                Text(skill.format).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

struct WritingEditor: View {
    @EnvironmentObject private var store: AppStore
    @State private var task: WritingTask

    @State private var text = ""
    @State private var start = Date()
    @State private var busy = false
    @State private var error: String?
    @State private var evaluation: Evaluation?
    @State private var commentary = ""
    @State private var commenting = false
    @State private var confirmShort = false
    @FocusState private var editing: Bool

    /// Name the result is saved under (book tests use "Cambridge 18 · Test 2 · Writing Task 2").
    private let attemptTitle: String?

    /// - Parameter task: nil picks a random Task 2 question from the bank.
    init(task: WritingTask?, attemptTitle: String? = nil) {
        _task = State(initialValue: task ?? QuestionBank.shared.randomTask2())
        self.attemptTitle = attemptTitle
    }

    private var words: Int { Marking.wordCount(text) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                question
                if let evaluation {
                    EvaluationView(evaluation: evaluation, color: Skill.writing.color)
                    if let sample = task.sample {
                        DisclosureGroup {
                            Text(sample).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                        } label: {
                            Label(task.sampleBand.map { "Compare with a band \(bandText($0)) answer" } ?? "Compare with a sample answer",
                                  systemImage: "doc.text.magnifyingglass")
                        }
                        .font(.headline)
                        .cardStyle()
                    }
                    commentarySection
                    DisclosureGroup("Your answer · \(words) words") {
                        Text(text).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }
                    .font(.headline)
                    .cardStyle()
                } else {
                    editor
                    ErrorText(message: error)
                }
            }
            .padding(16)
        }
        .dismissKeyboardOnScroll()
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            if evaluation == nil { bottomBar }
        }
        .navigationTitle("Task \(task.taskNumber)")
        .inlineTitle()
        .toolbar {
            if editing {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { editing = false }
                }
            }
        }
        .confirmationDialog("Your answer is under \(task.minimumWords) words", isPresented: $confirmShort, titleVisibility: .visible) {
            Button("Submit Anyway") { Task { await submit() } }
            Button("Keep Writing", role: .cancel) {}
        } message: {
            Text("It has \(words) words. In the test, a short answer loses marks for Task \(task.taskNumber == 1 ? "Achievement" : "Response").")
        }
        .sensoryFeedback(.success, trigger: evaluation)
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Tag(text: "Task \(task.taskNumber)", color: Skill.writing.color)
                Tag(text: "\(task.minutes) min", symbol: "clock")
                Tag(text: "\(task.minimumWords)+ words", symbol: "text.word.spacing")
            }
            Text(task.prompt).font(.body).fixedSize(horizontal: false, vertical: true)
            if let chart = task.chart { ChartSpecView(spec: chart) }
            if let image = task.image { Task1Image(name: image) }
        }
        .cardStyle()
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Start writing your answer…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .focused($editing)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 360)
                .disabled(busy)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay {
            if busy {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Marking your answer…").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
    }

    private var bottomBar: some View {
        ActionBar {
            VStack(alignment: .leading, spacing: 4) {
                TimerLabel(start: start, minutes: task.minutes)
                HStack(spacing: 6) {
                    Gauge(value: min(Double(words), Double(task.minimumWords)), in: 0...Double(task.minimumWords)) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(words >= task.minimumWords ? Theme.success : Skill.writing.color)
                    .frame(width: 70)
                    Text("\(words) words")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                editing = false
                if words < task.minimumWords {
                    confirmShort = true
                } else {
                    Task { await submit() }
                }
            } label: {
                Text("Submit").font(.headline).padding(.horizontal, 8)
            }
            .primaryAction(Skill.writing.color)
            .disabled(words < 20 || busy)
        }
    }

    /// Comments from the optional on-device language model.
    @ViewBuilder private var commentarySection: some View {
        if store.generator != nil {
            VStack(alignment: .leading, spacing: 10) {
                Label("Comments on your ideas", systemImage: "sparkles").font(.headline)
                if commentary.isEmpty && !commenting {
                    Text("Ask the on-device model how well your ideas are developed. It is given the bands and errors above and does not change them.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Comment on My Ideas") { Task { await comment() } }
                        .buttonStyle(.bordered)
                        .tint(Skill.writing.color)
                } else {
                    Text(markdown(commentary.isEmpty ? "…" : commentary)).font(.subheadline)
                }
            }
            .cardStyle()
        }
    }

    @MainActor private func comment() async {
        guard let generator = store.generator, let evaluation else { return }
        commenting = true
        let request = ChatMessage(
            role: "user",
            text: "\(Prompts.feedbackFacts(evaluation))\n\nQuestion: \(task.prompt)\n\nEssay:\n\(text)"
        )
        do {
            _ = try await generator.generate(system: Prompts.feedback, messages: [request], maxTokens: 250) { piece in
                commentary += piece
            }
        } catch {
            commentary = "Could not generate comments: \(error.localizedDescription)"
        }
        commenting = false
    }

    @MainActor private func submit() async {
        busy = true
        error = nil
        do {
            let result = try await store.examiner.evaluateWriting(task: task, response: text)
            withAnimation { evaluation = result }
            store.record(Attempt(
                skill: .writing, title: attemptTitle ?? "Writing Task \(task.taskNumber)", prompt: task.prompt,
                response: text, band: result.band, evaluation: result
            ))
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
