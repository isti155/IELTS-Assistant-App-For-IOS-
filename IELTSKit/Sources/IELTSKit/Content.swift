import Foundation

/// Questions harvested from the public datasets by ml/scripts/prepare_data.py.
public struct QuestionBank: Codable {
    public var task2: [String] = []
    public var part1: [String] = []
    public var cueCards: [CueCard] = []

    public static let shared: QuestionBank = {
        guard let url = Bundle.module.url(forResource: "question_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(QuestionBank.self, from: data) else { return QuestionBank() }
        return bank
    }()

    public func randomTask2() -> WritingTask {
        if let item = Library.writing.task2.randomElement() {
            return WritingTask(taskNumber: 2, prompt: item.prompt, chart: nil, sample: item.sample, sampleBand: item.band)
        }
        let prompt = task2.randomElement() ?? SeedContent.writingTask2[0].prompt
        return WritingTask(taskNumber: 2, prompt: prompt, chart: nil)
    }
}

public struct SpeakingTopic {
    public var cueCard: CueCard
    public var roundingOff: String
    public var part3: [String]
}

public enum SpeakingContent {
    /// Cue cards with the discussion questions that follow from them.
    public static let topics: [SpeakingTopic] = [
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a teacher who influenced you.", bullets: ["who the teacher was", "what they taught", "what was special about them", "and explain how they influenced you"]),
            roundingOff: "Are you still in contact with this teacher?",
            part3: ["What qualities make someone a good teacher?", "Do you think teachers are valued enough in your country? Why?", "How might technology change the role of teachers in the future?", "Should education focus more on knowledge or on character? Why?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a journey that did not go as planned.", bullets: ["where you were going", "who you were with", "what went wrong", "and explain how you dealt with the situation"]),
            roundingOff: "Would you make the same journey again?",
            part3: ["Why do some people enjoy travelling more than others?", "What are the advantages and disadvantages of travelling alone?", "How has tourism changed places in your country?", "Do you think people will travel less in the future? Why?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a piece of technology you find useful.", bullets: ["what it is", "when you started using it", "what you use it for", "and explain why it is useful to you"]),
            roundingOff: "Do most of your friends use it too?",
            part3: ["Do you think people depend too much on technology?", "How has technology changed the way people communicate?", "Are older people at a disadvantage with new technology? Why?", "What are the risks of children using technology from a young age?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a time you helped someone.", bullets: ["who you helped", "what the situation was", "how you helped", "and explain how you felt afterwards"]),
            roundingOff: "Has that person ever helped you in return?",
            part3: ["Why are some people more willing to help strangers than others?", "Should children be taught to do voluntary work? Why?", "Is it the government's job or individuals' job to help people in need?", "Has community spirit become weaker in modern cities? Why?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a book or film that made you think.", bullets: ["what it was", "when you read or saw it", "what it was about", "and explain why it made you think"]),
            roundingOff: "Would you recommend it to other people?",
            part3: ["Why do some stories stay popular for generations?", "Do films influence the way people behave?", "Is reading still important now that so much information is on video?", "Should governments support the arts with public money? Why?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a place in your city where people go to relax.", bullets: ["where it is", "what people do there", "how often you go there", "and explain why it is a good place to relax"]),
            roundingOff: "Has this place changed much over the years?",
            part3: ["Why are public spaces important in a city?", "How do people's leisure habits differ between generations?", "Should cities spend more on parks or on roads? Why?", "Do people today have more or less free time than in the past?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe an important decision you made.", bullets: ["what the decision was", "when you made it", "who helped you decide", "and explain why it was important"]),
            roundingOff: "Do you think it was the right decision?",
            part3: ["Do people make better decisions alone or with advice from others?", "At what age should young people make their own decisions?", "Why do some people find it hard to make decisions?", "How do big decisions by governments affect ordinary people?"]),
        SpeakingTopic(
            cueCard: CueCard(topic: "Describe a job you would like to do in the future.", bullets: ["what the job is", "what skills it needs", "how you could get it", "and explain why you would like to do it"]),
            roundingOff: "Do you know anyone who does this job?",
            part3: ["What matters more in a job: salary or satisfaction? Why?", "How is the job market changing in your country?", "Should people stay in one career for life?", "Which jobs do you think machines will not be able to replace? Why?"]),
    ]

    private static let frame = [
        "Let's talk about what you do. Do you work, or are you a student?",
        "What do you like most about the place where you live?",
    ]

    static let roundingOff = [
        "Would you like to do that again in the future?", "Do your friends feel the same way?",
        "Is that common in your country?", "Has your opinion about it changed over time?",
    ]

    /// A fresh test assembled from the speaking question bank.
    public static func randomScript() -> SpeakingScript {
        let bank = Library.speaking
        let curated = topics.randomElement()!
        let part1Topic = bank.part1.randomElement()
        let part1 = frame + (part1Topic.map { Array($0.questions.shuffled().prefix(4)) } ?? Array(SeedContent.speaking.part1.suffix(3)))
        guard let card = bank.cueCards.filter({ $0.bullets.count >= 3 }).randomElement() else {
            return SpeakingScript(part1: part1, cueCard: curated.cueCard, roundingOff: curated.roundingOff, part3: curated.part3)
        }
        return SpeakingScript(part1: part1, cueCard: CueCard(topic: card.topic, bullets: card.bullets),
                              roundingOff: roundingOff.randomElement()!, part3: part3(for: card))
    }

    /// Part 3 questions whose topic shares the most words with the cue card.
    static func part3(for card: BankCueCard) -> [String] {
        let stop: Set<String> = ["describe", "a", "an", "the", "you", "your", "that", "who", "which", "of", "to", "in", "and", "time", "when"]
        let words = Set((card.topic + " " + (card.theme ?? "")).lowercased().split { !$0.isLetter }.map(String.init)).subtracting(stop)
        let best = Library.speaking.part3.max { a, b in
            Set(a.topic.lowercased().split { !$0.isLetter }.map(String.init)).intersection(words).count
                < Set(b.topic.lowercased().split { !$0.isLetter }.map(String.init)).intersection(words).count
        }
        let overlap = best.map { Set($0.topic.lowercased().split { !$0.isLetter }.map(String.init)).intersection(words).count } ?? 0
        if let best, overlap > 0 { return Array(best.questions.prefix(5)) }
        return Array((Library.speaking.part3.randomElement()?.questions ?? topics.randomElement()!.part3).prefix(5))
    }

    /// Follow-up questions for conversation practice when no language model is installed.
    public static let discussion: [String] = topics.flatMap(\.part3) + [
        "What do you usually do to relax after a busy day, and why does it work for you?",
        "Tell me about a skill you would like to learn. Why that one?",
        "How is your home town different from ten years ago?",
        "What kind of news do you follow, and where do you get it?",
        "Do you prefer to plan things carefully or decide at the last minute? Why?",
        "What is one change that would make your city a better place to live?",
    ]
}

/// Instructions for the optional on-device language model.
/// A 1.5B-parameter model answers well only from facts it is given, so every prompt
/// supplies them (tested in ml/scripts; see docs/PLAN.md section 4).
enum Prompts {
    static func tutor(notes: [GuideArticle], candidate: String) -> String {
        var prompt = """
        You are an IELTS Academic tutor. Answer the student's question using ONLY the reference notes below. \
        If the notes do not cover the question, say that you are not sure and suggest reading the study guides \
        in the Tutor tab. Be concise and give one short example.
        """
        prompt += "\n\nAbout the student: \(candidate)"
        prompt += "\n\nREFERENCE NOTES:\n"
        prompt += notes.isEmpty ? "(none match this question)" : notes.map { "\($0.title)\n\($0.body)" }.joined(separator: "\n\n")
        return prompt
    }

    static let feedback = """
    You are an IELTS Writing examiner writing a short comment for a student. The bands and the list of errors \
    have already been decided and are given below as facts; do not change them and do not add new errors. \
    Write 3 to 5 sentences about the IDEAS only: whether every part of the question is answered, whether the \
    main ideas are explained and supported with examples, and one specific way to develop them further. \
    Quote the essay when you refer to it.
    """

    static func feedbackFacts(_ evaluation: Evaluation) -> String {
        let bands = evaluation.criteria.map { "\($0.name) \(Int($0.band))" }.joined(separator: "; ")
        let errors = evaluation.corrections.prefix(6).map { "\"\($0.original)\" → \"\($0.corrected)\"" }
        return "Bands decided: overall \(bandText(evaluation.band)); \(bands). Errors detected: "
            + (errors.isEmpty ? "none" : errors.joined(separator: ", ")) + "."
    }
    static let partner = """
    You are a friendly English conversation partner helping someone prepare for IELTS Speaking. Reply in \
    plain spoken English, two or three sentences, with no lists or symbols. If the user made a clear \
    language error, first say "A more natural way to say that is" and give the corrected sentence. \
    Always end with one open question.
    """
}

/// Short study guides shown in the Tutor tab; always available offline.
public struct GuideArticle: Identifiable, Hashable {
    public var title: String
    public var body: String
    public var id: String { title }

    /// The skill a guide belongs to, from its title ("Reading: …", "Writing Task 1"); nil for general guides.
    var skill: Skill? {
        Skill.allCases.first { title.hasPrefix($0.title) }
    }

    /// Title without the skill prefix, for lists already grouped by skill.
    var shortTitle: String {
        guard let skill else { return title }
        var rest = title.dropFirst(skill.title.count)
        while let first = rest.first, first == ":" || first == " " { rest = rest.dropFirst() }
        return rest.isEmpty ? title : rest.prefix(1).uppercased() + rest.dropFirst()
    }
}

public enum Guide {
    public static let articles: [GuideArticle] = [
        GuideArticle(title: "Test format and timing", body: """
        **Listening** — 4 recordings, 40 questions, about 30 minutes. Each recording plays once.
        **Reading** — 3 passages, 40 questions, 60 minutes. No extra time to transfer answers.
        **Writing** — Task 1 (150+ words, about 20 minutes) and Task 2 (250+ words, about 40 minutes). Task 2 is worth twice as much.
        **Speaking** — 11–14 minutes: Part 1 short questions, Part 2 a two-minute talk after one minute of preparation, Part 3 discussion.

        Your overall band is the average of the four skills, rounded to the nearest half band.
        """),
        GuideArticle(title: "How bands are decided", body: """
        Listening and Reading are marked out of 40. Roughly: 30 correct is band 7, 23 is band 6, 35 is band 8 (Academic Reading needs a mark or two more than Listening at some bands).

        Writing and Speaking each have four criteria worth 25% each, marked in whole bands and averaged.
        **Writing:** Task Achievement/Response, Coherence and Cohesion, Lexical Resource, Grammatical Range and Accuracy.
        **Speaking:** Fluency and Coherence, Lexical Resource, Grammatical Range and Accuracy, Pronunciation.

        The usual jump from 6 to 7: fewer errors (most sentences error-free), ideas that are developed rather than listed, and vocabulary used precisely rather than just ambitiously.
        """),
        GuideArticle(title: "Writing Task 1", body: """
        1. **Introduction** — paraphrase the question in one sentence.
        2. **Overview** — the two or three biggest trends or differences, with no figures. Start with "Overall,". Without an overview you cannot score above 5 for Task Achievement.
        3. **Detail paragraphs** — group the data logically and support each point with figures. Compare; do not list every number.

        Never give opinions or reasons that are not in the data. Use the right tense for the time period shown. Spend 20 minutes, no more.
        """),
        GuideArticle(title: "Writing Task 2", body: """
        Read the question twice and underline every part you must answer; missing one part limits Task Response to 5.

        A reliable structure:
        - **Introduction** — paraphrase the topic and state your position.
        - **Body 1 and 2** — one main idea each: topic sentence, explanation, specific example, link back to the question.
        - **Conclusion** — answer the question again in different words. No new ideas.

        Plan for five minutes. Two well-developed ideas beat four thin ones. Leave three minutes to check verb agreement, articles and spelling.
        """),
        GuideArticle(title: "Reading: True / False / Not Given", body: """
        - **TRUE** — the passage says the same thing.
        - **FALSE** — the passage says the opposite, or something that cannot be true at the same time.
        - **NOT GIVEN** — the passage does not say; you would need outside knowledge to decide.

        Find the sentence the statement is about first (questions follow passage order). Watch qualifiers such as *all, most, some, always, only*: they are the usual trap. If you are hunting for the information for more than a minute, it is probably Not Given.
        """),
        GuideArticle(title: "Reading: managing time", body: """
        Allow 20 minutes per passage; the third is the hardest. Skim the passage for one or two minutes to learn what each paragraph is about, then go to the questions. For completion questions, respect the word limit and copy words exactly from the passage. Never leave a blank: there is no penalty for a wrong answer.
        """),
        GuideArticle(title: "Listening", body: """
        Use the time before each recording to read the questions and predict the type of answer (a number, a name, a noun). Answers come in order. Speakers often correct themselves — "on Tuesday… no, sorry, Thursday" — so wait for the final version. Check spelling and singular/plural: "apron" and "aprons" are different answers. Keep to the word limit.
        """),
        GuideArticle(title: "Speaking", body: """
        **Part 1** — answer in two or three sentences: answer, reason, small detail.
        **Part 2** — use the minute to note one or two words per bullet. Keep talking until you are stopped; tell a story with details.
        **Part 3** — give an opinion, explain why, give an example, and consider another view.

        Fluency matters more than perfection: correct yourself briefly and move on. Do not memorise answers; examiners recognise them and they score poorly.
        """),
        GuideArticle(title: "A four-week plan", body: """
        **Week 1** — one attempt in every skill to find your level. Read the guides for your weakest skill.
        **Week 2** — daily: one Reading or Listening set, alternating. Three Task 2 essays and two Task 1 reports; fix every correction before the next one.
        **Week 3** — two full Speaking tests and daily conversation practice. Rewrite your two weakest essays.
        **Week 4** — timed practice only. Two full mock sessions under exam conditions. Rest the day before the test.

        Keep a list of your repeated mistakes from the Corrections sections and review it every day.
        """),
        GuideArticle(title: "Reading: matching headings", body: """
        Read the list of headings first and note the key idea of each. Then read each paragraph and decide its **main idea** — usually in the first one or two sentences, sometimes in the last. Do not match on a single shared word: distractor headings often repeat a word from a detail in the paragraph. Do the paragraphs you are sure of first, then use elimination. There are always more headings than paragraphs.
        """),
        GuideArticle(title: "Reading: completion questions", body: """
        Check the word limit: "NO MORE THAN TWO WORDS" means one or two words; a number counts as one word. Copy the words exactly from the passage — the spelling must be correct. Predict the type of word that fits the gap (noun, verb, number) and check that your answer makes the sentence grammatical. Questions usually follow the order of the passage within one section.
        """),
        GuideArticle(title: "Writing Task 1: language for trends", body: """
        **Rising:** increase, rise, grow, climb — sharply, steadily, gradually, slightly.
        **Falling:** decrease, fall, drop, decline — dramatically, significantly, marginally.
        **No change:** remain stable, stay constant, level off, plateau.
        **Peaks and lows:** peak at, reach a high of, hit a low of.
        **Comparing:** twice as many as, a third of, considerably higher than, whereas, while.

        Use the past tense for past dates and "is projected to" or "is expected to" for future dates. Vary nouns and verbs: "a sharp rise" and "rose sharply".
        """),
        GuideArticle(title: "Writing: vocabulary for band 7", body: """
        Band 7 Lexical Resource needs **less common words used accurately**, with awareness of collocation. Precision matters more than rare words: "a significant proportion of young adults" beats "a plethora of youngsters". Paraphrase the question instead of copying it. Avoid informal words (kids, stuff, a lot of) and contractions. Learn words in pairs and phrases — "pose a threat", "address a problem", "widen the gap" — rather than alone.
        """),
        GuideArticle(title: "Writing: grammar for band 7", body: """
        Band 7 Grammar needs **a variety of complex structures** and **frequent error-free sentences**. Use a mix of relative clauses ("which", "who"), conditionals ("If governments invested…, fewer people would…"), concession ("Although…", "Despite…"), and passive forms where the doer is unimportant. Accuracy counts as much as range: check subject–verb agreement, articles (a, an, the), plurals and verb tenses in the last three minutes.
        """),
        GuideArticle(title: "Speaking: Part 2 long turn (cue card)", body: """
        The examiner gives you a cue card with a topic and four bullets. You get one minute of preparation and then speak for up to two minutes. In the preparation minute, write a few key words for each bullet — not sentences. Start with a direct opening ("I'd like to talk about…"), cover every bullet, and spend the most time on the last bullet (the "explain" part), because it is where you show range. Add a short story, feelings and details. If you finish early, add an example or say what you would do differently.
        """),
        GuideArticle(title: "Speaking: fluency and pronunciation", body: """
        Fluency is about speaking at length without long pauses, not about speed. Use natural linking phrases ("on top of that", "the main reason is", "having said that") and thinking phrases ("that's a tricky question, but I'd say…") instead of silence. For pronunciation, focus on word stress and sentence stress: stress the important words and keep small words weak. Being easy to understand matters more than having a particular accent.
        """),
    ]

    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "is", "are", "be", "do", "does", "i", "my",
        "me", "you", "your", "how", "what", "when", "which", "should", "can", "could", "would", "it", "this",
        "that", "with", "at", "about", "tell", "please", "ielts", "get", "need", "want", "much", "many",
    ]

    private static func terms(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
            .map { $0.count > 4 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 }
    }

    /// The guides most related to a question, best first. Title words count three times as
    /// much as body words, and words that appear in few guides count more.
    public static func relevant(to question: String, limit: Int = 2) -> [GuideArticle] {
        let query = Set(terms(question))
        guard !query.isEmpty else { return [] }
        let documents = articles.map { (title: Set(terms($0.title)), body: Set(terms($0.body))) }
        func rarity(_ term: String) -> Double {
            let count = documents.filter { $0.title.contains(term) || $0.body.contains(term) }.count
            return log(Double(articles.count + 1) / Double(count + 1)) + 0.1
        }
        let scored = zip(articles, documents).map { article, document -> (GuideArticle, Double) in
            let score = query.reduce(0.0) { total, term in
                total + (document.title.contains(term) ? 3 : 0) * rarity(term)
                    + (document.body.contains(term) ? 1 : 0) * rarity(term)
            }
            return (article, score)
        }
        let best = scored.map(\.1).max() ?? 0
        guard best >= 1 else { return [] }
        // Keep the runner-up only when it is nearly as relevant as the best match.
        return scored.filter { $0.1 >= best * 0.6 }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}
