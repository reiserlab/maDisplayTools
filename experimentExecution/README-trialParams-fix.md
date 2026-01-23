# CommandExecutor trialParams() Migration

## Summary of Changes

This update fixes a bug in the experiment conductor where trials were not executing properly. The `CommandExecutor` now uses `PanelsController.trialParams()` instead of `startG41Trial()` for trial execution.

## Problem

The previous implementation called `startG41Trial()` which:
1. Did not wait for the G4 Host's "Sequence completed" TCP response
2. Used a MATLAB `pause()` as a workaround, which was unreliable
3. Had inconsistent required fields per mode (mode 4 checked for `frame_position` but used `frame_index`)

## Solution

Switched to `trialParams()` which:
1. Properly waits for the "Sequence completed" response from the G4 Host
2. Uses a unified parameter interface (all fields always required)
3. Has been tested and verified to work correctly

## Changes Made

### File: `experimentExecution/CommandExecutor.m`

**Before:** Mode-specific switch statement with different required fields per mode, calling `startG41Trial()` + `pause(dur)`

**After:** Unified validation requiring all fields, calling `trialParams()` which handles waiting internally

### YAML Protocol Requirements

All `startG41Trial` (or `trialParams`) commands now require these fields:
- `mode` (2, 3, or 4)
- `pattern` (pattern filename)
- `pattern_ID` (numeric ID)
- `frame_index` (starting frame)
- `duration` (seconds)
- `frame_rate` (fps, set to 0 if unused)
- `gain` (closed-loop gain, set to 0 if unused)

### Mode-Specific Parameter Behavior

Parameters are always sent to the hardware, but some are ignored based on mode:

| Mode | Description | Used Parameters | Ignored Parameters |
|------|-------------|-----------------|-------------------|
| 2 | Constant Rate | pattern_ID, frame_index, duration, frame_rate | gain |
| 3 | Position Stream | pattern_ID, frame_index, duration | frame_rate, gain |
| 4 | Closed-Loop ADC | pattern_ID, frame_index, duration, gain | frame_rate |

When an ignored parameter has a non-zero value, an INFO log message is generated to help users catch potential mistakes.

## Backwards Compatibility

Both command names are supported:
- `command_name: "startG41Trial"` (original)
- `command_name: "trialParams"` (new)

Existing YAML protocols using `startG41Trial` will continue to work, but must include all required fields (add `frame_rate: 0` and `gain: 0` if not already present).
