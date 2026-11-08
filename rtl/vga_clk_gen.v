`timescale 1ns / 1ps
`default_nettype none
// -----------------------------------------------------------------------------
// vga_clk_gen
//   12 MHz (Cmod A7 oscillator) -> 25.2 MHz pixel clock
//
//   VCO     = 12 MHz * 63 / 1 = 756 MHz   (MMCM VCO range, -1 grade: 600..1200)
//   CLKOUT0 = 756 MHz / 30    = 25.2 MHz  (VGA nominal 25.175 MHz, +0.1 %)
// -----------------------------------------------------------------------------
module vga_clk_gen (
    input  wire clk_in,    // 12 MHz
    output wire clk_pix,   // 25.2 MHz, on a global clock buffer
    output wire locked     // high when the MMCM output is stable
);

    wire clk_fb;
    wire clk_pix_unbuf;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKIN1_PERIOD      (83.333),
        .DIVCLK_DIVIDE      (1),
        .CLKFBOUT_MULT_F    (63.000),
        .CLKFBOUT_PHASE     (0.0),
        .CLKOUT0_DIVIDE_F   (30.000),
        .CLKOUT0_PHASE      (0.0),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .STARTUP_WAIT       ("FALSE")
    ) mmcm_i (
        .CLKIN1    (clk_in),
        .CLKFBIN   (clk_fb),
        .CLKFBOUT  (clk_fb),
        .CLKFBOUTB (),
        .CLKOUT0   (clk_pix_unbuf),
        .CLKOUT0B  (),
        .CLKOUT1   (),
        .CLKOUT1B  (),
        .CLKOUT2   (),
        .CLKOUT2B  (),
        .CLKOUT3   (),
        .CLKOUT3B  (),
        .CLKOUT4   (),
        .CLKOUT5   (),
        .CLKOUT6   (),
        .LOCKED    (locked),
        .PWRDWN    (1'b0),
        .RST       (1'b0)
    );

    BUFG bufg_pix_i (
        .I (clk_pix_unbuf),
        .O (clk_pix)
    );

endmodule

`default_nettype wire
