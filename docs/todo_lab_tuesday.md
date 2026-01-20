# To-Do List - Return to Lab (Tuesday)

## Priority 0: Setup
- [ ] Install Claude on the lab PC (claude.ai or Claude desktop app) to help with debugging

## Priority 1: Isolate the Problem

### Step 1: Test with known-good patterns (no SD copy code)
```matlab
% Manually load existing patterns that have worked before
% Use PanelsController directly to rule out pattern encoding issues
pc = PanelsController('YOUR_IP');
pc.open(false);
pc.allOn();   % Basic connection test
pc.allOff();
% Try panelsController.trialParams with a pattern you know works
pc.close(true);
```

Where to find patterns:
Lisa placed some in /examples
Laura has made some here: https://github.com/leburnett/G4_Display_Tools/tree/G4-1_test_patterns_protocols/Patterns/Patterns_2x12

### Step 2: If Step 1 works, test SD copy with known-good patterns
```matlab
% Use prepare_sd_card with patterns that have worked before
old_patterns = {
    'C:\path\to\known_good_pat1.pat'
    'C:\path\to\known_good_pat2.pat'
};
mapping = prepare_sd_card(old_patterns, 'E');
% Then test on controller
```

### Step 3: If Step 2 works, test with newly generated patterns
```matlab
% Use our test patterns
test_sd_card_copy('E');
% Then test on controller
```

This isolates: connection vs SD copy code vs pattern generation

---

## Priority 2: Debug Based on Findings

### If connection fails (Step 1):
- [ ] Reset controller (power cycle)
- [ ] Check network cable
- [ ] Try `PanelsControllerTeensyFunctionalTest` individual tests

### Known error: `WSA error: WSACONNRESET`
This means the controller forcibly closed the connection. Possible causes:
- Controller crashed or reset mid-communication
- Controller overwhelmed by too many rapid commands
- Protocol mismatch (bad packet format)
- Controller in bad state from previous failed test

**Things to try:**
- [ ] Power cycle the controller (full reset)
- [ ] Add small delays between commands (e.g., `pause(0.1)`)
- [ ] Send fewer commands initially (test with single `allOn`/`allOff`)
- [ ] Check if controller needs firmware reset
- [ ] Monitor controller serial output if available

### If SD copy fails (Step 2):
- [ ] Check MANIFEST.bin contents (should be 6 bytes)
- [ ] Verify pattern files copied correctly (compare sizes)
- [ ] Check FAT32 filesystem on SD card
- [ ] Try formatting SD card fresh

### If new patterns fail (Step 3):
- [ ] Compare header bytes of working vs non-working patterns
- [ ] Check `load_pat` / `preview_pat` on new patterns
- [ ] Verify gs_val=2 encoding is correct
- [ ] Test with just one simple pattern (e.g., all-white)

---

## Priority 3: Once Working

- [ ] Run full test suite with all 20 test patterns
- [ ] Document any fixes made
- [ ] Update `create_experiment_folder_g41` to call `prepare_sd_card`
- [ ] Test end-to-end: YAML → SD card → run experiment
- [ ] Share with Lisa for integration testing

---

## Quick Reference

**Key files:**
- `utils/prepare_sd_card.m` — SD copy function
- `examples/create_test_patterns.m` — generates test patterns
- `examples/test_sd_card_copy.m` — copies test patterns to SD
- `controller/PanelsController.m` — hardware communication
- `logs/` — check for recent MANIFEST logs

**GitHub branch:** `g41-controller-update`

**IP address:** `10.102.40.47` (confirmed correct)