# Remote Work Plan (Jan 17-20)

No hardware needed — can do from anywhere.

## 1. ✅ Set up web tools directory structure (COMPLETED)

**Status**: Web tools moved to separate public repository at `webDisplayTools`

**What was done**:
- Created flat directory structure with single HTML files
- Built modern dark theme landing page (`index.html`)
- Integrated existing G6 Panel Pattern Editor (20×20 pixels)
- Added placeholder pages for future tools
- Rebranded as "PanelDisplayTools"
- All tools use consistent dark theme with green accents
- Added Reiser Lab branding and GitHub links
- Repository: https://github.com/reiserlab/webDisplayTools

**Tools included**:
- ✅ G6 Panel Pattern Editor (functional)
- ✅ Arena Layout Editor (functional - see section 3)
- 🚧 G4.1 Pattern Editor (placeholder)
- 🚧 G6 Pattern Editor (placeholder)
- 🚧 Experiment Designer (placeholder)

**Next step**: Deploy to GitHub Pages once repository is pushed

---

## 2. Move G6 pattern tools (MATLAB)

- [ ] Locate existing G6 MATLAB pattern code
- [ ] Move/copy into `maDisplayTools` repo under `G6/` subfolder
- [ ] Add `G6_` prefix to MATLAB functions or organize in subdirectory
- [ ] Document what exists vs what's missing
- [ ] Ensure MATLAB tools match web tool outputs
- [ ] **NEW**: Implement CI/CD validation for G6 pattern editor (see section 7)

---

## 3. ✅ Arena layout parameterization (COMPLETED)

**Status**: MATLAB `design_arena.m` function created and validated

**What was done**:
- Consolidated multiple legacy arena layout scripts into single `design_arena.m` function
- Supports all panel generations: G3, G4, G4.1, G5, G6
- Features:
  - Configurable number of panels (4-36)
  - Partial arena support (panels_installed parameter)
  - Angle offset for rotation
  - Units toggle (inches/mm)
  - Auto-scaling figure
  - PDF export
  - Returns computed geometry (radii, resolution, coverage)
- Panel specifications from hardware documentation:
  - G3: 32mm width, 8 pixels/panel
  - G4: 40.45mm width, 16 pixels/panel
  - G4.1: 40mm width, 16 pixels/panel, 6.35mm depth
  - G5: 40mm width, 20 pixels/panel
  - G6: 45.4mm width, 20 pixels/panel, dual 5-pin headers

**Files created**:
- `utils/design_arena.m` - Main function
- `utils/test_design_arena.m` - Test script generating sample arenas
- `utils/generate_web_reference_data.m` - Generates JSON for web validation
- `docs/arena-designs/reference_data.json` - Reference geometry data

**Key formula**: `c_radius = panel_width / (tan(alpha/2)) / 2` where `alpha = 2π/num_panels`

---

## 4. ✅ Web arena editor (COMPLETED)

**Status**: Full-featured Arena Layout Editor implemented in webDisplayTools

**What was done**:
- Built `arena_editor.html` with SVG-based visualization
- Matches MATLAB `design_arena.m` calculations exactly
- Features:
  - Panel generation tabs (G3, G4, G4.1, G5, G6, Custom)
  - Configurable number of panels with +/- controls
  - Angle offset control
  - Click-to-toggle panels for partial arena designs
  - Units toggle (inches/mm)
  - Labeled dimension line showing inner radius
  - Dimmed inactive panels for visual contrast
  - Resolution box showing degrees/pixel
  - Export PDF (via print dialog)
  - Export Data (JSON with full geometry and pin coordinates)
  - Custom panel configuration modal
- Default: G6 with 10 panels
- Version: v1.0.0 (2026-01-16)

**CI/CD Validation**:
- Created `js/arena-calculations.js` - Standalone calculation module
- Created `tests/validate-arena-calculations.js` - Node.js test runner
- Created `.github/workflows/validate-calculations.yml` - GitHub Actions workflow
- Copied `data/reference_data.json` from MATLAB output
- All 11 test configurations pass validation

**Validation workflow**:
1. MATLAB `generate_web_reference_data.m` creates reference JSON
2. Copy to `webDisplayTools/data/reference_data.json`
3. Run `npm test` or push to GitHub to validate JS matches MATLAB

---

## 5. Pattern editors (G4.1 and G6 multi-panel)

After arena editor, build pattern editors:

### G4.1 Pattern Editor
- [ ] Research G4.1 display specifications
- [ ] Build pattern creation interface
- [ ] Add frame sequencing support
- [ ] Implement export functionality

### G6 Pattern Editor (multi-panel)
- [ ] Extend single-panel editor to multi-panel
- [ ] Add arena layout integration
- [ ] Support for full arena patterns
- [ ] Animation and sequencing tools

---

## 6. Experiment Designer

Build experiment configuration tool:

- [ ] Define experiment file format
- [ ] Build UI for stimulus sequence design
- [ ] Add parameter configuration interface
- [ ] Implement experiment export

---

## 7. CI/CD Validation Strategy

**Purpose**: Ensure web tools produce identical results to MATLAB reference implementations.

**Pattern established with Arena Editor**:

1. **MATLAB generates reference data**:
   - Create `generate_web_reference_data.m` script
   - Output JSON with computed values for all test configurations
   - Store in `docs/[tool-name]/reference_data.json`

2. **Web tool uses same calculations**:
   - Keep calculations self-contained in HTML for portability
   - Also create `js/[tool]-calculations.js` module for testing

3. **Node.js test validates**:
   - `tests/validate-[tool]-calculations.js` loads reference JSON
   - Runs JS calculations for each configuration
   - Compares with tolerance (0.0001)
   - Reports pass/fail

4. **GitHub Actions runs on push**:
   - Triggers when relevant files change
   - Fails build if calculations diverge

**To implement for G6 Panel Editor**:
- [ ] Create MATLAB function that generates reference pattern data
- [ ] Extract calculation logic into `js/g6-panel-calculations.js`
- [ ] Create `tests/validate-g6-panel-calculations.js`
- [ ] Add workflow trigger for G6 panel files
- [ ] Document pattern format specification

**Benefits**:
- Catches drift between MATLAB and web implementations
- Automated testing on every push
- Reference data serves as documentation
- Self-contained HTML files remain portable

---

## 8. Future: 3D Arena Visualization

Reserved for later implementation:

- [ ] Three.js or similar for 3D rendering
- [ ] Interactive arena rotation/zoom
- [ ] Panel placement visualization
- [ ] Export 3D models for CAD

---

## Notes

- All web outputs must match MATLAB outputs exactly
- Keep it simple—vanilla JS is preferred
- Tools are client-side only, no server needed
- Can test locally by opening HTML files
- GitHub Pages deployment for public access
- Separate repositories:
  - `maDisplayTools` (private) - MATLAB tools
  - `webDisplayTools` (public) - Web tools
- CI/CD validation ensures MATLAB ↔ Web consistency
