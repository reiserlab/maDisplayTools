# Pattern Editor Regression Testing Plan

> **Purpose**: Ensure pattern editor refactoring doesn't break existing functionality
> **Last Updated**: 2026-01-18

---

## Overview

Before modifying `G4_Pattern_Generator_gui.m` to support multiple panel generations, we need:

1. **Baseline patterns** — Reference patterns generated with current (unmodified) code
2. **Feature inventory** — Complete list of pattern types and options
3. **Test procedure** — Reproducible steps to validate each feature
4. **Comparison tools** — Scripts to diff patterns before/after changes

---

## Directory Structure

```
maDisplayTools/
└── docs/
    └── pattern_testing/
        ├── README.md                    # This file
        ├── baseline_inventory.md        # Feature checklist
        ├── baseline_patterns/           # Generated with original code
        │   ├── G4_defaults/
        │   │   ├── square_grating_16px.pat
        │   │   ├── sine_grating_32px.pat
        │   │   ├── edge_moving_right.pat
        │   │   └── ...
        │   └── generation_scripts/      # MATLAB scripts that made them
        │       ├── make_baseline_square_grating.m
        │       └── ...
        ├── refactored_patterns/         # Generated after refactor
        │   ├── G3/
        │   ├── G4/
        │   ├── G41/
        │   └── G6/
        └── comparison_results/          # Diff reports
            └── 2026-01-XX_comparison.md
```

---

## Phase 1: Baseline Collection (Before Any Changes)

### Step 1: Inventory Features

Create `baseline_inventory.md` documenting every feature in `G4_Pattern_Generator_gui.m`:

#### Pattern Types
- [ ] Square wave grating
- [ ] Sine wave grating
- [ ] Edge (moving bar)
- [ ] Starfield / random dots
- [ ] Checkerboard
- [ ] Solid color
- [ ] Custom image import
- [ ] (list all others...)

#### Parameters per Pattern Type
For each pattern type, document:
- Spatial frequency / wavelength options
- Orientation (horizontal, vertical, diagonal)
- Direction of motion
- Contrast / grayscale levels
- Number of frames
- Frame rate settings

#### Additional Options
- [ ] Anti-aliasing (aa_samples, aa_poles)
- [ ] Phase shift
- [ ] Background frame
- [ ] Flip right
- [ ] Snap dots
- [ ] Dot re-randomization
- [ ] Color settings
- [ ] Mask options (solid angle, long/lat)

### Step 2: Generate Baseline Patterns

For each pattern type with default settings:

```matlab
% Example: Generate baseline square grating
% Save this script in generation_scripts/make_baseline_square_grating.m

% 1. Open the GUI
G4_Pattern_Generator_gui

% 2. Set parameters (document exact settings)
% Pattern type: Square grating
% Wavelength: 16 pixels
% Orientation: Vertical
% Grayscale: 2 levels
% Frames: 16 (one full cycle)
% Arena: 4 rows × 12 columns (G4 default)

% 3. Generate and save
% Output: baseline_patterns/G4_defaults/square_grating_16px.pat

% 4. Also save the pattern struct for comparison
% Output: baseline_patterns/G4_defaults/square_grating_16px.mat
```

### Step 3: Document the Pattern Header

For each baseline pattern, record:
```
Pattern: square_grating_16px.pat
Generated: 2026-01-XX
GUI Version: (git commit hash)
Settings:
  - Pattern type: Square grating
  - Wavelength: 16 px
  - Orientation: Vertical
  - gs_val: 2
  - num_frames: 16
  - arena: 4×12 (G4)
File size: XXXX bytes
Header bytes: [hex dump of first 20 bytes]
Checksum: [if applicable]
```

---

## Phase 2: Refactor with Confidence

### Approach

1. **Branch**: Create `feature/pattern-editor-multi-gen`
2. **Minimal changes**: Only add generation selector, don't refactor internals yet
3. **Test frequently**: After each change, regenerate test patterns

### Key Changes for Multi-Generation Support

```matlab
% Add generation selector to GUI
% Dropdown: G3, G4, G4.1, G6

% Update pixel calculations based on generation
function pixels = get_pixels_per_panel(generation)
    switch generation
        case 'G3',  pixels = 8;
        case 'G4',  pixels = 16;
        case 'G4.1', pixels = 16;
        case 'G6',  pixels = 20;
    end
end

% Update arena defaults based on generation
function [rows, cols] = get_default_arena(generation)
    switch generation
        case 'G3',  rows = 4; cols = 12;
        case 'G4',  rows = 4; cols = 12;
        case 'G4.1', rows = 2; cols = 12;
        case 'G6',  rows = 2; cols = 10;
    end
end
```

### Testing After Each Change

```matlab
% Run after each modification
function test_pattern_generator()
    % Generate same patterns as baseline
    % Compare output files
    
    patterns_to_test = {
        'square_grating_16px'
        'sine_grating_32px'
        'edge_moving_right'
    };
    
    for i = 1:length(patterns_to_test)
        % Generate with refactored code
        % Compare to baseline
        % Report differences
    end
end
```

---

## Phase 3: Comparison Tools

### Binary Comparison

```matlab
function result = compare_pattern_files(baseline_path, new_path)
    % Compare two .pat files byte-by-byte
    %
    % Returns:
    %   result.identical - true if files match exactly
    %   result.size_match - true if same file size
    %   result.header_match - true if headers match
    %   result.first_diff_byte - index of first difference (0 if none)
    %   result.diff_count - total bytes that differ
    
    baseline = read_binary(baseline_path);
    new_file = read_binary(new_path);
    
    result.size_match = length(baseline) == length(new_file);
    
    if result.size_match
        diff_mask = baseline ~= new_file;
        result.identical = ~any(diff_mask);
        result.diff_count = sum(diff_mask);
        
        if result.diff_count > 0
            result.first_diff_byte = find(diff_mask, 1);
        else
            result.first_diff_byte = 0;
        end
    else
        result.identical = false;
        result.diff_count = abs(length(baseline) - length(new_file));
        result.first_diff_byte = min(length(baseline), length(new_file)) + 1;
    end
    
    % Compare headers separately (first N bytes)
    header_len = 20;  % Adjust based on format
    if length(baseline) >= header_len && length(new_file) >= header_len
        result.header_match = isequal(baseline(1:header_len), new_file(1:header_len));
    else
        result.header_match = false;
    end
end
```

### Visual Comparison

```matlab
function compare_pattern_visuals(baseline_path, new_path)
    % Load and display patterns side-by-side
    
    baseline = load_pattern(baseline_path);
    new_pat = load_pattern(new_path);
    
    figure('Name', 'Pattern Comparison');
    
    % Show frame 1 of each
    subplot(2, 2, 1);
    imagesc(baseline.frames(:,:,1));
    title('Baseline - Frame 1');
    colorbar;
    
    subplot(2, 2, 2);
    imagesc(new_pat.frames(:,:,1));
    title('New - Frame 1');
    colorbar;
    
    % Show difference
    subplot(2, 2, 3);
    diff_frame = double(baseline.frames(:,:,1)) - double(new_pat.frames(:,:,1));
    imagesc(diff_frame);
    title('Difference');
    colorbar;
    
    % Show histogram of differences
    subplot(2, 2, 4);
    histogram(diff_frame(:));
    title('Difference Distribution');
    xlabel('Pixel Value Difference');
end
```

### Batch Comparison Report

```matlab
function generate_comparison_report(baseline_dir, new_dir, report_path)
    % Compare all patterns and generate markdown report
    
    baseline_files = dir(fullfile(baseline_dir, '*.pat'));
    
    report = {};
    report{end+1} = '# Pattern Comparison Report';
    report{end+1} = sprintf('Date: %s', datestr(now, 'yyyy-mm-dd HH:MM'));
    report{end+1} = '';
    report{end+1} = '| Pattern | Size Match | Header Match | Identical | Diff Bytes |';
    report{end+1} = '|---------|------------|--------------|-----------|------------|';
    
    all_pass = true;
    
    for i = 1:length(baseline_files)
        name = baseline_files(i).name;
        baseline_path = fullfile(baseline_dir, name);
        new_path = fullfile(new_dir, name);
        
        if exist(new_path, 'file')
            result = compare_pattern_files(baseline_path, new_path);
            
            size_str = result.size_match ? '✓' : '✗';
            header_str = result.header_match ? '✓' : '✗';
            identical_str = result.identical ? '✓' : '✗';
            
            report{end+1} = sprintf('| %s | %s | %s | %s | %d |', ...
                name, size_str, header_str, identical_str, result.diff_count);
            
            if ~result.identical
                all_pass = false;
            end
        else
            report{end+1} = sprintf('| %s | MISSING | - | - | - |', name);
            all_pass = false;
        end
    end
    
    report{end+1} = '';
    if all_pass
        report{end+1} = '## Result: ✓ ALL PATTERNS MATCH';
    else
        report{end+1} = '## Result: ✗ DIFFERENCES FOUND';
    end
    
    % Write report
    fid = fopen(report_path, 'w');
    fprintf(fid, '%s\n', report{:});
    fclose(fid);
    
    fprintf('Report saved to: %s\n', report_path);
end
```

---

## Phase 4: Multi-Generation Testing

After refactor supports G3/G4/G4.1/G6:

### Test Matrix

| Pattern Type | G3 (8×8) | G4 (16×16) | G4.1 (16×16) | G6 (20×20) |
|--------------|----------|------------|--------------|------------|
| Square grating | [ ] | [ ] | [ ] | [ ] |
| Sine grating | [ ] | [ ] | [ ] | [ ] |
| Edge | [ ] | [ ] | [ ] | [ ] |
| Starfield | [ ] | [ ] | [ ] | [ ] |
| Checkerboard | [ ] | [ ] | [ ] | [ ] |
| Solid | [ ] | [ ] | [ ] | [ ] |

### Cross-Generation Validation

For patterns that should look identical across generations (just different resolutions):

```matlab
function validate_cross_generation(pattern_type, params)
    % Generate same logical pattern for all generations
    % Verify visual equivalence (when downsampled/upsampled)
    
    generations = {'G3', 'G4', 'G4.1', 'G6'};
    patterns = cell(1, 4);
    
    for i = 1:4
        patterns{i} = generate_pattern(pattern_type, params, generations{i});
    end
    
    % Visual comparison
    figure('Name', sprintf('%s - Cross Generation', pattern_type));
    for i = 1:4
        subplot(2, 2, i);
        imagesc(patterns{i}.frames(:,:,1));
        title(generations{i});
        axis equal tight;
    end
end
```

---

## Checklist

### Before Starting Refactor
- [ ] Create `feature/pattern-editor-multi-gen` branch
- [ ] Complete `baseline_inventory.md`
- [ ] Generate all baseline patterns with scripts
- [ ] Document header format for each pattern
- [ ] Commit baseline patterns to repo

### During Refactor
- [ ] After each change, run comparison tests
- [ ] Document any intentional differences
- [ ] Keep baseline patterns unchanged

### After Refactor
- [ ] All G4 patterns match baseline (regression test)
- [ ] G3 patterns generate correctly
- [ ] G4.1 patterns generate correctly
- [ ] G6 patterns generate correctly
- [ ] Cross-generation visual validation
- [ ] Generate final comparison report
- [ ] Merge to main only after all tests pass

---

## Notes

- **Don't modify baseline patterns** — they are the reference
- **Version control everything** — scripts, patterns, reports
- **Document intentional changes** — if a bug fix changes output, note it
- **Test on hardware when possible** — file comparison isn't enough

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-18 | Initial plan created |
