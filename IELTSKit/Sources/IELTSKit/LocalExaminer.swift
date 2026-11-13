import Foundation

/// An on-device language model, supplied by the app target when one is installed
/// (see IELTSAssistant/MLXGenerator.swift). The app works without it; the tutor
/// chat and free-form conversation replies need it.
public protocol TextGenerator: AnyObject {
    func generate(
        system: String, messages: [ChatMessage], maxTokens: Int,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String
}

/// Paraphrased summaries of the public IELTS band descriptors, used to explain a band.
enum Descriptors {
    static let writing: [String: [Int: String]] = [
        "Task Achievement": [
            9: "fully satisfies every requirement of the task",
            8: "covers all requirements and presents key features clearly and appropriately",
            7: "gives a clear overview and highlights key features, though they could be extended",
            6: "has an overview and covers key features adequately, with some irrelevant or inaccurate detail",
            5: "recounts detail mechanically with no clear overview",
            4: "attempts the task but misses key features",
        ],
        "Task Response": [
            9: "fully addresses all parts with a fully developed position and well-supported ideas",
            8: "addresses all parts sufficiently with well-developed, extended ideas",
            7: "addresses all parts with a clear position throughout; main ideas are extended and supported",
            6: "addresses all parts though some more fully than others; some ideas are underdeveloped",
            5: "addresses the task only partially; the position is not always clear and development is limited",
            4: "responds minimally or tangentially; the position is unclear",
        ],
        "Coherence and Cohesion": [
            9: "uses cohesion that attracts no attention, with skilful paragraphing",
            8: "sequences ideas logically and manages all aspects of cohesion well",
            7: "is logically organised with clear progression and a range of cohesive devices",
            6: "is arranged coherently with overall progression, but linking can be faulty or mechanical",
            5: "shows some organisation but lacks overall progression; linkers are inadequate or overused",
            4: "does not arrange ideas coherently; basic linkers are repetitive or inaccurate",
        ],
        "Lexical Resource": [
            9: "uses a wide range of vocabulary naturally and precisely",
            8: "uses a wide range fluently, with skilful use of uncommon words and only occasional slips",
            7: "has enough range for flexibility and precision, with some less common items and occasional errors",
            6: "has an adequate range and attempts less common words with some inaccuracy",
            5: "has a limited range that is minimally adequate, with noticeable errors",
            4: "uses basic vocabulary repetitively, with errors that strain the reader",
        ],
        "Grammatical Range and Accuracy": [
            9: "uses a wide range of structures with full flexibility and accuracy",
            8: "uses a wide range of structures; most sentences are error-free",
            7: "uses a variety of complex structures with frequent error-free sentences",
            6: "mixes simple and complex forms; errors rarely reduce communication",
            5: "uses a limited range; complex sentences are attempted but less accurate",
            4: "uses a very limited range; errors predominate",
        ],
    ]

    static func text(_ criterion: String, _ band: Int) -> String {
        let table = writing[criterion] ?? [:]
        let clamped = min(9, max(4, band))
        return table[clamped] ?? ""
    }
}

/// Marks Writing and Speaking entirely on the device: the trained Core ML model
/// gives the bands, deterministic analysis explains them and supplies corrections.
public struct LocalExaminer {
    public init() {}

    // MARK: Writing

    public func evaluateWriting(task: WritingTask, response: String) async throws -> Evaluation {
        let prediction = try await Task.detached(priority: .userInitiated) {
            try BandScorer.shared.predict(task: task.taskNumber, prompt: task.prompt, essay: response)
        }.value
        return Self.buildWritingEvaluation(task: task, response: response, prediction: prediction)
    }

    static func buildWritingEvaluation(task: WritingTask, response: String, prediction: BandPrediction) -> Evaluation {
        let analysis = WritingAnalysis(task: task.taskNumber, text: response)
        let taskName = task.taskNumber == 1 ? "Task Achievement" : "Task Response"

        // The overall head was trained on the most reliable labels. The four criterion heads
        // give the profile; they are shifted so that their mean agrees with the overall band.
        let raw = [prediction.task, prediction.coherence, prediction.lexical, prediction.grammar]
        let shift = prediction.overall - raw.reduce(0, +) / 4
        var bands = raw.map { min(9, max(1, ($0 + shift).rounded())) }
        var overall = (prediction.overall * 2).rounded() / 2
        var caveats: [String] = []

        // IELTS rules the model cannot be trusted to apply by itself.
        let ratio = Double(analysis.words) / Double(task.minimumWords)
        if ratio < 1 {
            let cap: Double = ratio < 0.6 ? 4 : (ratio < 0.8 ? 5 : 6)
            if bands[0] > cap {
                bands[0] = cap
                caveats.append("Your response has \(analysis.words) words; the minimum is \(task.minimumWords). An under-length response cannot fully develop the task, so \(taskName) is capped at \(Int(cap)).")
            }
        }
        if task.taskNumber == 1 && !analysis.hasOverview && bands[0] > 5 {
            bands[0] = 5
            caveats.append("No overview sentence was found (for example one starting 'Overall,'). Without a clear overview, Task Achievement cannot go above 5.")
        }
        overall = min(overall, BandMath.taskBand(bands))

        if prediction.truncated {
            caveats.append("The scoring model reads about the first 400 words; the end of a longer essay is not scored.")
        }
        if task.taskNumber == 1 {
            caveats.append("The model reads your text but cannot see the chart, so it cannot check whether the figures you quote are accurate.")
        }
        caveats.append("This band is an estimate from the scoring model on this iPhone, not an official result. When tested on examiner-scored essays, it was within half a band 60% of the time and within one band 86% of the time.")

        let names = [taskName, "Coherence and Cohesion", "Lexical Resource", "Grammatical Range and Accuracy"]
        let grammarFixes = analysis.corrections.filter { $0.category == "grammar" || $0.category == "punctuation" }
        let spellingFixes = analysis.corrections.filter { $0.category == "spelling" }

        var evidence: [[String]] = [[], [], [], []]
        evidence[0].append("\(analysis.words) words in \(analysis.paragraphs) paragraph(s)")
        if task.taskNumber == 1 {
            evidence[0].append(analysis.hasOverview ? "Overview sentence present" : "No overview sentence found")
            evidence[0].append("\(analysis.figureCount) figures quoted from the data")
            if analysis.hasOpinion { evidence[0].append("Personal opinion found — Task 1 should only report the data") }
        } else {
            evidence[0].append(analysis.hasOpinion ? "Your own position is stated" : "No clear statement of your own position found")
            evidence[0].append(analysis.hasConclusion ? "Conclusion signalled" : "No concluding phrase found")
        }
        let linkerList = analysis.linkersUsed.keys.sorted().prefix(8).joined(separator: ", ")
        evidence[1].append("\(analysis.linkersUsed.count) different linking expressions" + (linkerList.isEmpty ? "" : ": \(linkerList)"))
        if !analysis.overusedLinkers.isEmpty {
            evidence[1].append("Used four or more times: \(analysis.overusedLinkers.joined(separator: ", "))")
        }
        evidence[2].append(String(format: "Vocabulary variety %.0f%% (share of different words in each 50-word stretch)", analysis.lexicalVariety * 100))
        if !analysis.repeatedWords.isEmpty {
            evidence[2].append("Most repeated: " + analysis.repeatedWords.map { "\($0.word) ×\($0.count)" }.joined(separator: ", "))
        }
        if !spellingFixes.isEmpty { evidence[2].append("\(spellingFixes.count) possible spelling error(s)") }
        if !analysis.informalItems.isEmpty { evidence[2].append("Informal: " + analysis.informalItems.joined(separator: ", ")) }
        evidence[3].append(String(format: "Average sentence length %.0f words; %.0f%% of sentences use a complex structure", analysis.averageSentenceLength, analysis.complexShare * 100))
        if !grammarFixes.isEmpty { evidence[3].append("\(grammarFixes.count) common grammar slip(s) detected (see Corrections)") }

        let criteria = (0..<4).map { index in
            CriterionScore(
                name: names[index], band: bands[index],
                justification: "Band \(Int(bands[index])): a response that \(Descriptors.text(names[index], Int(bands[index]))).",
                evidence: evidence[index]
            )
        }

        var strengths: [String] = []
        var improvements: [String] = []
        if analysis.words >= task.minimumWords { strengths.append("You met the word requirement.") }
        if analysis.linkersUsed.count >= 6 && analysis.overusedLinkers.isEmpty { strengths.append("You use a good variety of linking expressions without leaning on one.") }
        if analysis.complexShare >= 0.5 { strengths.append("Most of your sentences use complex structures.") }
        if analysis.lexicalVariety >= 0.78 { strengths.append("Your vocabulary is varied, with little repetition.") }
        if analysis.corrections.isEmpty { strengths.append("No common grammar slips or spelling errors were detected.") }

        if analysis.words < task.minimumWords {
            improvements.append("Write at least \(task.minimumWords) words; you wrote \(analysis.words).")
        }
        let wantedParagraphs = task.taskNumber == 1 ? 3 : 4
        if analysis.paragraphs < wantedParagraphs {
            improvements.append("Use at least \(wantedParagraphs) paragraphs separated by a blank line: " + (task.taskNumber == 1 ? "introduction, overview, and one or two detail paragraphs." : "introduction, two body paragraphs and a conclusion."))
        }
        if task.taskNumber == 1 {
            if !analysis.hasOverview { improvements.append("Add an overview of the main trends or differences, starting with 'Overall,'. It is the single most important sentence in Task 1.") }
            if analysis.figureCount < 4 { improvements.append("Support each main feature with figures from the chart.") }
            if analysis.hasOpinion { improvements.append("Remove opinions and explanations; report only what the data shows.") }
        } else {
            if !analysis.hasOpinion { improvements.append("State your own position clearly in the introduction and keep it consistent to the conclusion.") }
            if !analysis.hasConclusion { improvements.append("Finish with a short conclusion that answers the question directly.") }
        }
        if !analysis.overusedLinkers.isEmpty {
            improvements.append("Vary your linking: you rely on \(analysis.overusedLinkers.joined(separator: ", ")). Try reference words (this, these, such) instead of another linker.")
        }
        if analysis.linkersUsed.count < 4 { improvements.append("Signal the relationship between ideas with a wider range of linking expressions.") }
        if !analysis.repeatedWords.isEmpty {
            improvements.append("Replace some repetitions of \(analysis.repeatedWords.prefix(3).map(\.word).joined(separator: ", ")) with synonyms or pronouns.")
        }
        if !analysis.informalItems.isEmpty { improvements.append("Keep an academic register: avoid \(analysis.informalItems.prefix(3).joined(separator: ", ")).") }
        if analysis.complexShare < 0.35 { improvements.append("Combine short sentences using 'although', 'which', 'because' or 'whereas' to show a wider grammatical range.") }
        if analysis.averageSentenceLength > 32 { improvements.append("Some sentences are very long; split them to keep control of grammar and punctuation.") }
        if !grammarFixes.isEmpty { improvements.append("Fix the recurring grammar slips listed under Corrections; frequent basic errors hold Grammar at 6 or below.") }

        let weakest = zip(names, bands).min { $0.1 < $1.1 }!
        let strongest = zip(names, bands).max { $0.1 < $1.1 }!
        var summary = "Estimated band \(bandText(overall))."
        if weakest.1 < strongest.1 {
            summary += " Your strongest area is \(strongest.0) (\(Int(strongest.1))) and the one holding you back is \(weakest.0) (\(Int(weakest.1)))."
        } else {
            summary += " Your four criteria are level at \(Int(weakest.1))."
        }

        return Evaluation(criteria: criteria, summary: summary, strengths: strengths, improvements: improvements,
                          corrections: analysis.corrections, caveats: caveats, overallBand: overall)
    }

    // MARK: Speaking

    public func evaluateSpeaking(turns: [SpeakingTurn]) async throws -> Evaluation {
        let transcript = turns.map(\.transcript).filter { !$0.isEmpty }.joined(separator: " ")
        let questions = turns.map(\.question).prefix(3).joined(separator: " ")
        var prediction: BandPrediction?
        if Marking.wordCount(transcript) >= 60 {
            prediction = try? await Task.detached(priority: .userInitiated) {
                try BandScorer.shared.predict(task: 2, prompt: questions, essay: transcript)
            }.value
        }
        return Self.buildSpeakingEvaluation(turns: turns, prediction: prediction)
    }

    static func buildSpeakingEvaluation(turns: [SpeakingTurn], prediction: BandPrediction?) -> Evaluation {
        let transcript = turns.map(\.transcript).joined(separator: " ")
        let words = turns.map(\.metrics.words).reduce(0, +)
        let seconds = turns.map(\.metrics.seconds).reduce(0, +)
        let wpm = seconds > 0 ? Double(words) / seconds * 60 : 0
        let pauses = turns.map(\.metrics.longPauses).reduce(0, +)
        let pausesPerMinute = seconds > 0 ? Double(pauses) / seconds * 60 : 0
        let longTurn = turns.first { $0.part == 2 && $0.metrics.seconds > 45 || $0.part == 2 && $0.question.contains("You should say") }
        let analysis = WritingAnalysis(task: 2, text: transcript)
        var caveats = [
            "Speaking is scored from the speech-recognition transcript and timing, not from the sound of your voice. Treat every speaking band as a rough guide.",
        ]

        // Fluency and Coherence: speech rate, long pauses, length of the long turn, linking.
        var fluency: Double
        switch wpm {
        case ..<70: fluency = 4
        case ..<95: fluency = 5
        case ..<115: fluency = 6
        case ..<140: fluency = 7
        default: fluency = 8
        }
        if pausesPerMinute > 5 { fluency -= 1 }
        if let longTurn, longTurn.metrics.seconds < 60 { fluency = min(fluency, 5) }
        if analysis.linkersUsed.count < 3 { fluency = min(fluency, 6) }
        fluency = min(8, max(3, fluency))

        // Lexical and Grammar: the trained model's lexical and grammar outputs on the transcript.
        var lexical = 6.0, grammar = 6.0
        if let prediction {
            lexical = min(8, max(4, prediction.lexical.rounded()))
            grammar = min(8, max(4, prediction.grammar.rounded()))
            caveats.append("Lexical Resource and Grammar use the model trained on written essays, applied to your transcript. Spoken language differs from writing and recognition errors can lower the result.")
        } else {
            lexical = analysis.lexicalVariety >= 0.75 ? 6 : 5
            grammar = analysis.complexShare >= 0.4 ? 6 : 5
            caveats.append("Too little speech was recognised to run the trained model, so Lexical Resource and Grammar are basic estimates.")
        }
        let slips = analysis.corrections.filter { $0.category == "grammar" }
        if slips.count >= 4 { grammar = min(grammar, 5) }

        // Pronunciation: only indirect evidence is available.
        let confidences = turns.compactMap(\.metrics.meanConfidence)
        var pronunciation = 6.0
        if confidences.isEmpty {
            caveats.append("The recogniser gave no confidence values, so Pronunciation is set to 6 by default and is not a measurement.")
        } else {
            let mean = confidences.reduce(0, +) / Double(confidences.count)
            switch mean {
            case ..<0.70: pronunciation = 4
            case ..<0.80: pronunciation = 5
            case ..<0.90: pronunciation = 6
            default: pronunciation = 7
            }
            caveats.append("Pronunciation is inferred from how confidently the recogniser understood you. A human examiner could differ by a band or more.")
        }

        let unclear = Array(Set(turns.flatMap(\.metrics.lowConfidenceWords))).prefix(10)
        let criteria = [
            CriterionScore(name: "Fluency and Coherence", band: fluency,
                           justification: "Based on your speech rate, long pauses, the length of your Part 2 answer and your use of linking words.",
                           evidence: [
                               "\(Int(wpm)) words per minute (fluent test speech is usually 110–160)",
                               String(format: "%.1f pauses longer than one second per minute", pausesPerMinute),
                               longTurn.map { "Part 2 long turn: \(Int($0.metrics.seconds)) seconds (aim for close to 120)" } ?? "No Part 2 long turn in this session",
                               "\(analysis.linkersUsed.count) different linking expressions",
                           ]),
            CriterionScore(name: "Lexical Resource", band: lexical,
                           justification: "Based on the range and precision of the vocabulary in your transcript.",
                           evidence: [String(format: "Vocabulary variety %.0f%%", analysis.lexicalVariety * 100)]
                               + (analysis.repeatedWords.isEmpty ? [] : ["Most repeated: " + analysis.repeatedWords.map { "\($0.word) ×\($0.count)" }.joined(separator: ", ")])),
            CriterionScore(name: "Grammatical Range and Accuracy", band: grammar,
                           justification: "Based on the range of structures and the errors found in your transcript.",
                           evidence: [String(format: "%.0f%% of sentences use a complex structure", analysis.complexShare * 100),
                                      "\(slips.count) common grammar slip(s) detected"]),
            CriterionScore(name: "Pronunciation", band: pronunciation,
                           justification: "Estimated from recogniser confidence; not a direct measurement.",
                           evidence: unclear.isEmpty ? ["No words were flagged as unclear"] : ["Words the recogniser was unsure of: " + unclear.joined(separator: ", ")]),
        ]

        var improvements: [String] = []
        if wpm < 110 { improvements.append("Aim to speak a little faster and keep going: you averaged \(Int(wpm)) words per minute.") }
        if pausesPerMinute > 3 { improvements.append("Reduce long silences. When you need thinking time, use a filler phrase such as 'That's an interesting question' instead of stopping.") }
        if let longTurn, longTurn.metrics.seconds < 90 { improvements.append("In Part 2, keep talking until the examiner stops you. Cover every bullet on the card and add an example or a short story.") }
        if analysis.linkersUsed.count < 5 { improvements.append("Connect your ideas with a wider range of spoken linkers: 'on top of that', 'having said that', 'the main reason is'.") }
        if !analysis.repeatedWords.isEmpty { improvements.append("Paraphrase instead of repeating \(analysis.repeatedWords.prefix(3).map(\.word).joined(separator: ", ")).") }
        if analysis.complexShare < 0.35 { improvements.append("Extend answers with 'because', 'although', 'which' and conditionals ('If I had more time, I would…').") }
        if !unclear.isEmpty { improvements.append("Practise saying these words clearly: \(unclear.joined(separator: ", ")).") }
        let shortAnswers = turns.filter { $0.part == 3 && $0.metrics.words < 25 }.count
        if shortAnswers > 0 { improvements.append("\(shortAnswers) of your Part 3 answers were very short. Give an opinion, a reason and an example each time.") }

        var strengths: [String] = []
        if wpm >= 120 { strengths.append("You speak at a natural pace.") }
        if pausesPerMinute <= 2 && seconds > 60 { strengths.append("Few long pauses.") }
        if let longTurn, longTurn.metrics.seconds >= 100 { strengths.append("You sustained the Part 2 long turn.") }

        let band = BandMath.taskBand([fluency, lexical, grammar, pronunciation])
        return Evaluation(
            criteria: criteria,
            summary: "Estimated band \(bandText(band)), from \(words) recognised words over \(Int(seconds)) seconds of speech.",
            strengths: strengths, improvements: improvements,
            corrections: analysis.corrections.filter { $0.category != "spelling" && $0.category != "punctuation" },
            caveats: caveats, overallBand: nil
        )
    }
}
