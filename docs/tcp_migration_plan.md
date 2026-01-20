# PanelsController TCP Migration Plan

## Overview

Migrate from `pnet` (2008 MEX binary) to MATLAB's built-in `tcpclient` for cross-platform compatibility.

## Why Migrate

| | pnet | tcpclient |
|---|---|---|
| Mac Intel | ✓ (old binary) | ✓ |
| Mac Apple Silicon | ✗ (needs recompile) | ✓ |
| Windows | ✓ | ✓ |
| Maintained | No (2008) | Yes (MathWorks) |

---

## Code Changes

### Property

```matlab
% Before
tcpConn = -10;

% After  
tcpConn = [];  % Will hold tcpclient object
```

### open()

```matlab
% Before
self.tcpConn = pnet('tcpconnect', self.hostName, self.port);

% After
self.tcpConn = tcpclient(self.hostName, self.port, 'Timeout', 5);
```

### close()

```matlab
% Before
pnet(self.tcpConn, 'close');
self.tcpConn = -5;

% After
clear self.tcpConn;
self.tcpConn = [];
```

### get.isOpen()

```matlab
% Before
isOpen = true;
if self.tcpConn < 0
    isOpen = false;
else
    rval = pnet(self.tcpConn, 'status');
    if rval <= 0
        isOpen = false;
    end
end

% After
isOpen = ~isempty(self.tcpConn) && isa(self.tcpConn, 'tcpclient') && self.tcpConn.Connected;
```

### write()

```matlab
% Before
pnet(self.tcpConn, 'write', data);

% After
write(self.tcpConn, uint8(data));
```

### pullResponse()

```matlab
% Before
self.iBuf = [self.iBuf pnet(self.tcpConn, 'read', 65536, 'uint8', 'noblock')];

% After
if self.tcpConn.NumBytesAvailable > 0
    self.iBuf = [self.iBuf read(self.tcpConn, self.tcpConn.NumBytesAvailable, 'uint8')];
end
```

---

## Testing Plan

### Phase 1: Command Verification

Test all commands return expected responses.

| Command | Method | Expected |
|---------|--------|----------|
| all-on | `allOn()` | "All-On Received" |
| all-off | `allOff()` | "All-Off Received" |
| stop-display | `stopDisplay()` | "Display has been stopped" |
| display-reset | `sendDisplayReset()` | "Reset Command Sent to FPGA" |
| set-control-mode | `setControlMode(mode)` | Response code 0 |
| set-pattern-id | `setPatternID(id)` | Response code 0 |
| set-frame-rate | `setFrameRate(fps)` | Response code 0 |
| start-display | `startDisplay(duration)` | "Sequence completed" |
| trial-params | `trialParams(...)` | Response code 0 |
| stream-frame | `streamFrame(...)` | Response code 0 |
| get-version | `getVersion()` | Version string |

### Phase 2: Timing Benchmarks

Measure round-trip latency (100 iterations each):

```matlab
function timing = benchmark_command_timing(ip, iterations)
    pc = PanelsController(ip);
    pc.open(false);
    
    % Benchmark allOn
    times = zeros(1, iterations);
    for i = 1:iterations
        tic; pc.allOn(); times(i) = toc;
    end
    timing.allOn.mean_ms = mean(times) * 1000;
    timing.allOn.std_ms = std(times) * 1000;
    
    % Repeat for other commands...
    pc.close(false);
end
```

### Phase 3: Reliability Testing

Run continuous commands for 5+ minutes, track success rate:

```matlab
function reliability = test_reliability(ip, duration_min)
    pc = PanelsController(ip);
    pc.open(false);
    
    total = 0; success = 0;
    start = tic;
    while toc(start) < duration_min * 60
        if pc.allOn(), success = success + 1; end
        total = total + 1;
        pause(0.05);
    end
    
    reliability.success_rate = success / total * 100;
    pc.close(false);
end
```

Target: >99.9% success rate

### Phase 4: Frame Streaming Benchmarks

#### Mode 3: Stream Pattern Position

Test position updates at various FPS:

```matlab
function result = benchmark_mode3(ip, pattern_id, fps_list)
    % fps_list = [30, 60, 100, 120, 150, 200, 300]
    pc = PanelsController(ip);
    pc.open(false);
    
    for fps = fps_list
        pc.setControlMode(3);
        pc.setPatternID(pattern_id);
        
        interval = 1/fps;
        num_frames = fps * 5;  % 5 sec test
        times = zeros(1, num_frames);
        
        start = tic;
        for i = 1:num_frames
            while toc(start) < (i-1)*interval, end
            times(i) = toc(start);
            pc.setPositionX(mod(i-1, 100));
        end
        
        jitter = std(diff(times)) / interval * 100;
        fprintf('%d FPS: jitter=%.1f%%\n', fps, jitter);
    end
    pc.close(false);
end
```

#### Mode 5: Full Frame Streaming

Test streaming complete frames (more bandwidth):

```matlab
function result = benchmark_mode5(ip, rows, cols, fps_list)
    % fps_list = [10, 20, 30, 40, 50, 60]
    pc = PanelsController(ip);
    pc.open(false);
    
    % Generate test frame
    frame = uint8(randi([0,15], rows*16, cols*16));
    frame_cmd = pc.getFrameCmd16Mex(frame);
    frame_bytes = length(frame_cmd);
    
    for fps = fps_list
        interval = 1/fps;
        num_frames = fps * 5;
        times = zeros(1, num_frames);
        
        start = tic;
        for i = 1:num_frames
            while toc(start) < (i-1)*interval, end
            times(i) = toc(start);
            pc.streamFrameCmd16(frame_cmd);
        end
        
        jitter = std(diff(times)) / interval * 100;
        bw_kbps = frame_bytes * fps * 8 / 1000;
        fprintf('%d FPS: jitter=%.1f%%, bandwidth=%.0f kbps\n', fps, jitter, bw_kbps);
    end
    pc.close(false);
end
```

**Success criteria:** Jitter < 10%

---

## Comparison: pnet vs tcpclient

Run all benchmarks with both implementations, compare:
- Command latency (mean, std, max)
- Reliability (success rate over time)
- Max streaming FPS for Mode 3 and Mode 5

---

## Migration Checklist

- [ ] Backup current PanelsController.m
- [ ] Implement tcpclient changes
- [ ] Phase 1: All commands work
- [ ] Phase 2: Timing comparable to pnet
- [ ] Phase 3: >99.9% reliability
- [ ] Phase 4a: Mode 3 streaming benchmarks
- [ ] Phase 4b: Mode 5 streaming benchmarks
- [ ] Compare pnet vs tcpclient
- [ ] Test on Windows
- [ ] Test on Mac
- [ ] Update docs
