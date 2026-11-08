# Knowledge base — Cmod A7-35T VGA (mode 13h, RGB222)

This file collects everything learned while building the VGA controller in this
repository (November 2026). It is written so that a **new, larger project carried
out with Claude** can start from it: copy it into the new repository (for example
as `docs/KNOWLEDGE_BASE.md`) and point to it from the new project's `CLAUDE.md`
(a template is in [section 13](#13-starter-claudemd-for-the-new-project)).

Claude's automatic memory is stored per project folder, so a project in a new
folder does **not** see what was learned here. This file is the bridge.

## How reliable each statement is

| Tag | Meaning |
|-----|---------|
| **[HW]** | Verified on the real board and monitor |
| **[SIM]** | Verified in simulation and/or by a clean Vivado build, not by itself on hardware |
| **[DOC]** | Taken from the Digilent manual, the Digilent master XDC or AMD documentation; not tested here |
| **[CALC]** | Calculated or standard values, never built or measured here |

---

## Contents

1. [Project summary](#1-project-summary)
2. [Working method with Claude](#2-working-method-with-claude)
3. [Hardware reference: Cmod A7-35T](#3-hardware-reference-cmod-a7-35t)
4. [VGA analog interface](#4-vga-analog-interface)
5. [Video timing and pixel clock](#5-video-timing-and-pixel-clock)
6. [RTL architecture](#6-rtl-architecture)
7. [Constraints (XDC)](#7-constraints-xdc)
8. [Build, programming and flash boot](#8-build-programming-and-flash-boot)
9. [Verification methodology](#9-verification-methodology)
10. [Environment on this PC](#10-environment-on-this-pc)
11. [Pitfalls and lessons learned](#11-pitfalls-and-lessons-learned)
12. [Planning the larger project](#12-planning-the-larger-project)
13. [Starter CLAUDE.md for the new project](#13-starter-claudemd-for-the-new-project)
14. [References](#14-references)

---

## 1. Project summary

**Goal:** generate a VGA signal from a Digilent Cmod A7-35T, 320x200 "mode 13h"
style, each pixel in the format `0b00rrggbb` (2 bits per colour channel).

**Result [HW]:** the monitor shows the static test image exactly as simulated;
the design boots from the on-board flash at power-on.

| Step | Content | Status |
|------|---------|--------|
| 0 | Electrical circuit (resistor DAC) and constraints for the wiring actually built | [HW] |
| 1 | HSync/VSync 640x400 @ 70 Hz, black screen: monitor recognises the mode | [HW] |
| 2 | Static test image (colour bars, ramps, 64-colour grid, white border) | [HW] identical to simulation |
| 3 | RGB LED forced off, BTN0 = reset, LD1/LD2 status LEDs | [HW] |
| 4 | Boot from Quad-SPI flash at power-on | [HW] after a real power cycle |
| 5 | Repository on GitHub | `https://github.com/Algia71/cmod-a7-vga` (private, MIT licence) |

**Important colour note:** `0b00rrggbb` carries 6 useful bits, i.e. **64 colours,
not 256**. The two top bits never reach the connector. The original mode 13h
shows 256 colours through a palette (8-bit index → 18-bit colour in the VGA DAC).
For 256 *direct* colours an RGB332 output would be needed (see 4.5 and 12.3).

**Resources used [SIM]** (post-route, xc7a35tcpg236-1):

| Resource | Used | Available |
|----------|------|-----------|
| Slice LUTs | 124 | 20 800 |
| Slice registers | 60 | 41 600 |
| Block RAM | 0 | 50 (RAMB36) |
| MMCM | 1 | 5 |
| BUFG | 1 | 32 |

Timing: all constraints met, WNS +29.9 ns on the 25.2 MHz pixel clock (period
39.7 ns). Bitstream with compression: `vga_top.bit` 298 804 bytes, `vga_top.bin`
298 592 bytes (uncompressed it would be about 2.2 MB).

---

## 2. Working method with Claude

### 2.1 User preferences (keep them in the new project)

- **Chat language: Italian.** Repository documentation (README, this file) is in
  English; code comments are in English.
- **Incremental steps.** One small, testable step at a time. Each step ends with a
  test on real hardware, and **the user decides the next step**. Claude does not
  start the next step on its own.
- The user builds the circuit on the breadboard and may choose different pins
  from those proposed: Claude adapts the constraints to the wiring actually built
  and checks the wiring table for mistakes (in this project: two channels listed
  on the same VGA pin, missing sync resistors, a duplicated "NC" row).
- The user edits files **directly on GitHub** and locally (README, images,
  LICENSE). Always fetch before committing or pushing (see 2.4).

### 2.2 The step loop that worked

1. **Read the facts first.** Board manual, master XDC, datasheets. If a source
   cannot be read, say so; do not fill gaps from memory.
2. **Write the RTL** for the step only, plus a **self-checking testbench**.
3. **Simulate** until PASS.
4. **Negative test:** break the design on purpose (wrong sync width, sync not
   delayed with the colour) and check that the testbench FAILS. A testbench that
   never fails proves nothing.
5. **Build** with the batch Tcl script; read timing, DRC and warnings. Explain
   any warning that remains (only "constant-driven port" warnings were accepted).
6. **Show the expected result**: the simulated frame converted to PNG, sent to
   the user, so the monitor can be compared with it.
7. **Program over JTAG** (volatile) after the user's go-ahead; tell the user what
   to look at (LEDs, monitor info, what each test area proves).
8. **User confirms on hardware** ("Sì, la riconosce", "Sì, è uguale", ...).
9. Write to flash or push to GitHub **only when the user asks**.

### 2.3 Definition of "done" for a step

- Testbench PASS, negative test FAIL as expected.
- Build: timing met, no critical warnings, remaining warnings explained.
- User confirmation on the real monitor.
- Status recorded (memory / docs).

### 2.4 Git and GitHub conventions used

- Repository: `Algia71/cmod-a7-vga`, **private**, branch `main`, created with
  `gh repo create ... --private --source . --push`. `gh` is logged in as `Algia71`.
- `build/` is ignored: bitstreams and reports are regenerated by `build.tcl`.
  Also ignored: `.Xil/`, `*.jou`, `*.log`, `xsim.dir/`, `*.wdb`, `*.pb`,
  `webtalk*`, `frame.ppm`.
- Commit messages in Italian, ending with the line
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Before every commit/push:** `git fetch`, then look at `git log HEAD..origin/main`.
  If the user changed something on GitHub, integrate it first
  (`git merge --ff-only origin/main` or `git pull --rebase` when there are local
  commits). Never force-push.
- **Look at every image before publishing it** (it happened twice: circuit photo
  and monitor photo; both were also later resized by the user from ~2.5 MB to
  ~200 KB — large binaries stay in git history forever).
- `warning: LF will be replaced by CRLF` messages are harmless
  (`core.autocrlf` is on). A `.gitattributes` could make line endings explicit.

---

## 3. Hardware reference: Cmod A7-35T

### 3.1 Board resources [DOC]

| Item | Value |
|------|-------|
| FPGA | Artix-7 **XC7A35T-1CPG236C** (Vivado part `xc7a35tcpg236-1`) |
| Logic | 20 800 LUTs, 41 600 flip-flops, 225 KB block RAM (50 × RAMB36), 5 clock management tiles |
| Clock | 12 MHz oscillator on pin **L17** (MRCC, bank 14) |
| SRAM | 512 KB, ISSI IS61WV5128BLL-10BLI, 19 address + 8 data + 3 control lines, 8 ns access at 3.3 V ±5 % |
| Flash | 4 MB Quad-SPI. Manual says Micron N25Q032A; **this board has a Macronix MX25L3273F [HW]** |
| USB | FTDI FT2232HQ: JTAG + USB-UART on the same micro-USB cable |
| User I/O | 2 LEDs, 1 RGB LED, 2 push buttons, 1 Pmod (JA), 48-pin DIP (44 digital I/O, 2 analog inputs) |
| XADC | 12-bit, 1 MSPS; DIP pins 15 and 16 through an on-board divider (0–3.3 V range) |

### 3.2 Power and electrical limits [DOC]

- Power from USB, or from an external 3.3–5.5 V supply on **DIP pin 24 (VU)**
  with **DIP pin 25 = GND**. When powered from USB, VU carries the USB 5 V
  (through a Schottky diode) and can power external circuits.
- VCC3V3 rail: 0.6 A max for SRAM, USB controller, Pmod, LEDs, buttons and FPGA I/O.
- **DIP pins are connected directly to the FPGA, with no series resistors.**
  Voltage ratings:

| Condition | Abs. min | Rec. min | Rec. max | Abs. max |
|-----------|----------|----------|----------|----------|
| Board powered (USB or VU) | −0.4 V | −0.2 V | 3.4 V | 3.75 V |
| Board **unpowered** | −0.4 V | — | — | **0.55 V** |

  Never drive a DIP pin from an external powered circuit while the Cmod is off.
- **Pmod JA pins have 200 Ω series resistors** on the board (protection, but they
  limit switching speed).
- All user I/O banks (14, 16, 34, 35) are at 3.3 V → `IOSTANDARD LVCMOS33`.
  Bank 0 is at 3.3 V too → `CFGBVS VCCO`, `CONFIG_VOLTAGE 3.3`.

### 3.3 DIP pin map [DOC] (from Digilent `Cmod-A7-Master.xdc`, rev. B)

| DIP | FPGA | Bank | | DIP | FPGA | Bank |
|-----|------|------|-|-----|------|------|
| 1 | M3 | 35 | | 25 | **GND** | — |
| 2 | L3 | 35 | | 26 | R3 | 34 |
| 3 | A16 | 16 (MRCC) | | 27 | T3 | 34 |
| 4 | K3 | 35 | | 28 | R2 | 34 |
| 5 | C15 | 16 (SRCC) | | 29 | T1 | 34 |
| 6 | H1 | 35 | | 30 | T2 | 34 |
| 7 | A15 | 16 | | 31 | U1 | 34 |
| 8 | B15 | 16 (SRCC) | | 32 | W2 | 34 |
| 9 | A14 | 16 | | 33 | V2 | 34 |
| 10 | J3 | 35 | | 34 | W3 | 34 |
| 11 | J1 | 35 | | 35 | V3 | 34 |
| 12 | K2 | 35 | | 36 | W5 | 34 (MRCC) |
| 13 | L1 | 35 | | 37 | V4 | 34 (SRCC) |
| 14 | L2 | 35 | | 38 | U4 | 34 (SRCC) |
| 15 | analog AIN15 (XADC vaux4: G3/G2) | 35 | | 39 | V5 | 34 |
| 16 | analog AIN16 (XADC vaux12: H2/J2) | 35 | | 40 | W4 | 34 (MRCC) |
| 17 | M1 | 35 | | 41 | U5 | 34 |
| 18 | N3 | 35 (MRCC) | | 42 | U2 | 34 |
| 19 | P3 | 35 (MRCC) | | 43 | W6 | 34 (MRCC) |
| 20 | M2 | 35 | | 44 | U3 | 34 |
| 21 | N1 | 35 | | 45 | U7 | 34 |
| 22 | N2 | 35 | | 46 | W7 | 34 (MRCC) |
| 23 | P1 | 35 | | 47 | U8 | 34 (SRCC) |
| 24 | **VU** (power) | — | | 48 | V8 | 34 (SRCC) |

MRCC/SRCC pins are clock-capable: use them if an external clock must enter the FPGA.

### 3.4 On-board I/O [DOC], polarity confirmed [HW] where noted

| Function | Port name used | FPGA pin | Notes |
|----------|----------------|----------|-------|
| 12 MHz clock | `sysclk` | L17 | `create_clock -period 83.33` |
| LD1 | `led[0]` | A17 | Active **high** [HW], 330 Ω on board [DOC] |
| LD2 | `led[1]` | C16 | Active **high** [HW], 330 Ω on board [DOC] |
| RGB LED blue | `led0_b` | B17 | Active **low**: anodes on 3.3 V, cathodes on FPGA [HW] |
| RGB LED green | `led0_g` | B16 | Active low [HW] |
| RGB LED red | `led0_r` | C17 | Active low [HW] |
| BTN0 | `btn0` | A18 | Low at rest, **high when pressed**, series resistor on board [HW] |
| BTN1 | `btn[1]` | B18 | Same as BTN0 [DOC] |
| UART PC→FPGA | `uart_txd_in` | J17 | FT2232HQ, appears as a COM port on the PC [DOC] |
| UART FPGA→PC | `uart_rxd_out` | J18 | [DOC] |
| Pmod JA 1–4 | `ja[0..3]` | G17, G19, N18, L18 | 200 Ω series [DOC] |
| Pmod JA 7–10 | `ja[4..7]` | H17, H19, J19, K18 | 200 Ω series [DOC] |
| QSPI flash | `qspi_cs`, `qspi_dq[0..3]` | K19, D18, D19, G18, F18 | Clock is the configuration CCLK; manual: also reachable on E19 after configuration, no STARTUPE2 needed [DOC] |
| SRAM address | `MemAdr[0..18]` | M18 M19 K17 N17 P17 P18 R18 W19 U19 V19 W18 T17 T18 U17 U18 V16 W16 W17 V15 | [DOC] |
| SRAM data | `MemDB[0..7]` | W15 W13 W14 U15 U16 V13 V14 U14 | [DOC] |
| SRAM control | `RamOEn`, `RamWEn`, `RamCEn` | P19, R19, N19 | Active low [DOC] |
| Crypto chip | `crypto_sda` | D17 | ATSHA204A [DOC] |

**Unused pins** get a pull-down by default in Vivado. That is why the RGB LED
(active low) was **lit** before its pins were driven: always drive the RGB LED
pins to `1` explicitly [HW].

### 3.5 Configuration [DOC] + [HW]

- At power-on the FPGA configures itself from the Quad-SPI flash; if no valid
  image is found it waits for JTAG.
- The uncompressed bitstream is 17 536 096 bits (~2.2 MB), so about half of the
  4 MB flash is free for user data; with compression (as here) ~300 KB is used.
- Flash programming is "indirect": Vivado first loads a small flash-programmer
  core into the FPGA through JTAG, then writes the flash through it.
- Writing the flash **overwrote the Digilent factory demo** (it can be restored
  from the Digilent site if needed).

---

## 4. VGA analog interface

### 4.1 VGA signal levels

- **R, G, B:** analog, 0 V (black) to 0.7 V (full intensity), into a **75 Ω
  termination inside the monitor**. Do not add a 75 Ω resistor on the breadboard.
- **HSync, VSync:** TTL-level digital inputs; 3.3 V CMOS is enough (threshold ~2 V).
- **Blanking must be black (0 V):** the monitor uses the level during blanking as
  its black reference. Colour must be forced to 0 outside the visible area.

### 4.2 Weighted-resistor DAC: method

Each colour channel uses one resistor per bit, all joined at the VGA pin. With the
75 Ω load, by superposition (a pin at 0 acts as a resistor to ground):

```
V_out = 3.3 V × (sum of 1/R_i for bits at 1) / (sum of all 1/R_i + 1/75 Ω)
```

Design procedure [CALC]:

1. Full scale 0.7 V requires the parallel combination of all bit resistors to be
   `R_par = 75 Ω × (3.3 − 0.7) / 0.7 ≈ 278.6 Ω`
   (from 3.3·G / (G + 1/75) = 0.7, with G = 1/R_par).
2. Split the conductance with binary weights:
   - 2 bits: R_MSB = 1.5·R_par ≈ **418 Ω**, R_LSB = 3·R_par ≈ **836 Ω**
   - 3 bits: R = 1.75·R_par ≈ **488 Ω**, 3.5·R_par ≈ **975 Ω**, 7·R_par ≈ **1950 Ω**
3. Subtract the FPGA output impedance (~25 Ω for LVCMOS33, DRIVE 12) and pick the
   nearest standard values.

### 4.3 The circuit actually built [HW]

| Cmod DIP | FPGA pin | Signal | Resistor | VGA pin |
|----------|----------|--------|----------|---------|
| 1 | M3 | `vga_vs` | 100 Ω | 14 VSync |
| 2 | L3 | `vga_hs` | 100 Ω | 13 HSync |
| 3 | A16 | `vga_b[1]` | 390 Ω | 3 Blue (MSB) |
| 4 | K3 | `vga_b[0]` | 820 Ω | 3 Blue (LSB) |
| 5 | C15 | `vga_g[1]` | 390 Ω | 2 Green (MSB) |
| 6 | H1 | `vga_g[0]` | 820 Ω | 2 Green (LSB) |
| 7 | A15 | `vga_r[1]` | 390 Ω | 1 Red (MSB) |
| 8 | B15 | `vga_r[0]` | 820 Ω | 1 Red (LSB) |
| 25 | — | GND | — | 5, 6, 7, 8, 10 |

VGA pins 4, 9, 11, 12, 15 are not connected: they are ID/DDC lines, and pin 9 is
the +5 V that a PC supplies for DDC, which must stay unconnected here.
The VGA connector is a Winford DE-15 breakout board; photo in `img/the_real_circuit.jpg`.

Levels with 390/820 Ω [CALC]:

| Bits (MSB LSB) | Ideal driver | With ~25 Ω driver |
|----------------|--------------|-------------------|
| 00 | 0 V | 0 V |
| 01 | 0.235 V | 0.231 V |
| 10 | 0.494 V | 0.470 V |
| 11 | 0.729 V | 0.701 V |

Maximum current per pin ≈ 7 mA (MSB high, LSB low), below the 12 mA of `DRIVE 12`.
The 100 Ω on the syncs protect the unprotected DIP pins and damp ringing.

**The test image proved the analog part [HW]:** colour bars → each channel on the
right VGA pin; ramps → level 1 uses only the 820 Ω, level 2 only the 390 Ω, so
the four levels must grow evenly (if 1 and 2 look swapped, the resistors are swapped).

### 4.4 Alternatives [CALC]

- **Only 470 Ω / 1 kΩ at hand:** works; white is ~0.6 V, image ~15 % darker.
- **Using Pmod JA instead of DIP pins:** the board already has 200 Ω in series,
  so use 180 Ω (MSB) and 620 Ω (LSB) externally; syncs can go direct.
- **RGB332 (256 direct colours, 8 colour pins):** red and green with 3 resistors
  each, e.g. 470 Ω / 910 Ω / 1.8 kΩ (gives 0 … 0.707 V in 8 even steps with a
  25 Ω driver), blue with 390 Ω / 820 Ω.
- **More bits per channel** (RGB444, RGB565...): same formula; above 4 bits the
  resistor tolerance (1 % parts) starts to matter, an R-2R ladder or a video DAC
  chip becomes preferable.

### 4.5 Breadboard practice

- Short wires (< ~15 cm), resistors close to the VGA connector, a ground wire
  running next to the signals; connect the connector shield to GND if the
  breakout exposes it.
- Power comes from USB; nothing else is needed.

---

## 5. Video timing and pixel clock

### 5.1 Mode 13h on a VGA monitor

320x200 is not a native VGA timing: the original VGA card sends **640x400 @ 70 Hz**
and doubles every logical pixel (2 clocks wide, 2 lines tall). The same sync
timing is used by the 720x400 text mode, so **monitors cannot tell them apart and
often report "720x400 @ 70 Hz"** — the user's Dell monitor does [HW].

### 5.2 640x400 @ 70 Hz (used here) [HW]

| | Visible | Front porch | Sync | Back porch | Total | Sync polarity |
|---|---|---|---|---|---|---|
| Horizontal (pixels) | 640 | 16 | 96 | 48 | 800 | **negative** |
| Vertical (lines) | 400 | 12 | 2 | 35 | 449 | **positive** |

- Nominal pixel clock 25.175 MHz; used 25.2 MHz (+0.1 %, well inside tolerance).
- Line rate 25.2 MHz / 800 = 31.5 kHz; frame rate 31.5 kHz / 449 = 70.156 Hz.
- Counter positions: HSync active for `h_cnt` 656…751, VSync for `v_cnt` 412…413.
- Logical coordinates: `px = x[9:1]` (0…319), `py = y[8:1]` (0…199).

### 5.3 Other standard modes for the future [CALC] (VESA DMT values; not built here)

| Mode | Pixel clock | H: vis / fp / sync / bp (total) | V: vis / fp / sync / bp (total) | Polarity H/V |
|------|-------------|------------------------------|------------------------------|--------------|
| 640x480 @ 60 | 25.175 MHz | 640/16/96/48 (800) | 480/10/2/33 (525) | −/− |
| 800x600 @ 60 | 40.000 MHz | 800/40/128/88 (1056) | 600/1/4/23 (628) | +/+ |
| 1024x768 @ 60 | 65.000 MHz | 1024/24/136/160 (1344) | 768/3/6/29 (806) | −/− |

`vga_timing.v` is parameterised, so these only need new parameters (and wider
counters for totals above 1023).

### 5.4 Pixel clock from the 12 MHz oscillator with an MMCM

```
f_VCO = 12 MHz × CLKFBOUT_MULT_F / DIVCLK_DIVIDE      (600…1200 MHz for speed grade -1)
f_out = f_VCO / CLKOUT0_DIVIDE_F
```

Constraints to respect (Artix-7, -1) [DOC]: MMCM input ≥ 10 MHz (12 MHz is fine),
VCO 600–1200 MHz, `CLKFBOUT_MULT_F` and `CLKOUT0_DIVIDE_F` in steps of 0.125.

| Target | MULT | DIVCLK | OUT0 | VCO | Result | Status |
|--------|------|--------|------|-----|--------|--------|
| 25.175 MHz (VGA) | 63 | 1 | 30 | 756 MHz | 25.2 MHz | [HW] |
| 40 MHz (800x600) | 60 | 1 | 18 | 720 MHz | 40.0 MHz | [CALC] |
| 65 MHz (1024x768) | 65 | 1 | 12 | 780 MHz | 65.0 MHz | [CALC] |

The MMCM was instantiated directly (`MMCME2_BASE` + `BUFG`) instead of the
Clocking Wizard IP: no IP to generate, works in a non-project Tcl flow, and the
simulation uses the `unisims_ver` model. More outputs (`CLKOUT1…6`) of the same
MMCM can provide extra clocks (e.g. a faster clock for SRAM or a CPU).

### 5.5 LCD monitors

- An LCD must guess the pixel phase of an analog signal: if the image is shifted
  or vertical edges shimmer, run the monitor's **auto-adjust**. The 1-pixel white
  border of the test image is what auto-adjust locks onto.
- When BTN0 is held, syncs stop: the monitor may show "no signal"; after release
  it takes 1–2 s to relock [HW].

---

## 6. RTL architecture

### 6.1 Block diagram

```
          12 MHz                 25.2 MHz (clk_pix, BUFG)
sysclk ──► vga_clk_gen (MMCM) ──┬──────────────────────────────────────────────┐
                    │ locked    │                                              │
                    ▼           ▼                                              │
btn0 ──► 2-FF sync ──► reset generator ── rst (sync release) ──┐               │
                                                                ▼               ▼
                                     vga_timing ── hsync, vsync, active, x, y, frame_start
                                                                │
                                         x[9:1], y[8:1]         ▼
                                  test_pattern (combinational) ── rgb[5:0]
                                                                │
                                   output registers: rgb_q = active ? rgb : 0,
                                   hs_q, vs_q (syncs delayed by the same 1 clock)
                                                                │
                                         vga_r[1:0] vga_g[1:0] vga_b[1:0] vga_hs vga_vs
frame_start ──► frame counter (0…34) ──► blink ──► led[1];  locked ──► led[0]
```

### 6.2 Modules

| File | Module | Interface | Function |
|------|--------|-----------|----------|
| `rtl/vga_clk_gen.v` | `vga_clk_gen` | `clk_in` → `clk_pix`, `locked` | MMCME2_BASE 12 → 25.2 MHz, BUFG on the output, feedback CLKFBOUT→CLKFBIN direct, RST/PWRDWN tied to 0 |
| `rtl/vga_timing.v` | `vga_timing #(H_ACTIVE, H_FRONT, H_SYNC, H_BACK, H_SYNC_POL, V_...)` | `clk`, `rst` (sync, active high) → `hsync`, `vsync`, `active`, `x[9:0]`, `y[9:0]`, `frame_start` | 10-bit counters; **all outputs registered from the same counter value**, so they are mutually aligned |
| `rtl/test_pattern.v` | `test_pattern` | `px[8:0]`, `py[7:0]` → `rgb[5:0]` | Pure combinational image generator (no memory) |
| `rtl/vga_top.v` | `vga_top` | board pins | Reset, output stage, LEDs |

Test image layout (logical 320x200):

| Rows | Content | What it verifies |
|------|---------|------------------|
| 0–79 | 8 bars, 40 px wide: white, yellow, cyan, green, magenta, red, blue, black | Each channel on the right VGA pin |
| 80–143 | 4 ramps 16 px tall (red, green, blue, grey), levels 0–3, 80 px each | Each resistor; levels must grow evenly |
| 144–199 | All 64 colours, 16 columns × 4 rows, 20×14 px, index `{row, col}` = `rrggbb` | Every combination |
| border | 1 px white frame | Image not cut or shifted; LCD auto-adjust |

### 6.3 Design rules applied (reuse them)

- **Alignment:** whatever pipeline stages the colour goes through, HSync/VSync
  must be delayed by exactly the same number of clocks. Here: 1 output register
  for both. With a frame buffer (BRAM read latency 1–2 clocks), add matching
  delay stages to `hsync`, `vsync`, `active`.
- **Black during blanking:** `rgb_q <= active ? pixel : 0`.
- **Registered outputs** to the pins: clean edges, predictable timing.
- **Reset scheme:**
  - Sources: MMCM not locked (asynchronous assert) or BTN0 pressed.
  - Release always synchronous to `clk_pix` (2-flop shift register `rst_sync`,
    preset to `11`).
  - BTN0 goes through a 2-flop synchroniser marked `(* ASYNC_REG = "TRUE" *)`.
  - No debouncer: a bounce only re-asserts the same reset.
  - XDC: `set_false_path -from [get_ports btn0]`.
  - Idle levels in reset: HSync high (negative pulse), VSync low (positive
    pulse), colour 0, blink LED off.
- **Measured latencies [SIM]:** button release → first VSync = 329 607 clocks =
  412 lines × 800 + 7 clocks (synchroniser + reset release + pipeline).
- **Heartbeat LED:** `led[1]` toggles every 35 frames (≈1 Hz at 70 Hz): it proves
  the timing chain runs even with a black screen. `led[0]` = MMCM locked.
- `` `default_nettype none `` at the top of every file (restored to `wire` at the
  end); explicit widths on every constant.

---

## 7. Constraints (XDC)

File `cmod_a7_vga.xdc`, explained:

```tcl
# Bank 0 at 3.3 V: removes a DRC warning
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Boot from the Quad-SPI flash: x4 bus, 33 MHz CCLK, compressed bitstream
set_property CONFIG_MODE SPIx4                 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4   [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33    [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE   [current_design]

# 12 MHz clock
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { sysclk }];
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { sysclk }];

# VGA (DIP 1-8, banks 16 and 35, both at 3.3 V)
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { vga_vs   }]; # DIP 1
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports { vga_hs   }]; # DIP 2
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]; # DIP 3
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]; # DIP 4
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]; # DIP 5
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]; # DIP 6
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]; # DIP 7
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]; # DIP 8
set_property -dict { DRIVE 12 SLEW SLOW } [get_ports { vga_* }]

# LEDs, RGB LED (active low), BTN0 (high when pressed)
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN B17 IOSTANDARD LVCMOS33 } [get_ports { led0_b }];
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports { led0_g }];
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { led0_r }];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { btn0 }];
set_false_path -from [get_ports { btn0 }]
```

Notes:
- Port names in the top module must match the XDC exactly.
- The generated pixel clock needs no constraint: Vivado derives it from the MMCM
  (`clk_gen_i/mmcm_i/CLKOUT0`).
- `SLEW SLOW` on VGA outputs reduces ringing on breadboard wires; at 25 MHz it is
  more than fast enough.
- No output-delay constraints were needed: the monitor samples an analog signal.

---

## 8. Build, programming and flash boot

All flows are **non-project, batch Tcl** (no `.xpr`), launched from PowerShell:

```powershell
& "C:\tools\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source build.tcl
& "C:\tools\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source program.tcl
& "C:\tools\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source program_flash.tcl
```

Run Vivado from a scratch directory if you do not want `vivado*.jou/log` and
`.Xil/` in the project folder (they are git-ignored anyway).

### 8.1 `build.tcl`

`read_verilog [glob rtl/*.v]` → `read_xdc` → `synth_design -top vga_top -part xc7a35tcpg236-1`
→ `opt_design` → `place_design` → `route_design` → reports
(`clocks`, `timing_summary`, `utilization`, `drc`, `io` in `build/`) →
`write_bitstream build/vga_top.bit` → flash image:

```tcl
write_cfgmem -force -format bin -size 4 -interface SPIx4 \
    -loadbit [list up 0x00000000 build/vga_top.bit] -file build/vga_top.bin
```

Check after every build: "All user specified timing constraints are met", WNS ≥ 0,
DRC clean, `report_io` pins match the wiring.

### 8.2 `program.tcl` — JTAG, volatile

`open_hw_manager` → `connect_hw_server -allow_non_jtag` → `open_hw_target` →
device `get_hw_devices xc7a35t*` → `PROGRAM.FILE` = `build/vga_top.bit` →
`program_hw_devices` → print `REGISTER.IR.BIT5_DONE` (must be 1).
Lost at power-off; the flash is not touched. Use it for every development test.

### 8.3 `program_flash.tcl` — permanent

1. `create_hw_cfgmem -hw_device $dev [get_cfgmem_parts mx25l3273f-spi-x1_x2_x4]`
2. Properties: `ADDRESS_RANGE use_file`, `FILES build/vga_top.bin`,
   `UNUSED_PIN_TERMINATION pull-none`, `BLANK_CHECK 0`, `ERASE 1`,
   `CFG_PROGRAM 1`, `VERIFY 1`, `CHECKSUM 0`.
3. Load the flash-programmer core:
   `create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]`
   + `program_hw_devices`.
4. `program_hw_cfgmem -hw_cfgmem $cfgmem` (erase, program, verify).
5. `boot_hw_device $dev` → reboots from flash like a power cycle; wait 3 s; check DONE.

The flash part can be overridden: `-tclargs <cfgmem part>`. If the part is wrong,
Vivado reads the JEDEC ID and **stops before erasing**:
`Part selected n25q32-3.3v, but part mx25l3273f detected` (manufacturer ID `c2` = Macronix).

**Workflow consequence:** after a change loaded only with `program.tcl`, the next
power-on brings back the version stored in the flash. Run `program_flash.tcl`
again to make a new version permanent.

---

## 9. Verification methodology

### 9.1 Levels

| Level | Tool | What it proves |
|-------|------|----------------|
| Unit testbench (`tb_vga_timing.v`) | xsim | Sync periods, widths, porches, active window, `frame_start` |
| Full-chip "virtual monitor" (`tb_vga_top.v`) | xsim + `unisims_ver` (real MMCM model) | Every pixel of two frames, blanking, reset behaviour, RGB LED |
| Negative tests | xsim | The testbenches really detect errors |
| Expected-image PNG | testbench PPM + PowerShell | The user can compare the monitor with the simulation |
| Hardware | monitor + LEDs | Final acceptance by the user |

### 9.2 `tb_vga_timing.v` [SIM]

Drives `vga_timing` with a 25.2 MHz clock for 3 frames and measures everything
from the outside, like a monitor: HSync period 800 and width 96, front porch 16,
back porch 48, active width 640; VSync period 359 200 clocks and width 1 600,
400 active lines, active + front porch = 412 × 800 clocks, back porch 35 × 800,
`frame_start` at (0,0). Result: 11 540 checks, 0 errors.
Negative test: changing the sync width parameter → FAIL.

### 9.3 `tb_vga_top.v`, the virtual monitor [SIM]

- Instantiates the whole `vga_top` with the 12 MHz clock (MMCM included); needs
  `-L unisims_ver` and `glbl`.
- Samples the pins on `dut.clk_pix` (a real monitor regenerates the pixel clock;
  the testbench borrows it).
- Locks **only on the sync edges**: `hcnt` = clocks since the HSync falling edge,
  `lcnt` = HSync pulses since the VSync rising edge (set to −1 at the VSync edge).
- Pixel coordinates: `col = hcnt − (96 + 48)`, `line = lcnt − (2 + 35 − 1)`.
- A second `test_pattern` instance is the **reference model**: every visible pixel
  must equal `ref(col/2, line/2)`; every blanking pixel must be 0.
- Sequence: check frame after VSync #1 → write `frame.ppm` at VSync #2 → press
  BTN0 200 µs later for 20 µs (syncs idle, colour 0, blink LED off) → release →
  VSync #3 must arrive 329 600…329 610 clocks later → check the frame after
  VSync #3 → stop at VSync #4. RGB LED pins must always be 1.
- Result: 512 000 visible + 206 400 blanking pixels, 0 errors; 504 reset-hold
  clocks, 0 errors; release → VSync 329 607 clocks. **Run time ≈ 3 minutes.**
- Negative test: removing the 1-clock sync delay → pixel errors at every bar edge.
- **Race pitfall (fixed):** the block uses `#1` to let the reference settle; pins
  must be captured into variables **at the start of the block, before any delay**,
  otherwise the values updated by the same clock edge are read.

To reuse it with a frame buffer: replace the reference `test_pattern` with a model
of the memory content (e.g. the same `$readmemh` file) and adjust the pipeline
latency, not the sync-based coordinate logic.

### 9.4 Simulation commands

From a working directory **outside** the repository (xsim creates `xsim.dir`
in the current directory):

```
xvlog <repo>/rtl/vga_timing.v <repo>/sim/tb_vga_timing.v
xelab tb_vga_timing -s tb_timing
xsim tb_timing -R

xvlog <repo>/rtl/*.v <repo>/sim/tb_vga_top.v $XILINX_VIVADO/data/verilog/src/glbl.v
xelab tb_vga_top glbl -L unisims_ver -s tb_top
xsim tb_top -R
```

In PowerShell the tools are `xvlog.bat`, `xelab.bat`, `xsim.bat` in the Vivado
`bin` folder, called with `&`. Both testbenches end with `RESULT: PASS` or
`RESULT: FAIL`.

### 9.5 PPM → PNG converter (PowerShell, no extra software)

The testbench writes `frame.ppm` as plain-text P3, 640x400, maxval 3.
This script converts it to PNG with `System.Drawing`:

```powershell
param([string]$InPath, [string]$OutPath)
Add-Type -AssemblyName System.Drawing
$tok = ([System.IO.File]::ReadAllText($InPath)) -split '\s+' | Where-Object { $_ -ne '' }
if ($tok[0] -ne 'P3') { throw "not a P3 file" }
$w = [int]$tok[1]; $h = [int]$tok[2]; $max = [int]$tok[3]
$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $bmp.PixelFormat)
$stride = $data.Stride
$buf = New-Object byte[] ($stride * $h)
$k = 4
for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
        $o = $row + 3 * $x
        $buf[$o + 2] = [byte]([int]$tok[$k]     * 255 / $max)   # R
        $buf[$o + 1] = [byte]([int]$tok[$k + 1] * 255 / $max)   # G
        $buf[$o]     = [byte]([int]$tok[$k + 2] * 255 / $max)   # B
        $k += 3
    }
}
[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $data.Scan0, $buf.Length)
$bmp.UnlockBits($data)
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"saved $OutPath ($w x $h)"
```

Usage: `powershell -File ppm2png.ps1 -InPath frame.ppm -OutPath frame.png`.
The result for this project is `sim/test_pattern_sim.png`.

---

## 10. Environment on this PC

| Item | Value |
|------|-------|
| OS | Windows 10 Pro; shells: PowerShell 5.1 and Git Bash |
| Vivado | **2026.1** at `C:\tools\AMDDesignTools\2026.1\Vivado\bin` — **not on PATH** |
| Calling Vivado tools | From PowerShell with `& "<path>\vivado.bat" ...`; Git Bash cannot run the `.bat` files directly |
| JTAG | Local `hw_server`, Digilent cable over the same USB; works in batch mode |
| Python | `C:\tools\python\python.exe` with `pypdf`; run with `-I -X utf8`. The `py` launcher is broken (points to a non-existent `C:\python`) |
| PDF reading | No `pdftoppm`/`pdftotext`; extract text with `pypdf` |
| git | 2.48, `core.autocrlf` on, global user "Alessandro Giancane" |
| GitHub CLI | `gh` 2.83, logged in as `Algia71` (https) |
| Web sources | `digilent.com` reference pages are behind a bot check (HTTP 403) from automated fetches; the master XDC is readable at `raw.githubusercontent.com/Digilent/digilent-xdc`; PDF copies of the manual can be read with `pypdf` |

---

## 11. Pitfalls and lessons learned

1. **64 vs 256 colours:** `0b00rrggbb` is RGB222 = 64 colours. Say it early when
   the requirement says "256 colours".
2. **Monitor says 720x400:** normal for 640x400 @ 70 Hz.
3. **Blanking not black → wrong colours:** always force 0 outside `active`.
4. **One-clock misalignment** between colour and syncs shifts the image by one
   pixel; the virtual-monitor testbench catches it at every bar edge.
5. **RGB LED lit by default:** unused pins are pulled down and the LED is active
   low. Drive its pins high.
6. **Flash part mismatch:** the manual names Micron N25Q032A, the board has a
   Macronix MX25L3273F. Vivado detects it and stops safely; read the error message
   for the right part name.
7. **JTAG vs flash:** JTAG programming is lost at power-off; the flash keeps the
   last version written with `program_flash.tcl`.
8. **Testbench race:** sample DUT outputs before any `#delay` inside a clocked block.
9. **xsim pollutes the cwd** with `xsim.dir`, `*.pb`, `*.wdb`, logs: run it in a
   scratch directory.
10. **PowerShell pipelines:** `... | Select-Object -First N` can cut the native
    program's output and make the exit code look like a failure (255) — check the
    printed result, not only the exit code.
11. **Wiring tables from the user:** check them (channels on the same VGA pin,
    missing resistors, duplicated rows) before writing constraints.
12. **DIP pins have no protection:** keep series resistors on every output and
    never drive DIP pins while the board is unpowered (abs. max 0.55 V).
13. **Sources that cannot be read:** say so and look for another source
    (GitHub raw files, PDF copies) instead of answering from memory.
14. **Git:** the user also edits on GitHub; fetch before every push. Large images
    stay in history forever — resize before the first commit.

---

## 12. Planning the larger project

Nothing here has been built yet: all of this section is **[CALC]**.

### 12.1 Resource budget on the XC7A35T

| Item | Size | Fits in |
|------|------|---------|
| Frame buffer 320×200, 8 bit/pixel | 64 000 B = 512 000 bits | ~16 of 50 RAMB36 |
| Frame buffer 320×200, 6 bit/pixel (RGB222 direct) | 384 000 bits | ~12 RAMB36 |
| Double buffer, 8 bit | 1 024 000 bits | ~32 RAMB36 |
| 256-entry palette, 18 bit (true mode 13h DAC) | 4.6 Kbit | 1 RAMB18 or distributed RAM |
| External SRAM | 512 KB | 8 frames of 64 000 B |

### 12.2 Frame buffer options

- **Block RAM, true dual port:** port A in the pixel clock domain reads pixels;
  port B, with its own clock, is written by the producer (CPU, UART loader, drawing
  engine). The dual-clock BRAM is itself the clock-domain crossing for the data.
  Read address = `py * 320 + px` = `(py << 8) + (py << 6) + px` (shifts and adds,
  no multiplier). The shortcut address `{py, px}` (stride 512) wastes memory: a
  17-bit address → up to 32 RAMB36 for 8-bit pixels instead of ~16. Add one
  sync/active delay stage per BRAM read latency stage.
- **External SRAM (512 KB, 8-bit, async, 10 ns part):** room for many frames;
  needs a small controller and time-sharing between video reads and writes
  (e.g. a controller clock 2–4× the pixel rate, or a line buffer in BRAM filled
  during the previous line, which also handles the line doubling).
- Each logical line is shown twice: a **line buffer** of 320 pixels read twice
  halves the frame-buffer bandwidth.

### 12.3 Colour

- Keep RGB222 output (6 pins, current circuit) and add a **palette** mapping 8-bit
  indices to 6-bit colours: software sees 256 indices like mode 13h, the monitor
  shows 64 distinct colours.
- Or extend the circuit to **RGB332** (8 pins, 256 direct colours) or more bits
  per channel with a palette (see 4.4). There are 44 DIP I/O available.

### 12.4 Host interface and control

- **USB-UART** (pins J17/J18) through the same USB cable: simplest way to load
  images or commands from the PC (a COM port). Start at 115 200 baud; the FT2232H
  supports much higher rates, to be verified.
- Synchronise any signal crossing clock domains: single bits with 2 flip-flops
  (`ASYNC_REG`), multi-bit data with a dual-clock FIFO/BRAM or a handshake.
- Switch buffers (double buffering) only during vertical blanking, using a
  synchronised `frame_start`/VSync event.
- A soft CPU (MicroBlaze, block design) is possible on this board, but it changes
  the flow (project mode, IP); a custom FSM may be enough for simple tasks.

### 12.5 What to reuse from this repository

- `vga_clk_gen.v`, `vga_timing.v` (parameterised), the reset scheme and output
  stage of `vga_top.v`.
- `cmod_a7_vga.xdc` (pins already matching the breadboard wiring).
- `build.tcl`, `program.tcl`, `program_flash.tcl` (change only file names/top).
- `tb_vga_top.v` as the template of the virtual monitor; the PPM → PNG script.
- `test_pattern.v` as a known-good image source while bringing up the frame buffer.

### 12.6 Suggested first steps (each one verified on hardware)

1. Copy the repository structure; rebuild and check the test image still appears.
2. Frame buffer in BRAM initialised from a file (`$readmemh`), displayed instead
   of `test_pattern`; virtual monitor compares with the same file.
3. Palette stage (if 8-bit indices are wanted).
4. Write port: UART receiver → BRAM writes; send an image from the PC.
5. Then the features of the larger project.

---

## 13. Starter CLAUDE.md for the new project

Copy into the new repository as `CLAUDE.md` and adapt:

```markdown
# Project instructions for Claude

## Language and method
- Chat with me in Italian. Repository docs and code comments in English.
- Work in small steps. Each step: RTL + self-checking testbench, simulation PASS,
  a negative test that must FAIL, Vivado build with timing met, then JTAG load
  after my OK. I verify on the real hardware and I decide the next step.
- Write to the flash (program_flash.tcl) and push to GitHub only when I ask.
- Before every commit/push: git fetch and integrate my changes made on GitHub.
  Commit messages in Italian with the Co-Authored-By line.

## Hardware and tools
- Board: Digilent Cmod A7-35T (xc7a35tcpg236-1), 12 MHz clock on L17.
- VGA on DIP pins 1-8 with a resistor DAC (RGB222); see docs/KNOWLEDGE_BASE.md.
- Vivado 2026.1: C:\tools\AMDDesignTools\2026.1\Vivado\bin (not on PATH), call the
  .bat files from PowerShell with &. Run xsim in a scratch directory.
- Flash part: mx25l3273f-spi-x1_x2_x4 (not the N25Q032A in the manual).
- Python with pypdf: C:\tools\python\python.exe -I -X utf8 (py launcher broken).

## Knowledge base
- Read docs/KNOWLEDGE_BASE.md before proposing hardware or timing changes.
```

---

## 14. References

- Digilent Cmod A7 reference manual:
  `https://digilent.com/reference/programmable-logic/cmod-a7/reference-manual`
  (bot-protected for automated tools; PDF copies exist)
- Digilent master XDC (rev. B):
  `https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Cmod-A7-Master.xdc`
- Digilent forum, protection circuit for Cmod A7:
  `https://forum.digilent.com/topic/17294-recommended-protection-circuit-for-cmod-a7/`
- AMD UG472 (7 Series Clocking: MMCM ranges), UG908 (programming and debugging:
  `write_cfgmem`, indirect flash programming), DS181 (Artix-7 DC/AC characteristics).
- This project: `https://github.com/Algia71/cmod-a7-vga`
