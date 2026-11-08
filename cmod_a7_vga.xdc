## =====================================================================
## Cmod A7-35T  ->  VGA DE-15   (RGB222, 0b00rrggbb)
## Pin mapping taken from Digilent Cmod-A7-Master.xdc (rev. B)
## =====================================================================

## ---------------------------------------------------------------------
## Configuration (bank 0 at 3.3 V on the Cmod A7)
## ---------------------------------------------------------------------
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## Boot from the on-board 4 MB Quad-SPI flash (Macronix MX25L3273F on this board)
set_property CONFIG_MODE SPIx4                 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4   [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33    [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE   [current_design]

## ---------------------------------------------------------------------
## 12 MHz system clock
## ---------------------------------------------------------------------
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { sysclk }]; #IO_L12P_T1_MRCC_14 Sch=gclk
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { sysclk }];

## ---------------------------------------------------------------------
## VGA
##   DIP pin  FPGA pin  Signal     Resistor  VGA pin
##   1        M3        vga_vs     100 R     14 VSync
##   2        L3        vga_hs     100 R     13 HSync
##   3        A16       vga_b[1]   390 R     3  Blue  (MSB)
##   4        K3        vga_b[0]   820 R     3  Blue  (LSB)
##   5        C15       vga_g[1]   390 R     2  Green (MSB)
##   6        H1        vga_g[0]   820 R     2  Green (LSB)
##   7        A15       vga_r[1]   390 R     1  Red   (MSB)
##   8        B15       vga_r[0]   820 R     1  Red   (LSB)
## ---------------------------------------------------------------------
set_property -dict { PACKAGE_PIN M3    IOSTANDARD LVCMOS33 } [get_ports { vga_vs   }]; #IO_L8N_T1_AD14N_35   Sch=pio[01]
set_property -dict { PACKAGE_PIN L3    IOSTANDARD LVCMOS33 } [get_ports { vga_hs   }]; #IO_L8P_T1_AD14P_35   Sch=pio[02]
set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]; #IO_L12P_T1_MRCC_16   Sch=pio[03]
set_property -dict { PACKAGE_PIN K3    IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]; #IO_L7N_T1_AD6N_35    Sch=pio[04]
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]; #IO_L11P_T1_SRCC_16   Sch=pio[05]
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]; #IO_L3P_T0_DQS_AD5P_35 Sch=pio[06]
set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]; #IO_L6N_T0_VREF_16    Sch=pio[07]
set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]; #IO_L11N_T1_SRCC_16   Sch=pio[08]

## Drive strength and slew rate for all VGA outputs
set_property -dict { DRIVE 12 SLEW SLOW } [get_ports { vga_* }]

## ---------------------------------------------------------------------
## Status LEDs
##   led[0] = MMCM locked, led[1] = 1 Hz blink driven by the frame counter
## ---------------------------------------------------------------------
set_property -dict { PACKAGE_PIN A17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L12N_T1_MRCC_16 Sch=led[1]
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L13P_T2_MRCC_16 Sch=led[2]

## ---------------------------------------------------------------------
## RGB LED (active low: driven high to keep it off)
## ---------------------------------------------------------------------
set_property -dict { PACKAGE_PIN B17   IOSTANDARD LVCMOS33 } [get_ports { led0_b }]; #IO_L14N_T2_SRCC_16 Sch=led0_b
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports { led0_g }]; #IO_L13N_T2_MRCC_16 Sch=led0_g
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { led0_r }]; #IO_L14P_T2_SRCC_16 Sch=led0_r

## ---------------------------------------------------------------------
## Reset push button BTN0 (high when pressed)
## ---------------------------------------------------------------------
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { btn0 }]; #IO_L19N_T3_VREF_16 Sch=btn[0]
set_false_path -from [get_ports { btn0 }]
