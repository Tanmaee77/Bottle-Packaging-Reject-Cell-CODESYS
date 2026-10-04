VAR_GLOBAL
    // Conveyor & System Run Signals
    bSystemEnable       : BOOL := FALSE;      // Master Start/Stop toggle
    bSimEncoderPulse    : BOOL := FALSE;      // Conveyor pitch pulse (1 pulse = 1 bottle move)

    // Field Sensor Inputs
    bRawDefectSensor    : BOOL := FALSE;      // Inspection camera / cap sensor signal
    bBottlePresent      : BOOL := FALSE;      // Bottle presence at inspection station

    // Actuator Outputs
    bRejectPusherSol    : BOOL := FALSE;      // Pneumatic pusher solenoid command

    // Production Counters
    nTotalInspected     : UDINT := 0;
    nGoodCount          : UDINT := 0;
    nDefectCount        : UDINT := 0;
    rDefectRatePct      : REAL  := 0.0;
	
	bResetCounters : BOOL := FALSE; // Operator reset command for batch counters
END_VAR