#!/bin/sh
# Benchmarks Yap on your own recordings and appends one row of totals to bench/RESULTS.md.
# DATA_DIR holds clips/*.wav, meta.json and the original engines' out_*/ folders. It must be outside
# the repo: recordings and transcripts never go in git. Run ./bundle.sh first.
set -e
umask 077
cd "$(dirname "$0")/.."
data=${1:-"$HOME/Library/Application Support/YapBench"}
case "$(cd "$data" && pwd -P)/" in "$(pwd -P)/"*) echo "DATA_DIR must be outside the repo" >&2; exit 1 ;; esac
run="$data/runs/$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
mkdir -p "$run" && chmod 700 "$data/runs" "$run"

echo "transcribing $(ls "$data"/clips/*.wav | wc -l | tr -d ' ') clips…"
Yap.app/Contents/MacOS/Yap --transcribe "$run" "$data"/clips/*.wav >/dev/null
scores=$(uv run -q --with jiwer --with whisper-normalizer bench/score.py "$data" "$run")
# Speed: ms from start until the recogniser is ready, and ms of work per second of audio.
speed=$(jq -s '{ready_p50: (map(.ready_ms) | sort | .[length/2|floor]),
                ms_per_audio_s: ((map(.total_ms) | add) / (map(.audio_s) | add) | floor),
                audio_s: (map(.audio_s) | add | floor)}' "$run/timing.jsonl")
# Live latency from real dictations: release to pasted text.
live=$(jq -s '[.[] | select(.outcome == "pasted" and .finish_ms != null) | .finish_ms] | sort
              | {n: length, p50: (if length > 0 then .[length/2|floor] else null end),
                 p90: (if length > 0 then .[(length*9/10)|floor] else null end)}' \
       "$HOME/Library/Logs/Yap/dictations.jsonl" 2>/dev/null || echo '{"n":0}')
res=$(bench/resources.sh)

[ -f bench/RESULTS.md ] || printf '%s\n%s\n' \
  "| date | commit | macOS | Reference disagreement raw | cleaned | setup p50 | ms per audio s | live finish p50/p90 (n) | Yap idle footprint / CPU | Wispr footprint |" \
  "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |" > bench/RESULTS.md
echo "| $(date +%Y-%m-%d) | $(git rev-parse --short HEAD) | $(sw_vers -productVersion) \
| $(echo "$scores" | jq -r .wer_raw)% | $(echo "$scores" | jq -r .wer_clean)% \
| $(echo "$speed" | jq -r .ready_p50) ms | $(echo "$speed" | jq -r .ms_per_audio_s) \
| $(echo "$live" | jq -r '"\(.p50 // "–") / \(.p90 // "–") ms (\(.n))"') \
| $(echo "$res" | jq -r '"\(.yap_mb // "–") MB / \(.yap_cpu // "–")%"') | $(echo "$res" | jq -r '"\(.wispr_mb // "not running") MB"') |" >> bench/RESULTS.md
tail -1 bench/RESULTS.md
