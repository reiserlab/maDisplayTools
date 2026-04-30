---
title: Patterns Directory
parent: MATLAB Tools
grand_parent: Generation 6
nav_order: 70
---

# Patterns Directory

Generated `.pat` files live in the [`patterns/`](https://github.com/reiserlab/maDisplayTools/tree/main/patterns) directory of the maDisplayTools repository. Only curated reference patterns are tracked in git — everything else is generated on demand.

## Tracked directories

- **`reference/`** — Curated "out of box" patterns for lab testing.
  - `G41_2x12_cw/` — 12 experiment patterns (gratings, counters, luminance).
- **`web_generated/`** — Web roundtrip test reference patterns (8 files plus a manifest).

## Gitignored (regenerate as needed)

All other subdirectories hold user-generated patterns and are gitignored. Regenerate with:

- `tests/create_g41_experiment_patterns.m` — G4.1 experiment set.
- The Pattern Generator GUI — interactive pattern creation.
