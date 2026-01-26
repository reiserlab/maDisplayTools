# Pattern Editor Assessment

Assessment of pattern generation tools and feature comparison between the original G4_Pattern_Generator_gui.m and the new PatternGeneratorApp.m.

**Last Updated**: 2026-01-26

---

## Current Status

### PatternGeneratorApp.m (NEW - App Designer)

Modern App Designer GUI created for multi-generation pattern support.

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

**Missing Features (from G4 GUI):**
| Feature | Priority | Notes |
|---------|----------|-------|
| Duty cycle | High | Grating on/off ratio |
| Brightness levels | High | Low/high/background level controls |
| Pole coordinates | Medium | Azimuth/elevation for local patterns |
| Motion angle | Medium | Direction of motion |
| Arena pitch | Medium | Tilt angle |
| Pattern FOV | Medium | Full-field vs local (mask-centered) |
| Mask options | Medium | Solid angle, lat/long masks |
| Anti-aliasing | Low | Rendering smoothing options |
| Mercator view | Low | Alternative visualization mode |
| Starfield options | Low | Dot count, radius, size, occlusion, level |
| More Options dialog | Low | Advanced rendering settings |
| Configure Arena dialog | Low | Manual arena setup (replaced by YAML) |

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
| Mercator projection | ✅ | ❌ | Cylindrical unwrap |
| LED colormap | ❌ | ✅ | Phosphor green |
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

## Starfield Options (G4 GUI)

The G4 GUI has extensive starfield customization not yet in PatternGeneratorApp:

| Option | Description | Current Default |
|--------|-------------|-----------------|
| num_dots | Number of dots | 100 |
| dot_radius | Dot size in degrees | 5° |
| dot_size | 'static' or 'distance-relative' | 'static' |
| dot_occ | Occlusion: 'closest', 'sum', 'mean' | 'closest' |
| dot_level | 'fixed', 'random spread', 'random binary' | 'fixed' |
| dot_re_random | Re-randomize each frame | 1 |

---

## Mask Options (G4 GUI)

The G4 GUI supports masking patterns to specific regions:

| Mask Type | Description | Status |
|-----------|-------------|--------|
| Solid angle | Circular mask by solid angle | Not implemented |
| Lat/long | Rectangular mask by lat/long bounds | Not implemented |
| Full-field | No mask (entire arena) | Default |

---

## Rendering Options (G4 GUI - More Options Dialog)

Advanced rendering settings in `more_options.m`:

| Option | Description | Status |
|--------|-------------|--------|
| Anti-aliasing samples | Supersampling for smooth edges | Not implemented |
| Pixel vs pattern mode | How to render at boundaries | Not implemented |

---

## Next Steps

### Priority 1: Core Parameters
1. Add duty cycle spinner (grating patterns)
2. Add brightness level controls (low, high, background)
3. Add pattern FOV selector (full-field vs local)

### Priority 2: Advanced Controls
4. Add pole coordinates (azimuth, elevation)
5. Add motion angle control
6. Add arena pitch control
7. Add mask options (solid angle, lat/long)

### Priority 3: Starfield Options
8. Add starfield options panel (shown when starfield selected)
   - Dot count, radius, size mode, occlusion, level mode

### Priority 4: Export & Visualization
9. Add .pat binary export (generation-aware)
10. Add GIF export for pattern animation
11. Add Mercator projection view option
12. Add stim icon export (or defer to web tools)

### Priority 5: Advanced Rendering
13. Add anti-aliasing options
14. Add pixel vs pattern rendering mode

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
