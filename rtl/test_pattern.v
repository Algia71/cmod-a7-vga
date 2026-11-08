`timescale 1ns / 1ps
`default_nettype none
// -----------------------------------------------------------------------------
// test_pattern
//   Static test image in mode 13h logical coordinates (320x200), RGB222.
//   Purely combinational: colour = f(px, py).
//
//   py   0.. 79  8 colour bars, 40 px wide:
//                white, yellow, cyan, green, magenta, red, blue, black
//   py  80..143  4 ramps, 16 px tall: red, green, blue, grey
//                levels 0..3 left to right, 80 px per level
//                (level 1 = LSB only, level 2 = MSB only)
//   py 144..199  all 64 colours, 16 columns x 4 rows, 20 x 14 px each
//                colour index = {row, column} = 0b rrggbb
//   1 px white border on the outer edge of the 320x200 area
// -----------------------------------------------------------------------------
module test_pattern (
    input  wire [8:0] px,    // logical column 0..319
    input  wire [7:0] py,    // logical row    0..199
    output reg  [5:0] rgb    // 0b rrggbb
);

    localparam [5:0] WHITE   = 6'b11_11_11;
    localparam [5:0] YELLOW  = 6'b11_11_00;
    localparam [5:0] CYAN    = 6'b00_11_11;
    localparam [5:0] GREEN   = 6'b00_11_00;
    localparam [5:0] MAGENTA = 6'b11_00_11;
    localparam [5:0] RED     = 6'b11_00_00;
    localparam [5:0] BLUE    = 6'b00_00_11;
    localparam [5:0] BLACK   = 6'b00_00_00;

    wire border = (px == 9'd0) || (px == 9'd319) || (py == 8'd0) || (py == 8'd199);

    wire [8:0] bar_w   = px / 9'd40;            // 0..7
    wire [8:0] level_w = px / 9'd80;            // 0..3
    wire [8:0] col_w   = px / 9'd20;            // 0..15
    wire [7:0] ramp_y  = py - 8'd80;            // 0..63 inside the ramp region
    wire [7:0] row_w   = (py - 8'd144) / 8'd14; // 0..3 inside the palette region

    wire [2:0] bar   = bar_w[2:0];
    wire [1:0] level = level_w[1:0];
    wire [1:0] ramp  = ramp_y[5:4];
    wire [3:0] col   = col_w[3:0];
    wire [1:0] row   = row_w[1:0];

    always @* begin
        if (border) begin
            rgb = WHITE;
        end else if (py < 8'd80) begin
            case (bar)
                3'd0:    rgb = WHITE;
                3'd1:    rgb = YELLOW;
                3'd2:    rgb = CYAN;
                3'd3:    rgb = GREEN;
                3'd4:    rgb = MAGENTA;
                3'd5:    rgb = RED;
                3'd6:    rgb = BLUE;
                default: rgb = BLACK;
            endcase
        end else if (py < 8'd144) begin
            case (ramp)
                2'd0:    rgb = {level, 2'b00, 2'b00};   // red
                2'd1:    rgb = {2'b00, level, 2'b00};   // green
                2'd2:    rgb = {2'b00, 2'b00, level};   // blue
                default: rgb = {level, level, level};   // grey
            endcase
        end else begin
            rgb = {row, col};                           // 0b rrggbb
        end
    end

endmodule

`default_nettype wire
