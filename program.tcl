# -----------------------------------------------------------------------------
# Load build/vga_top.bit into the Cmod A7 FPGA over JTAG (volatile: lost at
# power-off, the on-board flash is not touched).
#
#   vivado -mode batch -source program.tcl
# -----------------------------------------------------------------------------
set root [file normalize [file dirname [info script]]]
set bit  [file join $root build vga_top.bit]

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

set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device -update_hw_probes false $dev
puts "DONE pin: [get_property REGISTER.IR.BIT5_DONE $dev]"

close_hw_target
disconnect_hw_server
close_hw_manager
