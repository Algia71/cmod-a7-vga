`timescale 1ns / 1ps
`default_nettype none
// -----------------------------------------------------------------------------
// vga_timing
//   Horizontal/vertical counters and sync generation.
//
//   Defaults: 640x400 @ 70 Hz, the timing used by VGA mode 13h
//   (320x200 doubled horizontally and vertically).
//
//                 visible  front  sync  back  total   sync polarity
//     horizontal    640     16     96    48    800    negative
//     vertical      400     12      2    35    449    positive
//
//   With a 25.2 MHz pixel clock: H = 31.5 kHz, V = 70.16 Hz.
//
//   All outputs are registered and aligned with each other: on the clock
//   edge where `active` is high, `x`/`y` hold the coordinates of the pixel
//   being displayed. Outside the visible area `x`/`y` keep counting through
//   the blanking interval (x up to H_TOTAL-1, y up to V_TOTAL-1).
// -----------------------------------------------------------------------------
module vga_timing #(
    parameter H_ACTIVE   = 640,
    parameter H_FRONT    = 16,
    parameter H_SYNC     = 96,
    parameter H_BACK     = 48,
    parameter H_SYNC_POL = 1'b0,   // 0 = active-low pulse
    parameter V_ACTIVE   = 400,
    parameter V_FRONT    = 12,
    parameter V_SYNC     = 2,
    parameter V_BACK     = 35,
    parameter V_SYNC_POL = 1'b1    // 1 = active-high pulse
) (
    input  wire       clk,          // pixel clock
    input  wire       rst,          // synchronous, active high
    output reg        hsync,
    output reg        vsync,
    output reg        active,       // high inside the visible area
    output reg  [9:0] x,            // current column
    output reg  [9:0] y,            // current line
    output reg        frame_start   // one-clock pulse on the first pixel of a frame
);

    localparam H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
    localparam H_SYNC_START = H_ACTIVE + H_FRONT;
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC;
    localparam V_SYNC_START = V_ACTIVE + V_FRONT;
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    wire h_last = (h_cnt == H_TOTAL - 1);
    wire v_last = (v_cnt == V_TOTAL - 1);

    // Counters
    always @(posedge clk) begin
        if (rst) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else if (h_last) begin
            h_cnt <= 10'd0;
            v_cnt <= v_last ? 10'd0 : v_cnt + 10'd1;
        end else begin
            h_cnt <= h_cnt + 10'd1;
        end
    end

    // Registered outputs, all decoded from the same counter value
    always @(posedge clk) begin
        if (rst) begin
            hsync       <= ~H_SYNC_POL;
            vsync       <= ~V_SYNC_POL;
            active      <= 1'b0;
            x           <= 10'd0;
            y           <= 10'd0;
            frame_start <= 1'b0;
        end else begin
            hsync       <= (h_cnt >= H_SYNC_START && h_cnt < H_SYNC_END) ?  H_SYNC_POL : ~H_SYNC_POL;
            vsync       <= (v_cnt >= V_SYNC_START && v_cnt < V_SYNC_END) ?  V_SYNC_POL : ~V_SYNC_POL;
            active      <= (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
            x           <= h_cnt;
            y           <= v_cnt;
            frame_start <= (h_cnt == 10'd0) && (v_cnt == 10'd0);
        end
    end

endmodule

`default_nettype wire
