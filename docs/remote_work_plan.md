# Remote Work Plan (Jan 17-20)

No hardware needed — can do from anywhere.

## 1. Set up web_tools directory structure

```
maDisplayTools/
└── web/
    ├── landing/           # Future: links to editors, docs
    ├── arena-editor/      # Arena layout configurator
    └── pattern-editor/    # G6 pattern editor (move existing)
```

- [ ] Create `web/` directory structure
- [ ] Add placeholder `index.html` in each subfolder
- [ ] Decide on shared CSS/JS approach (or keep each standalone)

## 2. Move G6 pattern tools

- [ ] Locate existing G6 MATLAB pattern code
- [ ] Locate existing G6 web pattern editor
- [ ] Move/copy into `maDisplayTools` repo
- [ ] Add `G6_` prefix to MATLAB functions or put in `G6/` subfolder
- [ ] Document what exists vs what's missing

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

## 4. Web arena editor (start)

- [ ] Sketch UI: dropdowns for rows/cols, preview of arena shape
- [ ] Choose tech: vanilla JS, React, or simple HTML+JS
- [ ] Build basic prototype that outputs arena config JSON

---

## Notes

- All web outputs must match MATLAB outputs exactly
- Keep it simple—vanilla JS is fine for now
- Can test web tools locally without deployment
