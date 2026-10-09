# Local benchmarks

Build with `./bundle.sh`, then run `bench/run.sh DATA_DIR`. The private data directory
must be outside the repository and contain `clips/*.wav`, `meta.json`, and baseline
`out_apple`, `out_pk3`, and `out_wt` transcripts. The script defaults to the existing
YapBench directory in the current user's Application Support folder.

Only aggregate results belong in git. Audio, references and generated transcripts stay
in the private data directory. Benchmark copies are separate from Yap's recording
retention: delete them when finished; this harness does not automatically reap them.

Scores are consensus disagreement, not measured accuracy. See RESULTS.md for limits.
Missing files fail scoring instead of silently counting as empty transcripts.
`Yap --transcribe OUTPUT_DIR AUDIO_FILE…` exits nonzero if any clip fails.
