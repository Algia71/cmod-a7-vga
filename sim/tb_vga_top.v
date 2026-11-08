`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_vga_top
//   Full-chip testbench (MMCM included) acting as a "virtual monitor":
//   it locks onto the VGA pins only through HSync/VSync, exactly like a
//   monitor, and rebuilds the 640x400 image from the colour pins.
//
//   Sequence
//     vsync #1 .. #2 : check one full frame, then write frame.ppm
//     after vsync #2 : press BTN0 for 20 us, then release it
//     vsync #3       : first vsync after the reset, must arrive 412 lines
//                      after the release (timing restarted from line 0)
//     vsync #3 .. #4 : check one more full frame
//
//   Checks
//     - every visible pixel equals the test pattern at (col/2, line/2)
//       (catches colour/sync misalignment and wrong pixel doubling)
//     - colour is 0 everywhere in the blanking interval
//     - while BTN0 is held: HSync/VSync idle, colour 0, blink LED off
//     - RGB LED pins always high (LED off)
//   Output
//     - frame.ppm (P3, 640x400, maxval 3) with the first complete frame
//
//   Needs: -L unisims_ver and glbl
// -----------------------------------------------------------------------------
module tb_vga_top;

    localparam H_SYNC_TO_PIXEL0 = 96 + 48;    // hsync start -> first visible pixel (clocks)
    localparam V_LINES_TO_LINE0 = 2 + 35 - 1; // hsync count after vsync start -> visible line 0
    localparam RELEASE_TO_VS    = 412 * 800;  // clocks from timing restart to first vsync

    reg sysclk = 1'b0;
    always #41.6667 sysclk = ~sysclk;          // 12 MHz

    reg        btn0 = 1'b0;
    wire [1:0] vga_r, vga_g, vga_b, led;
    wire       vga_hs, vga_vs;
    wire       led0_r, led0_g, led0_b;

    vga_top dut (
        .sysclk (sysclk),
        .btn0   (btn0),
        .vga_r  (vga_r), .vga_g (vga_g), .vga_b (vga_b),
        .vga_hs (vga_hs), .vga_vs (vga_vs),
        .led    (led),
        .led0_r (led0_r), .led0_g (led0_g), .led0_b (led0_b)
    );

    // Reference model fed with the coordinates the monitor reconstructs
    reg  [9:0] ref_col = 0;
    reg  [9:0] ref_line = 0;
    wire [5:0] ref_rgb;
    test_pattern ref_i (.px(ref_col[9:1]), .py(ref_line[8:1]), .rgb(ref_rgb));

    wire [5:0] rgb = {vga_r, vga_g, vga_b};
    wire       clk = dut.clk_pix;             // sampling clock (a monitor regenerates it)

    reg  [5:0] img [0:640*400-1];

    reg     hs_d = 1'b1, vs_d = 1'b0;
    integer cyc  = 0;
    integer hcnt = 0;          // clocks since last hsync start
    integer lcnt = 0;          // hsync starts since last vsync start
    integer vs_seen = 0;
    integer col, line;
    integer pix_checked = 0, pix_errors = 0;
    integer blank_checked = 0, blank_errors = 0;
    integer hold_checked = 0, hold_errors = 0;
    integer rgbled_errors = 0;
    integer t_release = -1, t_vs3 = -1;
    reg     hold_check = 1'b0;
    integer fd, i;
    reg [5:0] rgb_s;
    reg       hs_s, vs_s, blink_s;

    always @(posedge clk) begin
        rgb_s   = rgb;                                    // sample pins before the edge updates them
        hs_s    = vga_hs;
        vs_s    = vga_vs;
        blink_s = led[1];
        cyc     = cyc + 1;

        if (hs_d && !hs_s) begin hcnt = 0; lcnt = lcnt + 1; end
        else                     hcnt = hcnt + 1;
        if (!vs_d && vs_s) begin
            lcnt    = -1;
            vs_seen = vs_seen + 1;
            if (vs_seen == 2) begin
                fd = $fopen("frame.ppm", "w");
                $fwrite(fd, "P3\n640 400\n3\n");
                for (i = 0; i < 640*400; i = i + 1)
                    $fwrite(fd, "%0d %0d %0d\n", img[i][5:4], img[i][3:2], img[i][1:0]);
                $fclose(fd);
                $display("frame.ppm written");
            end
            if (vs_seen == 3) t_vs3 = cyc;
        end

        if (dut.locked && {led0_r, led0_g, led0_b} !== 3'b111)
            rgbled_errors = rgbled_errors + 1;

        if (hold_check) begin
            hold_checked = hold_checked + 1;
            if (hs_s !== 1'b1 || vs_s !== 1'b0 || rgb_s !== 6'd0 || blink_s !== 1'b0) begin
                hold_errors = hold_errors + 1;
                if (hold_errors <= 10)
                    $display("RESET ERROR cycle %0d: hs %b vs %b rgb %b blink %b", cyc, hs_s, vs_s, rgb_s, blink_s);
            end
        end

        if (vs_seen == 1 || vs_seen == 3) begin
            col  = hcnt - H_SYNC_TO_PIXEL0;
            line = lcnt - V_LINES_TO_LINE0;
            if (col >= 0 && col < 640 && line >= 0 && line < 400) begin
                ref_col  = col;
                ref_line = line;
                #1;                                       // let the reference settle
                pix_checked = pix_checked + 1;
                if (vs_seen == 1) img[line*640 + col] = rgb_s;
                if (rgb_s !== ref_rgb) begin
                    pix_errors = pix_errors + 1;
                    if (pix_errors <= 10)
                        $display("PIXEL ERROR col %0d line %0d: got %b expected %b", col, line, rgb_s, ref_rgb);
                end
            end else begin
                blank_checked = blank_checked + 1;
                if (rgb_s !== 6'd0) begin
                    blank_errors = blank_errors + 1;
                    if (blank_errors <= 10)
                        $display("BLANK ERROR hcnt %0d lcnt %0d: colour %b", hcnt, lcnt, rgb_s);
                end
            end
        end

        hs_d = hs_s;
        vs_d = vs_s;
    end

    initial begin
        // Press BTN0 in the middle of the frame that follows vsync #2
        wait (vs_seen == 2);
        #200000;
        @(posedge clk) btn0 <= 1'b1;
        repeat (8) @(posedge clk);                // synchronizer + reset latency
        hold_check = 1'b1;
        #20000;
        @(posedge clk) begin
            hold_check = 1'b0;
            btn0 <= 1'b0;
            t_release = cyc;
        end

        wait (vs_seen == 4);
        #100;
        $display("--------------------------------------------------");
        $display("MMCM locked          : %b", dut.locked);
        $display("visible px checked   : %0d  errors: %0d", pix_checked, pix_errors);
        $display("blank px checked     : %0d  errors: %0d", blank_checked, blank_errors);
        $display("reset-hold clocks    : %0d  errors: %0d", hold_checked, hold_errors);
        $display("release -> vsync     : %0d clocks (timing restart at %0d + latency)",
                 t_vs3 - t_release, RELEASE_TO_VS);
        $display("RGB LED errors       : %0d", rgbled_errors);
        if (pix_checked == 2 * 640 * 400 && pix_errors == 0 && blank_errors == 0 &&
            hold_checked > 0 && hold_errors == 0 && rgbled_errors == 0 &&
            t_vs3 - t_release >= RELEASE_TO_VS && t_vs3 - t_release <= RELEASE_TO_VS + 10)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
