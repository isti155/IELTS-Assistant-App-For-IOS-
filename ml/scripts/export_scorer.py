"""Convert the trained scorer (ml/models/scorer.pt) to Core ML and copy it, its
vocabulary and reference cases into the app's resources.

Run:  ml/.venv/bin/python ml/scripts/export_scorer.py
"""
import argparse
import json
import shutil
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from torch import nn
from transformers import AutoModel, AutoTokenizer

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "ml" / "data"
OUT = ROOT / "ml" / "models"
RESOURCES = ROOT / "IELTSKit" / "Sources" / "IELTSKit" / "Resources"
MAX_LEN, MAX_PROMPT = 512, 96

parser = argparse.ArgumentParser()
parser.add_argument("--model", default="distilbert-base-cased")
args = parser.parse_args()

tokenizer = AutoTokenizer.from_pretrained(args.model)
CLS, SEP, PAD = tokenizer.cls_token_id, tokenizer.sep_token_id, tokenizer.pad_token_id


def encode(task, prompt, essay):
    """Must stay identical to train_scorer.encode and ScorerTokenizer.encode in the app."""
    first = tokenizer(f"Task {task}: {prompt}", add_special_tokens=False)["input_ids"][:MAX_PROMPT]
    second = tokenizer(essay, add_special_tokens=False)["input_ids"][: MAX_LEN - 3 - len(first)]
    ids = [CLS] + first + [SEP] + second + [SEP]
    mask = [1] * len(ids) + [0] * (MAX_LEN - len(ids))
    return ids + [PAD] * (MAX_LEN - len(ids)), mask


class Scorer(nn.Module):
    def __init__(self, name):
        super().__init__()
        self.encoder = AutoModel.from_pretrained(name, attn_implementation="eager")
        self.head = nn.Linear(self.encoder.config.hidden_size, 5)

    def forward(self, input_ids, attention_mask):
        hidden = self.encoder(input_ids=input_ids, attention_mask=attention_mask).last_hidden_state
        mask = attention_mask.unsqueeze(-1).to(hidden.dtype)
        pooled = (hidden * mask).sum(1) / mask.sum(1).clamp(min=1)
        return self.head(pooled) * 9  # bands


class Plain(nn.Module):
    """The same DistilBERT computation written with basic operations only.
    The library's forward pass uses operations coremltools cannot convert."""

    def __init__(self, scorer):
        super().__init__()
        self.scorer = scorer
        self.register_buffer("positions", torch.arange(MAX_LEN).unsqueeze(0))
        config = scorer.encoder.config
        self.heads = int(config.n_heads)
        self.width = int(config.dim) // int(config.n_heads)

    def forward(self, input_ids, attention_mask):
        encoder = self.scorer.encoder
        embeddings = encoder.embeddings
        x = embeddings.LayerNorm(embeddings.word_embeddings(input_ids) + embeddings.position_embeddings(self.positions))
        mask = attention_mask.to(x.dtype)
        bias = (1.0 - mask[:, None, None, :]) * -1e4
        for layer in encoder.transformer.layer:
            attention = layer.attention
            heads, width = self.heads, self.width  # plain ints, so tracing records constants

            def split(t):
                return t.view(1, MAX_LEN, heads, width).transpose(1, 2)

            q, k, v = split(attention.q_lin(x)), split(attention.k_lin(x)), split(attention.v_lin(x))
            weights = torch.softmax(q @ k.transpose(-1, -2) / (width ** 0.5) + bias, dim=-1)
            context = (weights @ v).transpose(1, 2).reshape(1, MAX_LEN, heads * width)
            x = layer.sa_layer_norm(attention.out_lin(context) + x)
            x = layer.output_layer_norm(layer.ffn.lin2(torch.nn.functional.gelu(layer.ffn.lin1(x))) + x)
        m = mask.unsqueeze(-1)
        pooled = (x * m).sum(1) / m.sum(1).clamp(min=1)
        return self.scorer.head(pooled) * 9


original = Scorer(args.model)
original.load_state_dict(torch.load(OUT / "scorer.pt", map_location="cpu"))
original.eval()
model = Plain(original).eval()

with open(DATA / "scoring_test.jsonl") as handle:
    rows = [json.loads(line) for line in handle][:6]

example_ids, example_mask = encode(rows[0]["task"], rows[0]["prompt"], rows[0]["essay"])
example = (torch.tensor([example_ids]), torch.tensor([example_mask]))
with torch.no_grad():
    gap = (original(*example) - model(*example)).abs().max().item()
assert gap < 0.01, f"plain forward pass differs from the library's by {gap}"
print(f"plain forward pass matches the library's (max difference {gap:.5f} band)")
traced = torch.jit.trace(model, example, strict=False)
mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="input_ids", shape=(1, MAX_LEN), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_LEN), dtype=np.int32)],
    outputs=[ct.TensorType(name="bands")],
    minimum_deployment_target=ct.target.iOS17,
    compute_precision=ct.precision.FLOAT16,
)
package = OUT / "IELTSScorer.mlpackage"
if package.exists():
    shutil.rmtree(package)
mlmodel.save(str(package))

# Ship the compiled form so the app needs no build step for the model.
RESOURCES.mkdir(parents=True, exist_ok=True)
compiled = RESOURCES / "IELTSScorer.mlmodelc"
if compiled.exists():
    shutil.rmtree(compiled)
loaded = ct.models.MLModel(str(package))  # keep alive: its compiled copy is deleted with it
shutil.copytree(loaded.get_compiled_model_path(), compiled)
(RESOURCES / "scorer_vocab.txt").write_text("\n".join(tokenizer.convert_ids_to_tokens(range(tokenizer.vocab_size))) + "\n")

# Reference cases so the Swift tokenizer and Core ML output can be checked against PyTorch.
cases = []
for row in rows:
    ids, mask = encode(row["task"], row["prompt"], row["essay"])
    with torch.no_grad():
        torch_out = model(torch.tensor([ids]), torch.tensor([mask]))[0].tolist()
    coreml_out = mlmodel.predict({"input_ids": np.array([ids], dtype=np.int32),
                                  "attention_mask": np.array([mask], dtype=np.int32)})["bands"][0].tolist()
    cases.append(dict(task=row["task"], prompt=row["prompt"], essay=row["essay"], label=row["overall"],
                      ids=ids[: sum(mask)], torch=torch_out, coreml=coreml_out))
    print(f"label {row['overall']}  pytorch {torch_out[0]:.2f}  coreml {coreml_out[0]:.2f}")
(RESOURCES / "scorer_reference.json").write_text(json.dumps(cases, ensure_ascii=False))
drift = max(abs(a - b) for c in cases for a, b in zip(c["torch"], c["coreml"]))
print(f"exported to {compiled}. max PyTorch vs Core ML difference: {drift:.3f} band")
