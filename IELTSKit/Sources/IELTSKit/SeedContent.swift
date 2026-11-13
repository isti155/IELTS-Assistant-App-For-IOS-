import Foundation

/// Original practice material bundled with the app so every skill can be tried
/// offline and without an API key. Nothing here is taken from published tests.
public enum SeedContent {
    public static let writingTask2: [WritingTask] = [
        "Some people believe that universities should only offer subjects that are useful for future employment. Others think students should be free to study whatever interests them.\n\nDiscuss both these views and give your own opinion.",
        "In many cities, more and more people are choosing to live alone.\n\nWhat are the reasons for this trend? Is it a positive or negative development?",
        "Governments should spend money on public transport rather than on building new roads.\n\nTo what extent do you agree or disagree?",
        "Many young people now get most of their news from social media rather than from newspapers or television.\n\nDo the advantages of this development outweigh the disadvantages?",
        "In some countries, the number of people visiting museums and art galleries is falling.\n\nWhat problems might this cause, and what could be done to encourage more people to visit?",
    ].map { WritingTask(taskNumber: 2, prompt: $0, chart: nil) }

    public static let writingTask1: [WritingTask] = [
        WritingTask(
            taskNumber: 1,
            prompt: "The bar chart shows the percentage of households with internet access in four regions of one country in 2005, 2015 and 2025.\n\nSummarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            chart: ChartSpec(
                kind: "bar", title: "Households with internet access", xLabel: "Region", yLabel: "Households (%)",
                categories: ["North", "South", "East", "West"],
                series: [
                    ChartSeries(name: "2005", values: [32, 18, 25, 41]),
                    ChartSeries(name: "2015", values: [71, 49, 66, 80]),
                    ChartSeries(name: "2025", values: [93, 88, 90, 96]),
                ]
            )
        ),
        WritingTask(
            taskNumber: 1,
            prompt: "The line graph shows the average number of journeys made per person each year by three types of transport in one city between 1990 and 2020.\n\nSummarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            chart: ChartSpec(
                kind: "line", title: "Journeys per person per year", xLabel: "Year", yLabel: "Journeys per person",
                categories: ["1990", "2000", "2010", "2020"],
                series: [
                    ChartSeries(name: "Bus", values: [210, 180, 150, 155]),
                    ChartSeries(name: "Car", values: [320, 390, 410, 360]),
                    ChartSeries(name: "Bicycle", values: [40, 35, 70, 130]),
                ]
            )
        ),
    ]

    public static let reading = ReadingTest(
        title: "The Hidden Life of Urban Soil",
        passage: """
        A. For most city dwellers, soil is something to be covered: by asphalt, paving stones or the foundations of buildings. Yet beneath the streets of every city lies a living system that researchers have only recently begun to study in detail. Urban soil science emerged as a distinct discipline in the 1980s, when surveys in several European cities revealed that the ground beneath them differed markedly from the farmland soils that had dominated the field for a century.

        B. The most obvious difference is disturbance. Agricultural soil forms in layers over thousands of years, whereas urban soil is repeatedly dug up, mixed and compacted by construction. It frequently contains fragments of brick, glass and concrete, which raise its alkalinity and alter the way water drains through it. Compaction is particularly damaging: when soil particles are pressed together by heavy machinery, the gaps that hold air and water collapse, and tree roots struggle to penetrate more than a few centimetres. A street tree typically survives for only a fraction of the lifespan the same species would reach in woodland.

        C. Despite these pressures, urban soils are far from lifeless. When microbiologists sampled soil from a single large city park, they found almost as many distinct types of microorganism as had been recorded in samples drawn from natural habitats across the globe, and the majority of them had never been described. Earthworms, too, are often more abundant in garden soils than in neighbouring farmland, largely because gardeners add compost and seldom use heavy ploughs.

        D. This hidden life matters because of the work that soil does. Unsealed soil acts like a sponge during heavy rain, absorbing water that would otherwise rush into drains. As cities have expanded and sealed surfaces have multiplied, flooding has become more frequent, and engineers have turned to so-called rain gardens, shallow planted basins filled with sandy soil, to slow the flow. Soil also stores carbon. Because lawns and parks are rarely ploughed, the carbon in them can accumulate undisturbed for decades, and some measurements indicate that a hectare of old parkland holds more carbon than a hectare of nearby cropland.

        E. None of this means that urban soil is harmless. Decades of industry and traffic have left lead and other heavy metals in the ground, particularly beside older roads and around buildings once coated in lead-based paint. The risk is greatest for young children, who may swallow soil while playing. Public health agencies therefore advise urban gardeners to have their soil tested and, where contamination is found, to grow vegetables in raised beds filled with clean soil brought in from elsewhere. Planners, for their part, are beginning to treat soil not as an obstacle to construction but as a resource to be mapped and protected, although few cities yet have legislation that requires it.
        """,
        questions: [
            Question(id: 1, kind: "true_false_not_given", prompt: "Urban soil science became a separate field before scientists began studying farmland soils.", options: tfng, answer: "FALSE", accepted: [], explanation: "Paragraph A: farmland soils 'had dominated the field for a century' before urban soil science emerged in the 1980s."),
            Question(id: 2, kind: "true_false_not_given", prompt: "Building debris makes urban soil more alkaline.", options: tfng, answer: "TRUE", accepted: [], explanation: "Paragraph B: fragments of brick, glass and concrete 'raise its alkalinity'."),
            Question(id: 3, kind: "true_false_not_given", prompt: "Street trees grow faster than woodland trees during their first years.", options: tfng, answer: "NOT GIVEN", accepted: [], explanation: "Paragraph B compares lifespan only; growth rate is never mentioned."),
            Question(id: 4, kind: "true_false_not_given", prompt: "Most of the microorganisms found in the city park were already known to science.", options: tfng, answer: "FALSE", accepted: [], explanation: "Paragraph C: 'the majority of them had never been described'."),
            Question(id: 5, kind: "true_false_not_given", prompt: "The majority of cities have laws requiring soil to be protected.", options: tfng, answer: "FALSE", accepted: [], explanation: "Paragraph E: 'few cities yet have legislation that requires it'."),
            Question(id: 6, kind: "matching", prompt: "Which paragraph contains a reference to a health danger affecting one particular age group?", options: paragraphs, answer: "E", accepted: [], explanation: "Paragraph E: 'The risk is greatest for young children'."),
            Question(id: 7, kind: "matching", prompt: "Which paragraph contains an explanation of why a certain animal does well in gardens?", options: paragraphs, answer: "C", accepted: [], explanation: "Paragraph C: earthworms are abundant 'because gardeners add compost and seldom use heavy ploughs'."),
            Question(id: 8, kind: "matching", prompt: "Which paragraph contains a description of a method used to reduce flooding?", options: paragraphs, answer: "D", accepted: [], explanation: "Paragraph D describes rain gardens."),
            Question(id: 9, kind: "completion", prompt: "During heavy rain, soil that has not been sealed behaves like a ______. (ONE WORD)", options: [], answer: "sponge", accepted: [], explanation: "Paragraph D: 'Unsealed soil acts like a sponge'."),
            Question(id: 10, kind: "completion", prompt: "Rain gardens are basins filled with ______ soil. (ONE WORD)", options: [], answer: "sandy", accepted: [], explanation: "Paragraph D: 'shallow planted basins filled with sandy soil'."),
            Question(id: 11, kind: "completion", prompt: "Carbon builds up in parks and lawns because they are rarely ______. (ONE WORD)", options: [], answer: "ploughed", accepted: ["plowed"], explanation: "Paragraph D: 'Because lawns and parks are rarely ploughed'."),
            Question(id: 12, kind: "completion", prompt: "Where soil is contaminated, gardeners are advised to grow vegetables in ______. (TWO WORDS)", options: [], answer: "raised beds", accepted: [], explanation: "Paragraph E: 'grow vegetables in raised beds'."),
        ]
    )

    public static let listening = ListeningTest(
        title: "Pottery Course Enquiry",
        context: "You will hear a telephone conversation between a receptionist at an arts centre and a man who wants to join a course.",
        segments: [
            ListeningSegment(speaker: "Receptionist", text: "Good morning, Riverside Arts Centre, Anna speaking. How can I help?"),
            ListeningSegment(speaker: "Caller", text: "Hi, I'm calling about the pottery course for beginners. Is there still space?"),
            ListeningSegment(speaker: "Receptionist", text: "Let me check. Yes, there are a few places left on the evening course. It starts on the ninth of March."),
            ListeningSegment(speaker: "Caller", text: "Oh, I thought it began on the second."),
            ListeningSegment(speaker: "Receptionist", text: "It was going to, but the studio is being repainted that week, so we moved it back to the ninth."),
            ListeningSegment(speaker: "Caller", text: "That's fine. And which evening is it?"),
            ListeningSegment(speaker: "Receptionist", text: "It was on Tuesdays last term, but this term it's on Thursdays, from half past six until half past eight."),
            ListeningSegment(speaker: "Caller", text: "Thursdays suit me better, actually. How long does the course run?"),
            ListeningSegment(speaker: "Receptionist", text: "Eight weeks in total. It used to be ten, but we shortened it this year."),
            ListeningSegment(speaker: "Caller", text: "And what does it cost?"),
            ListeningSegment(speaker: "Receptionist", text: "The full price is one hundred and twenty pounds, but if you live locally there's a resident discount, which brings it down to ninety-five."),
            ListeningSegment(speaker: "Caller", text: "I do live locally. Does that include materials?"),
            ListeningSegment(speaker: "Receptionist", text: "Clay and glazes are included, and we provide all the tools. The only thing you'll need to bring is an apron. It gets quite messy."),
            ListeningSegment(speaker: "Caller", text: "Great. Who teaches it?"),
            ListeningSegment(speaker: "Receptionist", text: "The tutor is Helen Marchetti. That's M-A-R-C-H-E-T-T-I. She's been with us for six years."),
            ListeningSegment(speaker: "Caller", text: "Lovely. Can I book now?"),
            ListeningSegment(speaker: "Receptionist", text: "Of course. Can I take your name?"),
            ListeningSegment(speaker: "Caller", text: "It's David Okafor. That's O-K-A-F-O-R."),
            ListeningSegment(speaker: "Receptionist", text: "Thank you. One more thing. The main car park is closed for building work at the moment, so please use the entrance on Mill Lane. That's M-I-L-L."),
            ListeningSegment(speaker: "Caller", text: "Mill Lane. Got it."),
            ListeningSegment(speaker: "Receptionist", text: "You'll receive a confirmation by email today, and payment is due by the end of February."),
            ListeningSegment(speaker: "Caller", text: "Perfect. Thanks very much for your help."),
        ],
        questions: [
            Question(id: 1, kind: "completion", prompt: "Course starts: ______ March", options: [], answer: "9", accepted: ["9th", "ninth", "nine"], explanation: "The date was moved from the second to the ninth."),
            Question(id: 2, kind: "completion", prompt: "Day of the week: ______", options: [], answer: "Thursday", accepted: ["Thursdays"], explanation: "Tuesdays were last term; this term it is on Thursdays."),
            Question(id: 3, kind: "completion", prompt: "Length of course: ______ weeks", options: [], answer: "8", accepted: ["eight"], explanation: "Eight weeks; ten was the old length."),
            Question(id: 4, kind: "completion", prompt: "Price for local residents: £______", options: [], answer: "95", accepted: ["ninety-five", "ninety five"], explanation: "£120 is the full price; the resident discount makes it £95."),
            Question(id: 5, kind: "completion", prompt: "Students must bring an ______", options: [], answer: "apron", accepted: [], explanation: "Clay, glazes and tools are provided; only an apron is needed."),
            Question(id: 6, kind: "completion", prompt: "Tutor: Helen ______", options: [], answer: "Marchetti", accepted: [], explanation: "Spelled M-A-R-C-H-E-T-T-I."),
            Question(id: 7, kind: "completion", prompt: "Caller's surname: ______", options: [], answer: "Okafor", accepted: [], explanation: "Spelled O-K-A-F-O-R."),
            Question(id: 8, kind: "completion", prompt: "Use the entrance on ______ Lane", options: [], answer: "Mill", accepted: [], explanation: "The main car park is closed; use the Mill Lane entrance."),
            Question(id: 9, kind: "multiple_choice", prompt: "Why was the start date changed?", options: ["The tutor was unavailable", "The studio is being repainted", "Too few people had booked"], answer: "The studio is being repainted", accepted: [], explanation: "'The studio is being repainted that week, so we moved it back.'"),
            Question(id: 10, kind: "multiple_choice", prompt: "When must the caller pay?", options: ["At the first class", "By the end of February", "When the confirmation email arrives"], answer: "By the end of February", accepted: [], explanation: "'Payment is due by the end of February.'"),
        ]
    )

    public static let speaking = SpeakingScript(
        part1: [
            "Let's talk about where you live. Do you live in a house or an apartment?",
            "What do you like most about the area where you live?",
            "Do you work, or are you a student?",
            "Let's move on to the topic of reading. How often do you read for pleasure?",
            "Did you enjoy reading when you were a child?",
            "Do you prefer reading on paper or on a screen? Why?",
        ],
        cueCard: CueCard(
            topic: "Describe a skill that took you a long time to learn.",
            bullets: [
                "what the skill is",
                "when you started learning it",
                "why it took a long time",
                "and explain how you felt when you finally learned it",
            ]
        ),
        roundingOff: "Do you still use this skill today?",
        part3: [
            "We've been talking about a skill that took you a long time to learn. Let's consider learning in general. Why do some people give up quickly when they try to learn something difficult?",
            "Do you think children learn practical skills more easily than adults? Why?",
            "How has technology changed the way people learn new skills?",
            "Some people say schools should teach more practical skills and less academic knowledge. What's your view?",
            "In the future, which skills do you think will become more important, and which less?",
        ]
    )

    private static let tfng = ["TRUE", "FALSE", "NOT GIVEN"]
    private static let paragraphs = ["A", "B", "C", "D", "E"]
}
