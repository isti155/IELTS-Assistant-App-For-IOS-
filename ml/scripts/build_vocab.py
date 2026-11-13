"""Build IELTSKit/Resources/vocabulary.json from:
  - English CEFR Wordlist (w3nabil/english-cefr-wordlist, MIT): word, part of speech, CEFR level
  - WordNet 3.0 (via NLTK): definition, synonyms, antonyms, word family, topic
  - CMU Pronouncing Dictionary: pronunciation, converted to IPA
  - the 1,051 IELTS-style reading passages: a real academic example sentence and frequency
  - the grammar book's wordlist

Run:  ml/.venv/bin/python ml/scripts/build_vocab.py
"""
import collections
import json
import re
from pathlib import Path

import nltk

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "ml" / "data" / "raw"
nltk.data.path.insert(0, str(ROOT / "ml" / "data" / "nltk_data"))
from nltk.corpus import cmudict, wordnet as wn  # noqa: E402

OUT = ROOT / "IELTSKit" / "Sources" / "IELTSKit" / "Resources" / "vocabulary.json"

POS = {"noun": "n", "verb": "v", "adjective": "a", "adverb": "r"}
TOPICS = {
    "noun.body": "Health & body", "verb.body": "Health & body", "noun.state": "Health & body",
    "noun.food": "Food & drink", "verb.consumption": "Food & drink",
    "noun.animal": "Nature & environment", "noun.plant": "Nature & environment", "noun.object": "Nature & environment",
    "noun.phenomenon": "Science & technology", "noun.substance": "Science & technology", "noun.artifact": "Science & technology",
    "noun.quantity": "Science & technology", "noun.shape": "Science & technology",
    "noun.communication": "Media & communication", "verb.communication": "Media & communication",
    "noun.cognition": "Education & thinking", "verb.cognition": "Education & thinking",
    "noun.feeling": "Feelings & personality", "verb.emotion": "Feelings & personality", "adj.all": "Describing things",
    "adj.pert": "Describing things", "adv.all": "Describing actions",
    "noun.possession": "Money & work", "verb.possession": "Money & work",
    "noun.group": "Society & government", "verb.social": "Society & government", "noun.act": "Society & government",
    "noun.person": "People & relationships", "noun.relation": "People & relationships",
    "noun.location": "Places & travel", "verb.motion": "Places & travel", "noun.motion": "Places & travel",
    "noun.time": "Time & change", "verb.change": "Time & change", "noun.event": "Time & change", "noun.process": "Time & change",
    "verb.creation": "Arts & culture", "verb.competition": "Sport & leisure", "verb.contact": "Everyday actions",
    "verb.perception": "Everyday actions", "noun.attribute": "Describing things", "verb.stative": "Everyday actions",
}

ARPABET = {
    "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ", "B": "b", "CH": "tʃ", "D": "d", "DH": "ð",
    "EH": "e", "ER": "ɜr", "EY": "eɪ", "F": "f", "G": "ɡ", "HH": "h", "IH": "ɪ", "IY": "i", "JH": "dʒ", "K": "k",
    "L": "l", "M": "m", "N": "n", "NG": "ŋ", "OW": "oʊ", "OY": "ɔɪ", "P": "p", "R": "r", "S": "s", "SH": "ʃ",
    "T": "t", "TH": "θ", "UH": "ʊ", "UW": "u", "V": "v", "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
}
VOWELS = {"AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW"}


ONSETS = {("P", "R"), ("B", "R"), ("T", "R"), ("D", "R"), ("K", "R"), ("G", "R"), ("F", "R"), ("TH", "R"), ("SH", "R"),
          ("P", "L"), ("B", "L"), ("K", "L"), ("G", "L"), ("F", "L"), ("S", "L"), ("S", "P"), ("S", "T"), ("S", "K"),
          ("S", "M"), ("S", "N"), ("S", "W"), ("T", "W"), ("K", "W"), ("D", "W"), ("G", "W"), ("P", "Y"), ("B", "Y"),
          ("K", "Y"), ("F", "Y"), ("M", "Y"), ("V", "Y"), ("HH", "Y")}


def ipa(phones):
    """ARPAbet → IPA, with the primary stress mark before the stressed syllable's onset."""
    bases = [re.match(r"([A-Z]+)(\d?)", p).groups() for p in phones]
    vowels = [i for i, (b, _) in enumerate(bases) if b in VOWELS]
    stressed = next((i for i, (_, st) in enumerate(bases) if st == "1"), None)
    mark_at = None
    if stressed is not None and len(vowels) > 1:
        start = stressed
        previous_vowel = max([v for v in vowels if v < stressed], default=-1)
        # Extend the onset backwards while the consonants form a legal English onset.
        if start - 1 > previous_vowel and bases[start - 1][0] not in VOWELS:
            start -= 1
            if start - 1 > previous_vowel and (bases[start - 1][0], bases[start][0]) in ONSETS:
                start -= 1
                if start - 1 > previous_vowel and bases[start - 1][0] == "S" and (bases[start][0], bases[start + 1][0]) in ONSETS:
                    start -= 1
        mark_at = start
    out = []
    for i, (base, stress) in enumerate(bases):
        if i == mark_at:
            out.append("ˈ")
        if base in VOWELS:
            out.append("ə" if base == "AH" and stress == "0" else ("ər" if base == "ER" and stress == "0" else ARPABET[base]))
        else:
            out.append(ARPABET.get(base, ""))
    return "/" + "".join(out) + "/"


# ---------------------------------------------------------------- corpus: academic sentences

passages = []
for split in ("train", "validation", "test"):
    with open(RAW / f"reading_tests_{split}.jsonl") as handle:
        for line in handle:
            test = json.loads(line)
            passages.extend(p["text"] for p in test["paragraphs"])
sentences = []
for paragraph in passages:
    for sentence in re.split(r"(?<=[.!?])\s+(?=[A-Z\"'])", paragraph):
        words = sentence.split()
        if 8 <= len(words) <= 26 and not re.search(r"[;()\[\]]", sentence):
            sentences.append(sentence.strip())
index = collections.defaultdict(list)
frequency = collections.Counter()
for number, sentence in enumerate(sentences):
    for token in set(re.findall(r"[a-z][a-z'-]+", sentence.lower())):
        index[token].append(number)
for paragraph in passages:
    frequency.update(re.findall(r"[a-z][a-z'-]+", paragraph.lower()))
print(f"{len(sentences)} example sentences from {len(passages)} paragraphs")

# ---------------------------------------------------------------- the book's wordlist

book_words = set()
try:
    from pypdf import PdfReader
    reader = PdfReader(str(next(ROOT.glob("Mentors*Grammar*.pdf"))))
    if reader.is_encrypted:
        reader.decrypt("")
    for page in reader.pages[173:]:
        for line in (page.extract_text() or "").split("\n"):
            match = re.match(r"^\s*([A-Z][A-Za-z' -]{1,30}?)\s*[-–]", line)
            if match:
                book_words.add(match.group(1).strip().lower())
except Exception as error:
    print("book wordlist skipped:", error)
print(f"{len(book_words)} words in the book's wordlist")

# ---------------------------------------------------------------- entries

pronunciations = cmudict.dict()
LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]
rows = [json.loads(line)["value"] for line in open(RAW / "cefr_words.jsonl")]
# Book words missing from the CEFR list are added at B2 (they are academic course words).
known = {r["word"].lower() for r in rows}
for word in sorted(book_words - known):
    synsets = wn.synsets(word)
    if synsets and " " not in word:
        name = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective", "r": "adverb"}[synsets[0].pos()]
        rows.append(dict(word=word, type=name, level="B2"))

used_sentences = collections.Counter()
entries, seen = [], set()
for row in rows:
    word, kind, level = row["word"].strip(), row["type"].strip().lower(), row["level"].strip().upper()
    if level not in LEVELS or (word.lower(), kind) in seen or not re.fullmatch(r"[A-Za-z][A-Za-z' -]*", word):
        continue
    seen.add((word.lower(), kind))
    pos = POS.get(kind)
    synsets = wn.synsets(word.replace(" ", "_"), pos=pos) if pos else []
    if pos == "a":
        synsets += wn.synsets(word.replace(" ", "_"), pos="s")
    if not synsets:
        continue
    sense = synsets[0]
    lemma_names = []
    for s in synsets[:3]:
        for lemma in s.lemmas():
            name = lemma.name().replace("_", " ")
            if name.lower() != word.lower() and name not in lemma_names and len(name) < 22:
                lemma_names.append(name)
    antonyms = sorted({a.name().replace("_", " ") for s in synsets[:2] for l in s.lemmas() for a in l.antonyms()})[:3]
    family = sorted({d.name().replace("_", " ") for l in sense.lemmas() if l.name().lower() == word.lower().replace(" ", "_")
                     for d in l.derivationally_related_forms() if d.name().lower() != word.lower()})[:4]
    examples = [e for e in sense.examples() if word.lower().split()[0][:4] in e.lower()][:1]
    # An academic example from the reading passages, preferring sentences not already used.
    candidates = index.get(word.lower(), [])
    if candidates:
        best = min(candidates[:400], key=lambda n: (used_sentences[n], abs(len(sentences[n].split()) - 16)))
        used_sentences[best] += 1
        examples.append(sentences[best])
    phones = pronunciations.get(word.lower())
    entry = dict(
        w=word, p=kind, l=level,
        d=sense.definition(),
        e=examples[:2],
        s=lemma_names[:4],
        a=antonyms,
        f=family,
        t=TOPICS.get(sense.lexname(), "General"),
        i=ipa(phones[0]) if phones else None,
        n=frequency.get(word.lower(), 0),
    )
    if word.lower() in book_words:
        entry["b"] = 1
    entries.append({k: v for k, v in entry.items() if v not in (None, [], "")})

entries.sort(key=lambda e: (LEVELS.index(e["l"]), e["w"].lower()))
OUT.write_text(json.dumps(dict(
    sources=["English CEFR Wordlist (CEFR-J and Octanove, MIT)", "Princeton WordNet 3.0", "CMU Pronouncing Dictionary",
             "IELTS-style reading passages (irfanhossainsust, MIT)"],
    words=entries), ensure_ascii=False, separators=(",", ":")))

by_level = collections.Counter(e["l"] for e in entries)
by_topic = collections.Counter(e["t"] for e in entries)
academic = sum(1 for e in entries if e["l"] in ("B2", "C1", "C2") and e.get("n", 0) >= 20)
print(f"{len(entries)} words written ({OUT.stat().st_size // 1024} KB)")
print("levels:", dict(sorted(by_level.items())))
print("topics:", by_topic.most_common())
print("with academic example:", sum(1 for e in entries if any(len(x.split()) >= 8 for x in e.get("e", []))),
      "| with IPA:", sum(1 for e in entries if "i" in e), "| B2+ words seen 20+ times in passages:", academic,
      "| book words:", sum(1 for e in entries if e.get("b")))
for e in entries[::1700]:
    print(json.dumps(e, ensure_ascii=False)[:400])
