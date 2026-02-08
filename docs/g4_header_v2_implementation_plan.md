# G4 Pattern Header V2 - Implementation Specification

## Overview

Extend the G4 pattern header to include panel generation and arena configuration metadata, using the previously unused NumPatsY bytes (2-3) in a backward-compatible way.

**Status:** Planning document for coding session  
**Date:** 2026-02-06  
**Context:** Peter confirmed firmware reads and ignores bytes 2-3, making this extension safe.

---

## Header Specification

### G4 Pattern Header - 7 bytes total

| Byte | V1 (legacy) | V2 |
|------|-------------|-----|
| 0-1 | NumPatsX (uint16 BE) | NumPatsX (unchanged) |
| 2 | NumPatsY high | Config high: `[V][GGG][RRRR]` |
| 3 | NumPatsY low | Config low: `[AAAAAAAA]` |
| 4 | GSLevels | GSLevels (unchanged) |
| 5 | RowN | RowN (unchanged) |
| 6 | ColN | ColN (unchanged) |

### Byte 2 Bit Layout

```
Bit 7:    V2 flag (1 = V2 header)
Bits 6-4: Generation (3 bits, 0-7)
Bits 3-0: Reserved (must be 0)
```

### Byte 3

```
Bits 7-0: Arena config ID (8 bits, 0-255)
```

### Version Detection

```
V1: Bytes 2-3 as uint16 < 0x8000 (typically 0x0001)
V2: Bytes 2-3 as uint16 >= 0x8000 (MSB set)
```

Simple check: `is_v2 = (byte2 >= 0x80)`

---

## Generation Values

| Value | Generation | Notes |
|-------|------------|-------|
| 0 | Unspecified | Legacy or unknown |
| 1 | Gen 3 | Original generation 3 panels |
| 2 | G4 | G4 panels (16×16 LEDs) |
| 3 | G4.1 | G4.1 with SD card support |
| 4 | G6 | G6 panels (20×20 LEDs) |
| 5-7 | Reserved | Future generations |

---

## Arena Config Ranges

| Range | Purpose | Registration |
|-------|---------|--------------|
| 0 | Unspecified/custom | N/A |
| 1-10 | Reiser lab official | Maintained by reiserlab |
| 11-200 | Community registered | Submit PR to registry |
| 201-254 | User-defined/experimental | No registration needed |
| 255 | Reserved | N/A |

---

## Backward Compatibility

Two options discussed:

1. **Update G4 controller** to reject values ≥ 0x8000 in bytes 2-3 (firmware change)
2. **Don't use V2 with original G4** - only enable for G4.1/G6 patterns

**Recommendation:** Option 2 for initial implementation - simpler, no firmware changes required for legacy G4 systems.

---

## Registry Folder Structure

```
G4_Pattern_Generator/
└── arena_registry/
    ├── README.md              # How to register new arenas
    ├── schema.yaml            # Validation schema
    ├── generations.yaml       # Generation definitions
    ├── index.yaml             # Master ID → name mapping
    └── arenas/
        ├── 001_cylinder_12x1.yaml
        ├── 002_cylinder_12x3.yaml
        ├── 003_cylinder_12x4.yaml
        ├── 004_treadmill_2x10.yaml
        └── ...
```

---

## Registry File Formats

### generations.yaml

```yaml
# Panel generation definitions
version: 1

generations:
  0:
    name: unspecified
    description: "Legacy or unknown generation"
  1:
    name: G3
    description: "Generation 3 panels"
    panel_size: 8
  2:
    name: G4
    description: "G4 panels (16x16 LEDs)"
    panel_size: 16
  3:
    name: G4.1
    description: "G4.1 panels with SD card support"
    panel_size: 16
  4:
    name: G6
    description: "G6 panels (20x20 LEDs)"
    panel_size: 20
```

### index.yaml

```yaml
# Master index of arena config IDs
# This file is the source of truth for ID assignments
version: 1

# Reiser lab official (1-10)
1: cylinder_12x1
2: cylinder_12x3
3: cylinder_12x4
4: treadmill_2x10
5: open_18x3

# Community registered (11-200)
# Add via pull request

# User-defined (201-254) - not registered
# 255: reserved
```

### arenas/001_cylinder_12x1.yaml

```yaml
id: 1
name: cylinder_12x1
description: "Standard 12-inch cylindrical arena, single row"
maintainer: reiserlab
created: 2026-02-06

geometry:
  rows: 1
  cols: 12
  panel_size: 16        # pixels per panel edge
  circumference: 12     # columns needed to fully enclose

supported_generations:
  - G4
  - G4.1

notes: |
  The standard cylindrical arena used in most fly vision experiments.
  Panels are arranged in a single horizontal ring.
```

### arenas/004_treadmill_2x10.yaml

```yaml
id: 4
name: treadmill_2x10
description: "Walking treadmill arena with 2 rows, 10 columns"
maintainer: reiserlab
created: 2026-02-06

geometry:
  rows: 2
  cols: 10
  panel_size: 16
  circumference: null   # not a closed cylinder

supported_generations:
  - G4.1

notes: |
  Used for tethered walking experiments on air-suspended ball.
```

### README.md (for registry)

```markdown
# G4 Arena Registry

This registry assigns unique IDs to arena configurations for use in
G4 pattern file headers (V2 format).

## ID Ranges

| Range | Purpose | Process |
|-------|---------|---------|
| 0 | Unspecified | N/A |
| 1-10 | Reiser lab official | Maintained by reiserlab |
| 11-200 | Community | Submit PR |
| 201-254 | User-defined | No registration needed |
| 255 | Reserved | N/A |

## Registering a New Arena

1. Fork this repository
2. Choose next available ID in range 11-200 (check index.yaml)
3. Create `arenas/NNN_your_arena_name.yaml` using existing files as template
4. Add entry to `index.yaml`
5. Submit pull request with:
   - Description of the arena
   - Photo or diagram (optional but helpful)
   - Your contact info as maintainer

## File Naming Convention

`NNN_arena_name.yaml` where:
- NNN = zero-padded 3-digit ID
- arena_name = lowercase with underscores, matching the `name` field
```

---

## MATLAB Implementation Notes

> **Note:** The code samples below are starting points. The actual G4_Display_Tools codebase has drifted, so these will need to be adapted to match current function signatures and conventions during the coding session.

### Core Functions Needed

1. **`write_pattern_header_v2.m`** - Generate 7-byte header with V2 fields
2. **`read_pattern_header.m`** - Parse header, detect V1 vs V2, extract fields
3. **`get_generation_name.m`** - Look up generation name from ID
4. **`get_arena_name.m`** - Look up arena name from registry index
5. **`load_arena_config.m`** - Load full arena YAML for detailed config

### Version Detection Logic (Pseudocode)

```matlab
% Read bytes 2-3
config_high = header(3);  % byte index 3 in MATLAB (1-indexed)
config_low = header(4);

% Check V2 flag (MSB of byte 2)
is_v2 = config_high >= 0x80;

if is_v2
    generation = bitand(bitshift(config_high, -4), 7);
    arena_config = config_low;
else
    % V1 legacy - no generation/arena info
    generation = 0;
    arena_config = 0;
end
```

### Integration Points

- Modify existing `save_pattern_G4.m` (or equivalent) to accept V2 options
- Modify existing pattern loading code to call `read_pattern_header`
- Pattern Generator GUI could add dropdown for arena selection (future)

---

## Testing Checklist

- [ ] Create registry folder structure with initial arenas
- [ ] Header write function produces correct byte sequence
- [ ] Header read function correctly detects V1 vs V2
- [ ] Header read function correctly parses generation and arena_config
- [ ] V2 pattern still loads on G4.1 controller (bytes 2-3 ignored by firmware)
- [ ] Round-trip test: write V2 → read V2 → values match
- [ ] Registry lookup functions return correct names
- [ ] Invalid/unknown IDs handled gracefully

---

## Future Enhancements

### Near-term (out of scope for initial implementation)

- GUI dropdown for arena selection in Pattern Generator
- Automatic arena validation (check rows/cols match registry)
- SD card manifest includes arena config
- YAML experiment files reference arena by name

### Observer Position Registry (Future Consideration)

> **Note:** This is a placeholder for future work. The concept needs further discussion.

The current pattern geometry code has ignored pitch and translation parameters that define the observer's position relative to the arena. A future extension could register "observer positions" similar to arena configs.

**Potential use cases:**
- Flying vs walking setups (different eye positions)
- Pitched arenas for specific visual field coverage
- Translated observer positions for asymmetric stimulation

**Open questions:**
- Should observer position be a separate registry, or embedded in arena config?
- What parameters define an observer position? (pitch angle, translation vector, eye height?)
- How does this interact with pattern generation math?
- Is this per-arena, per-experiment, or per-pattern?

This may warrant its own byte allocation in a future V3 header, or could use some of the reserved bits in V2. To be discussed when the pattern geometry code is revisited.

---

## References

- Slack conversation (2026-02-06): Peter confirmed bytes 2-3 are "read and ignored"
- Previous Claude conversation: G6 header specification discussion
- Google Doc: "Pattern Format Review and Update"
- GitHub: janelia-arduino/ArenaController
- GitHub: JaneliaSciComp/G4_Display_Tools

---

## Session Workflow

1. **Start:** Review current `save_pattern_G4.m` and related code to understand actual signatures
2. **Create:** Registry folder structure and initial YAML files
3. **Implement:** Header write/read functions adapted to current codebase
4. **Test:** Verify round-trip and backward compatibility
5. **Integrate:** Hook into existing pattern save/load workflow
