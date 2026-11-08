`timescale 1ns / 1ps
`default_nettype none
// -----------------------------------------------------------------------------
// vga_top  -  Cmod A7-35T, VGA RGB222
//
//   Step 1: correct HSync/VSync for 640x400 @ 70 Hz (mode 13h timing).
//   Step 2: static test image (test_pattern) at 320x200, each logical pixel
//           doubled to 2x2 physical pixels.
//
//   btn0   : reset while pressed (high when pressed)
//   led[0] : on when the MMCM is locked (pixel clock running)
//   led[1] : blinks at 1 Hz, toggled every 35 frames (proves VSync is running)
//   led0_r/g/b : on-board RGB LED, kept off (active low)
// -----------------------------------------------------------------------------
module vga_top (
    input  wire       sysclk,   // 12 MHz
    input  wire       btn0,     // reset push button
    output wire [1:0] vga_r,
    output wire [1:0] vga_g,
    output wire [1:0] vga_b,
    output wire       vga_hs,
    output wire       vga_vs,
    output wire [1:0] led,
    output wire       led0_r,
    output wire       led0_g,
    output wire       led0_b
);

    // -------------------------------------------------------------------------
    // Pixel clock
    // -------------------------------------------------------------------------
    wire clk_pix;
    wire locked;

    vga_clk_gen clk_gen_i (
        .clk_in  (sysclk),
        .clk_pix (clk_pix),
        .locked  (locked)
    );

    // -------------------------------------------------------------------------
    // Reset
    //   Sources: MMCM not locked (asynchronous) or BTN0 pressed.
    //   BTN0 is brought into the pixel clock domain by a two-flop synchronizer;
    //   contact bounce only re-triggers the reset, so no debouncer is needed.
    //   Release is always synchronous to clk_pix.
    // -------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] btn_sync = 2'b00;
    always @(posedge clk_pix)
        btn_sync <= {btn_sync[0], btn0};

    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk_pix or negedge locked) begin
        if (!locked)
            rst_sync <= 2'b11;
        else if (btn_sync[1])
            rst_sync <= 2'b11;
        else
            rst_sync <= {rst_sync[0], 1'b0};
    end
    wire rst = rst_sync[1];

    // -------------------------------------------------------------------------
    // Timing generator
    // -------------------------------------------------------------------------
    wire       hsync;
    wire       vsync;
    wire       active;
    wire [9:0] x;
    wire [9:0] y;
    wire       frame_start;

    vga_timing timing_i (
        .clk         (clk_pix),
        .rst         (rst),
        .hsync       (hsync),
        .vsync       (vsync),
        .active      (active),
        .x           (x),
        .y           (y),
        .frame_start (frame_start)
    );

    // -------------------------------------------------------------------------
    // Test image, 320x200 logical: x/2 = 0..319, y/2 = 0..199
    // -------------------------------------------------------------------------
    wire [5:0] pattern_rgb;

    test_pattern pattern_i (
        .px  (x[9:1]),
        .py  (y[8:1]),
        .rgb (pattern_rgb)
    );

    // -------------------------------------------------------------------------
    // Output stage: colour is registered, so the syncs are delayed by the
    // same clock to stay aligned. Colour is forced to 0 outside the visible
    // area (the monitor uses the blanking level as its black reference).
    // -------------------------------------------------------------------------
    reg [5:0] rgb_q = 6'd0;
    reg       hs_q  = 1'b1;
    reg       vs_q  = 1'b0;
    always @(posedge clk_pix) begin
        if (rst) begin
            rgb_q <= 6'd0;
            hs_q  <= 1'b1;                  // HSync idle level (negative pulse)
            vs_q  <= 1'b0;                  // VSync idle level (positive pulse)
        end else begin
            rgb_q <= active ? pattern_rgb : 6'd0;
            hs_q  <= hsync;
            vs_q  <= vsync;
        end
    end

    assign vga_r  = rgb_q[5:4];
    assign vga_g  = rgb_q[3:2];
    assign vga_b  = rgb_q[1:0];
    assign vga_hs = hs_q;
    assign vga_vs = vs_q;

    // -------------------------------------------------------------------------
    // Status LEDs
    // -------------------------------------------------------------------------
    reg [5:0] frame_cnt = 6'd0;
    reg       blink     = 1'b0;
    always @(posedge clk_pix) begin
        if (rst) begin
            frame_cnt <= 6'd0;
            blink     <= 1'b0;
        end else if (frame_start) begin
            if (frame_cnt == 6'd34) begin
                frame_cnt <= 6'd0;
                blink     <= ~blink;
            end else begin
                frame_cnt <= frame_cnt + 6'd1;
            end
        end
    end

    assign led[0] = locked;
    assign led[1] = blink;

    // RGB LED: cathodes on the FPGA pins, so a high level keeps it off
    assign led0_r = 1'b1;
    assign led0_g = 1'b1;
    assign led0_b = 1'b1;

endmodule

`default_nettype wire
