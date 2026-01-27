# Pattern Editor Assessment

Assessment of pattern generation tools and feature comparison between the original G4_Pattern_Generator_gui.m and the new PatternGeneratorApp.m.

**Last Updated**: 2026-01-27

---

## Current Status

### PatternGeneratorApp.m (NEW - App Designer)

Modern App Designer GUI created for multi-generation pattern support. **Feature parity with G4 GUI achieved!**

**Implemented Features:**
| Feature | Status | Notes |
|---------|--------|-------|
| Arena config dropdown | ✅ Done | Loads YAML configs from `configs/arenas/` |
| Generation detection | ✅ Done | Auto-detected from arena config |
| Pattern types | ✅ Done | Square grating, sine grating, edge, starfield, off-on |
| Motion types | ✅ Done | Rotation, translation, expansion-contraction |
| Grayscale modes | ✅ Done | Binary (1-bit), Grayscale (4-bit) |
| Spatial frequency | ✅ Done | Degrees input |
| Step size | ✅ Done | Degrees input with pixel equivalent display |
| LED preview | ✅ Done | Green phosphor colormap (568nm) |
| Frame playback | ✅ Done | Play/Stop with 1/5/10/20 FPS |
| Frame slider | ✅ Done | Discrete ticks per frame |
| Arena info display | ✅ Done | Panels, pixels, deg/px horizontal |
| Save pattern (.mat) | ✅ Done | Standard MATLAB format |
| Export script | ✅ Done | Generates standalone MATLAB script |
| Duty cycle | ✅ Done | 1-99% spinner |
| Brightness levels | ✅ Done | High/Low/Background spinners (auto-adjust for 1-bit/4-bit) |
| Pattern FOV | ✅ Done | Full-field / Local (mask-centered) dropdown |
| Motion angle | ✅ Done | 0-360° spinner (only in Local mode) |
| Pole coordinates | ✅ Done | Longitude (-180 to 180°) and Latitude (-90 to 90°) spinners (only in Full-field mode) |
| Arena pitch | ✅ Done | -90 to 90° spinner |
| Solid angle mask | ✅ Done | Checkbox + Configure dialog (azimuth, elevation, radius, invert) |
| Lat/long mask | ✅ Done | Checkbox + Configure dialog (lon min/max, lat min/max, invert) |
| Starfield options | ✅ Done | Conditional panel with dot count, radius, size, occlusion, level, re-randomize |

| Mercator view | ✅ Done | View dropdown: Grid (Pixels) / Mercator projection |
| Mollweide view | ✅ Done | Equal-area projection with elliptical display |
| Adjustable dot size | ✅ Done | 25-400% slider for projection views |
| Context-aware params | ✅ Done | Unused parameters disabled per pattern type |
| FOV zoom controls | ✅ Done | Lon+/Lat+ zoom buttons + Reset for projection views |
| Info dialog | ✅ Done | Reference button with coordinate diagrams and parameter explanations |
| 1:1 aspect ratio | ✅ Done | Grid (pixels) and projection (degrees) views use equal aspect |

**Remaining Features (lower priority):**
| Feature | Priority | Notes |
|---------|----------|-------|
| .pat binary export | Medium | Generation-aware binary format |
| Phase shift | Low | Starting phase offset (default 0) |
| Anti-aliasing control | Low | Fixed at 15 samples (hardcoded) |
| AA poles checkbox | Low | Anti-alias at rotation poles (default on) |
| Checkerboard layout | Low | Hardware-specific panel arrangement |
| GIF export | Low | Consider deferring to web tools |

---

## Feature Comparison

### Pattern Types

| Pattern | G4 GUI | PatternGeneratorApp | Notes |
|---------|--------|---------------------|-------|
| Square grating | ✅ | ✅ | Rectangular wave |
| Sine grating | ✅ | ✅ | Sinusoidal intensity |
| Edge | ✅ | ✅ | Single edge stimulus |
| Starfield | ✅ | ✅ (basic) | Missing advanced options |
| Off-On | ✅ | ✅ | Simple toggle |

### Motion Types

| Motion | G4 GUI | PatternGeneratorApp | Notes |
|--------|--------|---------------------|-------|
| Rotation | ✅ | ✅ | Azimuthal rotation |
| Translation | ✅ | ✅ | Linear translation |
| Expansion-contraction | ✅ | ✅ | Radial expansion |

### Grayscale Modes

| Mode | G4 GUI | PatternGeneratorApp | Notes |
|------|--------|---------------------|-------|
| 1-bit (binary) | ✅ | ✅ | On/off only |
| 4-bit (grayscale) | ✅ | ✅ | 16 levels (0-15) |

### Arena Configuration

| Feature | G4 GUI | PatternGeneratorApp | Notes |
|---------|--------|---------------------|-------|
| Generation selector | ❌ | ✅ | Auto from config |
| YAML config loading | ❌ | ✅ | `configs/arenas/` |
| Multi-generation | ❌ | ✅ | G3, G4, G4.1, G6 |
| Manual arena config | ✅ | ❌ | Replaced by YAML |
| Pixel size auto-detect | ❌ | ✅ | Via `get_generation_specs()` |

### Preview & Visualization

| Feature | G4 GUI | PatternGeneratorApp | Notes |
|---------|--------|---------------------|-------|
| Grid projection | ✅ | ✅ | Direct pixel view |
| Mercator projection | ✅ | ✅ | Cylindrical unwrap |
| Mollweide projection | ❌ | ✅ | Equal-area elliptical |
| LED colormap | ❌ | ✅ | Phosphor green |
| Adjustable dot size | ❌ | ✅ | 25-400% scaling slider |
| Frame navigation | ✅ | ✅ | Slider + buttons |
| Playback animation | ❌ | ✅ | Timer-based |
| FPS control | ❌ | ✅ | 1/5/10/20 fps |

### Export Options

| Feature | G4 GUI | PatternGeneratorApp | Notes |
|---------|--------|---------------------|-------|
| Save .mat | ✅ | ✅ | Pattern data |
| Save .pat | ✅ | ❌ | Binary format |
| Export script | ✅ | ✅ | Standalone MATLAB |
| GIF export | ❌ | ❌ | Planned |
| Stim icon export | ❌ | ❌ | Planned |

---

## Parameter Usage by Pattern Type

PatternGeneratorApp enables/disables parameters based on the selected pattern type. Disabled parameters are grayed out in the UI.

| Parameter | Square Grating | Sine Grating | Edge | Starfield | Off/On |
|-----------|:-------------:|:------------:|:----:|:---------:|:------:|
| Spatial Frequency | ✅ | ✅ | ✅ | ❌ | ❌ |
| Step Size | ✅ | ✅ | ✅ | ✅ | ❌ |
| Duty Cycle | ✅ | ❌ | ❌ | ❌ | ❌ |
| Motion Type | ✅ | ✅ | ✅ | ✅ | ❌ |
| Motion Angle | ✅ | ✅ | ✅ | ✅ | ❌ |
| Pole Coordinates | ✅ | ✅ | ✅ | ✅ | ❌ |
| Pattern FOV | ✅ | ✅ | ✅ | ✅ | ❌ |
| Arena Pitch | ✅ | ✅ | ✅ | ✅ | ❌ |
| Brightness High | ✅ | ✅ | ✅ | ✅ | ✅ |
| Brightness Low | ✅ | ✅ | ✅ | ✅ | ✅ |
| Brightness Background | ✅ | ✅ | ✅ | ✅ | ❌ |
| Masks (SA/LatLong) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Starfield options | ❌ | ❌ | ❌ | ✅ | ❌ |

---

## Starfield Options

PatternGeneratorApp now has full starfield support with a conditional options panel:

| Option | Description | Status |
|--------|-------------|--------|
| num_dots | Number of dots (1-1000) | ✅ Implemented |
| dot_radius | Dot size in degrees (0.1-45°) | ✅ Implemented |
| dot_size | 'Static' or 'Distance-relative' | ✅ Implemented |
| dot_occ | Occlusion: 'Closest', 'Sum', 'Mean' | ✅ Implemented |
| dot_level | 'Fixed', 'Random spread', 'Random binary' | ✅ Implemented |
| dot_re_random | Re-randomize each frame checkbox | ✅ Implemented |

---

## Mask Options

PatternGeneratorApp supports both mask types via Configure dialogs:

| Mask Type | Description | Status |
|-----------|-------------|--------|
| Solid angle | Circular mask by solid angle | ✅ Implemented (checkbox + dialog) |
| Lat/long | Rectangular mask by lat/long bounds | ✅ Implemented (checkbox + dialog) |
| Full-field | No mask (entire arena) | ✅ Default |

---

## Rendering Options

| Option | Description | Status |
|--------|-------------|--------|
| Anti-aliasing samples | Supersampling for smooth edges | Fixed at 15 (hardcoded) |
| Pixel vs pattern mode | How to render at boundaries | Not exposed in UI |

---

## Remaining Work

### Lower Priority Features
1. Add .pat binary export (generation-aware) — Medium priority
2. Add GIF export for pattern animation — Consider deferring to web tools
3. Expose anti-aliasing control — Low priority

---

## Coordinate System & Geometry

This section explains how the arena coordinate system works and how the pattern parameters relate to it.

### Arena Coordinate System

The LED arena is modeled as a cylindrical surface surrounding the fly:

```
                    +Z (up)
                     |
                     |
              ___----+----___
           /         |         \
         /           |           \
        |     FLY    |            |   ← Arena cylinder
        |     (•)----+-------→ +Y (straight ahead)
        |           /             |
         \         /             /
          \___---/----___-----/
                /
               +X (right)
```

**Coordinate Conventions:**
- **+Y axis**: Straight ahead (fly's forward direction)
- **+X axis**: Right side of the fly
- **+Z axis**: Above the fly (dorsal)
- **Origin**: Center of the arena (where the fly is positioned)
- **Radius**: Normalized to 1 for coordinate calculations

### Spherical Coordinates

The arena uses spherical coordinates for pattern calculations:

| Coordinate | Symbol | Range | Description |
|------------|--------|-------|-------------|
| **Azimuth (φ)** | phi | -180° to +180° | Horizontal angle from +Y axis (0° = front) |
| **Elevation (θ)** | theta | -90° to +90° | Vertical angle from horizon (0° = horizon) |
| **Colatitude** | theta_col | 0° to 180° | Angle from +Z pole (90° = horizon) |

Note: Internally, the code uses colatitude (0° = up, 90° = horizon, 180° = down) and converts to latitude for display.

### Pattern Parameters Explained

#### Pole Coordinates (Longitude, Latitude)

The **pole** defines the axis of symmetry for the pattern in **Full-field mode**. Think of it as placing a pole through the arena - the pattern is organized around this pole.

**Note**: Pole coordinates are only visible in **Full-field mode**. In **Local (mask-centered) mode**, the pole is automatically positioned at the mask center and **Motion Angle** is shown instead.

```
Full-field mode with pole at (0°, -90°) [default]:
         POLE below (latitude = -90°)
              ↓
       ╱──────┼─────────┼──────╲
      │       │         │       │
      │  ←────┼────→    │       │  ← Rotation motion circles the pole
      │       │         │       │
       ╲──────┼─────────┼──────╱
              ↑
         creates HORIZONTAL gratings

Full-field mode with pole at (90°, 0°) [horizon, right]:
              ┌─────────┐
             /│          │\
            / │          │ \
      POLE ●──┼──────────┼──○
            \ │          │ /
             \│          │/
              └─────────┘
              ← Vertical gratings →
```

- **Longitude** (-180° to 180°): Horizontal position of the pole
  - 0° = directly in front
  - 90° = to the right
  - 180° or -180° = behind
  - -90° = to the left

- **Latitude** (-90° to 90°): Vertical position of the pole
  - -90° = directly below (G4 GUI default → horizontal gratings)
  - 0° = on the horizon
  - 90° = directly above

**Default**: Pole at (0°, -90°) = below and in front → creates horizontal gratings that move vertically.

#### Motion Type

How the pattern moves from frame to frame:

| Motion | Description | Pole Effect |
|--------|-------------|-------------|
| **Rotation** | Pattern rotates around the pole axis | Full circles around pole |
| **Translation** | Pattern moves linearly in pole direction | Parallel bars move perpendicular to pole |
| **Expansion-Contraction** | Pattern expands/contracts from pole | Concentric circles from pole |

#### Motion Angle (0-360°) — Local Mode Only

**Note**: Motion Angle is only visible in **Local (mask-centered) mode**. In **Full-field mode**, pole coordinates are shown instead.

The direction of pattern motion relative to the mask center, measured clockwise from the default direction:

```
Rotation (local mode):
┌─────────────────────────┐
│                         │
│   ←───── (0° default)   │  Motion angle = 0° → leftward rotation
│                         │
│   ─────→ (180°)         │  Motion angle = 180° → rightward rotation
│                         │
└─────────────────────────┘

Translation (local mode):
Motion angle rotates the direction of translation.
0° = rightward motion (default)
90° = downward motion
180° = leftward motion
270° = upward motion
```

#### Arena Pitch (-90° to 90°)

Tilts the entire arena coordinate system forward/backward. This is separate from the pattern pole.

```
Arena pitch = 0° (normal):
              ────────
             /        \
            │   (•)    │  ← Fly at center
             \        /
              ────────

Arena pitch = 30° (tilted forward):
                 ─────
               /      \
            ──│   (•)  │  ← Front of arena is lower
             \        /
              ────────
```

Pitch is useful when the physical arena is mounted at an angle to match the fly's head orientation.

#### Pattern FOV (Field of View)

| Mode | Description |
|------|-------------|
| **Full-field** | Pattern covers entire arena, pole at specified coordinates |
| **Local (mask-centered)** | Pattern pole positioned at mask center for localized stimuli |

### Masking

Masks restrict the visible pattern to a region of the arena:

**Solid Angle Mask**: Circular region defined by:
- Center azimuth (0-360°)
- Center elevation (-90° to 90°)
- Radius (0-180°): angular radius of visible region
- Invert: show outside instead of inside

**Lat/Long Mask**: Rectangular region defined by:
- Longitude min/max (-180° to 180°)
- Latitude min/max (-90° to 90°)
- Invert: show outside instead of inside

### Visualization Projections

The GUI offers three ways to view patterns:

| Projection | Description | Best For |
|------------|-------------|----------|
| **Grid (Pixels)** | Direct pixel array view | Checking exact pixel values |
| **Mercator** | Cylindrical unwrap (lon/lat grid) | Seeing horizontal structure |
| **Mollweide** | Equal-area elliptical projection | Seeing relative sizes correctly |

```
Grid:                    Mercator:                 Mollweide:
┌────────────────┐      ┌────────────────┐        ╭──────────────╮
│░░░░░░░░░░░░░░░░│      │                │       ╱                ╲
│████████████████│      │████████████████│      │████████████████████│
│░░░░░░░░░░░░░░░░│      │                │       ╲                ╱
│████████████████│      │████████████████│        ╰──────────────╯
└────────────────┘      └────────────────┘
Columns × Rows          Longitude × Latitude      Equal-area distortion
```

---

## Missing/Low-Priority Parameters

These parameters exist in the G4 GUI but are not yet exposed in PatternGeneratorApp:

| Parameter | Description | Priority | Notes |
|-----------|-------------|----------|-------|
| `phase_shift` | Starting phase offset for gratings | Low | Usually 0 |
| `aa_poles` | Anti-alias at poles | Low | Default on |
| `back_frame` | Include background frame | Low | Default off |
| `flip_right` | Mirror pattern horizontally | Low | Rarely used |
| `snap_dots` | Snap starfield dots to pixels | Low | Default off |
| `checker_layout` | Checkerboard panel arrangement | Low | Hardware-specific |
| Preview color | RGB color for preview display | Low | Fixed to phosphor green |

These are available in the original G4 GUI via the "More Options" dialog but are rarely changed from defaults.

---

## Architecture Notes

### Single Source of Truth
- `get_generation_specs.m` — Panel specifications (pixels, dimensions)
- `configs/arenas/*.yaml` — Arena configurations
- `load_arena_config.m` — YAML loader with derived calculations

### Pattern Generation Pipeline
```
PatternGeneratorApp
    → buildHandlesStruct() — Build params for Pattern_Generator
    → arena_coordinates() — Generate pixel coordinates from YAML
    → Pattern_Generator() — Core pattern generation
    → updatePreview() — Display with LED colormap
```

### Key Files
| File | Purpose |
|------|---------|
| `PatternGeneratorApp.m` | New App Designer GUI |
| `Pattern_Generator.m` | Core pattern engine |
| `arena_coordinates.m` | 3D pixel coordinate calculation |
| `make_grating_edge.m` | Grating/edge pattern generation |
| `make_starfield.m` | Starfield pattern generation |
| `make_off_on.m` | Simple on/off pattern |
| `save_pattern.m` | Pattern file writer |
| `get_generation_specs.m` | Panel specs lookup |

---

## Legacy Files (Reference Only)

These files from G4_Display_Tools are kept for reference but PatternGeneratorApp is the primary tool:

| File | Status |
|------|--------|
| `G4_Pattern_Generator_gui.m` | Reference - original GUIDE GUI |
| `G4_Pattern_Generator_gui.fig` | Reference - GUIDE figure file |
| `configure_arena.m/.fig` | Reference - replaced by YAML configs |
| `mask_options.m/.fig` | Reference - to be integrated |
| `more_options.m/.fig` | Reference - to be integrated |
