# IELTS Assistant — plan and architecture

An iPhone app for IELTS Academic preparation that runs entirely on the device. No cloud
service, API key or network request is involved: marking uses models trained on this Mac
from public IELTS datasets.

Last updated: 2026-11-12. Target phone: iPhone 13 Pro Max (6 GB memory, no Apple Intelligence).

## 1. Decisions

| Decision | Choice | Why |
|---|---|---|
| Where AI runs | On the phone only | Owner's requirement (2026-11-12); replaces an earlier cloud-API design |
| Writing bands | DistilBERT (cased) fine-tuned here, run with Core ML | Small enough for the phone (124 MB), can be trained on a 16 GB Mac |
| Explanations and corrections | Rule-based analysis of the candidate's own text plus the system spell checker | Deterministic, specific and never invents errors |
| Free text (tutor chat, conversation replies, written feedback) | Qwen2.5 1.5B, 4-bit, LoRA fine-tuned here, run with MLX | Largest model that fits comfortably in 6 GB; Apple's built-in model needs an iPhone 15 Pro or newer |
| Speech | Apple Speech framework (on-device) and system voices | Free, offline |
| Datasets | Used for personal, non-distributed training | Owner's decision; several have unclear or non-commercial licences, so the app and models must not be distributed |

## 2. Datasets used

| Dataset (Hugging Face) | Rows | Labels | Used for |
|---|---|---|---|
| `nlpatunt/D_Ielts_Writing_Dataset` | 1,435 | Overall band per essay, Task 1 and 2; the most trustworthy labels | Scorer training (weighted ×4) and the main accuracy benchmark |
| `chillies/IELTS-writing-task-2-evaluation` | 10,324 | Overall band plus machine-written evaluation with per-criterion bands | Scorer training; language-model fine-tuning; Task 2 question bank |
| `hai2131/IELTS-essays-task-1` | 13,925 | Overall and four criterion bands (machine-scored) | Scorer training |
| `qwertyuiopasdfg/IELTs-Speaking-answer` | 216 | Question and model answer | Part 1 question bank; language-model fine-tuning |
| `felixnatanaelbutarbutar/coherence-speaking-part2-ielts` | 1,615 | Cue cards (only 15 distinct) | Cue-card bank |

Found but not used yet: `vuihocrnd/IELTStestData4440Entries` (4,413 audio clips with phoneme-level
error labels, 1.4 GB) and speechocean762 — both are for a future pronunciation model.
`TraTacXiMuoi/Ielts_writing_task1_academic` has the Task 1 chart images (770 MB) and could
supply real charts later.

Label quality matters: only the first dataset has examiner-style scores. The two large
collections are machine-scored, and their criterion bands average 0.4 below their own overall
bands, so the per-criterion outputs are the least reliable part of the scorer.

## 3. Measured accuracy of the trained scorer

Trained on 6,885 essays (all 885 examiner-scored training essays plus 3,000 from each
machine-scored collection), 2 epochs, about one hour on an M5. Held-out test results for the
overall band:

| Test set | Essays | Mean error (bands) | Within 0.5 | Within 1.0 | QWK | Error if always guessing the median |
|---|---|---|---|---|---|---|
| Examiner-scored essays | 228 | 0.69 | 60% | 86% | 0.64 | 0.90 |
| Task 1, machine-scored | 373 | 0.66 | 61% | 86% | 0.82 | 1.29 |
| Task 2, machine-scored | 344 | 1.08 | 40% | 64% | 0.46 | 1.19 |

What this means in practice:

- On the benchmark that matters, the model is within half a band 60% of the time and within one
  band 86% of the time. That is useful for tracking progress, but it is not examiner-level
  accuracy: one essay in seven is more than a band out.
- It pulls towards the middle: very strong essays (band 8.5–9) are scored about a band low and
  very weak ones a little high.
- It reads only the first 512 word pieces (about 400 words).
- For Task 1 it cannot see the chart, so it cannot tell whether quoted figures are right.

How to improve it (in order of expected gain): train on all 17,000 essays for 3 epochs
(about three hours); use a larger encoder; obtain more examiner-scored essays.

## 3b. The language model

Qwen2.5-1.5B-Instruct (4-bit) with a LoRA fine-tune: 2,608 examples (examiner feedback from
`chillies/IELTS-writing-task-2-evaluation` and speaking model answers), 500 steps, about 20 minutes
on the M5. Validation loss went from 2.24 to 1.50 at step 400 and 1.56 at step 500. The fused
model is 839 MB (`ml/models/ielts-llm`).

Tested on the Mac before wiring it in:

| Job | Asked from memory | Given the facts |
|---|---|---|
| Essay feedback | Right format, but scored a band 9 essay 7.5 and invented "errors" that would make the essay worse | Sensible comments on idea development, no invented errors |
| Tutor answer (True/False/Not Given) | Partly wrong advice ("use the answer key", "ask someone else") | Correct, taken from the guide, with a slightly muddled example |
| Conversation reply to an error-filled sentence | Corrected it well, in about 1.5 s | — |

So the app never asks the model anything from memory:

- **Tutor chat** retrieves the one or two most relevant of 16 study guides (keyword match
  weighted towards rare words and titles), tells the model to answer only from them, and shows
  "Based on: <guide>" under each answer. Questions no guide covers get "not sure".
- **Comments on ideas** (Writing) pass the scorer's bands and the detected errors as fixed facts;
  the model comments only on how the ideas are developed. It never sets a band.
- **Conversation partner** uses it freely; mistakes there are low-stakes.

Fine-tuning made little difference compared with the base model once prompts carried the facts.

## 4. How a Writing band is produced

1. The Core ML model outputs five numbers: overall, task, coherence, lexical, grammar.
2. The overall band is the model's overall output rounded to a half band. The four criterion
   outputs are shifted so their mean agrees with it, then rounded to whole bands.
3. IELTS rules are applied in code: an under-length response caps the Task criterion
   (below 60% of the minimum: 4; below 80%: 5; below 100%: 6); a Task 1 response without an
   overview caps Task Achievement at 5. The overall band can never exceed the criteria mean.
4. `WritingAnalysis` measures the text (length, paragraphs, linking expressions, vocabulary
   variety, repeated words, sentence complexity, informal items) and finds corrections:
   about 45 common learner-error patterns plus the system spell checker (British and American).
5. The report shows the bands, the measured evidence, specific actions and the caveats.

Speaking is scored without a trained speaking model: Fluency from speech rate, long pauses and
long-turn length; Lexical and Grammar from the writing model applied to the transcript;
Pronunciation inferred from recogniser confidence. Every speaking report says it is a rough guide.

## 5. Architecture

```
IELTS Assistant/
├── IELTSAssistant.xcodeproj         iOS app target (iOS 17+, iPhone)
├── IELTSAssistant/
│   └── IELTSAssistantApp.swift      @main; optional MLX language model (compiled only if MLX is added)
├── IELTSKit/                        Swift package: all logic and UI
│   └── Sources/
│       ├── IELTSKit/
│       │   ├── BandScorer.swift     WordPiece tokenizer + Core ML inference
│       │   ├── WritingAnalysis.swift  Text measurements and corrections
│       │   ├── LocalExaminer.swift  Builds Writing and Speaking reports; TextGenerator protocol
│       │   ├── BandMath.swift       Band rounding, score tables, answer marking
│       │   ├── Speech.swift         Speech-to-text, delivery metrics, text-to-speech
│       │   ├── Content.swift        Question bank, speaking topics, study guides
│       │   ├── SeedContent*.swift   Original reading, listening and writing material
│       │   ├── AppStore.swift       State and JSON persistence
│       │   ├── Resources/           IELTSScorer.mlmodelc, vocabulary, question bank
│       │   └── UI/                  SwiftUI screens
│       └── SelfCheck/main.swift     `swift run SelfCheck`
├── ml/
│   ├── scripts/prepare_data.py      Download datasets; build training set and question bank
│   ├── scripts/train_scorer.py      Fine-tune and evaluate the scorer
│   ├── scripts/export_scorer.py     Convert to Core ML, write reference cases
│   ├── scripts/train_llm.py         LoRA fine-tune of the language model with MLX
│   ├── data/, models/, .venv/       Generated; not in version control
└── docs/PLAN.md
```

## 6. What exists now (version 0.3)

Five tabs: **Home · Practice · Learn · Tutor · Progress**.

| Module | Content | Source |
|---|---|---|
| Grammar course | 61 original units in 7 sections (tenses; modals, verb patterns, passive; nouns and articles; adjectives, comparison, prepositions; clauses and conditionals; accuracy; academic grammar), B1–C1. Each unit: rule cards, form table, common mistakes, "Use it in IELTS" card, 4–9 questions (400 in total: choice, correct sentence, typed gap, find the mistake, word tiles, punctuation). IELTS priority on every unit (30 essential, 22 important, 9 useful). Section tests, IELTS grammar check (one question per essential unit → personal study list), mistakes review | Written for the app (`Resources/GrammarCourse/*.json`) |
| Mentors' book | 16 chapters, 105 lesson cards, 54 exercises (540 auto-marked questions + self-check exercises with the answer key) | Mentors' *Foundation Grammar & Writing* PDF, parsed by `ml/scripts/build_grammar.py` |
| Vocabulary | 9,485 words A1–C2 with definition, IPA, examples, synonyms, antonyms, word family, topic; sets by level, by 17 topics, 761 IELTS academic words, 338 book words | CEFR Wordlist (MIT), WordNet, CMUdict, reading passages (`build_vocab.py`) |
| Tutor | Study plan by phase (Foundation / Skills / Exam), 4 daily tasks that tick themselves off, 25-lesson IELTS course (5 units, 38 check questions), 16 quick-reference guides | Written for the app (`Resources/course.json`) |
| Reading | 1,051 tests, 14,188 questions, 7 question types, evidence + explanation + distractor notes + paraphrase pairs; 2 starter passages | irfanhossainsust/ielts-style-reading-passage3 (MIT, synthetic) |
| Listening | 2 conversations + 421 academic lectures read aloud (built from the reading passages) | as above |
| Writing | 120 Task 1 visuals with images and band 8+ samples (7 types incl. maps and processes), 5 interactive charts, 400 Task 2 questions (237 with band 7+ samples) | TraTacXiMuoi/Ielts_writing_task1_academic, chillies Task 2 set |
| Exam practice | Cambridge IELTS book companion (books 1–21 × 4 tests): timed 40-question answer sheets for Listening and Reading, marking from the learner's own answer key (saved for retakes), real band conversion, question-type mistake tagging linked to tutor lessons, Writing and Speaking for each book test; 263 full Reading papers (3 passages, 40 questions, 60 min); 120 full Writing papers | The books' content is not included: the learner works from their own copy |
| Speaking | Full mock tests, Part 2 practice for 149 cue cards, Part 1 practice for 181 topics, 88 real test transcripts (bands 3.5–9), conversation partner | Binhminh1210/ieltsspeaking-testbank, Amanafif554/IELTS-Speaking-Clean-1 |

Practice modes: flip flashcards with swipe, mixed vocabulary quiz (meaning, word, real-sentence gap,
listen-and-spell), timed matching game, grammar quiz engine (choice, typed gaps with verb hints,
word tiles, tap the capitals, tap to add commas, self-check). Spaced repetition (Leitner boxes:
1, 2, 4, 8, 16, 32 days), XP, daily goal and streak. Learning progress is saved with the rest of
the app state.

No language model is needed. The chat tutor was removed (owner's request, 2026-11-12); the
optional on-device model is used only, if installed, for free conversation replies.

Verified: `swift run SelfCheck` passes (content checks: every grammar and reading answer is
selectable, all images present, spaced repetition and streak logic). The app builds for iPhone
(Debug and Release, no warnings) and was checked screen by screen in the iOS simulator.

## 6b. Interface

Standard iOS patterns throughout, defined once in `UI/Theme.swift` and `UI/Components.swift`:

- Five tabs (Home, Practice, Learn, Tutor, Progress), large titles, inset grouped lists, SF Symbols.
- System colours only, so light mode, dark mode and Dynamic Type work without extra code.
  One colour per skill: Listening purple, Reading teal, Writing orange, Speaking pink; indigo accent.
- Home: overall band ring with a target tick, four skill tiles, "Up next", recent attempts.
- Tests: the main action sits in a bar pinned to the bottom (timer and word count for Writing,
  "8 of 12 answered" for Reading); a dialog asks before submitting a short or incomplete answer.
- Questions are grouped with their instructions as in the real paper; answers are tap-to-choose
  chips or cards, and after marking each card shows the right answer and the reason.
- Reports: band ring, tappable criteria that expand to show the evidence, corrections as
  wrong → right, and an "About this score" note.
- Speaking: part progress bar, examiner card, cue card, countdown rings.
- First launch asks for the target band and test date. App icon and accent colour are in
  `IELTSAssistant/Assets.xcassets`.

Debug builds accept `-screen <name>` at launch (see `UI/DebugScreens.swift`) to open one screen
with sample progress, which is how the screens were checked in the iOS simulator.

## 7. Limits to know about

- Writing and Speaking bands are estimates (section 3); speaking pronunciation is inferred, not measured.
- Reading tests are synthetic IELTS-style Passage 3 material, not official papers; there are no
  Passage 1–2 level tests yet. Lectures are read by the iPhone voice from reading passages.
- Grammar lesson text is extracted from the PDF automatically; a few cards keep the book's
  layout quirks. 14 exercises without a parsable format use self-check with the answer key.
- Word definitions come from WordNet's most common sense, which is occasionally not the sense
  a learner expects.
- Datasets are used for personal study only; several have non-commercial or unclear licences.

## 8. Roadmap

1. Passage 1–2 level reading tests and Section 1–3 listening scripts.
2. Full timed mock exam (L + R + W + S) with one overall band.
3. Retrain the scorer on the full dataset; pronunciation model from the phoneme-labelled audio data.
4. Error log built automatically from writing corrections and wrong grammar answers.
