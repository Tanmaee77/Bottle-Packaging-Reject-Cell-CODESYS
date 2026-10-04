# High-Speed Bottle Packaging & Defect Reject Cell

![CODESYS](https://img.shields.io/badge/CODESYS-V3.5%20SP17%2B-orange)
![Language](https://img.shields.io/badge/Language-Structured%20Text-blue)
![Standard](https://img.shields.io/badge/IEC-61131--3-green)

An automated inspection, spatial FIFO tracking, and pneumatic rejection cell built in **CODESYS V3.5** using **Structured Text (IEC 61131-3)** with an integrated HMI visualization.

The project demonstrates encoder-pitch-synchronized product tracking, input debouncing, fixed-duration pneumatic actuation, and live quality KPI computation.

---

## Demo

### Manual Defect Injection
Operator-triggered defect flagging with signal debouncing and spatial rejection at Station 5.

▶️ [Watch the manual injection demo](Docs/manual_defect.mp4)

### Automatic High-Throughput Mode
Continuous run with periodic defect rejection and live defect-rate calculation.

▶️ [Watch the automatic mode demo](Docs/auto_defect.mp4)

---

## Features

- **Virtual encoder:** a cyclic timer generates a pitch pulse every 250 ms
- **Debounced inspection input:** 15 ms `TON` filter plus `R_TRIG` single-scan edge detection
- **Spatial FIFO tracking:** 8-pocket boolean shift register advanced by pitch pulses, not by time
- **Pneumatic reject:** 120 ms `TP` pulse at Station 5
- **Live KPIs:** total inspected, good units, defect units, and defect rate %
- **HMI visualization:** manual injection, auto mode, and live counters

---

## System Architecture

```text
 [ Station 0 ] ────> [ Station 1-4 ] ────> [ Station 5 ] ────> [ Station 6-7 ]
 Photo-Eye / Camera    Tracking Buffer      Pneumatic Reject      Outfeed Line
 (Debounced TON)      (8-Bit Shift Reg)    (TP Pulse: 120 ms)    (Good Pockets)
```

### 1. Virtual Encoder / Pitch Generation
- A cyclic IEC timer generates a pulse every `250 ms`.
- Each pulse represents one pitch advance of the pocket conveyor.

### 2. Defect Signal Conditioning
- A `TON` timer filters the raw inspection input with a `15 ms` debounce window to suppress optical noise and mechanical chatter.
- Validated events are converted to a single-scan pulse with an `R_TRIG` edge detector.

### 3. Spatial Shift Register (FIFO)
- `arrShiftRegister : ARRAY[0..7] OF BOOL` tracks the status of 8 conveyor pockets.
- On each pitch pulse, data shifts downstream (`arr[i] := arr[i-1]`), so position tracking follows conveyor movement rather than elapsed time.

### 4. Pneumatic Rejection
- When a defect bit reaches `arrShiftRegister[5]`, a `TP` pulse timer energizes the solenoid for `120 ms`.
- The fixed pulse allows full cylinder stroke and clean retraction.

### 5. Real-Time Quality Metrics
- Tracks `Total Inspected`, `Good Units`, `Defect Units`, and `Defect Rate %`.
- The rate calculation is guarded against division by zero.

---

## Repository Structure

```text
├── Docs/
│   ├── manual_defect.mp4           # Manual injection test recording
│   └── auto_defect.mp4             # Automatic endurance test recording
├── Source/
│   ├── GVL_Tracking.st             # Global variable list
│   └── PLC_PRG.st                  # Main control logic and shift register
├── ├── Bottle_Packaging_Reject_Cell.project            # Native CODESYS V3.5 project archive
└── README.md
```

---

## Design Decisions

### Why a shift register instead of a `TON` delay for rejection?
A fixed time delay assumes constant conveyor speed. Real lines ramp, slow, and stop due to upstream backpressure, which would cause early or late ejection. A shift register advanced by encoder pitch pulses stays aligned with physical pocket position regardless of speed changes.

### Why a `TP` timer instead of set/reset logic for the cylinder?
Pneumatic actuators need a fixed dwell time to fill and complete their stroke; a single-scan pulse is not reliable. `TP` provides a fixed-width, non-retriggerable 120 ms pulse without blocking the scan cycle.

### How is division by zero handled in the KPI calculation?
The defect-rate calculation is wrapped in `IF GVL_Tracking.nTotalInspected > 0`, and integer counts are converted with `UDINT_TO_REAL` so the percentage is computed in floating point.

---

## Getting Started

**Requirements:** CODESYS Development System V3.5 SP17 or higher.

1. Open `Bottle_Packaging_Reject_Cell.project` in CODESYS.
2. Set the target device to **CODESYS Control Win V3 x64**, or enable **Online → Simulation**.
3. Log in with **Online → Login** (`Alt + F8`).
4. Start the application with **Debug → Start** (`F5`).
5. Open the **Visualization** object and operate the cell from the HMI panel.

---

## Possible Extensions

- Replace the virtual encoder with a real encoder input and high-speed counter
- Add reject-confirmation sensing to detect failed ejections
- Add conveyor-stop and jam handling states
- Log KPIs to an external database or OPC UA

---

