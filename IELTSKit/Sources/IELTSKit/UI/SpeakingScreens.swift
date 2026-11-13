import SwiftUI

// MARK: - Mock test

/// Runs the three-part test the way an examiner does: from a fixed script, with fixed timings.
@MainActor
final class SpeakingSession: ObservableObject {
    enum Phase { case idle, examiner, answering, preparing, marking, finished, failed }

    @Published var phase = Phase.idle
    @Published var part = 1
    @Published var examinerLine = ""
    @Published var cueCard: CueCard?
    @Published var secondsLeft = 0
    @Published var limit = 1
    @Published var turns: [SpeakingTurn] = []
    @Published var evaluation: Evaluation?
    @Published var error: String?

    let speaker = Speaker()
    let transcriber = SpeechTranscriber()
    /// Name the result is saved under.
    var title = "Speaking mock test"
    private var moveOn = false
    private var runner: Task<Void, Never>?

    func start(script: SpeakingScript, store: AppStore) {
        guard runner == nil else { return }
        runner = Task {
            do {
                try await run(script)
                await mark(store: store)
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
                phase = .failed
            }
        }
    }

    /// The candidate has finished an answer (or wants to skip the rest of the preparation time).
    func next() { moveOn = true }

    func cancel() {
        runner?.cancel()
        speaker.stop()
        Task { _ = await transcriber.stop() }
    }

    func mark(store: AppStore) async {
        phase = .marking
        error = nil
        do {
            let result = try await store.examiner.evaluateSpeaking(turns: turns)
            evaluation = result
            let transcript = turns.map { "Q: \($0.question)\nA: \($0.transcript)" }.joined(separator: "\n\n")
            store.record(Attempt(
                skill: .speaking, title: title, prompt: title,
                response: transcript, band: result.band, evaluation: result
            ))
            phase = .finished
        } catch {
            self.error = error.localizedDescription
            phase = .failed
        }
    }

    private func run(_ script: SpeakingScript) async throws {
        if !script.part1.isEmpty {
            try await say("Good morning. My name is Alex, and I'll be your examiner today. In this first part, I'd like to ask you some questions about yourself.")
            for question in script.part1 {
                try await ask(question, part: 1, limit: 40)
            }
        }
        guard !script.cueCard.topic.isEmpty else {
            try await say("Thank you. That is the end of this practice.")
            return
        }

        part = 2
        cueCard = script.cueCard
        try await say("Now I'm going to give you a topic, and I'd like you to talk about it for one to two minutes. Before you talk, you'll have one minute to think about what you're going to say. Here is your topic. \(script.cueCard.topic)")
        phase = .preparing
        try await wait(seconds: 60)
        try await say("All right? Remember, you have one to two minutes for this, so don't worry if I stop you. Can you start speaking now, please?")
        let card = script.cueCard.topic + " You should say: " + script.cueCard.bullets.joined(separator: "; ")
        try await answer(to: card, part: 2, limit: 120)
        try await say("Thank you.")
        if !script.roundingOff.isEmpty {
            try await ask(script.roundingOff, part: 2, limit: 30)
        }

        part = 3
        cueCard = nil
        for question in script.part3 {
            try await ask(question, part: 3, limit: 75)
        }
        try await say(script.part3.isEmpty ? "Thank you. That is the end of this practice." : "Thank you very much. That is the end of the speaking test.")
    }

    private func say(_ line: String) async throws {
        try Task.checkCancellation()
        phase = .examiner
        examinerLine = line
        await speaker.speak(line)
        try Task.checkCancellation()
    }

    private func ask(_ question: String, part: Int, limit: Int) async throws {
        try await say(question)
        try await answer(to: question, part: part, limit: limit)
    }

    private func answer(to question: String, part: Int, limit: Int) async throws {
        try await transcriber.start()
        phase = .answering
        try await wait(seconds: limit)
        let spoken = await transcriber.stop()
        turns.append(SpeakingTurn(part: part, question: question, transcript: spoken.transcript, metrics: spoken.metrics))
    }

    /// Waits until the time limit or until the candidate taps to move on.
    private func wait(seconds: Int) async throws {
        moveOn = false
        limit = max(seconds, 1)
        secondsLeft = seconds
        while !moveOn && secondsLeft > 0 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            secondsLeft -= 1
        }
    }
}

struct LiveTranscript: View {
    @ObservedObject var transcriber: SpeechTranscriber

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Live transcript", systemImage: "text.bubble").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(transcriber.transcript.isEmpty ? "Start speaking…" : transcriber.transcript)
                .font(.callout)
                .foregroundStyle(transcriber.transcript.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }
}

/// Seconds remaining shown as a shrinking ring around an icon.
struct CountdownRing: View {
    let remaining: Int
    let total: Int
    let symbol: String
    let color: Color
    var pulsing = false

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(total, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, isActive: pulsing)
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) seconds left")
    }
}

struct PartProgress: View {
    let part: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(index <= part ? Skill.speaking.color : Theme.fill)
                        .frame(height: 5)
                    Text("Part \(index)")
                        .font(.caption.weight(index == part ? .bold : .regular))
                        .foregroundStyle(index == part ? Color.primary : Color.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Part \(part) of 3")
    }
}

struct CueCardView: View {
    let card: CueCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cue card", systemImage: "rectangle.and.pencil.and.ellipsis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Skill.speaking.color)
            Text(card.topic).font(.title3.weight(.semibold))
            Text("You should say:").font(.subheadline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(card.bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Skill.speaking.color).frame(width: 6, height: 6)
                        Text(bullet)
                    }
                }
            }
        }
        .cardStyle(padding: 18)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Skill.speaking.color.opacity(0.35), lineWidth: 1)
        )
    }
}

struct SpeakingTestView: View {
    @EnvironmentObject private var store: AppStore
    @State private var script: SpeakingScript
    @StateObject private var session = SpeakingSession()

    private let attemptTitle: String?

    /// - Parameter script: nil builds a test from random questions.
    init(script: SpeakingScript?, attemptTitle: String? = nil) {
        _script = State(initialValue: script ?? SpeakingContent.randomScript())
        self.attemptTitle = attemptTitle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch session.phase {
                case .idle: intro
                case .examiner, .answering, .preparing: live
                case .marking: BusyCard(label: "Marking your test…")
                case .finished, .failed: results
                }
            }
            .padding(16)
            .animation(.snappy, value: session.phase)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Speaking test")
        .inlineTitle()
        .onDisappear { session.cancel() }
        .sensoryFeedback(.success, trigger: session.evaluation)
    }

    @ViewBuilder private var bottomBar: some View {
        switch session.phase {
        case .idle:
            ActionBar {
                Button {
                    if let attemptTitle { session.title = attemptTitle }
                    session.start(script: script, store: store)
                } label: {
                    Label("Begin Test", systemImage: "mic.fill").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(Skill.speaking.color)
            }
        case .answering:
            ActionBar {
                Button {
                    session.next()
                } label: {
                    Text("I've Finished").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(Skill.speaking.color)
            }
        case .preparing:
            ActionBar {
                Button {
                    session.next()
                } label: {
                    Text("I'm Ready to Speak").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(.orange)
            }
        default:
            EmptyView()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                partRow(1, "person.fill.questionmark", "Introduction and interview", "Short questions about you and familiar topics · 4–5 min")
                Divider().padding(.leading, 52)
                partRow(2, "rectangle.and.pencil.and.ellipsis", "Long turn", "One minute to prepare, then talk for up to two minutes")
                Divider().padding(.leading, 52)
                partRow(3, "bubble.left.and.bubble.right.fill", "Discussion", "Wider questions linked to Part 2 · 4–5 min")
            }
            .cardStyle(padding: 14)

            VStack(alignment: .leading, spacing: 10) {
                Label("Before you start", systemImage: "lightbulb.fill").font(.headline).foregroundStyle(.orange)
                tip("Find a quiet place and hold the phone about 30 cm away.")
                tip("Tap “I've Finished” after each answer. If you run over, the examiner moves on.")
                tip("Your speech is transcribed and scored on this iPhone.")
            }
            .cardStyle()
        }
    }

    private func partRow(_ number: Int, _ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: Skill.speaking.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Part \(number) · \(title)").font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(text).font(.subheadline)
        }
    }

    private var live: some View {
        VStack(alignment: .leading, spacing: 16) {
            PartProgress(part: session.part)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: session.phase == .examiner ? "waveform" : "person.fill")
                    .font(.title3)
                    .symbolEffect(.variableColor.iterative, isActive: session.phase == .examiner)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.gradient, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Examiner").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(session.examinerLine).font(.body)
                }
            }
            .cardStyle()

            if let card = session.cueCard { CueCardView(card: card) }

            if session.phase == .preparing {
                VStack(spacing: 10) {
                    CountdownRing(remaining: session.secondsLeft, total: session.limit, symbol: "hourglass", color: .orange)
                    Text("Preparation time — make a few notes").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .cardStyle(padding: 20)
            }
            if session.phase == .answering {
                VStack(spacing: 10) {
                    CountdownRing(remaining: session.secondsLeft, total: session.limit, symbol: "mic.fill", color: .red, pulsing: true)
                    Text("Recording your answer").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .cardStyle(padding: 20)
                LiveTranscript(transcriber: session.transcriber)
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorText(message: session.error)
            if let evaluation = session.evaluation {
                EvaluationView(evaluation: evaluation, color: Skill.speaking.color)
            } else if !session.turns.isEmpty {
                Button("Try Marking Again") { Task { await session.mark(store: store) } }
                    .primaryAction(Skill.speaking.color)
            }
            TranscriptList(turns: session.turns)
        }
    }
}

struct TranscriptList: View {
    let turns: [SpeakingTurn]

    var body: some View {
        if !turns.isEmpty {
            DisclosureGroup("Your transcript") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(turns) { turn in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Part \(turn.part) · \(turn.question)").font(.footnote).foregroundStyle(.secondary)
                            Text(turn.transcript.isEmpty ? "(nothing recognised)" : turn.transcript).font(.subheadline)
                            Text("\(Int(turn.metrics.wordsPerMinute)) words/min · \(turn.metrics.longPauses) long pauses")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.top, 10)
            }
            .font(.headline)
            .cardStyle()
        }
    }
}

// MARK: - Conversation partner

@MainActor
final class PartnerSession: ObservableObject {
    enum Phase { case ready, recording, thinking, speaking, marking }

    @Published var phase = Phase.ready
    @Published var shown: [ChatMessage] = []
    @Published var turns: [SpeakingTurn] = []
    @Published var evaluation: Evaluation?
    @Published var error: String?

    let speaker = Speaker()
    let transcriber = SpeechTranscriber()
    private static let opener = "Hi! Let's have a chat to warm up your English. What have you been doing today?"
    // The API needs the conversation to open with a user turn, so the opener is framed as a reply.
    private var history = [
        ChatMessage(role: "user", text: "(The conversation starts now. Greet me and ask an opening question.)"),
        ChatMessage(role: "assistant", text: opener),
    ]

    func begin() async {
        guard shown.isEmpty else { return }
        shown = [ChatMessage(role: "assistant", text: Self.opener)]
        phase = .speaking
        await speaker.speak(Self.opener, voice: 0)
        if phase == .speaking { phase = .ready }
    }

    func toggleMicrophone(store: AppStore) async {
        error = nil
        if phase == .recording {
            await send(store: store)
        } else if phase == .ready || phase == .speaking {
            speaker.stop()
            do {
                try await transcriber.start()
                phase = .recording
            } catch {
                self.error = error.localizedDescription
                phase = .ready
            }
        }
    }

    private func send(store: AppStore) async {
        let spoken = await transcriber.stop()
        guard !spoken.transcript.isEmpty else {
            error = "I didn't catch that. Tap the microphone and try again."
            phase = .ready
            return
        }
        let question = history.last?.text ?? ""
        turns.append(SpeakingTurn(part: 3, question: question, transcript: spoken.transcript, metrics: spoken.metrics))
        let message = ChatMessage(role: "user", text: spoken.transcript)
        history.append(message)
        shown.append(message)
        phase = .thinking
        do {
            let reply = try await nextReply(to: spoken.transcript, store: store)
            let answer = ChatMessage(role: "assistant", text: reply)
            history.append(answer)
            shown.append(answer)
            phase = .speaking
            await speaker.speak(reply, voice: 0)
            if phase == .speaking { phase = .ready }
        } catch {
            self.error = error.localizedDescription
            phase = .ready
        }
    }

    /// With a language model installed the partner replies freely. Without one it
    /// points out a detected slip and moves on to a new discussion question.
    private func nextReply(to transcript: String, store: AppStore) async throws -> String {
        if let generator = store.generator {
            return try await generator.generate(system: Prompts.partner, messages: history, maxTokens: 160) { _ in }
        }
        var reply = ""
        if let slip = WritingAnalysis.findCorrections(in: transcript).first(where: { $0.category == "grammar" }) {
            reply = "A more natural way to say \(slip.original) is \(slip.corrected). "
        } else if Marking.wordCount(transcript) < 20 {
            reply = "Try to say a little more next time: give a reason and an example. "
        } else {
            reply = ["Thank you.", "I see.", "That's interesting.", "Right."].randomElement()! + " "
        }
        let unused = SpeakingContent.discussion.filter { question in !history.contains { $0.text.contains(question) } }
        return reply + (unused.randomElement() ?? SpeakingContent.discussion.randomElement()!)
    }

    func finish(store: AppStore) async {
        speaker.stop()
        phase = .marking
        error = nil
        do {
            let result = try await store.examiner.evaluateSpeaking(turns: turns)
            evaluation = result
            let transcript = turns.map { "Q: \($0.question)\nA: \($0.transcript)" }.joined(separator: "\n\n")
            store.record(Attempt(
                skill: .speaking, title: "Speaking partner conversation", prompt: "Free conversation",
                response: transcript, band: result.band, evaluation: result
            ))
        } catch {
            self.error = error.localizedDescription
        }
        phase = .ready
    }

    func cancel() {
        speaker.stop()
        Task { _ = await transcriber.stop() }
    }
}

struct PartnerView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var session = PartnerSession()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let evaluation = session.evaluation {
                        EvaluationView(evaluation: evaluation, color: Skill.speaking.color)
                        TranscriptList(turns: session.turns)
                    } else {
                        if store.generator == nil {
                            Label("Without the language model, your partner asks discussion questions and points out slips it detects.",
                                  systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                        }
                        ForEach(session.shown) { message in
                            ChatBubble(text: message.text, isUser: message.role == "user").id(message.id)
                        }
                        if session.phase == .recording { LiveTranscript(transcriber: session.transcriber) }
                        if session.phase == .thinking { ProgressView().padding(.leading, 8) }
                        if session.phase == .marking { BusyCard(label: "Scoring your conversation…") }
                        ErrorText(message: session.error)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .padding(16)
            }
            .onChange(of: session.shown.count) { withAnimation { proxy.scrollTo("bottom") } }
            .onChange(of: session.phase) { withAnimation { proxy.scrollTo("bottom") } }
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            if session.evaluation == nil { micBar }
        }
        .navigationTitle("Conversation")
        .inlineTitle()
        .toolbar {
            if session.evaluation == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Finish") { Task { await session.finish(store: store) } }
                        .disabled(session.turns.count < 3 || session.phase != .ready)
                }
            }
        }
        .task { await session.begin() }
        .onDisappear { session.cancel() }
    }

    private var micBar: some View {
        let recording = session.phase == .recording
        return ActionBar {
            VStack(alignment: .leading, spacing: 2) {
                Text(status).font(.subheadline.weight(.semibold))
                Text(session.turns.count < 3 ? "Answer at least 3 times to get a band" : "Tap Finish for your band estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await session.toggleMicrophone(store: store) }
            } label: {
                Image(systemName: recording ? "arrow.up" : "mic.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background((recording ? Color.red : Skill.speaking.color).gradient, in: Circle())
                    .symbolEffect(.pulse, isActive: recording)
            }
            .buttonStyle(.plain)
            .disabled(session.phase == .thinking || session.phase == .marking)
            .accessibilityLabel(recording ? "Send answer" : "Start speaking")
        }
    }

    private var status: String {
        switch session.phase {
        case .ready: return "Tap the microphone to answer"
        case .recording: return "Listening… tap to send"
        case .thinking: return "Thinking…"
        case .speaking: return "Your partner is speaking"
        case .marking: return "Scoring…"
        }
    }
}
