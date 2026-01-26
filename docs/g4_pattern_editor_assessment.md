# G4 Pattern Editor Assessment

Assessment of `G4_Pattern_Generator_gui.m` for multi-generation support update.

**Source**: `/Users/reiserm/Documents/GitHub/G4_Display_Tools/G4_Pattern_Generator/`

---

## Feature Inventory

### Pattern Types (popupmenu1)
| Pattern | Description | Generation-Specific? |
|---------|-------------|---------------------|
| Square grating | Rectangular wave pattern | No - universal |
| Sine grating | Sinusoidal intensity pattern | No - universal |
| Edge | Single edge stimulus | No - universal |
| Starfield | Random dot pattern (optic flow) | No - universal |
| Off-On | Simple on/off pattern | No - universal |

### Motion Types (popupmenu2)
| Motion | Description |
|--------|-------------|
| Rotation | Azimuthal rotation around arena |
| Translation | Linear translation |
| Expansion-contraction | Radial expansion/contraction |

### Grayscale Modes (popupmenu5)
| Mode | Description | Generation Support |
|------|-------------|-------------------|
| 1 bit | Binary (on/off) | All generations |
| 4 bits | 16 levels (0-15) | G4, G4.1, G6 |

### Pattern FOV (popupmenu7)
| Mode | Description |
|------|-------------|
| Full-field | Pattern covers entire arena |
| Local (mask-centered) | Pattern centered on specified mask |

### Visualization Modes (popupmenu6)
| Mode | Description |
|------|-------------|
| Mercator projection | Cylindrical projection view |
| Grid projection | Direct pixel grid view |

### Starfield Options
- Dot count (num_dots)
- Dot radius (degrees)
- Dot size: static or distance-relative
- Dot occlusion: closest, sum, or mean
- Dot level: fixed, random spread, or random binary

---

## Arena Configuration

### Current Implementation
The G4 Pattern Generator loads arena configuration from a MAT file:
- Default path: `C:\matlabroot\G4\Arena\arena_parameters.mat`
- Uses `arena_coordinates.m` to generate pixel coordinates

### Arena Parameters (aparam struct)
| Parameter | Description | Current Value |
|-----------|-------------|---------------|
| Psize | Pixels per panel edge | **16** (G4 hardcoded) |
| Pcols | Panel columns | Variable |
| Prows | Panel rows | Variable |
| Pcircle | Panels in full circle | Variable |
| rot180 | Arena upside-down flag | 0/1 |
| model | Cylinder model | 'poly' or 'smooth' |
| rotations | [yaw, pitch, roll] | radians |
| translations | [x, y, z] | arena units |

### Generation-Specific Changes Needed
| Generation | Psize | Notes |
|------------|-------|-------|
| G3 | 8 | 8x8 pixel panels |
| G4 | 16 | 16x16 pixel panels |
| G4.1 | 16 | 16x16 pixel panels |
| G6 | 20 | 20x20 pixel panels |

---

## Universal vs Generation-Specific Features

### Universal Features (No Changes Needed)
- Pattern type selection (gratings, edge, starfield, off-on)
- Motion type (rotation, translation, expansion-contraction)
- Grayscale mode selection
- Pattern preview (mercator and grid projections)
- Frame navigation
- Masking options (solid angle, lat/long)
- Anti-aliasing settings
- Pattern export to .mat and .pat files

### Generation-Specific Features (Changes Required)

1. **Panel pixel size**
   - Currently hardcoded to 16x16
   - Need to support: 8x8 (G3), 16x16 (G4/G4.1), 20x20 (G6)

2. **Arena coordinate calculation**
   - `arena_coordinates.m` needs Psize parameter from generation
   - Different generations have different panel widths (affects radius)

3. **Pattern file format**
   - G4: Uses `save_pattern_G4.m` with G4 binary format
   - G6: Uses `g6_save_pattern.m` with G6 binary format
   - Need to select correct save function based on generation

4. **Panel specifications** (from `design_arena.m`)
   - G3: 32mm panel
   - G4: 40.45mm panel
   - G4.1: 40mm panel
   - G6: 45.4mm panel

---

## UI Components

### Main Window Elements
| Component | Type | Purpose |
|-----------|------|---------|
| Pattern type | Popup menu | Select pattern algorithm |
| Motion type | Popup menu | Select motion type |
| Spatial freq | Edit field | Grating wavelength (degrees) |
| Step size | Edit field | Animation step (degrees) |
| Duty cycle | Edit field | Grating on/off ratio |
| GS value | Popup menu | Grayscale depth |
| Pattern FOV | Popup menu | Full-field vs local |
| Pole coordinates | Edit fields | Azimuth, elevation |
| Motion angle | Edit field | Direction of motion |
| Arena pitch | Edit field | Tilt angle |
| Mask params | Edit fields | Solid angle mask |
| Levels | Edit fields | Brightness levels (low, high, bg) |
| Frame preview | Axes | Pattern visualization |
| Frame navigation | Buttons | Prev/Next/Go to frame |
| Save directory | Text + button | Output path selection |
| Pattern name | Edit field | Output filename |

### Support Dialogs
| Dialog | File | Purpose |
|--------|------|---------|
| More Options | `more_options.m/.fig` | Advanced rendering settings |
| Mask Options | `mask_options.m/.fig` | Full-field mask configuration |
| Configure Arena | `configure_arena.m/.fig` | Arena setup |

---

## Update Strategy for Multi-Generation Support

### Phase 1: Add Generation Selector
1. Add popup menu for generation selection (G3, G4, G4.1, G6)
2. Store generation in handles struct
3. Update arena configuration path/handling

### Phase 2: Integrate Arena Config System
1. Replace hardcoded arena path with config file lookup
2. Use `load_arena_config.m` from maDisplayTools
3. Read Psize from config instead of hardcoding

### Phase 3: Update Pattern Save Functions
1. Add generation-aware save logic
2. Call appropriate save function based on generation:
   - G3/G4/G4.1: `save_pattern_G4.m` (with appropriate Psize)
   - G6: `g6_save_pattern.m`

### Phase 4: Update Arena Coordinate Generation
1. Modify `arena_coordinates.m` to use config-based Psize
2. Or create wrapper that reads from YAML config

### Phase 5: Testing & Validation
1. Generate test patterns for each generation
2. Validate against known-good patterns
3. Test load/save round-trip

---

## Files to Modify

| File | Changes |
|------|---------|
| `G4_Pattern_Generator_gui.m` | Add generation popup, update arena loading |
| `G4_Pattern_Generator_gui.fig` | Add generation selector UI element |
| `arena_coordinates.m` | Accept Psize from config or add generation param |
| `save_pattern_G4.m` | May need updates for different Psize values |
| `configure_arena.m/.fig` | Add generation selector |

---

## Dependencies

### From G4_Display_Tools
- `G4_Pattern_Generator.m` (core pattern generation)
- `arena_coordinates.m` (arena pixel coordinates)
- `save_pattern_G4.m` (G4 pattern file writer)
- Support functions: `make_grating_edge.m`, `make_starfield.m`, `make_off_on.m`
- Mask functions: `sa_mask.m`, `long_lat_mask.m`

### From maDisplayTools
- `load_arena_config.m` (YAML config loader)
- `g6_save_pattern.m` (G6 pattern writer)
- Arena configs in `configs/arenas/`

---

## Recommendations

1. **Keep GUIDE GUI for now** - App Designer migration is lower priority
2. **Use maDisplayTools configs** - Integrate with existing YAML system
3. **Test incrementally** - Add G6 support first, then G3
4. **Maintain backward compatibility** - Existing G4 patterns should still work
5. **Document changes** - Update user guide with multi-generation workflow

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Add generation selector | Low |
| Integrate arena config | Medium |
| Update save functions | Medium |
| Update arena coordinates | Low |
| Testing & validation | Medium |
| **Total** | Medium (1-2 days) |
