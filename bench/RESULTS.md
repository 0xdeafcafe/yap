| date | commit | macOS | Reference disagreement raw | cleaned | setup p50 | ms per audio s | live finish p50/p90 (n) | Yap idle footprint / CPU | Wispr footprint |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-10-09 | 2219b93 | 27.0 | 7.6% | 9.1% | 3 ms | 30 | 309 / 309 ms (1) | 31 MB / 0.2% | not running |

These are saved results from the initial run, before benchmark error handling was hardened.
All scores compare against a multi-engine consensus, not human-labelled ground truth.
The reference pool includes an earlier Apple run, which may favour Apple. Cleanup can
remove filler words, increasing disagreement without reducing usefulness.

The 3 ms value measures recogniser/context setup, not microphone readiness or first-word latency.
File transcription shares the live recogniser configuration but does not exercise microphone
capture, release padding, paste, or spoken Markdown (cleanup is measured with formatting off).
The single live sample cannot establish typical latency. RAM/CPU cover the Yap process only;
Apple's separate speech services and active-dictation resource use were not measured.
