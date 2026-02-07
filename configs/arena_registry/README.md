# Arena Registry

This registry assigns unique IDs to arena configurations for use in G4.1 V2 and G6 V1 pattern file headers.

## Overview

Arena IDs allow pattern files to embed metadata about which arena configuration they were designed for. This enables:
- Automatic validation when loading patterns
- Proper dimension checking for partial arenas
- Better documentation and organization

## Key Design: Per-Generation Namespaces

**IMPORTANT**: Arena IDs are **per-generation**, not global.

- G4 arena ID 1 is **independent** of G6 arena ID 1
- Each generation (G4, G4.1, G6) has its own ID namespace
- This allows 10+ IDs per generation without conflicts

## ID Range Allocation

### G4.1 Patterns (8-bit arena_id: 0-255)
| Range | Purpose | Process |
|-------|---------|---------|
| 0 | Unspecified/unknown | N/A |
| 1-10 | Reiser lab official | Maintained by reiserlab |
| 11-200 | Community registered | Submit PR to this repository |
| 201-254 | User-defined/experimental | No registration needed |
| 255 | Reserved | Future use |

### G6 Patterns (6-bit arena_id: 0-63)
| Range | Purpose | Process |
|-------|---------|---------|
| 0 | Unspecified/unknown | N/A |
| 1-10 | Reiser lab official | Maintained by reiserlab |
| 11-50 | Community registered | Submit PR to this repository |
| 51-62 | User-defined/experimental | No registration needed |
| 63 | Reserved | Future use |

## Registering a New Arena

### For Reiser Lab Official Arenas (IDs 1-10)

1. Choose next available ID for your generation in `index.yaml`
2. Create arena YAML file in `arenas/{GEN}/NNN_arena_name.yaml`
3. Add entry to `index.yaml` under the appropriate generation section
4. Update this README if needed

### For Community Registered Arenas (IDs 11-200 or 11-50)

1. Fork this repository
2. Check `index.yaml` for the next available community ID for your generation
3. Create `arenas/{GEN}/NNN_your_arena_name.yaml` using existing files as template
4. Add entry to `index.yaml` under the appropriate generation section
5. Submit pull request with:
   - Description of the arena configuration
   - Photo or diagram (optional but helpful)
   - Your contact info as maintainer

### For User-Defined Arenas (IDs 201-254 or 51-62)

No registration needed! Use these IDs for:
- Custom lab setups
- Experimental configurations
- Temporary arenas

## File Structure

```
arena_registry/
├── README.md              # This file
├── index.yaml            # Master ID → name mapping (per generation)
├── generations.yaml      # Generation definitions
└── arenas/
    ├── G4/
    │   ├── 001_G4_4x12.yaml
    │   └── 002_G4_3x12of18.yaml
    ├── G41/
    │   └── 001_G41_2x12_cw.yaml
    └── G6/
        ├── 001_G6_2x10.yaml
        ├── 002_G6_2x8of10.yaml
        └── 003_G6_3x12of18.yaml
```

## File Naming Convention

Arena files must follow this pattern:
```
NNN_arena_name.yaml
```

Where:
- `NNN` = zero-padded 3-digit ID (e.g., 001, 012, 254)
- `arena_name` = lowercase with underscores, matching the `name` field in the file

Examples:
- `001_G4_4x12.yaml` (ID 1, name: G4_4x12)
- `012_custom_arena.yaml` (ID 12, name: custom_arena)

## Relationship to configs/arenas/

The main arena config files live in `configs/arenas/*.yaml`. This registry simply assigns IDs to those configs.

**Naming must match exactly:**
- Registry name: `G6_2x10`
- Config file: `configs/arenas/G6_2x10.yaml`

## Usage in Code

### Get arena ID from name
```matlab
arena_id = get_arena_id('G6', 'G6_2x10');
% Returns: 1 (first G6 arena in registry)
```

### Get arena name from ID
```matlab
arena_name = get_arena_name('G6', 1);
% Returns: 'G6_2x10'
```

### Load full arena config
```matlab
arena_config = load_arena_config('G6_2x10');
% Loads from configs/arenas/G6_2x10.yaml
```

## Version History

- **v1.0** (2026-02-07): Initial registry
  - G4: 2 arenas (full 4×12, partial 3×12of18)
  - G4.1: 1 arena (treadmill 2×12)
  - G6: 3 arenas (full 2×10, partial 2×8of10, partial 3×12of18)

## Future Considerations

### Observer Position Registry

Future versions may add an observer position registry to record:
- Observer pitch angle
- Observer translation (x, y, z)
- Eye height

This would use the 6-bit observer_position_id field in the G6 header (currently set to 0 = unspecified).
