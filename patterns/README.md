# Patterns Directory

Generated .pat files are stored here. Only curated reference patterns are tracked in git.

## Tracked directories

- **`reference/`** — Curated "out of box" patterns for lab testing
  - `G41_2x12_cw/` — 12 experiment patterns (gratings, counters, luminance)

- **`web_generated/`** — Web roundtrip test reference patterns (8 files + manifest)

## Gitignored

All other subdirectories (user-generated patterns) are gitignored. Regenerate with:
- `tests/create_g41_experiment_patterns.m` — G4.1 experiment set
- Pattern Generator GUI — interactive pattern creation
