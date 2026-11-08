# -----------------------------------------------------------------------------
# Non-project build for the Cmod A7-35T VGA design.
#
#   vivado -mode batch -source build.tcl
#
# Output: build/vga_top.bit (JTAG), build/vga_top.bin (Quad-SPI flash image)
#         plus timing / utilization / DRC reports.
# -----------------------------------------------------------------------------
set root [file normalize [file dirname [info script]]]
set out  [file join $root build]
file mkdir $out

read_verilog [glob [file join $root rtl *.v]]
read_xdc     [file join $root cmod_a7_vga.xdc]

synth_design -top vga_top -part xc7a35tcpg236-1
opt_design
place_design
route_design

report_clocks          -file [file join $out clocks.rpt]
report_timing_summary  -file [file join $out timing_summary.rpt]
report_utilization     -file [file join $out utilization.rpt]
report_drc             -file [file join $out drc.rpt]
report_io              -file [file join $out io.rpt]

write_bitstream -force [file join $out vga_top.bit]

# Flash image for the 4 MB Quad-SPI flash, bitstream at address 0
write_cfgmem -force -format bin -size 4 -interface SPIx4 \
    -loadbit [list up 0x00000000 [file join $out vga_top.bit]] \
    -file [file join $out vga_top.bin]
