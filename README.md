# maDisplayTools

MATLAB tools for LED arena display systems (G3, G4, G4.1, G6) used in fly behavioral experiments.

## Overview

This repository provides tools for:
- **Pattern Generation** — Create visual stimuli for cylindrical LED arenas
- **Arena Configuration** — Define and manage arena geometries
- **SD Card Deployment** — Prepare patterns for hardware playback
- **TCP Communication** — Control arena displays via network

## Quick Start

```matlab
% Add maDisplayTools to path
run('maDisplayTools.m')

% Launch the Pattern Generator App
PatternGeneratorApp
```

## Pattern Generator

The **PatternGeneratorApp** (`patternGenerator/PatternGeneratorApp.m`) is a modern App Designer GUI for creating visual patterns across all supported display generations.

### Features

- **Multi-generation support** — G3 (8×8), G4/G4.1 (16×16), G6 (20×20) pixel panels
- **Pattern types** — Square grating, sine grating, edge, starfield, off-on
- **Motion types** — Rotation, translation, expansion-contraction
- **Grayscale modes** — Binary (1-bit) and grayscale (4-bit)
- **Arena config integration** — Load YAML configs from `configs/arenas/`
- **Real-time preview** — LED-accurate green phosphor colormap
- **Playback controls** — Animate patterns at 1/5/10/20 FPS
- **Arena info display** — Shows panels, pixels, and degrees per pixel

### Usage

1. Select an arena configuration from the dropdown
2. Choose pattern type, motion type, and parameters
3. Adjust spatial frequency, step size, and grayscale levels
4. Preview the pattern using the frame slider or Play button
5. Generate and save the pattern

## Directory Structure

```
maDisplayTools/
├── configs/
│   ├── arenas/           # Arena YAML configs (G6_2x10_full, G41_2x12_ccw, etc.)
│   └── rigs/             # Rig configs (reference arena YAML + hardware settings)
├── controller/           # PanelsController for TCP communication
├── docs/                 # Documentation and roadmap
├── examples/             # Test patterns and example scripts
├── g6/                   # G6-specific encoding tools
├── patternGenerator/     # Pattern generation tools and GUI
│   ├── PatternGeneratorApp.m    # Main App Designer GUI
│   ├── Pattern_Generator.m      # Core pattern generation engine
│   └── support/                 # Helper functions
├── utils/                # Utility functions
│   ├── design_arena.m           # Arena geometry visualization
│   ├── get_generation_specs.m   # Panel specs (single source of truth)
│   ├── load_arena_config.m      # Load arena YAML configs
│   ├── load_rig_config.m        # Load rig configs
│   └── prepare_sd_card.m        # SD card deployment
└── maDisplayTools.m      # Path setup script
```

## Arena Configurations

Standard arena configs are in `configs/arenas/`:

| Config | Generation | Panels | Description |
|--------|------------|--------|-------------|
| G6_2x10_full | G6 | 2×10 | Full cylinder, 20 panels |
| G6_2x8_walking | G6 | 2×8 | Walking arena, 16 panels |
| G41_2x12_ccw | G4.1 | 2×12 | Counter-clockwise columns |
| G41_2x12_cw | G4.1 | 2×12 | Clockwise columns |
| G4_3x12_full | G4 | 3×12 | 3-row full arena |
| G4_4x12_full | G4 | 4×12 | 4-row full arena |

## Related Repositories

- **[webDisplayTools](https://github.com/reiserlab/webDisplayTools)** — Web-based editors (arena editor, 3D viewer, panel editor)
- **[G4_Display_Tools](https://github.com/reiserlab/G4_Display_Tools)** — Legacy G4 tools (reference)

## Documentation

- [G4G6 Roadmap](docs/G4G6_ROADMAP.md) — Development roadmap and session notes
- [Experiment Pipeline Guide](docs/experiment_pipeline_guide.md) — YAML experiment workflow
- [SD Card Deployment](docs/sd_card_deployment_notes.md) — Pattern deployment guide

## Requirements

- MATLAB R2020b or later (App Designer support)
- [YAML library](https://github.com/serg3y/MatLab-YAML) (included in `external/`)

## Citations

Serge (2025). Read and Write YAML files (https://github.com/serg3y/MatLab-YAML/releases/tag/1.1.2), GitHub. Retrieved December 9, 2025.
