"""Download the public IELTS datasets and build:

  ml/data/scoring_{train,val,test}.jsonl   essays with band labels for the scorer
  IELTSKit/Sources/IELTSKit/Resources/question_bank.json   prompts for the app

Run:  ml/.venv/bin/python ml/scripts/prepare_data.py
"""
import hashlib
import json
import random
import re
from pathlib import Path

from datasets import load_dataset

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "ml" / "data"
RESOURCES = ROOT / "IELTSKit" / "Sources" / "IELTSKit" / "Resources"
DATA.mkdir(parents=True, exist_ok=True)
RESOURCES.mkdir(parents=True, exist_ok=True)
random.seed(7)

CRITERIA = {
    "tr": r"Task (?:Achievement|Response)",
    "cc": r"Coherence (?:and|&) Cohesion",
    "lr": r"Lexical Resource",
    "gra": r"Grammatical Range (?:and|&) Accuracy",
}


def band(value):
    """Parse a band label such as '7.5', '<4' or 6 into a float in 1..9, else None."""
    if value is None:
        return None
    text = str(value).strip()
    if text.startswith("<"):
        return 3.5
    match = re.search(r"\d+(?:\.\d+)?", text)
    if not match:
        return None
    number = float(match.group())
    if not 1 <= number <= 9:
        return None
    return round(number * 2) / 2


def criteria_from_text(evaluation):
    """Pull per-criterion bands out of an evaluation such as '**Lexical Resource: [7]**'."""
    text = evaluation or ""
    # Locate each criterion heading, then read the score inside that criterion's section.
    starts = {}
    for key, pattern in CRITERIA.items():
        match = re.search(pattern, text, re.I)
        if match:
            starts[key] = match.start()
    found = {key: None for key in CRITERIA}
    ordered = sorted(starts.items(), key=lambda item: item[1])
    for position, (key, start) in enumerate(ordered):
        end = ordered[position + 1][1] if position + 1 < len(ordered) else len(text)
        section = text[start:end]
        heading = re.match(r"[^\n]*", section).group()
        on_heading = re.search(r"[:\[\]*\s](\d(?:\.[05])?)\s*\]?\**\s*$", heading)
        labelled = re.search(r"(?i)(?:band score|score|band)[^\d\n]{0,40}?(\d(?:\.[05])?)(?![\d.])", section)
        match = on_heading or labelled
        found[key] = band(match.group(1)) if match else None
    return found


def clean(text):
    return re.sub(r"[ \t]+", " ", (text or "").replace("\r", "\n")).strip()


def clean_prompt(text):
    text = clean(text)
    text = re.sub(r"\n\s*\n+", "\n\n", text)
    # Drop boilerplate instructions that the app adds itself.
    text = re.sub(r"(?is)\s*(give reasons for your answer.*|you should write at least.*|write at least \d+ words.*)$", "", text)
    return text.strip()


def all_splits(name):
    dataset = load_dataset(name)
    for split in dataset:
        for row in dataset[split]:
            yield row


records = []

print("Loading nlpatunt/D_Ielts_Writing_Dataset (essays with examiner-style overall bands)…")
for row in all_splits("nlpatunt/D_Ielts_Writing_Dataset"):
    records.append(dict(source="scored_essays", task=int(row["Task_Type"]), prompt=clean_prompt(row["Question"]),
                        essay=clean(row["Essay"]), overall=band(row["Overall_Score"]),
                        tr=None, cc=None, lr=None, gra=None))

print("Loading chillies/IELTS-writing-task-2-evaluation…")
for row in all_splits("chillies/IELTS-writing-task-2-evaluation"):
    scores = criteria_from_text(row["evaluation"])
    records.append(dict(source="task2_eval", task=2, prompt=clean_prompt(row["prompt"]), essay=clean(row["essay"]),
                        overall=band(row["band"]), **scores))

print("Loading hai2131/IELTS-essays-task-1…")
for row in all_splits("hai2131/IELTS-essays-task-1"):
    records.append(dict(source="task1_eval", task=1, prompt=clean_prompt(row["subject"]), essay=clean(row["content"]),
                        overall=band(row["overall_band_score"]), tr=band(row["task_response_score"]),
                        cc=band(row["coherence_cohesion_score"]), lr=band(row["lexical_resource_score"]),
                        gra=band(row["grammatical_range_accuracy_score"])))

# Keep usable rows and drop duplicate essays (the collections overlap).
# The examiner-scored set is listed first, so its label wins when an essay repeats.
seen, unique = set(), []
for record in records:
    words = len(record["essay"].split())
    if record["overall"] is None or words < 40 or words > 900:
        continue
    key = hashlib.md5(re.sub(r"[^a-z0-9]", "", record["essay"].lower())[:300].encode()).hexdigest()
    if key in seen:
        continue
    seen.add(key)
    unique.append(record)

random.shuffle(unique)
train, val, test = [], [], []
for record in unique:
    draw = random.random()
    # Hold out more of the examiner-scored set: it is the benchmark that matters.
    test_share = 0.20 if record["source"] == "scored_essays" else 0.04
    if draw < test_share:
        test.append(record)
    elif draw < test_share + 0.04:
        val.append(record)
    else:
        train.append(record)

for name, rows in [("train", train), ("val", val), ("test", test)]:
    with open(DATA / f"scoring_{name}.jsonl", "w") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    by_source = {}
    for row in rows:
        by_source[row["source"]] = by_source.get(row["source"], 0) + 1
    print(f"{name}: {len(rows)} essays {by_source}")

# ---------------------------------------------------------------- question bank
def distinct(items, limit, key=lambda x: x):
    seen, out = set(), []
    for item in items:
        k = re.sub(r"[^a-z0-9]", "", key(item).lower())[:80]
        if k and k not in seen:
            seen.add(k)
            out.append(item)
    random.shuffle(out)
    return out[:limit]


task2 = distinct([r["prompt"] for r in unique if r["task"] == 2 and 15 <= len(r["prompt"].split()) <= 90], 400)

print("Loading speaking question sets…")
part1 = []
try:
    for row in all_splits("qwertyuiopasdfg/IELTs-Speaking-answer"):
        question = clean(row["instruction"])
        if question.endswith("?") and len(question.split()) <= 20:
            part1.append(question)
except Exception as error:  # the bank still works without this set
    print("  skipped part 1 questions:", error)
cue_cards = []
try:
    for row in all_splits("felixnatanaelbutarbutar/coherence-speaking-part2-ielts"):
        bullets = [b.strip() for b in clean(row["quecard"]).split(";") if b.strip()]
        topic = clean(row["prompt"])
        if topic.lower().startswith("describe") and 3 <= len(bullets) <= 5:
            cue_cards.append(dict(topic=topic, bullets=bullets))
except Exception as error:
    print("  skipped cue cards:", error)

bank = dict(
    task2=task2,
    part1=distinct(part1, 200),
    cueCards=distinct(cue_cards, 150, key=lambda c: c["topic"]),
)
with open(RESOURCES / "question_bank.json", "w") as handle:
    json.dump(bank, handle, ensure_ascii=False, indent=1)
print("question bank:", {k: len(v) for k, v in bank.items()})
