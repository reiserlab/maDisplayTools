# G6 Pattern Tools - Quick Start

## Basic Usage

```matlab
% Add maDisplayTools to path
addpath('/path/to/maDisplayTools');
addpath('/path/to/maDisplayTools/g6');

% Create a simple binary pattern (2 rows × 10 cols arena)
Pats = zeros(40, 200, 10, 'uint8');  % 10 frames
Pats(1:20, :, :) = 1;                % Top row of panels lit

stretch = ones(10, 1) * 192;         % Stretch value per frame

g6_save_pattern(Pats, stretch, [2, 10], './patterns', 'my_pattern');
```

## GS16 (Grayscale) Patterns

```matlab
% 16 intensity levels (0-15)
Pats = uint8(randi([0 15], 40, 200, 10));
stretch = ones(10, 1) * 192;

g6_save_pattern(Pats, stretch, [2, 10], './patterns', 'gradient', 'Mode', 'GS16');
```

## Output Files

- `filename_G6.mat` — MATLAB struct with metadata
- `filename.pat` — Binary file for controller

## Array Dimensions

| Arena | Pixel Rows | Pixel Cols | Example |
|-------|------------|------------|---------|
| 1×1   | 20         | 20         | Single panel |
| 2×10  | 40         | 200        | Standard arena |
| 2×12  | 40         | 240        | Wide arena |

## Functions

| Function | Purpose |
|----------|---------|
| `g6_save_pattern()` | Create and save pattern files |
| `g6_encode_panel()` | (Internal) Encode single 20×20 panel |

## See Also

- `docs/g6_migration_plan.md` — Development roadmap
- `docs/g6_led_mapping.md` — LED wiring documentation (TODO)
