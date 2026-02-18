# G4.1 Arena Hardware Test Checklist

**Date:** ____________
**Tester:** ____________
**Arena IP:** ____________
**MATLAB version:** ____________

## Prerequisites

- [ ] G4.1 arena powered on and connected via Ethernet
- [ ] SD card inserted with test patterns loaded
- [ ] MATLAB running with `maDisplayTools` on the path
- [ ] Software-only tests (`test_protocol_parser.m`, `test_log_command.m`, `test_script_plugin.m`, `test_class_plugin.m`, `test_protocol_runner_dryrun.m`) all passing

---

## Part A: Direct PanelsController Commands

Run these in the MATLAB command window interactively.

### A1. Connection
```matlab
arenaIP = '192.168.1.X';  % <-- UPDATE with your arena IP
pc = PanelsController(arenaIP);
pc.open(false);
```
- [ ] **PASS** / **FAIL**: Connection established, no error
  Notes: ____________

### A2. allOn
```matlab
suc = pc.allOn();
```
- [ ] **PASS** / **FAIL**: All panels illuminate, `suc == true`
  Notes: ____________

### A3. allOff
```matlab
suc = pc.allOff();
```
- [ ] **PASS** / **FAIL**: All panels turn off, `suc == true`
  Notes: ____________

### A4. setColorDepth
```matlab
suc2 = pc.setColorDepth(2);
suc16 = pc.setColorDepth(16);
```
- [ ] **PASS** / **FAIL**: Both return `true`
  Notes: ____________

### A5. trialParams
```matlab
% Use a known pattern ID that exists on the SD card
patID = 1;  % <-- UPDATE with a valid pattern ID
suc = pc.trialParams(2, patID, 60, 1, 0, 50, true);
```
- [ ] **PASS** / **FAIL**: Pattern displays for ~5 seconds, "Sequence completed" received, `suc == true`
  Notes: ____________

### A6. stopDisplay
```matlab
suc = pc.stopDisplay();
```
- [ ] **PASS** / **FAIL**: Display stops, `suc == true`
  Notes: ____________

### A7. Close connection
```matlab
pc.close();
```
- [ ] **PASS** / **FAIL**: No error
  Notes: ____________

---

## Part B: Full Protocol Execution via ProtocolRunner

### B1. Run minimal controller-only experiment
```matlab
yamlPath = fullfile(pwd, 'testing', 'test_g41_controller_only.yaml');
arenaIP = '192.168.1.X';  % <-- UPDATE
outputDir = fullfile(tempdir, 'g41_test_run');
runner = ProtocolRunner(yamlPath, arenaIP, ...
    'OutputDir', outputDir, 'Verbose', true, 'DryRun', false);
runner.run();
```
- [ ] **PASS** / **FAIL**: Full experiment executes without error
  - [ ] Pretrial: allOn + 1s wait observed
  - [ ] Block: 2 conditions x 2 reps = 4 trials displayed
  - [ ] Intertrial: 0.5s wait between trials
  - [ ] Posttrial: allOff + 0.5s wait
  Notes: ____________

### B2. Inspect experiment output directory
```matlab
ls(outputDir)
% Look for: <yamlName>_<timestamp>/
%   logs/experimentLog_<timestamp>.log
%   trial_order.mat
%   experimentSummary_<timestamp>.txt
```
- [ ] **PASS** / **FAIL**: All expected files present
  - [ ] `logs/experimentLog_*.log` exists
  - [ ] `trial_order.mat` exists
  - [ ] `experimentSummary_*.txt` exists
  Notes: ____________

### B3. Verify log file contents
```matlab
% Open the .log file and inspect
logFiles = dir(fullfile(outputDir, '*', 'logs', '*.log'));
type(fullfile(logFiles(end).folder, logFiles(end).name));
```
- [ ] **PASS** / **FAIL**: Log contains expected entries
  - [ ] Timestamps on every line
  - [ ] `=== EXPERIMENT START ===` header
  - [ ] Trial markers: `--- Trial 1/4 ---`, etc.
  - [ ] Controller command logs with parameters
  - [ ] `=== EXPERIMENT COMPLETE ===` or cleanup messages
  Notes: ____________

### B4. Run again with randomization — verify different order
```matlab
runner2 = ProtocolRunner(yamlPath, arenaIP, ...
    'OutputDir', outputDir, 'Verbose', true, 'DryRun', false);
runner2.run();
```
- [ ] **PASS** / **FAIL**: Second run completes
  - [ ] Trial order differs from first run (check log or trial_order.mat)
  Notes: ____________

---

## Part C: Error Handling (optional)

### C1. Disconnect arena mid-experiment
While a ProtocolRunner experiment is running, disconnect the Ethernet cable.
- [ ] **PASS** / **FAIL**: Error is caught, logged, and cleanup is called
  Notes: ____________

### C2. Invalid pattern ID
```matlab
% Use a pattern ID that doesn't exist on the SD card
suc = pc.trialParams(2, 9999, 60, 1, 0, 50, true);
```
- [ ] **PASS** / **FAIL**: Returns `false` or errors gracefully
  Notes: ____________

---

## Issues Found

| # | Description | Severity | File/Line |
|---|-------------|----------|-----------|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Known Issues to Discuss with Lisa

1. **SerialPlugin port field mismatch**: `ProtocolParser` validates `port_windows`/`port_posix`, but `SerialPlugin.extractConfiguration()` reads `self.definition.port`. Needs alignment.
2. **Log command with missing `params.message`**: Falls through to plugin lookup with misleading error. Consider explicit validation.
3. **experimentTemplate.yaml**: Uses `template_version` instead of `version` — will fail parser validation (this is expected for a template, but worth noting).
