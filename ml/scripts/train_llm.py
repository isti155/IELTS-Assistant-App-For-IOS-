"""Fine-tune a small language model on IELTS data with MLX (LoRA) and write a
ready-to-bundle model folder to ml/models/ielts-llm.

The base model is about 1.5 billion parameters in 4-bit form (roughly 1 GB), which
fits an iPhone with 6 GB of memory.

Run:  ml/.venv/bin/python ml/scripts/train_llm.py [--iters 600]
"""
import argparse
import json
import random
import re
import subprocess
import sys
from pathlib import Path

from datasets import load_dataset

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "ml" / "data" / "llm"
ADAPTER = ROOT / "ml" / "models" / "ielts-llm-adapter"
OUTPUT = ROOT / "ml" / "models" / "ielts-llm"

parser = argparse.ArgumentParser()
parser.add_argument("--base", default="mlx-community/Qwen2.5-1.5B-Instruct-4bit")
parser.add_argument("--iters", type=int, default=600)
parser.add_argument("--examples", type=int, default=2500)
args = parser.parse_args()
random.seed(7)
DATA.mkdir(parents=True, exist_ok=True)

EXAMINER = ("You are an IELTS Writing examiner. Assess the essay against the four criteria and give "
            "specific, honest feedback with the band for each criterion.")
TUTOR = "You are an expert IELTS tutor. Give a natural, well-developed model answer."


def words(text):
    return len(text.split())


examples = []

print("Building examiner feedback examples…")
dataset = load_dataset("chillies/IELTS-writing-task-2-evaluation")
rows = [row for split in dataset for row in dataset[split]]
random.shuffle(rows)
for row in rows:
    essay, evaluation = row["essay"].strip(), row["evaluation"].strip()
    band = re.search(r"\d(?:\.\d)?", str(row["band"]))
    # Keep examples that fit the training window: essay plus feedback under ~900 words.
    if not band or not 150 <= words(essay) <= 420 or not 80 <= words(evaluation) <= 450:
        continue
    examples.append({"messages": [
        {"role": "system", "content": EXAMINER},
        {"role": "user", "content": f"Question: {row['prompt'].strip()}\n\nEssay:\n{essay}"},
        {"role": "assistant", "content": f"{evaluation}\n\nOverall band: {band.group()}"},
    ]})
    if len(examples) >= args.examples:
        break

print("Building speaking model-answer examples…")
try:
    speaking = load_dataset("qwertyuiopasdfg/IELTs-Speaking-answer")
    for split in speaking:
        for row in speaking[split]:
            examples.append({"messages": [
                {"role": "system", "content": TUTOR},
                {"role": "user", "content": f"Give a model answer to this IELTS Speaking question: {row['instruction'].strip()}"},
                {"role": "assistant", "content": row["response"].strip()},
            ]})
except Exception as error:
    print("  skipped speaking answers:", error)

random.shuffle(examples)
cut = max(20, len(examples) // 25)
for name, part in [("valid", examples[:cut]), ("train", examples[cut:])]:
    with open(DATA / f"{name}.jsonl", "w") as handle:
        for example in part:
            handle.write(json.dumps(example, ensure_ascii=False) + "\n")
print(f"{len(examples) - cut} training and {cut} validation examples")


def run(*command):
    print("\n$", " ".join(str(c) for c in command), flush=True)
    subprocess.run([sys.executable, "-m", *[str(c) for c in command]], check=True)


run("mlx_lm", "lora", "--model", args.base, "--train", "--data", DATA,
    "--iters", args.iters, "--batch-size", 1, "--num-layers", 8, "--learning-rate", "1e-4",
    "--max-seq-length", 1400, "--steps-per-report", 25, "--steps-per-eval", 200,
    "--val-batches", 10, "--adapter-path", ADAPTER, "--grad-checkpoint")
run("mlx_lm", "fuse", "--model", args.base, "--adapter-path", ADAPTER, "--save-path", OUTPUT)
print(f"\nModel written to {OUTPUT}")
