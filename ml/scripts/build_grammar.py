"""Turn the Mentors' Foundation Grammar & Writing PDF into IELTSKit/Resources/grammar.json:
chapters with lesson sections, and the book's exercises paired with its answer key.

Run:  ml/.venv/bin/python ml/scripts/build_grammar.py
"""
import json
import re
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
PDF = next(ROOT.glob("Mentors*Grammar*.pdf"))
OUT = ROOT / "IELTSKit" / "Sources" / "IELTSKit" / "Resources" / "grammar.json"
REPORT = ROOT / "ml" / "grammar" / "report.txt"

# ---------------------------------------------------------------- text

reader = PdfReader(str(PDF))
if reader.is_encrypted:
    reader.decrypt("")
PAGES = {}
for number, page in enumerate(reader.pages, start=1):
    lines = []
    for line in (page.extract_text() or "").split("\n"):
        # The book's symbol font puts private-use characters in headers and bullets.
        line = re.sub(r"^\s*[\ue000-\uf8ff]\s*", "• ", line)
        line = re.sub(r"[\ue000-\uf8ff]", "", line)
        if re.search(r"MENTRS|Foundation Grammar & Writing Page", line):
            continue
        lines.append(line.rstrip())
    PAGES[number] = "\n".join(lines)


def fix(text):
    """Repair common extraction artefacts: split words and stray spaces before punctuation."""
    text = text.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    text = re.sub(r"\b(Progressi|ensu|th|mountai|routine|empower|alien) (ve|res|eoretical|n|s|st|ate)\b",
                  lambda m: m.group(1) + m.group(2), text)
    text = re.sub(r"(\w) ([,.;:!?])", r"\1\2", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


CHAPTERS = [
    (1, "Nouns", 6, 15), (2, "Pronouns", 16, 23), (3, "Sentence Structure & Verbs", 24, 30),
    (4, "Articles, Capitals & Punctuation", 31, 42), (5, "Adjectives", 43, 49), (6, "Adverbs", 50, 54),
    (7, "Prepositions", 55, 65), (8, "Sentence Types", 66, 74), (9, "Present Tense", 75, 85),
    (10, "Past Tense", 86, 92), (11, "Future Tense", 93, 96), (12, "Subject–Verb Agreement", 97, 103),
    (13, "Modal Verbs", 104, 110), (14, "Conditional Sentences", 111, 116), (15, "Verbals", 117, 120),
    (16, "Voice", 121, 133),
]
SYMBOLS = {1: "cube.fill", 2: "person.2.fill", 3: "rectangle.split.3x1.fill", 4: "textformat", 5: "paintpalette.fill",
           6: "speedometer", 7: "arrow.down.right.and.arrow.up.left", 8: "list.bullet.indent", 9: "clock.fill",
           10: "clock.arrow.circlepath", 11: "calendar", 12: "equal.circle.fill", 13: "hand.raised.fill",
           14: "arrow.triangle.branch", 15: "ellipsis.curlybraces", 16: "arrow.left.arrow.right"}

EXERCISE_HEAD = re.compile(r"(?m)^\s*(\d{1,2})\s?\.\s?(\d{1,2})\s+(?:Exercise:\s*)?([A-Z][^\n]*)$")

# ---------------------------------------------------------------- answer key

key_text = "\n".join(PAGES[n] for n in range(144, 174))
KEY = {}
parts = re.split(r"(?m)^\s*(\d{1,2})\s?\.\s?(\d{1,2})\s*$", key_text)
for i in range(1, len(parts) - 2, 3):
    KEY[f"{int(parts[i])}.{int(parts[i + 1])}"] = parts[i + 2].strip()


def looks_like_heading(line):
    words = line.split()
    return (1 <= len(words) <= 6 and line[0].isupper() and "_" not in line
            and not re.search(r"[.?!,;:)\]]$", line) and not re.search(r"\b[A-D]\)", line))


def numbered(text, near_start=False):
    """'1. foo\\n2. bar' → {1: 'foo', 2: 'bar'}. Continuation lines join the item; the list ends
    when numbering restarts or a heading appears (the lesson text that follows an exercise)."""
    items, current, last = {}, None, 0
    for index, raw in enumerate(text.split("\n")):
        line = raw.strip()
        match = re.match(r"^(\d{1,2})\s?[.)]\s*(.*)$", line)
        if match:
            number = int(match.group(1))
            if number <= last or (near_start and not items and index > 6):
                break
            current = last = number
            items[number] = match.group(2).strip()
        elif current is not None and line:
            if re.match(r"^(Answers?:?|Chapter-\d+)$", line, re.I):
                continue
            if looks_like_heading(line):
                break
            items[current] += " " + line
    return {k: fix(v) for k, v in items.items()}


# ---------------------------------------------------------------- exercises

GAP = re.compile(r"_{2,}")
HINT_AFTER = re.compile(r"^\s*[\(\[]([^\)\]]{1,60})[\)\]]")


def norm(text):
    return re.sub(r"[^a-z0-9' ]", "", text.lower().replace("’", "'")).split()


def derive_gaps(item, answer):
    """Find what fills each gap by matching the gapped item against the corrected sentence."""
    pieces = GAP.split(item)
    if len(pieces) < 2:
        return None
    def fixed(piece):
        words = re.findall(r"[A-Za-z0-9']+", piece)
        return r"[^A-Za-z0-9']*".join(re.escape(w) for w in words)
    pattern = r"^[^A-Za-z0-9']*" + r"[^A-Za-z0-9']*(.*?)[^A-Za-z0-9']*".join(fixed(p) for p in pieces) + r"[^A-Za-z0-9']*$"
    match = re.match(pattern, answer.strip(), re.I)
    if not match:
        return None
    fills = [g.strip(" ,.;:!?\"'") for g in match.groups()]
    return fills if all(len(f.split()) <= 5 for f in fills) else None


def clean_fill(fill):
    fill = fill.strip()
    if fill.lower() in {"x", "-", "–", "no article", "(x)", "×"}:
        return ""
    return fill


def options_from_hint(hint):
    if "/" in hint:
        return [o.strip() for o in hint.split("/") if o.strip()]
    return None


def parse_items(body, key):
    """Sentence-by-sentence exercises: gaps, choices, MCQ letters, classification or rewriting."""
    items = numbered(body, near_start=True)
    answers = numbered(key)
    if len(items) < 3 or not answers:
        return None
    result, failed = [], 0
    for number in sorted(items):
        if number not in answers:
            failed += 1
            continue
        prompt, answer = items[number], answers[number]
        letters = re.findall(r"\(?([A-Da-d])\)\s*(.+?)(?=\s+\(?[A-Da-d]\)|$)", prompt)
        if len(letters) >= 3:
            stem = re.split(r"\s\(?[Aa]\)", prompt)[0].strip()
            options = [text.strip() for _, text in letters]
            chosen = re.match(r"^\(?([A-Da-d])\)", answer.strip())
            if not chosen or "ABCD".index(chosen.group(1).upper()) >= len(options):
                failed += 1
                continue
            result.append(dict(kind="choice", prompt=stem, options=options,
                               answers=[options["ABCD".index(chosen.group(1).upper())]]))
            continue
        hint_match = re.search(r"\(([^()]*?/[^()]*?)\)", prompt)
        options = options_from_hint(hint_match.group(1)) if hint_match else None
        gaps = len(GAP.findall(prompt))
        if gaps:
            stripped = re.sub(r"\s*\(([^()]*?/[^()]*?)\)", "", prompt) if options else prompt
            fixed_words = set(norm(GAP.sub(" ", re.sub(r"\([^()]*\)", " ", stripped))))
            answer_words = set(norm(answer))
            overlap = len(fixed_words & answer_words) / max(1, len(fixed_words))
            if overlap < 0.5:
                fills = [a.strip(" .") for a in re.split(r"[,;]", answer)] if gaps > 1 \
                    else ["/".join(a.strip(" .") for a in re.split(r"[,;]|\bor\b", answer) if a.strip(" ."))]
            else:
                fills = derive_gaps(stripped, answer)
            if not fills or len(fills) != gaps:
                failed += 1
                continue
            hints = []
            for piece in GAP.split(stripped)[1:]:
                hint = HINT_AFTER.match(piece)
                hints.append(hint.group(1) if hint and "/" not in hint.group(1) else None)
            fills = [clean_fill(f) for f in fills]
            if options and gaps == 1 and fills[0] and fills[0].lower() not in [o.lower() for o in options]:
                options = None
            if options and gaps == 1:
                fills = [next(o for o in options if o.lower() == fills[0].lower())] if fills[0] else fills
            result.append(dict(kind="choice" if options and gaps == 1 else "gap", prompt=stripped,
                               options=options, answers=fills, hints=hints,
                               full=answer if overlap >= 0.5 else None))
            continue
        prompt_words, answer_words = prompt.split(), answer.split()
        bare = lambda w: re.sub(r"[^A-Za-z0-9']", "", w)
        if len(prompt_words) == len(answer_words) and len(prompt_words) > 2:
            if all(bare(a).lower() == bare(b).lower() for a, b in zip(prompt_words, answer_words)):
                caps = [i for i, (a, b) in enumerate(zip(prompt_words, answer_words)) if bare(a) != bare(b)]
                commas = [i for i, (a, b) in enumerate(zip(prompt_words, answer_words))
                          if b.rstrip("\"'").endswith(",") and not a.rstrip("\"'").endswith(",")]
                if caps and not commas:
                    result.append(dict(kind="capitalize", prompt=prompt, words=prompt_words, targets=caps,
                                       answers=[answer.strip()]))
                    continue
                if commas and not caps:
                    result.append(dict(kind="punctuate", prompt=prompt, words=[w.rstrip(",") for w in prompt_words],
                                       targets=commas, answers=[answer.strip()]))
                    continue
        label = answer.split("-")[-1].strip() if re.search(r"\S-\s|\s-\s|\S- ", answer) else answer.strip(" .")
        if len(label.split()) <= 3 and "=" not in label:
            result.append(dict(kind="classify", prompt=prompt, answers=[label]))
        elif len(answer.split()) >= 3 and "=" not in answer and len(answer.split()) <= 22:
            result.append(dict(kind="build", prompt=prompt, answers=[answer.strip()]))
        else:
            result.append(dict(kind="self", prompt=prompt, answers=[answer.strip()]))
    classify = [r for r in result if r["kind"] == "classify"]
    if classify:
        labels = sorted({r["answers"][0].lower() for r in classify})
        if len(labels) > 5 or len(labels) * 2 > len(classify):
            for r in classify:
                r["kind"] = "self"
        else:
            for r in classify:
                r["kind"] = "choice"
                r["options"] = [l[0].upper() + l[1:] for l in labels]
                r["answers"] = [r["answers"][0].lower()[0].upper() + r["answers"][0].lower()[1:]]
    return result if result and failed <= max(1, len(items) // 5) else None


def parse_passage(body, key):
    """Running text with gaps marked by a hint in brackets, e.g. 'She ____ [wake] up'."""
    answers = numbered(key)
    pattern = re.compile(r"(?:\(\d{1,2}\)\s*)?_*\s*[\[(]([a-z][a-z /'-]{1,30})[\])]|\(\d{1,2}\)\s*_{2,}|_{3,}")
    text = re.sub(r"\s*\n\s*", " ", body).strip()
    segments, last, gaps = [], 0, 0
    for match in pattern.finditer(text):
        hint = match.group(1)
        if hint and " " in hint.strip() and "/" not in hint:
            if len(hint.split()) > 3:
                continue
        segments.append(dict(text=fix(text[last:match.start()])))
        gaps += 1
        options = options_from_hint(hint) if hint else None
        segments.append(dict(gap=gaps, hint=None if options else ((hint or "").strip() or None), options=options))
        last = match.end()
    segments.append(dict(text=fix(text[last:])))
    if gaps < 4:
        return None
    keyed = [answers.get(i) for i in range(1, gaps + 1)]
    if sum(a is not None for a in keyed) < gaps - 1 or len(answers) > gaps + 1:
        return None
    for segment in segments:
        if "gap" in segment:
            segment["answers"] = [clean_fill(a) for a in (answers.get(segment["gap"]) or "").split("/") if a] or None
    return segments


exercises_by_chapter, report = {}, []
for number, title, first, last in CHAPTERS:
    text = "\n".join(PAGES[n] for n in range(first, last + 1))
    heads = list(EXERCISE_HEAD.finditer(text))
    for index, head in enumerate(heads):
        exercise_id = f"{int(head.group(1))}.{int(head.group(2))}"
        if int(head.group(1)) != number:
            continue
        end = heads[index + 1].start() if index + 1 < len(heads) else len(text)
        body = text[head.end():end]
        # The exercise ends where the next lesson heading starts (a short title-case line without digits).
        cut = re.search(r"\n(?=[A-Z][A-Za-z ,/&'-]{3,60}\n(?:[A-Z][a-z]|\d\.))", body)
        instructions = fix(head.group(3))
        key = KEY.get(exercise_id, "")
        entry = dict(id=exercise_id, instructions=instructions)
        items = parse_items(body if not cut else body[:cut.start()], key) if key else None
        if not items and key:
            items = parse_items(body, key)
        passage = None if items else (parse_passage(body if not cut else body[:cut.start()], key) if key else None)
        if items:
            entry.update(kind="items", items=items)
        elif passage:
            entry.update(kind="passage", passage=passage)
        else:
            entry.update(kind="reveal", text=fix(body if not cut else body[:cut.start()]), key=fix(key) or None)
        exercises_by_chapter.setdefault(number, []).append(entry)
        report.append(f"{exercise_id:6} {entry['kind']:8} {len(entry.get('items') or []) or sum('gap' in s for s in entry.get('passage') or [])} | {instructions[:70]}")
# Answer-key sections whose exercise heading the extractor missed.
for exercise_id, key in KEY.items():
    chapter = int(exercise_id.split(".")[0])
    if not any(e["id"] == exercise_id for e in exercises_by_chapter.get(chapter, [])):
        report.append(f"{exercise_id:6} (answer key only — exercise text not found)")

# ---------------------------------------------------------------- lessons

def is_heading(line, following):
    words = line.split()
    if not 1 <= len(words) <= 8 or len(line) > 70:
        return False
    if re.search(r"[.?!,;]$", line) or re.match(r"^\d", line) or "+" in line:
        return False
    if line.endswith(":"):
        return len(words) <= 6 and line[0].isupper() and "." not in line and not following.startswith(" ")
    capitals = sum(w[0].isupper() for w in words if w[0].isalpha())
    return capitals >= max(1, len(words) - 2) and line[0].isupper()


def lesson_sections(text):
    sections, current = [], None
    lines = [l for l in text.split("\n")]
    examples_mode = False
    for index, raw in enumerate(lines):
        line = raw.strip()
        if not line:
            continue
        following = lines[index + 1] if index + 1 < len(lines) else ""
        indented = raw.startswith("  ")
        if re.match(r"^(For )?[Ee]xamples?( of [^:]*)?:?\s*$", line):
            examples_mode = True
            if current is None:
                current = dict(title="Introduction", blocks=[])
                sections.append(current)
            current["blocks"].append(dict(type="examples", items=[]))
            continue
        bullet = line.startswith("• ")
        if bullet:
            line = line[2:].strip()
        if is_heading(line, following) and not indented and not bullet:
            current = dict(title=fix(line.rstrip(":")), blocks=[])
            sections.append(current)
            examples_mode = False
            continue
        if current is None:
            current = dict(title="Introduction", blocks=[])
            sections.append(current)
        blocks = current["blocks"]
        if re.match(r"^(For )?[Ee]xamples?( of [^:]*)?:?\s*$", line):
            examples_mode = True
            blocks.append(dict(type="examples", items=[]))
            continue
        inline_example = re.match(r"^(?:For )?[Ee]xample[s]?:\s*(.+)$", line)
        if inline_example:
            blocks.append(dict(type="examples", items=[fix(inline_example.group(1))]))
            examples_mode = False
            continue
        if blocks and blocks[-1]["type"] == "formula" and line[0].islower():
            blocks[-1]["text"] = fix(blocks[-1]["text"] + " " + line)
            continue
        if " + " in line and len(line) < 160:
            blocks.append(dict(type="formula", text=fix(line)))
            examples_mode = False
            continue
        rule = re.match(r"^(?:(\d{1,2})\.\s*)?([A-Z][^:]{2,60}):\s*(.*)$", line)
        if rule and not indented:
            blocks.append(dict(type="rule", label=fix(rule.group(2)), text=fix(rule.group(3))))
            examples_mode = False
            continue
        looks_like_example = (indented or examples_mode) and len(line) < 140 and line[0].isupper()
        if looks_like_example:
            if blocks and blocks[-1]["type"] == "examples":
                blocks[-1]["items"].append(fix(line))
            else:
                blocks.append(dict(type="examples", items=[fix(line)]))
            continue
        examples_mode = False
        if blocks and blocks[-1]["type"] in ("text", "rule") and not re.match(r"^\d{1,2}\.", line) \
                and blocks[-1].get("text", "") and not blocks[-1]["text"].endswith((".", ":", "?", "!")):
            blocks[-1]["text"] = fix(blocks[-1]["text"] + " " + line)
        else:
            blocks.append(dict(type="text", text=fix(line)))
    # Drop empty sections and merge tiny ones into the previous section.
    merged = []
    for section in sections:
        section["blocks"] = [b for b in section["blocks"] if b.get("text") or b.get("items")]
        if not section["blocks"]:
            continue
        if merged and sum(len(b.get("text", "")) + sum(map(len, b.get("items", []))) for b in section["blocks"]) < 60:
            merged[-1]["blocks"].extend(section["blocks"])
        else:
            merged.append(section)
    # A section with little content (just a title and a formula, say) is merged into the next
    # one, so every card carries a complete idea: explanation, structure and examples.
    def size(section):
        return sum(len(b.get("text") or "") + len(b.get("label") or "") + sum(map(len, b.get("items") or [])) for b in section["blocks"])
    combined, carry = [], None
    for section in merged:
        if carry:
            section = dict(title=carry["title"], blocks=carry["blocks"] + [dict(type="rule", label=section["title"], text="")] + section["blocks"])
            carry = None
        if size(section) < 220:
            carry = section
        else:
            combined.append(section)
    if carry:
        if combined:
            combined[-1]["blocks"] += [dict(type="rule", label=carry["title"], text="")] + carry["blocks"]
        else:
            combined.append(carry)
    return combined


# The book reuses some exercise numbers; give every exercise a unique id.
for exercises in exercises_by_chapter.values():
    seen_ids = set()
    for exercise in exercises:
        while exercise["id"] in seen_ids:
            exercise["id"] += "b"
        seen_ids.add(exercise["id"])

chapters = []
for number, title, first, last in CHAPTERS:
    text = "\n".join(PAGES[n] for n in range(first, last + 1))
    text = re.sub(r"(?m)^\s*Chapter-\d+\s*$", "", text)
    text = re.sub(rf"(?m)^\s*{re.escape(title.split(' ')[0])}[^\n]*$", "", text, count=1)
    # Remove exercise bodies from the lesson text.
    for head in reversed(list(EXERCISE_HEAD.finditer(text))):
        rest = text[head.end():]
        stop = re.search(r"\n(?=[A-Z][A-Za-z ,/&'-]{3,60}\n(?:[A-Z][a-z]|\d\.))", rest)
        text = text[:head.start()] + (rest[stop.start():] if stop else "")
    sections = lesson_sections(text)
    intro = next((b["text"] for s in sections for b in s["blocks"] if b["type"] == "text" and len(b["text"]) > 60), "")
    chapters.append(dict(id=number, title=title, symbol=SYMBOLS[number], summary=intro[:220],
                         sections=sections, exercises=exercises_by_chapter.get(number, [])))

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(dict(source="Mentors' Foundation Grammar & Writing (1st edition)", chapters=chapters),
                          ensure_ascii=False, separators=(",", ":")))
REPORT.write_text("\n".join(report) + "\n")
kinds = {}
for c in chapters:
    for e in c["exercises"]:
        kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
print(f"{len(chapters)} chapters, {sum(len(c['sections']) for c in chapters)} lesson sections, "
      f"{sum(len(c['exercises']) for c in chapters)} exercises {kinds}; {OUT.stat().st_size // 1024} KB")
print("\n".join(report))
