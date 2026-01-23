# G6 Tools Migration Plan

**Status:** Step 1 Complete ✓  
**Goal:** Get G6 tools into maDisplayTools with minimal changes

---

## Three-Step Plan

### Step 1: Minimal Migration ✓ DONE
- [x] Two files: `g6_save_pattern.m` + `g6_encode_panel.m`
- [x] Create `g6/` directory
- [x] Write `g6_quickstart.md`
- [x] Simplified encoding: row-major order, (0,0) at bottom-left (no LED_MAP)

### Step 2: Stabilize & Validate
- [ ] Generate test patterns (known inputs → expected outputs)
- [ ] Create validation data files (JSON or .mat) for cross-platform testing
- [ ] Update web tools (webDisplayTools) to use same encoding convention
- [ ] Implement CI/CD workflow for automated testing

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

## Encoding Convention (Agreed with Will)

```
Panel pixel layout (as viewed from front):

     col 0  col 1  ...  col 19
row 0 (top)    [19,0] [19,1] ... [19,19]  ← MATLAB row 1
row 1          [18,0] [18,1] ... [18,19]  ← MATLAB row 2
...
row 19 (bot)   [0,0]  [0,1]  ... [0,19]   ← MATLAB row 20

Origin (0,0) is at BOTTOM-LEFT
Row-major ordering: pixel_num = row_from_bottom * 20 + col
```

**MATLAB implementation:**
```matlab
row_from_bottom = 19 - row;  % flip since MATLAB row 1 = top
pixel_num = row_from_bottom * 20 + col;
byte_idx = floor(pixel_num / 8) + 1;
bit_pos = 7 - mod(pixel_num, 8);
```

---

## Step 2 Details: Testing & Validation

### Test Patterns to Generate
1. Single pixel at (0,0) bottom-left — pixel_num = 0, byte 0, bit 7
2. Single pixel at (19,0) top-left — pixel_num = 380, byte 47, bit 3
3. Single pixel at (0,19) bottom-right — pixel_num = 19, byte 2, bit 4
4. Bottom row lit — pixels 0-19
5. Left column lit — pixels 0, 20, 40, ..., 380
6. Checkerboard — tests alternating bit patterns
7. Gradient (GS16) — tests nibble packing

### Validation Data Format
```
test_vectors/
├── g6_test_vectors.json      # Shared between MATLAB & web
└── g6_test_vectors.mat       # MATLAB-native copy
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
