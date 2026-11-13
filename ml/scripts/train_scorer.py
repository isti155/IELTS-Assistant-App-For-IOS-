"""Train the on-device IELTS Writing band scorer and export it to Core ML.

Input : "[CLS] Task N: <question> [SEP] <essay> [SEP]" (max 512 word pieces)
Output: five bands — overall, task, coherence, lexical, grammar.

Run:  ml/.venv/bin/python ml/scripts/train_scorer.py [--epochs 3] [--per-source 7000]
"""
import argparse
import json
import math
import random
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn
from transformers import AutoModel, AutoTokenizer

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "ml" / "data"
OUT = ROOT / "ml" / "models"
RESOURCES = ROOT / "IELTSKit" / "Sources" / "IELTSKit" / "Resources"
KEYS = ["overall", "tr", "cc", "lr", "gra"]
MAX_LEN = 512
MAX_PROMPT = 96

parser = argparse.ArgumentParser()
parser.add_argument("--model", default="distilbert-base-cased")
parser.add_argument("--epochs", type=int, default=3)
parser.add_argument("--batch", type=int, default=16)
parser.add_argument("--lr", type=float, default=3e-5)
parser.add_argument("--per-source", type=int, default=7000,
                    help="cap on essays taken from each machine-scored collection")
parser.add_argument("--limit", type=int, default=0, help="debug: use only this many training essays")
args = parser.parse_args()

random.seed(7)
torch.manual_seed(7)
device = "mps" if torch.backends.mps.is_available() else "cpu"
tokenizer = AutoTokenizer.from_pretrained(args.model)
CLS, SEP, PAD = tokenizer.cls_token_id, tokenizer.sep_token_id, tokenizer.pad_token_id


def load(name):
    with open(DATA / f"scoring_{name}.jsonl") as handle:
        return [json.loads(line) for line in handle]


def encode(task, prompt, essay):
    """Must stay identical to ScorerTokenizer.encode in the Swift app."""
    first = tokenizer(f"Task {task}: {prompt}", add_special_tokens=False)["input_ids"][:MAX_PROMPT]
    second = tokenizer(essay, add_special_tokens=False)["input_ids"][: MAX_LEN - 3 - len(first)]
    ids = [CLS] + first + [SEP] + second + [SEP]
    mask = [1] * len(ids) + [0] * (MAX_LEN - len(ids))
    return ids + [PAD] * (MAX_LEN - len(ids)), mask


def tensors(rows):
    ids, masks, targets, known, weights = [], [], [], [], []
    for row in rows:
        i, m = encode(row["task"], row["prompt"], row["essay"])
        ids.append(i)
        masks.append(m)
        targets.append([(row[k] or 0) / 9 for k in KEYS])
        known.append([row[k] is not None for k in KEYS])
        # Examiner-scored essays are few but trustworthy, so they count more.
        weights.append(4.0 if row["source"] == "scored_essays" else 1.0)
    return (torch.tensor(ids), torch.tensor(masks), torch.tensor(targets),
            torch.tensor(known, dtype=torch.float32), torch.tensor(weights))


class Scorer(nn.Module):
    def __init__(self, name):
        super().__init__()
        self.encoder = AutoModel.from_pretrained(name)
        self.head = nn.Linear(self.encoder.config.hidden_size, len(KEYS))

    def forward(self, input_ids, attention_mask):
        hidden = self.encoder(input_ids=input_ids, attention_mask=attention_mask).last_hidden_state
        mask = attention_mask.unsqueeze(-1).to(hidden.dtype)
        pooled = (hidden * mask).sum(1) / mask.sum(1).clamp(min=1)
        return self.head(pooled)  # bands / 9


def predict(model, ids, masks):
    model.eval()
    out = []
    with torch.no_grad():
        for start in range(0, len(ids), 32):
            batch = model(ids[start:start + 32].to(device), masks[start:start + 32].to(device))
            out.append(batch.float().cpu())
    return torch.cat(out).numpy() * 9


def half(x):
    return np.clip(np.round(x * 2) / 2, 1, 9)


def qwk(a, b):
    """Quadratic weighted kappa on half-band classes."""
    a = ((a - 1) * 2).astype(int)
    b = ((b - 1) * 2).astype(int)
    n = 17
    observed = np.zeros((n, n))
    for x, y in zip(a, b):
        observed[x, y] += 1
    weights = np.array([[(i - j) ** 2 for j in range(n)] for i in range(n)]) / (n - 1) ** 2
    expected = np.outer(observed.sum(1), observed.sum(0)) / observed.sum()
    return 1 - (weights * observed).sum() / (weights * expected).sum()


def report(model, rows, label):
    ids, masks, _, _, _ = tensors(rows)
    predicted = predict(model, ids, masks)
    result = {}
    for source in sorted({r["source"] for r in rows}):
        index = [i for i, r in enumerate(rows) if r["source"] == source]
        truth = np.array([rows[i]["overall"] for i in index])
        guess = half(predicted[index, 0])
        error = np.abs(guess - truth)
        result[source] = dict(
            essays=len(index), mae=round(float(error.mean()), 3),
            within_half_band=round(float((error <= 0.5).mean()), 3),
            within_one_band=round(float((error <= 1.0).mean()), 3),
            qwk=round(float(qwk(truth, guess)), 3),
            baseline_mae=round(float(np.abs(half(np.full_like(truth, np.median(truth))) - truth).mean()), 3),
        )
        print(f"  {label} {source}: {result[source]}")
    return result


train_rows = load("train")
capped, counts = [], {}
for row in train_rows:
    counts[row["source"]] = counts.get(row["source"], 0) + 1
    if row["source"] == "scored_essays" or counts[row["source"]] <= args.per_source:
        capped.append(row)
train_rows = capped[: args.limit] if args.limit else capped
val_rows, test_rows = load("val"), load("test")
print(f"device={device} train={len(train_rows)} val={len(val_rows)} test={len(test_rows)}")

start = time.time()
ids, masks, targets, known, weights = tensors(train_rows)
print(f"tokenised in {time.time() - start:.0f}s")

model = Scorer(args.model).to(device)
optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=0.01)
steps = math.ceil(len(train_rows) / args.batch) * args.epochs
scheduler = torch.optim.lr_scheduler.OneCycleLR(optimizer, max_lr=args.lr, total_steps=steps, pct_start=0.1)

best, best_state, step = 1e9, None, 0
for epoch in range(args.epochs):
    model.train()
    order = torch.randperm(len(train_rows))
    running = 0.0
    for start_index in range(0, len(order), args.batch):
        index = order[start_index:start_index + args.batch]
        output = model(ids[index].to(device), masks[index].to(device))
        squared = (output - targets[index].to(device)) ** 2 * known[index].to(device)
        loss = (squared.sum(1) / known[index].to(device).sum(1) * weights[index].to(device)).mean()
        optimizer.zero_grad()
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        scheduler.step()
        running += loss.item()
        step += 1
        if step % 100 == 0:
            print(f"epoch {epoch + 1} step {step}/{steps} loss {running / 100:.5f} ({time.time() - start:.0f}s)", flush=True)
            running = 0.0
    validation = report(model, val_rows, f"val epoch {epoch + 1}")
    score = sum(v["mae"] for v in validation.values()) / len(validation)
    if score < best:
        best = score
        best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}

model.load_state_dict(best_state)
metrics = dict(model=args.model, train_essays=len(train_rows), epochs=args.epochs, test=report(model, test_rows, "TEST"))

# ---------------------------------------------------------------- save, then export
OUT.mkdir(parents=True, exist_ok=True)
torch.save(best_state, OUT / "scorer.pt")
(OUT / "scorer_metrics.json").write_text(json.dumps(metrics, indent=1))
print(json.dumps(metrics, indent=1))

import subprocess
import sys

subprocess.run([sys.executable, str(Path(__file__).with_name("export_scorer.py")), "--model", args.model], check=True)
