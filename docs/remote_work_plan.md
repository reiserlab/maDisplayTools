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
- 🚧 Arena Layout Editor (placeholder)
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

---

## 3. Arena layout parameterization

Define arena config format that works for both MATLAB and web:

```yaml
# arena_layout.yaml (or .json)
name: "G4.1 Standard"
panel_rows: 2
panel_cols: 12
pixels_per_panel: 16
geometry: "cylinder"  # or "flat"
# ... other params
```

- [ ] Draft arena layout spec (YAML or JSON)
- [ ] List all parameters needed (rows, cols, radius, pixel pitch, etc.)
- [ ] Create MATLAB function to load/validate arena config
- [ ] Create JS equivalent for web tools

---

## 4. Web arena editor (implementation)

Build the Arena Layout Editor as next web tool:

- [ ] Design UI: dropdowns for rows/cols, preview of arena shape
- [ ] Implement arena visualization (cylinder/flat geometry)
- [ ] Add arena config export (JSON/YAML)
- [ ] Match output format with MATLAB requirements
- [ ] Test with existing arena configurations

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

## Notes

- All web outputs must match MATLAB outputs exactly
- Keep it simple—vanilla JS is preferred
- Tools are client-side only, no server needed
- Can test locally by opening HTML files
- GitHub Pages deployment for public access
- Separate repositories:
  - `maDisplayTools` (private) - MATLAB tools
  - `webDisplayTools` (public) - Web tools
