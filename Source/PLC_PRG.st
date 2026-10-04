PROGRAM PLC_PRG
VAR
    // Standard IEC 61131-3 Function Blocks
    fbEncoderPulseGen   : TON;      // Timer to generate recurring conveyor clock pulses
    fbSensorDebounce    : TON;      // Debounce timer to filter optical sensor chatter
    fbDefectTrig        : R_TRIG;   // Rising edge detector for the defect sensor
    fbShiftTrig         : R_TRIG;   // Rising edge detector for the conveyor pulse
    fbPusherPulse       : TP;       // Pulse timer to guarantee a safe, fixed-duration stroke

    // Shift Register Tracking Array
    // Index 0 = Inspection Point | Index 5 = Reject Pusher Station | Index 7 = Outfeed
    arrShiftRegister    : ARRAY[0..7] OF BOOL := [8(FALSE)];
    nIdx                : INT;      // Loop counter for shifting bits

    // Internal Process Flags
    bDebouncedDefect    : BOOL;     // Filtered sensor state
    bDefectPending      : BOOL;     // Latches the defect until the next encoder step
END_VAR
VAR CONSTANT
    // Process Timing Constants
    T_ENCODER_PERIOD    : TIME := T#250MS;   // Conveyor step rate (250 ms = 4 units/sec)
    T_SENSOR_DEBOUNCE   : TIME := T#15MS;    // 15 ms optical noise filter
    T_PUSHER_FIRE_TIME  : TIME := T#120MS;   // Pneumatic stroke duration
    REJECT_STATION_IDX  : INT  := 5;         // Station index where the reject cylinder sits
END_VAR

// ============================================================================
// NETWORK 1: Simulated Encoder Pulse Generator (Conveyor Motion Tick)
// ============================================================================
// When bSystemEnable is TRUE, fbEncoderPulseGen runs until T_ENCODER_PERIOD.
// NOT fbEncoderPulseGen.Q resets it automatically on the next scan cycle.
fbEncoderPulseGen(
    IN := GVL_Tracking.bSystemEnable AND NOT fbEncoderPulseGen.Q, 
    PT := T_ENCODER_PERIOD
);

// Detect the rising edge of the timer output to get a clean 1-scan tick
fbShiftTrig(CLK := fbEncoderPulseGen.Q);

// Expose the pulse to the global tag (useful for HMI animations and logging)
GVL_Tracking.bSimEncoderPulse := fbShiftTrig.Q;

// ============================================================================
// NETWORK 2: Sensor Debouncing and Defect Latching
// ============================================================================
// Filter optical bounce: defect sensor must be steadily active and bottle present
fbSensorDebounce(
    IN := GVL_Tracking.bRawDefectSensor AND GVL_Tracking.bBottlePresent,
    PT := T_SENSOR_DEBOUNCE
);
bDebouncedDefect := fbSensorDebounce.Q;

// Catch the clean rising edge of a detected defect
fbDefectTrig(CLK := bDebouncedDefect);

// Latch the defect state so it stays ready for the next encoder shift pulse
IF fbDefectTrig.Q THEN
    bDefectPending := TRUE;
END_IF;

// ============================================================================
// NETWORK 3: Synchronous Shift Register (FIFO Tracking)
// ============================================================================
// Execute shift only on the rising edge of the conveyor pitch pulse
IF fbShiftTrig.Q THEN
    
    // 1. Shift existing bottle data from tail to head (Downstream movement)
    FOR nIdx := 7 TO 1 BY -1 DO
        arrShiftRegister[nIdx] := arrShiftRegister[nIdx - 1];
    END_FOR;
    
    // 2. Load the inspection station's result into Index 0
    arrShiftRegister[0] := bDefectPending;
    
    // 3. Clear the pending latch so it is ready for the next bottle's window
    bDefectPending := FALSE;
    
END_IF;

// ============================================================================
// NETWORK 4: Pneumatic Reject Pusher Actuation (Pulse Timer)
// ============================================================================
// Fire the pusher when a defect occupies Index 5 on the shift pulse
fbPusherPulse(
    IN := (arrShiftRegister[REJECT_STATION_IDX] AND fbShiftTrig.Q),
    PT := T_PUSHER_FIRE_TIME
);

// Drive the physical output solenoid
GVL_Tracking.bRejectPusherSol := fbPusherPulse.Q;

// ============================================================================
// NETWORK 5: Production Metrics & Quality KPIs
// ============================================================================
// Update counters only on each conveyor pitch advance when a bottle is present
IF fbShiftTrig.Q AND GVL_Tracking.bBottlePresent THEN
    
    // Increment total inspected units
    GVL_Tracking.nTotalInspected := GVL_Tracking.nTotalInspected + 1;
    
    // Evaluate if the newly introduced bottle at Index 0 is defective
    IF arrShiftRegister[0] THEN
        GVL_Tracking.nDefectCount := GVL_Tracking.nDefectCount + 1;
    ELSE
        GVL_Tracking.nGoodCount := GVL_Tracking.nGoodCount + 1;
    END_IF;
    
    // Calculate defect percentage (prevent division by zero)
    IF GVL_Tracking.nTotalInspected > 0 THEN
        GVL_Tracking.rDefectRatePct := 
            (UDINT_TO_REAL(GVL_Tracking.nDefectCount) / 
             UDINT_TO_REAL(GVL_Tracking.nTotalInspected)) * 100.0;
    END_IF;

END_IF;

// ============================================================================
// RESET BATCH COUNTERS
// ============================================================================
IF GVL_Tracking.bResetCounters THEN
    GVL_Tracking.nTotalInspected := 0;
    GVL_Tracking.nGoodCount      := 0;
    GVL_Tracking.nDefectCount     := 0;
    GVL_Tracking.rDefectRatePct  := 0.0;
    
    // Auto-clear command
    GVL_Tracking.bResetCounters  := FALSE;
END_IF;