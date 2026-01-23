# G6 Tools Migration Plan

**Status:** Step 1 Complete ✓  
**Goal:** Get G6 tools into maDisplayTools with minimal changes

---

## Three-Step Plan

### Step 1: Minimal Migration ✓ DONE
- [x] Two files: `g6_save_pattern.m` + `g6_encode_panel.m`
- [x] Create `g6/` directory
- [x] Write `g6_quickstart.md`

### Step 2: Stabilize & Validate (After Will's Response)
- [ ] Resolve LED mapping convention with Will
- [ ] Generate test patterns (known inputs → expected outputs)
- [ ] Create validation data files (JSON or .mat) for cross-platform testing
- [ ] Update web tools (webDisplayTools) to use shared test vectors
- [ ] Implement CI/CD workflow for automated testing
- [ ] Sync LED_MAP between MATLAB and web tools

### Step 3: Full Integration (Future)
- [ ] Add `Generation` parameter to `maDisplayTools.m`
- [ ] Create `Arena` class with panel size handling
- [ ] Consolidate G4/G6 encoding into unified interface

---

## Current File Structure

```
maDisplayTools/
├── maDisplayTools.m          # Unchanged
├── g6/
│   ├── g6_save_pattern.m     # User-facing: create & save patterns
│   └── g6_encode_panel.m     # Internal: encode single panel (GS2/GS16)
└── docs/
    ├── g6_quickstart.md
    └── g6_migration_plan.md
```

---

## Step 2 Details: Testing & Validation

### Test Patterns to Generate
1. Single pixel at (0,0) — verifies LED_MAP corner case
2. Single pixel at (19,19) — opposite corner
3. Diagonal line — tests coordinate mapping
4. All pixels on — verifies full block encoding
5. Checkerboard — tests alternating bit patterns
6. Gradient (GS16) — tests nibble packing

### Validation Data Format
```
test_vectors/
├── g6_test_vectors.json      # Shared between MATLAB & web
└── g6_test_vectors.mat       # MATLAB-native copy
```

Each test case:
```json
{
  "name": "single_pixel_0_0",
  "mode": "GS2",
  "input": [[1,0,0,...], [0,0,0,...], ...],
  "expected_bytes": [1, 16, 0, 0, 0, 0, 64, ...]
}
```

### CI/CD Workflow
- GitHub Actions for MATLAB tests (on push/PR)
- Web tools validation via Node.js or browser tests
- Cross-check: MATLAB output == web editor output

---

## TODO: Arena Config Evolution

The `arena_config` struct will grow to include:

```matlab
arena_config.row_count      % ✓ exists
arena_config.col_count      % ✓ exists
arena_config.total_rows     % ✓ exists (pixels)
arena_config.total_cols     % ✓ exists (pixels)
arena_config.panel_mask     % ✓ exists
arena_config.generation     % TODO: 'G6'
arena_config.panel_size     % TODO: 20
arena_config.gs_mode        % TODO: 'GS2' or 'GS16'
```

---

## Blocking Issue

**LED mapping:** Waiting on Will's response. Our tools are correct for G6 hardware — Will's firmware needs to add LED_MAP lookup.
