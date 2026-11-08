# -----------------------------------------------------------------------------
# Write build/vga_top.bin into the Cmod A7 Quad-SPI flash (non-volatile), then
# reboot the FPGA from the flash, exactly as happens at power-on.
#
#   vivado -mode batch -source program_flash.tcl
#   vivado -mode batch -source program_flash.tcl -tclargs <cfgmem part>
#
# Default flash part: Macronix MX25L3273F, detected by Vivado on this board
# (the reference manual lists a Micron N25Q032A, used on older revisions:
# n25q32-3.3v-spi-x1_x2_x4). On an ID mismatch Vivado stops before erasing
# and reports the detected part: pass that one as argument.
# -----------------------------------------------------------------------------
set root [file normalize [file dirname [info script]]]
set bin  [file join $root build vga_top.bin]
set flash_part "mx25l3273f-spi-x1_x2_x4"
if {[llength $argv] > 0} { set flash_part [lindex $argv 0] }

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7a35t*] 0]
if {$dev eq ""} {
    puts "ERROR: no xc7a35t device found on the JTAG chain"
    exit 1
}
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

set part [lindex [get_cfgmem_parts $flash_part] 0]
if {$part eq ""} {
    puts "ERROR: unknown flash part $flash_part"
    exit 1
}
puts "Flash part: $part"
create_hw_cfgmem -hw_device $dev $part
set cfgmem [get_property PROGRAM.HW_CFGMEM $dev]
set_property PROGRAM.ADDRESS_RANGE          {use_file}  $cfgmem
set_property PROGRAM.FILES                  [list $bin] $cfgmem
set_property PROGRAM.PRM_FILE               {}          $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem
set_property PROGRAM.BLANK_CHECK            0           $cfgmem
set_property PROGRAM.ERASE                  1           $cfgmem
set_property PROGRAM.CFG_PROGRAM            1           $cfgmem
set_property PROGRAM.VERIFY                 1           $cfgmem
set_property PROGRAM.CHECKSUM               0           $cfgmem

# Load the indirect flash-programming core into the FPGA, then erase/write/verify
create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
program_hw_devices $dev
refresh_hw_device $dev
program_hw_cfgmem -hw_cfgmem $cfgmem

# Reboot the FPGA from the flash (same as a power cycle) and check DONE
boot_hw_device $dev
after 3000
refresh_hw_device -update_hw_probes false $dev
puts "DONE pin after boot from flash: [get_property REGISTER.IR.BIT5_DONE $dev]"

close_hw_target
disconnect_hw_server
close_hw_manager
