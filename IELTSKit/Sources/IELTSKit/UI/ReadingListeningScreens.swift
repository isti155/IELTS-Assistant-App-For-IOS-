import SwiftUI

// MARK: - Reading

struct ReadingTestView: View {
    @EnvironmentObject private var store: AppStore
    let test: ReadingTest

    private enum Pane: String, CaseIterable { case passage = "Passage", questions = "Questions" }

    @State private var pane = Pane.passage
    @State private var answers: [Int: String] = [:]
    @State private var submitted = false
    @State private var confirmSubmit = false
    @State private var start = Date()

    private var correct: Int { Marking.score(test.questions, answers: answers) }
    private var answered: Int { test.questions.filter { !(answers[$0.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count }
    private var band: Double {
        BandMath.academicReadingBand(raw: BandMath.scaledRaw(correct: correct, total: test.questions.count))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if pane == .passage {
                    PassageView(title: test.title, passage: test.passage)
                } else {
                    if submitted {
                        ScoreSummary(correct: correct, total: test.questions.count, band: band, color: Skill.reading.color)
                    }
                    QuestionsView(questions: test.questions, answers: $answers, submitted: submitted, color: Skill.reading.color)
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
                    Text("\(answered) of \(test.questions.count) answered")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Button {
                        if answered < test.questions.count { confirmSubmit = true } else { submit() }
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
        .confirmationDialog("Submit with \(test.questions.count - answered) unanswered?", isPresented: $confirmSubmit, titleVisibility: .visible) {
            Button("Submit") { submit() }
            Button("Keep Working", role: .cancel) {}
        } message: {
            Text("There is no penalty for wrong answers, so it is worth guessing.")
        }
        .sensoryFeedback(.success, trigger: submitted)
    }

    private func submit() {
        withAnimation {
            submitted = true
            pane = .questions
        }
        store.record(Attempt(
            skill: .reading, title: test.title, prompt: test.title, response: "",
            band: band, rawScore: correct, total: test.questions.count, estimated: true
        ))
    }
}

/// A reading passage with its paragraph letters set in the margin.
struct PassageView: View {
    let title: String
    let passage: String

    private var paragraphs: [(letter: String?, text: String)] {
        passage.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map { line in
            if line.count > 3, let first = line.first, first.isUppercase, line.dropFirst().hasPrefix(". ") {
                return (String(first), String(line.dropFirst(3)))
            }
            return (nil, line)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.bold))
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let letter = paragraph.letter {
                        Text(letter)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Skill.reading.color)
                            .frame(width: 18)
                    }
                    Text(paragraph.text)
                        .font(.body)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .cardStyle(padding: 18)
    }
}

// MARK: - Listening

struct ListeningTestView: View {
    @EnvironmentObject private var store: AppStore
    let test: ListeningTest

    @StateObject private var speaker = Speaker()
    @State private var answers: [Int: String] = [:]
    @State private var submitted = false
    @State private var played = false
    @State private var playing = false
    @State private var segment = 0
    @State private var playback: Task<Void, Never>?

    private var correct: Int { Marking.score(test.questions, answers: answers) }
    private var band: Double {
        BandMath.listeningBand(raw: BandMath.scaledRaw(correct: correct, total: test.questions.count))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                player
                if submitted {
                    ScoreSummary(correct: correct, total: test.questions.count, band: band, color: Skill.listening.color)
                }
                QuestionsView(questions: test.questions, answers: $answers, submitted: submitted, color: Skill.listening.color)
                if submitted { transcript }
            }
            .padding(16)
        }
        .dismissKeyboardOnScroll()
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            if !submitted {
                ActionBar {
                    Text(played ? (playing ? "Listen and answer" : "Check your answers") : "Read the questions first")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        submit()
                    } label: {
                        Text("Submit").font(.headline).padding(.horizontal, 8)
                    }
                    .primaryAction(Skill.listening.color)
                    .disabled(!played || playing)
                }
            }
        }
        .navigationTitle(test.title)
        .inlineTitle()
        .onDisappear {
            playback?.cancel()
            speaker.stop()
        }
        .sensoryFeedback(.success, trigger: submitted)
    }

    private var player: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(test.context).font(.subheadline)
            HStack(spacing: 16) {
                Button {
                    play()
                } label: {
                    Image(systemName: played ? (playing ? "waveform" : "checkmark") : "play.fill")
                        .font(.title2.weight(.semibold))
                        .symbolEffect(.variableColor.iterative, isActive: playing)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(played && !playing ? Color.secondary.gradient : Skill.listening.color.gradient, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(played)
                .accessibilityLabel(played ? (playing ? "Playing" : "Finished") : "Play recording")

                VStack(alignment: .leading, spacing: 6) {
                    Text(played ? (playing ? "Playing" : "Recording finished") : "Plays once only")
                        .font(.headline)
                    ProgressView(value: Double(played && !playing ? test.segments.count : segment), total: Double(max(test.segments.count, 1)))
                        .tint(Skill.listening.color)
                    Text(playing ? "Part \(segment + 1) of \(test.segments.count)" : speakerSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .cardStyle()
    }

    private var speakerSummary: String {
        let speakers = Set(test.segments.map(\.speaker)).count
        return speakers == 1 ? "One speaker" : "\(speakers) speakers"
    }

    private var transcript: some View {
        DisclosureGroup("Transcript") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(test.segments.enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.speaker).font(.caption.weight(.semibold)).foregroundStyle(Skill.listening.color)
                        Text(line.text).font(.subheadline)
                    }
                }
            }
            .padding(.top, 10)
        }
        .font(.headline)
        .cardStyle()
    }

    private func play() {
        played = true
        playing = true
        // Each distinct speaker keeps one voice for the whole recording.
        var voices: [String: Int] = [:]
        for line in test.segments where voices[line.speaker] == nil {
            voices[line.speaker] = voices.count
        }
        playback = Task { @MainActor in
            for (index, line) in test.segments.enumerated() {
                if Task.isCancelled { break }
                segment = index
                await speaker.speak(line.text, voice: voices[line.speaker] ?? 0)
            }
            playing = false
        }
    }

    private func submit() {
        withAnimation { submitted = true }
        store.record(Attempt(
            skill: .listening, title: test.title, prompt: test.context, response: "",
            band: band, rawScore: correct, total: test.questions.count, estimated: true
        ))
    }
}
