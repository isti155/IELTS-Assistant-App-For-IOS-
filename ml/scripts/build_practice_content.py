"""Build practice content for the app from public datasets:

  reading_bank.json   1,051 IELTS-style reading tests (irfanhossainsust/ielts-style-reading-passage3, MIT)
  speaking_bank.json  speaking topics with Part 1/2/3 questions (Binhminh1210/ieltsspeaking-testbank)
                      and transcripts of real speaking tests with bands (Amanafif554/IELTS-Speaking-Clean-1)
  writing_bank.json   Task 2 questions with the highest-rated sample essay for each, and Task 1 questions
                      with their chart image and a sample answer (TraTacXiMuoi/Ielts_writing_task1_academic)
  task1/*.jpg         the Task 1 chart images

Run:  ml/.venv/bin/python ml/scripts/build_practice_content.py
"""
import io
import json
import re
import urllib.request
from pathlib import Path

import pandas as pd
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "ml" / "data" / "raw"
DATA = ROOT / "ml" / "data"
RES = ROOT / "IELTSKit" / "Sources" / "IELTSKit" / "Resources"
TASK1_DIR = RES / "Task1"
TASK1_DIR.mkdir(parents=True, exist_ok=True)


def fetch(url, path=None, attempts=4):
    import time
    request = urllib.request.Request(url, headers={"User-Agent": "dataset-downloader"})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            break
        except Exception:
            if attempt == attempts - 1:
                raise
            time.sleep(3 * (attempt + 1))
    if path:
        Path(path).write_bytes(data)
    return data


def rows(dataset, total, length=100):
    out = []
    for offset in range(0, total, length):
        url = f"https://datasets-server.huggingface.co/rows?dataset={dataset}&config=default&split=train&offset={offset}&length={length}"
        out.extend(r["row"] for r in json.loads(fetch(url))["rows"])
    return out


# ---------------------------------------------------------------- reading

tests = []
for split in ("train", "validation", "test"):
    for line in open(RAW / f"reading_tests_{split}.jsonl"):
        t = json.loads(line)
        groups = []
        for g in t["question_groups"]:
            groups.append(dict(
                type=g["type"], instructions=g["instructions"],
                options=[dict(label=o["label"], text=o["text"]) for o in g.get("options") or []],
                summary=g.get("summary_text") or None,
                questions=[dict(
                    n=q["number"], q=q["question"],
                    options=[dict(label=o["label"], text=o["text"]) for o in q.get("options") or []],
                    a=q["answer"], ev=q.get("evidence") if q.get("evidence") not in (None, "", "none") else None,
                    p=q.get("paragraph") or None, x=q.get("explanation") or None,
                    dn=q.get("distractor_notes") or None,
                ) for q in g["questions"]],
            ))
        tests.append(dict(
            id=t["id"], area=t["subject_area"], topic=t["topic"], hard=t["difficulty"] == "hard",
            title=t["title"], subtitle=t.get("subtitle") or "",
            paragraphs=[dict(label=p["label"], text=p["text"]) for p in t["paragraphs"]],
            groups=groups,
            paraphrases=[dict(passage=pp["passage"], question=pp["question"]) for pp in t.get("paraphrase_pairs") or []],
        ))
(RES / "reading_bank.json").write_text(json.dumps(tests, ensure_ascii=False, separators=(",", ":")))
print(f"reading: {len(tests)} tests, {sum(len(q['questions']) for t in tests for q in t['groups'])} questions, "
      f"{(RES / 'reading_bank.json').stat().st_size // 1024} KB")

# ---------------------------------------------------------------- speaking

bank_path = RAW / "speaking_testbank.parquet"
if not bank_path.exists():
    fetch("https://huggingface.co/api/datasets/Binhminh1210/ieltsspeaking-testbank/parquet/default/train/0.parquet", bank_path)
frame = pd.read_parquet(bank_path)
part1, part2, part3 = {}, [], {}
for _, row in frame.iterrows():
    try:
        raw = json.loads(row["raw_question"])
    except Exception:
        continue
    part = str(raw.get("part") or row["part"]).lower()
    topic = str(raw.get("subtopic") or raw.get("topic") or row["topic"]).strip()
    questions = raw.get("question") or []
    if isinstance(questions, str):
        questions = [questions]
    questions = [q.strip() for q in questions if isinstance(q, str) and q.strip()]
    if "1" in part and questions:
        part1.setdefault(topic, []).extend(q for q in questions if q not in part1.get(topic, []))
    elif "3" in part and questions:
        part3.setdefault(topic, []).extend(q for q in questions if q not in part3.get(topic, []))
    elif "2" in part:
        title = (raw.get("title") or (questions[0] if questions else "")).strip()
        bullets = raw.get("cueCard") or raw.get("bullets") or []
        if isinstance(bullets, str):
            bullets = [b.strip() for b in re.split(r"\n|;", bullets) if b.strip()]
        if title.lower().startswith("describe"):
            part2.append(dict(topic=title, bullets=[b for b in bullets if isinstance(b, str)][:5], theme=topic))
print(f"speaking bank: {len(part1)} Part 1 topics ({sum(map(len, part1.values()))} questions), "
      f"{len(part2)} cue cards, {len(part3)} Part 3 topics ({sum(map(len, part3.values()))} questions)")

samples = []
try:
    for row in rows("Amanafif554/IELTS-Speaking-Clean-1", 94):
        text = (row.get("transcription") or "").strip()
        band = row.get("band_score")
        if text and band is not None:
            turns = []
            for chunk in re.split(r"\s*\|\s*|\n+", text):
                match = re.match(r"^(Examiner|Candidate)\s*:\s*(.+)$", chunk.strip(), re.I)
                if match:
                    turns.append(dict(who=match.group(1).capitalize(), text=match.group(2).strip()))
                elif turns:
                    turns[-1]["text"] += " " + chunk.strip()
            if len(turns) >= 6:
                samples.append(dict(band=float(band), turns=turns))
except Exception as error:
    print("speaking samples skipped:", error)
samples.sort(key=lambda s: -s["band"])
print(f"speaking samples: {len(samples)} transcripts, bands {sorted({s['band'] for s in samples})}")
(RES / "speaking_bank.json").write_text(json.dumps(dict(
    part1=[dict(topic=k, questions=v[:8]) for k, v in sorted(part1.items()) if len(v) >= 3],
    cueCards=part2,
    part3=[dict(topic=k, questions=v[:8]) for k, v in sorted(part3.items()) if len(v) >= 3],
    samples=samples,
), ensure_ascii=False, separators=(",", ":")))

# ---------------------------------------------------------------- writing

def norm(text):
    return re.sub(r"[^a-z0-9]", "", (text or "").lower())[:160]


bank = json.load(open(RES / "question_bank.json"))
essays = {}
for split in ("train", "val", "test"):
    for line in open(DATA / f"scoring_{split}.jsonl"):
        r = json.loads(line)
        if r["task"] == 2 and r["overall"] is not None and 260 <= len(r["essay"].split()) <= 420:
            key = norm(r["prompt"])
            if key not in essays or r["overall"] > essays[key]["band"]:
                essays[key] = dict(band=r["overall"], essay=r["essay"])
task2 = []
for prompt in bank["task2"]:
    model = essays.get(norm(prompt))
    task2.append(dict(prompt=prompt, sample=model["essay"] if model and model["band"] >= 7 else None,
                      band=model["band"] if model and model["band"] >= 7 else None))
print(f"writing task 2: {len(task2)} questions, {sum(1 for t in task2 if t['sample'])} with a band 7+ sample essay")

task1, seen = [], set()
shard = RAW / "task1_0.parquet"
if not shard.exists():
    fetch("https://huggingface.co/api/datasets/TraTacXiMuoi/Ielts_writing_task1_academic/parquet/default/train/0.parquet", shard)
for old in TASK1_DIR.glob("*.jpg"):
    old.unlink()
frame = pd.read_parquet(shard, columns=["topic", "subject", "image", "content", "overall_band_score"])
frame["band"] = pd.to_numeric(frame["overall_band_score"], errors="coerce")
frame = frame[frame["band"] >= 8].sort_values("band", ascending=False)
per_kind = {}
for _, row in frame.iterrows():
    key = norm(row["subject"])[:80]
    kind = (row["topic"] or "Chart").strip()
    if key in seen or per_kind.get(kind, 0) >= 25 or not isinstance(row["image"], dict) or not row["image"].get("bytes"):
        continue
    words = len((row["content"] or "").split())
    if not 150 <= words <= 320:
        continue
    try:
        image = Image.open(io.BytesIO(row["image"]["bytes"])).convert("RGB")
    except Exception:
        continue
    image.thumbnail((900, 900))
    name = f"task1-{len(task1) + 1:03d}.jpg"
    image.save(TASK1_DIR / name, "JPEG", quality=72, optimize=True)
    seen.add(key)
    per_kind[kind] = per_kind.get(kind, 0) + 1
    prompt = re.sub(r"\s+", " ", row["subject"]).strip()
    if "summarise" not in prompt.lower() and "summarize" not in prompt.lower():
        prompt += " Summarise the information by selecting and reporting the main features, and make comparisons where relevant."
    task1.append(dict(kind=kind, prompt=prompt, image=name, sample=row["content"].strip(), band=float(row["band"])))
    if len(task1) >= 120:
        break
print("task 1 kinds:", per_kind)
size = sum(f.stat().st_size for f in TASK1_DIR.glob("*.jpg"))
print(f"writing task 1: {len(task1)} questions with images ({size // 1024} KB of images)")
(RES / "writing_bank.json").write_text(json.dumps(dict(task1=task1, task2=task2), ensure_ascii=False, separators=(",", ":")))
