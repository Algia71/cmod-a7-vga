`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_vga_timing
//   Self-checking testbench for vga_timing (640x400 @ 70 Hz).
//   Measures the outputs as a monitor would see them (edges of hsync, vsync,
//   active) and compares every interval with the expected value.
// -----------------------------------------------------------------------------
module tb_vga_timing;

    localparam H_TOTAL = 800;
    localparam V_TOTAL = 449;
    localparam FRAMES  = 3;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #19.841 clk = ~clk;          // 25.2 MHz

    wire       hs, vs, de, frame;
    wire [9:0] x, y;

    vga_timing dut (
        .clk(clk), .rst(rst),
        .hsync(hs), .vsync(vs), .active(de),
        .x(x), .y(y), .frame_start(frame)
    );

    integer cyc = 0;
    integer errors = 0;
    integer checks = 0;

    reg hs_d = 1'b1, vs_d = 1'b0, de_d = 1'b0;

    integer t_hs_fall = -1, t_hs_rise = -1;
    integer t_de_rise = -1, t_de_fall = -1;
    integer t_vs_rise = -1, t_vs_fall = -1;
    integer t_frame_de = -1;            // first de rise after a vsync pulse
    integer de_lines   = 0;             // de rises since last vsync
    integer vs_pulses  = 0;
    reg     wait_first_de = 1'b0;

    task check(input [255:0] name, input integer got, input integer exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("ERROR @cycle %0d: %0s = %0d, expected %0d", cyc, name, got, exp);
            end
        end
    endtask

    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (!rst) begin
            // ---------------- horizontal ----------------
            if (hs_d && !hs) begin                       // hsync falling (pulse start)
                if (t_hs_fall >= 0) check("hsync period", cyc - t_hs_fall, H_TOTAL);
                if (t_de_fall >= 0 && t_de_fall > t_hs_fall)
                    check("h front porch", cyc - t_de_fall, 16);
                t_hs_fall = cyc;
            end
            if (!hs_d && hs) begin                       // hsync rising (pulse end)
                if (t_hs_fall >= 0) check("hsync width", cyc - t_hs_fall, 96);
                t_hs_rise = cyc;
            end
            if (!de_d && de) begin                       // active rising
                if (t_hs_rise >= 0)
                    check("h back porch", cyc - t_hs_rise, 48);
                check("x at first pixel", x, 0);
                t_de_rise = cyc;
                de_lines  = de_lines + 1;
                if (wait_first_de) begin
                    check("v back porch (clk)", cyc - t_vs_fall, 35 * H_TOTAL);
                    check("y at first line", y, 0);
                    wait_first_de = 1'b0;
                end
                if (de_lines == 1) t_frame_de = cyc;
            end
            if (de_d && !de) begin                       // active falling
                check("active width", cyc - t_de_rise, 640);
                check("x at last pixel", x, 640);        // x already moved on
                t_de_fall = cyc;
            end
            // ---------------- vertical ----------------
            if (!vs_d && vs) begin                       // vsync rising (pulse start)
                if (t_vs_rise >= 0) check("vsync period", cyc - t_vs_rise, V_TOTAL * H_TOTAL);
                if (t_frame_de >= 0) begin
                    check("lines per frame", de_lines, 400);
                    check("active+front porch (clk)", cyc - t_frame_de, (400 + 12) * H_TOTAL);
                end
                t_vs_rise = cyc;
                vs_pulses = vs_pulses + 1;
            end
            if (vs_d && !vs) begin                       // vsync falling (pulse end)
                check("vsync width", cyc - t_vs_rise, 2 * H_TOTAL);
                t_vs_fall     = cyc;
                de_lines      = 0;
                wait_first_de = 1'b1;
            end
            if (frame) check("frame_start position x/y", x * 1000 + y, 0);
        end
        hs_d <= hs;
        vs_d <= vs;
        de_d <= de;
    end

    initial begin
        repeat (5) @(posedge clk);
        rst <= 1'b0;
        wait (vs_pulses == FRAMES + 1);
        repeat (10) @(posedge clk);
        $display("--------------------------------------------------");
        $display("vsync pulses seen : %0d", vs_pulses);
        $display("checks            : %0d", checks);
        $display("errors            : %0d", errors);
        $display("H freq @25.2 MHz  : %0.3f kHz", 25200.0 / H_TOTAL);
        $display("V freq @25.2 MHz  : %0.3f Hz", 25.2e6 / (H_TOTAL * V_TOTAL));
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
