# Arena Configuration Audit

**Date:** 2026-01-25
**Purpose:** Document where arena_config/rig_config is NOT being used as the single source of truth

## Overview

The arena configuration system (`load_arena_config.m`, `load_rig_config.m`) was introduced to provide a centralized source of truth for panel specifications, arena geometry, and derived properties. This audit identifies areas where hardcoded values or duplicated specifications may cause inconsistencies.

## Configuration System Summary

### Proper Usage (Single Source of Truth)

| File | Function | Status |
|------|----------|--------|
| `utils/load_arena_config.m` | Loads arena YAML, computes derived properties | ✓ Primary source |
| `utils/load_rig_config.m` | Loads rig YAML, resolves arena reference | ✓ Uses load_arena_config |
| `experimentExecution/ProtocolParser.m` | Parses protocol YAML, loads rig config | ✓ Uses load_rig_config (V2) |

---

## Issues Found

### 1. Generation Specs Duplication (MEDIUM)

**Problem:** Panel specifications (pixels per panel, panel dimensions) are defined in THREE places:

| File | Lines | What's Duplicated |
|------|-------|-------------------|
| `utils/load_arena_config.m` | 136-180 | `gen_specs` struct with all generations |
| `utils/load_rig_config.m` | 154-193 | `compute_arena_derived()` duplicates specs |
| `utils/design_arena.m` | 314-385 | `get_panel_specs()` duplicates specs |

**Values duplicated:**
- G3: 8 pixels/panel, 32mm width
- G4: 16 pixels/panel, 40.45mm width
- G4.1: 16 pixels/panel, 40mm width
- G6: 20 pixels/panel, 45.4mm width

**Risk:** If panel specs change (e.g., new generation), all three files need updating.

**Recommendation:** Create a shared `get_generation_specs.m` function that all three files call.

---

### 2. Protocol V1 Missing Derived Properties (HIGH)

**Problem:** Protocol V1 format (inline `arena_info`) does not compute derived properties.

**Location:** `experimentExecution/ProtocolParser.m`, lines 636-640

```matlab
% Version 1: inline arena_info
protocol.arenaConfig = data.arena_info;
protocol.rigConfig = [];
protocol.derivedConfig = [];  % <-- EMPTY! No derived properties
```

**Impact:** V1 protocols lack:
- `pixels_per_panel`
- `total_pixels_x`, `total_pixels_y`
- `inner_radius_mm`
- `panel_width_mm`, `panel_depth_mm`

**Risk:** Code relying on `derivedConfig` will fail or behave incorrectly with V1 protocols.

**Recommendation:**
1. Add warning when parsing V1 protocols
2. Compute derived properties for V1 by calling generation specs lookup
3. Long-term: Deprecate V1 format entirely

---

### 3. G6 Module Hardcoded Dimensions (HIGH)

**Problem:** The G6 encoding tools hardcode 20x20 pixel dimensions.

**Locations:**

| File | Lines | Hardcoded Value |
|------|-------|-----------------|
| `g6/g6_encode_panel.m` | 31 | `assert(isequal(size(pixel_data), [20, 20])` |
| `g6/g6_encode_panel.m` | 60-61 | `for row = 0:19`, `for col = 0:19` |
| `g6/g6_encode_panel.m` | 65, 102 | `pixel_num = row_from_bottom * 20 + col` |
| `g6/g6_save_pattern.m` | 148-149 | `total_rows = row_count * 20` |
| `g6/g6_save_pattern.m` | 221, 223 | `row_start = panel_row * 20 + 1` |

**Risk:** Low for now (G6 is always 20x20), but violates single source of truth principle.

**Recommendation:**
- Add `pixels_per_panel` to arena_config parameter
- Use this value instead of hardcoded 20
- Note: A TODO comment at lines 151-154 of `g6_save_pattern.m` already acknowledges this

---

### 4. Legacy Pattern Tools Assume G4/G4.1 (HIGH)

**Problem:** `maDisplayTools.m` assumes 16 pixels per panel.

**Location:** `maDisplayTools.m`, lines 1088-1089

```matlab
dims.pixel_rows = RowN * 16;  % Hardcoded G4/G4.1 assumption
dims.pixel_cols = ColN * 16;
```

**Impact:** Pattern dimension validation will be incorrect for:
- G3 patterns (8 pixels per panel)
- G6 patterns (20 pixels per panel)

**Recommendation:**
- Accept `generation` parameter or arena_config
- Look up pixels_per_panel from generation specs
- Or derive from pattern file header if available

---

### 5. Experiment Template Shows V1 Pattern (LOW)

**Problem:** `examples/experimentTemplate.yaml` uses V1 format with inline `arena_info`.

**Current:**
```yaml
template_version: 1

arena_info:
  num_rows:
  num_cols:
  generation:
```

**Recommended:**
```yaml
version: 2

rig: "configs/rigs/your_rig.yaml"
```

**Recommendation:** Update template to show V2 format as the recommended approach, with V1 as legacy option.

---

## Summary Table

| Issue | Severity | Fix Complexity | Recommendation |
|-------|----------|----------------|----------------|
| Generation specs duplication | Medium | Low | Create shared function |
| V1 missing derived props | High | Medium | Compute for V1 or deprecate |
| G6 hardcoded 20x20 | High | Medium | Parameterize from config |
| Legacy tools assume G4 | High | Medium | Accept generation parameter |
| Template shows V1 | Low | Low | Update example template |

---

## Recommended Actions

### Immediate (Low Effort)
1. Update `experimentTemplate.yaml` to show V2 format
2. Add deprecation warning to V1 protocol parsing

### Short-term (Medium Effort)
3. Create `utils/get_generation_specs.m` as shared function
4. Update `load_arena_config.m`, `load_rig_config.m`, `design_arena.m` to use it
5. Compute derived properties for V1 protocols

### Long-term (Higher Effort)
6. Parameterize G6 tools to accept `pixels_per_panel`
7. Update `maDisplayTools.m` to accept generation parameter
8. Consider deprecating Protocol V1 entirely

---

## Files Requiring Updates

| File | Changes Needed |
|------|----------------|
| `utils/get_generation_specs.m` | NEW - shared generation specs |
| `utils/load_arena_config.m` | Use shared specs |
| `utils/load_rig_config.m` | Use shared specs |
| `utils/design_arena.m` | Use shared specs |
| `experimentExecution/ProtocolParser.m` | Add V1 warning, compute derived |
| `examples/experimentTemplate.yaml` | Update to V2 format |
| `g6/g6_encode_panel.m` | Parameterize pixel count |
| `g6/g6_save_pattern.m` | Parameterize pixel count |
| `maDisplayTools.m` | Accept generation parameter |

---

## Notes

- The `testing/` scripts intentionally hardcode values for testing specific scenarios - this is acceptable.
- Controller communication code (`g6/G6Controller.m`) is hardware-agnostic and doesn't need arena config.
- The column order convention (CW/CCW) is properly implemented in `design_arena.m` as of 2026-01-25.
