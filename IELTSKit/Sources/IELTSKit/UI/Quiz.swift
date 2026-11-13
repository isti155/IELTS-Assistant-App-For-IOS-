import SwiftUI

/// One question in an interactive practice session.
struct QuizItem: Identifiable {
    enum Kind {
        /// Tap one option.
        case choice(options: [String], answer: String)
        /// Type into one field per gap; each answer may list alternatives separated by "/".
        case typed(answers: [String], hints: [String?])
        /// Tap word tiles to build the sentence.
        case build(answer: String)
        /// Tap the words that need a capital letter.
        case capitalize(words: [String], targets: Set<Int>)
        /// Tap the words that should be followed by a comma.
        case punctuate(words: [String], targets: Set<Int>)
        /// Think, reveal the answer, then say whether you were right.
        case reveal(answer: String)
        /// Tap the word or phrase that contains the mistake.
        case findError(words: [String], target: Int, correction: String)
    }

    let id = UUID()
    var prompt: String
    var instruction: String?
    var kind: Kind
    var explanation: String?
    /// Text the speaker button reads aloud (vocabulary).
    var speak: String?
    /// Lets the caller link a result back to its source (a vocabulary word id).
    var tag: String?

    var correctAnswerText: String {
        switch kind {
        case .choice(_, let answer): return answer
        case .typed(let answers, _): return answers.map { $0.isEmpty ? "(no word)" : $0.replacingOccurrences(of: "/", with: " / ") }.joined(separator: " · ")
        case .build(let answer), .reveal(let answer): return answer
        case .capitalize(let words, let targets):
            return words.enumerated().map { targets.contains($0.offset) ? $0.element.prefix(1).uppercased() + $0.element.dropFirst() : $0.element }.joined(separator: " ")
        case .punctuate(let words, let targets):
            return words.enumerated().map { targets.contains($0.offset) ? $0.element + "," : $0.element }.joined(separator: " ")
        case .findError(let words, let target, let correction):
            let wrong = target >= 0 && target < words.count ? words[target] : ""
            if correction == "(delete)" { return "Delete “\(wrong)”" }
            return "“\(wrong)” → “\(correction)”"
        }
    }
}

/// Runs a list of questions one at a time with instant feedback and a results screen.
struct QuizRunner: View {
    let title: String
    let color: Color
    let items: [QuizItem]
    var onAnswer: ((QuizItem, Bool) -> Void)?
    var onFinish: (_ correct: Int, _ total: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var results: [Bool] = []
    @State private var checked = false
    @State private var lastCorrect = false
    @State private var finished = false
    @State private var choice: String?
    @State private var typed: [String] = []
    @State private var chosenTiles: [Int] = []
    @State private var tileOrder: [Int] = []
    @State private var tapped: Set<Int> = []
    @State private var revealed = false
    @StateObject private var speaker = Speaker()
    @FocusState private var focusedField: Int?

    private var item: QuizItem { items[index] }

    var body: some View {
        Group {
            if finished || items.isEmpty {
                QuizResults(title: title, color: color, items: items, results: results) {
                    restart()
                } done: {
                    dismiss()
                }
            } else {
                question
            }
        }
        .screenBackground()
        .navigationTitle(title)
        .inlineTitle()
        .onAppear { prepare() }
        .sensoryFeedback(trigger: results.count) { _, _ in
            lastCorrect ? .success : .error
        }
    }

    // MARK: Question screen

    private var question: some View {
        VStack(spacing: 0) {
            progressHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let instruction = item.instruction {
                        Text(instruction).font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top) {
                        Text(displayPrompt)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if let speak = item.speak {
                            Button {
                                Task { await speaker.speak(speak) }
                            } label: {
                                Image(systemName: "speaker.wave.2.fill").font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(color.opacity(0.14), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(color)
                            .accessibilityLabel("Play pronunciation")
                        }
                    }
                    input
                }
                .padding(20)
                .id(index)
            }
            .dismissKeyboardOnScroll()
            bottom
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color.gradient)
                        .frame(width: geometry.size.width * CGFloat(index + (checked ? 1 : 0)) / CGFloat(max(items.count, 1)))
                        .animation(.snappy, value: index)
                }
            }
            .frame(height: 10)
            Text("\(index + 1)/\(items.count)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var displayPrompt: String {
        var count = 0
        let pattern = try? NSRegularExpression(pattern: "_{2,}")
        guard let pattern else { return item.prompt }
        let text = item.prompt as NSString
        let matches = pattern.matches(in: item.prompt, range: NSRange(location: 0, length: text.length))
        if matches.count <= 1 { return pattern.stringByReplacingMatches(in: item.prompt, range: NSRange(location: 0, length: text.length), withTemplate: "_____") }
        var result = item.prompt
        for match in matches.reversed() {
            count += 1
            let number = matches.count - count + 1
            result = (result as NSString).replacingCharacters(in: match.range, with: "(\(number)) _____")
        }
        return result
    }

    @ViewBuilder private var input: some View {
        switch item.kind {
        case .choice(let options, let answer):
            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        if !checked { choice = option }
                    } label: {
                        HStack {
                            Text(option).multilineTextAlignment(.leading)
                            Spacer()
                            if checked && AnswerCheck.matches(option, answer) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                            } else if checked && option == choice {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.failure)
                            }
                        }
                        .font(.body.weight(.medium))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(optionBackground(option, answer), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(option == choice && !checked ? color : Color.clear, lineWidth: 2))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        case .typed(let answers, let hints):
            VStack(spacing: 10) {
                ForEach(answers.indices, id: \.self) { gap in
                    HStack(spacing: 10) {
                        if answers.count > 1 {
                            Text("\(gap + 1)").font(.subheadline.weight(.bold)).foregroundStyle(color)
                                .frame(width: 28, height: 28).background(color.opacity(0.14), in: Circle())
                        }
                        TextField(hintText(hints, gap), text: typedBinding(gap))
                            .answerField()
                            .focused($focusedField, equals: gap)
                            .disabled(checked)
                            .submitLabel(gap + 1 < answers.count ? .next : .done)
                            .onSubmit { focusedField = gap + 1 < answers.count ? gap + 1 : nil }
                    }
                }
            }
        case .build(let answer):
            let tokens = tokensOf(answer)
            VStack(alignment: .leading, spacing: 16) {
                FlowLayout(spacing: 8) {
                    ForEach(chosenTiles, id: \.self) { tile in
                        tileView(tokens[tile], filled: true) {
                            if !checked { chosenTiles.removeAll { $0 == tile } }
                        }
                    }
                }
                .frame(minHeight: 50, alignment: .topLeading)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Divider()
                FlowLayout(spacing: 8) {
                    ForEach(tileOrder, id: \.self) { tile in
                        let used = chosenTiles.contains(tile)
                        tileView(tokens[tile], filled: false) {
                            if !used && !checked { chosenTiles.append(tile) }
                        }
                        .opacity(used ? 0.25 : 1)
                    }
                }
            }
        case .capitalize(let words, let targets):
            FlowLayout(spacing: 8) {
                ForEach(words.indices, id: \.self) { position in
                    let on = tapped.contains(position)
                    let word = on ? words[position].prefix(1).uppercased() + words[position].dropFirst() : words[position]
                    tapWord(word, on: on, position: position, targets: targets)
                }
            }
        case .punctuate(let words, let targets):
            FlowLayout(spacing: 8) {
                ForEach(words.indices, id: \.self) { position in
                    let on = tapped.contains(position)
                    tapWord(on ? words[position] + "," : words[position], on: on, position: position, targets: targets)
                }
            }
        case .findError(let words, let target, _):
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 6) {
                    ForEach(words.indices, id: \.self) { position in
                        let picked = tapped.contains(position)
                        let state: Color = {
                            guard checked else { return picked ? color : Color.primary }
                            if position == target { return Theme.success }
                            return picked ? Theme.failure : Color.primary
                        }()
                        Button {
                            guard !checked else { return }
                            tapped = [position]
                        } label: {
                            Text(words[position])
                                .font(.title3)
                                .foregroundStyle(state)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(picked || (checked && position == target) ? state.opacity(0.14) : Theme.card,
                                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(picked ? state : Color.secondary.opacity(0.2), lineWidth: picked ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Every sentence has exactly one mistake.").font(.caption).foregroundStyle(.secondary)
            }
        case .reveal(let answer):
            if revealed {
                Text(answer)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("Think of your answer, then reveal the book's answer and mark yourself honestly.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func optionBackground(_ option: String, _ answer: String) -> Color {
        if checked {
            if AnswerCheck.matches(option, answer) { return Theme.success.opacity(0.18) }
            if option == choice { return Theme.failure.opacity(0.18) }
        }
        return option == choice ? color.opacity(0.14) : Theme.card
    }

    private func tileView(_ text: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(filled ? color.opacity(0.14) : Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.secondary.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }

    private func tapWord(_ word: String, on: Bool, position: Int, targets: Set<Int>) -> some View {
        let state: Color = {
            guard checked else { return on ? color : Color.primary }
            if targets.contains(position) { return Theme.success }
            return on ? Theme.failure : Color.primary
        }()
        return Button {
            guard !checked else { return }
            if on { tapped.remove(position) } else { tapped.insert(position) }
        } label: {
            Text(word)
                .font(.title3.weight(on || (checked && targets.contains(position)) ? .bold : .regular))
                .foregroundStyle(state)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(on ? state.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func hintText(_ hints: [String?], _ gap: Int) -> String {
        if gap < hints.count, let hint = hints[gap], !hint.isEmpty { return "Use: \(hint)" }
        return "Type your answer"
    }

    private func typedBinding(_ gap: Int) -> Binding<String> {
        Binding(get: { gap < typed.count ? typed[gap] : "" },
                set: { value in
                    while typed.count <= gap { typed.append("") }
                    typed[gap] = value
                })
    }

    private func tokensOf(_ answer: String) -> [String] {
        answer.split(separator: " ").map(String.init)
    }

    // MARK: Bottom bar

    private var bottom: some View {
        VStack(spacing: 0) {
            Divider()
            if checked {
                VStack(alignment: .leading, spacing: 10) {
                    Label(lastCorrect ? "Correct!" : "Not quite", systemImage: lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(lastCorrect ? Theme.success : Theme.failure)
                    if !lastCorrect {
                        Text("Answer: \(item.correctAnswerText)").font(.subheadline.weight(.semibold))
                    }
                    if let explanation = item.explanation, !explanation.isEmpty {
                        Text(explanation).font(.footnote).foregroundStyle(.secondary)
                    }
                    Button {
                        next()
                    } label: {
                        Text(index + 1 < items.count ? "Continue" : "See Results").font(.headline).frame(maxWidth: .infinity)
                    }
                    .primaryAction(lastCorrect ? Theme.success : Theme.failure)
                }
                .padding(16)
                .background((lastCorrect ? Theme.success : Theme.failure).opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if case .reveal = item.kind {
                HStack(spacing: 12) {
                    if revealed {
                        Button { mark(false) } label: { Text("I was wrong").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered).controlSize(.large).tint(Theme.failure)
                        Button { mark(true) } label: { Text("I was right").frame(maxWidth: .infinity) }
                            .primaryAction(Theme.success)
                    } else {
                        Button { withAnimation { revealed = true } } label: {
                            Text("Show Answer").font(.headline).frame(maxWidth: .infinity)
                        }
                        .primaryAction(color)
                    }
                }
                .padding(16)
            } else {
                Button {
                    check()
                } label: {
                    Text("Check").font(.headline).frame(maxWidth: .infinity)
                }
                .primaryAction(color)
                .disabled(!canCheck)
                .padding(16)
            }
        }
        .background(.bar)
        .animation(.snappy, value: checked)
    }

    private var canCheck: Bool {
        switch item.kind {
        case .choice: return choice != nil
        case .typed(let answers, _):
            // Allow an empty field only where "no word" is a valid answer.
            return answers.indices.allSatisfy { gap in
                let value = gap < typed.count ? typed[gap] : ""
                return !value.trimmingCharacters(in: .whitespaces).isEmpty || answers[gap].isEmpty
            }
        case .build: return !chosenTiles.isEmpty
        case .capitalize, .punctuate: return true
        case .findError: return !tapped.isEmpty
        case .reveal: return false
        }
    }

    private func check() {
        focusedField = nil
        let correct: Bool
        switch item.kind {
        case .choice(_, let answer):
            correct = AnswerCheck.matches(choice ?? "", answer)
        case .typed(let answers, _):
            correct = answers.indices.allSatisfy { gap in
                AnswerCheck.matches(gap < typed.count ? typed[gap] : "", answers[gap])
            }
        case .build(let answer):
            let tokens = tokensOf(answer)
            correct = AnswerCheck.normalize(chosenTiles.map { tokens[$0] }.joined(separator: " ")) == AnswerCheck.normalize(answer)
        case .capitalize(_, let targets), .punctuate(_, let targets):
            correct = tapped == targets
        case .findError(_, let target, _):
            correct = tapped == [target]
        case .reveal:
            correct = false
        }
        mark(correct)
    }

    private func mark(_ correct: Bool) {
        withAnimation(.snappy) {
            lastCorrect = correct
            checked = true
        }
        results.append(correct)
        onAnswer?(item, correct)
    }

    private func next() {
        guard index + 1 < items.count else {
            onFinish(results.filter { $0 }.count, items.count)
            withAnimation { finished = true }
            return
        }
        withAnimation(.snappy) {
            index += 1
            prepare()
        }
    }

    private func prepare() {
        checked = false
        choice = nil
        typed = []
        chosenTiles = []
        tapped = []
        revealed = false
        if !items.isEmpty, case .build(let answer) = item.kind {
            var order = Array(tokensOf(answer).indices)
            repeat { order.shuffle() } while order.count > 2 && order == order.sorted()
            tileOrder = order
        }
    }

    private func restart() {
        index = 0
        results = []
        finished = false
        prepare()
    }
}

// MARK: - Results

struct QuizResults: View {
    let title: String
    let color: Color
    let items: [QuizItem]
    let results: [Bool]
    var again: () -> Void
    var done: () -> Void

    private var correct: Int { results.filter { $0 }.count }
    private var fraction: Double { results.isEmpty ? 0 : Double(correct) / Double(results.count) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle().stroke(color.opacity(0.15), lineWidth: 14)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("\(correct) of \(results.count) correct").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 180, height: 180)
                .padding(.top, 24)

                Text(message).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                Tag(text: "+\(correct * 4 + 10) XP", symbol: "star.fill", color: .orange)

                let missed = zip(items, results).filter { !$0.1 }.map(\.0)
                if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Review your mistakes").font(.headline)
                        ForEach(missed) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.prompt).font(.subheadline).foregroundStyle(.secondary)
                                Text(item.correctAnswerText).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.success)
                            }
                            if item.id != missed.last?.id { Divider() }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(20)
        }
        .overlay { if fraction >= 0.8 { Confetti() } }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(action: again) { Text("Try Again").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).controlSize(.large).tint(color)
                Button(action: done) { Text("Done").font(.headline).frame(maxWidth: .infinity) }
                    .primaryAction(color)
            }
            .padding(16)
            .background(.bar)
        }
    }

    private var message: String {
        switch fraction {
        case 0.9...: return "Excellent work!"
        case 0.7..<0.9: return "Well done!"
        case 0.5..<0.7: return "Good effort — keep going"
        default: return "Keep practising — you'll get there"
        }
    }
}

/// A short burst of falling confetti for a strong result.
struct Confetti: View {
    @State private var start = Date()
    private let pieces: [(x: Double, speed: Double, spin: Double, color: Color, size: Double)] = (0..<60).map { _ in
        (Double.random(in: 0...1), Double.random(in: 0.5...1.2), Double.random(in: -3...3),
         [Color.orange, .pink, .purple, .teal, .yellow, .green, .indigo].randomElement()!, Double.random(in: 6...11))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < 3.5 else { return }
                for piece in pieces {
                    let y = -20 + elapsed * piece.speed * size.height * 0.45
                    let x = piece.x * size.width + sin(elapsed * 2 + piece.spin) * 20
                    var rect = context
                    rect.translateBy(x: x, y: y)
                    rect.rotate(by: .radians(elapsed * piece.spin))
                    rect.opacity = max(0, 1 - elapsed / 3.5)
                    rect.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                              with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Lays out children left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
