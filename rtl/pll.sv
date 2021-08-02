`timescale 1ns / 1ps

module pll(
    input wire logic clkref,   // 125 MHz
    output wire logic clkout   // 25 Mhz
    );
    
    wire logic clkfbout;

    // Clocking primitive
    PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),  // OPTIMIZED, HIGH, LOW
        .CLKFBOUT_MULT(10),        // Multiply value for all CLKOUT, (2-64)
        .CLKFBOUT_PHASE(0.0),     // Phase offset in degrees of CLKFB, (-360.000-360.000).
        .CLKIN1_PERIOD(8.0),      // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
        // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for each CLKOUT (1-128)
        .CLKOUT0_DIVIDE(50),
        // CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
        .CLKOUT0_DUTY_CYCLE(0.5),
        // CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
        .CLKOUT0_PHASE(0.0),
        .DIVCLK_DIVIDE(1),        // Master division value, (1-56)
        .REF_JITTER1(0.0),        // Reference input jitter in UI, (0.000-0.999).
        .STARTUP_WAIT("FALSE")    // Delay DONE until PLL Locks, ("TRUE"/"FALSE")
    )
    pll_base(
        // Clock Outputs: 1-bit (each) output: User configurable clock outputs
        .CLKOUT0(clkout),   // 1-bit output: CLKOUT0
        .CLKOUT1(),   // 1-bit output: CLKOUT1
        .CLKOUT2(),   // 1-bit output: CLKOUT2
        .CLKOUT3(),   // 1-bit output: CLKOUT3
        .CLKOUT4(),   // 1-bit output: CLKOUT4
        .CLKOUT5(),   // 1-bit output: CLKOUT5
        // Feedback Clocks: 1-bit (each) output: Clock feedback ports
        .CLKFBOUT(clkfbout), // 1-bit output: Feedback clock
        .LOCKED(),     // 1-bit output: LOCK
        .CLKIN1(clkref),     // 1-bit input: Input clock
        // Control Ports: 1-bit (each) input: PLL control ports
        .PWRDWN(1'b0),     // 1-bit input: Power-down
        .RST(1'b0),        // 1-bit input: Reset
        // Feedback Clocks: 1-bit (each) input: Clock feedback ports
        .CLKFBIN(clkfbout)    // 1-bit input: Feedback clock
    );
    
endmodule