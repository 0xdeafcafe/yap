# Word error rate for Yap's run against references frozen from the original benchmark.
# No human transcript exists, so each clip's reference is the medoid (the transcript closest to all
# the others) of four engines: Apple's first test, Parakeet v3, Whisper turbo and Wispr Flow.
# Prints aggregate numbers only, never what was said.
# usage: uv run --with jiwer --with whisper-normalizer bench/score.py DATA_DIR RUN_DIR
import json, os, sys
import jiwer
from whisper_normalizer.english import EnglishTextNormalizer

data, run = sys.argv[1], sys.argv[2]
norm = EnglishTextNormalizer()
meta = json.load(open(f"{data}/meta.json"))

def read(path):
    return norm(open(path).read())

def wer(ref, hyp):
    return jiwer.wer(ref, hyp) if ref.strip() else 0.0
assert wer("a b c", "a b c") == 0 and abs(wer("a b c d", "a x c d") - 0.25) < 1e-9

def medoid(cands):
    return min(cands, key=lambda c: sum(wer(o, c) for o in cands if o is not c))

pool = {e: {k: read(f"{data}/out_{e}/{k}.txt") for k in meta} for e in ("apple", "pk3", "wt")}
pool["wispr"] = {k: norm(v["wispr_asr"] or "") for k, v in meta.items()}
refs = [medoid([pool[e][k] for e in pool]) for k in meta]
assert medoid(["a b", "a b", "x y"]) == "a b"

out = {}
for name in ("raw", "clean"):
    hyps = [read(f"{run}/{name}/{k}.txt") for k in meta]
    out[f"wer_{name}"] = round(jiwer.wer(refs, hyps) * 100, 1)
    out[f"missing_{name}"] = sum(1 for h in hyps if not h)
print(json.dumps(out))
