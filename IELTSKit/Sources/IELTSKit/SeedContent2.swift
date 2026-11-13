import Foundation

/// More original practice material.
extension SeedContent {
    public static var readings: [ReadingTest] { [reading, readingLongitude] }
    public static var listenings: [ListeningTest] { [listening, listeningReserve] }
    public static var allTask1: [WritingTask] { writingTask1 + moreTask1 }

    private static let tf = ["TRUE", "FALSE", "NOT GIVEN"]
    private static let letters = ["A", "B", "C", "D", "E", "F"]

    public static let readingLongitude = ReadingTest(
        title: "The Clockmaker and the Sea",
        passage: """
        A. For centuries, sailors could work out how far north or south they were by measuring the height of the sun or the stars above the horizon. Finding their position east or west was another matter. Out of sight of land, a captain could only estimate longitude from the ship's speed and direction, and small mistakes grew into large ones over a long voyage. The cost of such errors became impossible to ignore in 1707, when four British warships struck rocks off the Scilly Isles and well over a thousand men drowned.

        B. In 1714 the British Parliament responded with the Longitude Act, which offered a prize of up to 20,000 pounds, a fortune at the time, for a practical method of finding longitude at sea. The principle was already understood. Because the Earth turns through fifteen degrees every hour, a navigator who knows the time at his home port and the local time on board can convert the difference into distance east or west. Local time could be found from the sun. The difficulty was carrying home time on a rolling ship: the best pendulum clocks of the day were useless at sea, and changes in temperature and humidity upset every other mechanism.

        C. Most learned opinion held that the answer would come from astronomy. The moon's movement against the background of stars could serve as a kind of clock in the sky, visible to everyone, and astronomers set about compiling tables of its position. The method worked in theory, but it demanded clear skies, delicate measurements on a moving deck and hours of calculation.

        D. John Harrison, a carpenter with no formal training in clockmaking, approached the problem differently. He believed a timekeeper could be built that would run accurately in any conditions. His first sea clock, finished in 1735, was a heavy brass machine that replaced the pendulum with linked balances, so that the motion of the ship affected both equally and cancelled out. Two larger machines followed over the next two decades, each with new devices to compensate for heat and cold, but Harrison was satisfied with neither.

        E. His fourth timekeeper, completed in 1759, looked nothing like its predecessors. It was a watch, only a little larger than a pocket watch of the period, and it was tested on a voyage to Jamaica. On arrival, after more than eleven weeks at sea, it was found to be wrong by only about five seconds. The board that judged the prize, which included astronomers who favoured the lunar method, was reluctant to accept that the result was more than luck and demanded further trials and a full explanation of the mechanism.

        F. Harrison spent years arguing his case. He was eventually paid most of the money, but only in 1773, after he had appealed to the king and Parliament had intervened; the board never formally declared him the winner. By then the argument had been settled in practice. Captain James Cook carried a copy of the watch on his second voyage and praised it warmly in his journal. Within a few decades, the marine chronometer had become standard equipment on ocean-going ships.
        """,
        questions: [
            Question(id: 1, kind: "true_false_not_given", prompt: "Before 1707, sailors had no reliable way of finding their latitude.", options: tf, answer: "FALSE", accepted: [], explanation: "Paragraph A: sailors 'could work out how far north or south they were' from the sun or stars."),
            Question(id: 2, kind: "true_false_not_given", prompt: "The idea of using time to calculate longitude was known before the prize was offered.", options: tf, answer: "TRUE", accepted: [], explanation: "Paragraph B: 'The principle was already understood.'"),
            Question(id: 3, kind: "true_false_not_given", prompt: "The lunar method could be used in any weather.", options: tf, answer: "FALSE", accepted: [], explanation: "Paragraph C: 'it demanded clear skies'."),
            Question(id: 4, kind: "true_false_not_given", prompt: "Harrison's first sea clock was tested on a voyage to Jamaica.", options: tf, answer: "NOT GIVEN", accepted: [], explanation: "Only the fourth timekeeper's Jamaica voyage is described; no trial of the first clock is mentioned."),
            Question(id: 5, kind: "true_false_not_given", prompt: "The prize board officially named Harrison as the winner.", options: tf, answer: "FALSE", accepted: [], explanation: "Paragraph F: 'the board never formally declared him the winner'."),
            Question(id: 6, kind: "matching", prompt: "Which paragraph contains a description of a disaster that prompted official action?", options: letters, answer: "A", accepted: [], explanation: "Paragraph A describes the 1707 shipwreck; the Act followed."),
            Question(id: 7, kind: "matching", prompt: "Which paragraph contains an explanation of why existing clocks failed on ships?", options: letters, answer: "B", accepted: [], explanation: "Paragraph B: pendulum clocks were useless at sea and temperature and humidity upset other mechanisms."),
            Question(id: 8, kind: "matching", prompt: "Which paragraph contains a reference to an explorer's approval of the invention?", options: letters, answer: "F", accepted: [], explanation: "Paragraph F: Cook 'praised it warmly in his journal'."),
            Question(id: 9, kind: "completion", prompt: "The Earth rotates through ______ degrees each hour. (ONE WORD OR A NUMBER)", options: [], answer: "fifteen", accepted: ["15"], explanation: "Paragraph B: 'the Earth turns through fifteen degrees every hour'."),
            Question(id: 10, kind: "completion", prompt: "Harrison originally worked as a ______. (ONE WORD)", options: [], answer: "carpenter", accepted: [], explanation: "Paragraph D: 'a carpenter with no formal training in clockmaking'."),
            Question(id: 11, kind: "completion", prompt: "In his first sea clock, the pendulum was replaced by linked ______. (ONE WORD)", options: [], answer: "balances", accepted: ["balance"], explanation: "Paragraph D: 'replaced the pendulum with linked balances'."),
            Question(id: 12, kind: "completion", prompt: "After the voyage, the fourth timekeeper was wrong by about five ______. (ONE WORD)", options: [], answer: "seconds", accepted: ["second"], explanation: "Paragraph E: 'wrong by only about five seconds'."),
        ]
    )

    public static let listeningReserve = ListeningTest(
        title: "Nature Reserve Welcome Talk",
        context: "You will hear a warden giving information to visitors at a nature reserve.",
        segments: [
            ListeningSegment(speaker: "Warden", text: "Good morning everyone, and welcome to Hartley Marsh Nature Reserve. My name's Priya, and I'm one of the wardens here. Before you set off, I'd like to give you some practical information."),
            ListeningSegment(speaker: "Warden", text: "The reserve covers about ninety hectares. It was a working farm until nineteen eighty-seven, when it was bought by the county wildlife trust."),
            ListeningSegment(speaker: "Warden", text: "There are three walking routes. The shortest is the Pond Trail, marked in yellow, which takes about twenty minutes. The Woodland Trail, marked in blue, takes about forty-five minutes. And the longest, the Marsh Trail, marked in red, takes around two hours."),
            ListeningSegment(speaker: "Warden", text: "I should mention that part of the Marsh Trail is closed today because the boardwalk is being repaired, so please turn back when you reach the bridge."),
            ListeningSegment(speaker: "Warden", text: "The bird hide is beside the lake, and it's the best place to see herons. If you're lucky you may also see an otter, though they're rarely seen after about nine in the morning."),
            ListeningSegment(speaker: "Warden", text: "Now, facilities. The café is in the old barn next to the car park. It serves hot food until half past two, though drinks are available until closing. The toilets are behind the visitor centre, not in the café as some of the older maps show."),
            ListeningSegment(speaker: "Warden", text: "Binoculars can be hired from the visitor centre for three pounds. You'll need to leave a deposit of ten pounds, which is returned when you bring them back."),
            ListeningSegment(speaker: "Warden", text: "Dogs are welcome on the Woodland Trail only, and must be kept on a lead. And please don't feed bread to the ducks. It's bad for them. Bags of grain are on sale at the visitor centre if you'd like to feed them."),
            ListeningSegment(speaker: "Warden", text: "Finally, the reserve closes at five o'clock in winter and seven in summer. We're on the summer timetable now, so the gates will be locked at seven. If you have any questions, look for the wardens. We all wear green jackets. Enjoy your visit."),
        ],
        questions: [
            Question(id: 1, kind: "completion", prompt: "Until 1987 the reserve was a ______.", options: [], answer: "farm", accepted: ["working farm"], explanation: "'It was a working farm until nineteen eighty-seven.'"),
            Question(id: 2, kind: "completion", prompt: "Colour of the Pond Trail markers: ______", options: [], answer: "yellow", accepted: [], explanation: "Yellow is the Pond Trail; blue and red are the other trails."),
            Question(id: 3, kind: "completion", prompt: "The Woodland Trail takes about ______ minutes.", options: [], answer: "45", accepted: ["forty-five", "forty five"], explanation: "Twenty minutes is the Pond Trail; the Woodland Trail takes forty-five."),
            Question(id: 4, kind: "completion", prompt: "On the Marsh Trail, visitors must turn back at the ______.", options: [], answer: "bridge", accepted: [], explanation: "The boardwalk is being repaired, so 'turn back when you reach the bridge'."),
            Question(id: 5, kind: "completion", prompt: "The bird hide is the best place to see ______.", options: [], answer: "herons", accepted: ["heron"], explanation: "Herons; otters are only a possibility early in the morning."),
            Question(id: 6, kind: "completion", prompt: "Hot food is served until ______.", options: [], answer: "2.30", accepted: ["2:30", "half past two", "14.30", "14:30", "2.30 pm", "2:30 pm"], explanation: "Hot food stops at half past two; drinks continue until closing."),
            Question(id: 7, kind: "completion", prompt: "Deposit for binoculars: £______", options: [], answer: "10", accepted: ["ten"], explanation: "Three pounds is the hire charge; the deposit is ten pounds."),
            Question(id: 8, kind: "multiple_choice", prompt: "Where are the toilets?", options: ["In the café", "Behind the visitor centre", "Next to the car park"], answer: "Behind the visitor centre", accepted: [], explanation: "'Behind the visitor centre, not in the café as some of the older maps show.'"),
            Question(id: 9, kind: "multiple_choice", prompt: "Where are dogs allowed?", options: ["On all three trails", "On the Woodland Trail only", "Nowhere in the reserve"], answer: "On the Woodland Trail only", accepted: [], explanation: "'Dogs are welcome on the Woodland Trail only.'"),
            Question(id: 10, kind: "multiple_choice", prompt: "What time will the gates be locked today?", options: ["Five o'clock", "Seven o'clock", "Nine o'clock"], answer: "Seven o'clock", accepted: [], explanation: "The summer timetable applies, so the gates are locked at seven."),
        ]
    )

    static let moreTask1: [WritingTask] = [
        WritingTask(
            taskNumber: 1,
            prompt: "The pie chart shows how one city's household waste was disposed of in 2024.\n\nSummarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            chart: ChartSpec(kind: "pie", title: "Household waste by disposal method, 2024", xLabel: "Method", yLabel: "Share of waste (%)",
                             categories: ["Landfill", "Recycling", "Incineration", "Composting", "Other"],
                             series: [ChartSeries(name: "2024", values: [38, 29, 18, 12, 3])])),
        WritingTask(
            taskNumber: 1,
            prompt: "The table shows the average number of hours per week that students in three age groups spent on four activities.\n\nSummarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            chart: ChartSpec(kind: "table", title: "Weekly hours by activity and age group", xLabel: "Activity", yLabel: "Hours per week",
                             categories: ["Studying", "Paid work", "Sport", "Screen time"],
                             series: [ChartSeries(name: "Age 12–14", values: [9, 0, 6, 14]),
                                      ChartSeries(name: "Age 15–17", values: [14, 3, 5, 19]),
                                      ChartSeries(name: "Age 18–21", values: [17, 11, 3, 23])])),
        WritingTask(
            taskNumber: 1,
            prompt: "The line graph shows the proportion of electricity generated from four sources in one country between 2000 and 2020.\n\nSummarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            chart: ChartSpec(kind: "line", title: "Electricity generation by source", xLabel: "Year", yLabel: "Share of electricity (%)",
                             categories: ["2000", "2005", "2010", "2015", "2020"],
                             series: [ChartSeries(name: "Coal", values: [52, 48, 40, 29, 16]),
                                      ChartSeries(name: "Gas", values: [25, 28, 31, 33, 34]),
                                      ChartSeries(name: "Nuclear", values: [20, 19, 18, 17, 15]),
                                      ChartSeries(name: "Renewables", values: [3, 5, 11, 21, 35])])),
    ]
}
