# TCP Migration: pnet → tcpclient

## Overview

Migrate from `pnet` (2008 MEX binary) to MATLAB's built-in `tcpclient` for cross-platform compatibility.

## Why Migrate

| Platform | pnet | tcpclient |
|----------|------|-----------|
| Mac Intel | ✓ (old binary) | ✓ |
| Mac Apple Silicon | ✗ (needs recompile) | ✓ |
| Windows | ✓ | ✓ |
| Maintained | No (2008) | Yes (MathWorks) |

## Files

| File | Description |
|------|-------------|
| `PanelsController.m` | Original implementation using pnet |
| `PanelsControllerNative.m` | New implementation using tcpclient |

## Code Changes Summary

```matlab
% Property
tcpConn = -10;                    % pnet: integer handle
tcpConn = [];                     % native: tcpclient object

% Connect
pnet('tcpconnect', host, port)    % pnet
tcpclient(host, port, 'Timeout', 5)  % native

% Write
pnet(conn, 'write', data)         % pnet
write(conn, uint8(data))          % native

% Read
pnet(conn, 'read', n, 'uint8', 'noblock')  % pnet
read(conn, conn.NumBytesAvailable, 'uint8') % native

% Close
pnet(conn, 'close')               % pnet
clear conn; conn = []             % native

% Status check
pnet(conn, 'status') > 0          % pnet
~isempty(conn) && isa(conn, 'tcpclient')  % native
```

## Testing

Run comparison benchmarks:
```matlab
run_comparison('localhost')
```

Tests include:
- Command verification (allOn, allOff, etc.)
- Timing benchmarks (100 iterations)
- Reliability test (5+ minutes)
- Streaming benchmarks (Mode 3 and Mode 5)

## Migration Path

1. Test both implementations side-by-side
2. Validate native matches pnet behavior
3. Replace PanelsController with native version
4. Remove pnet dependency
