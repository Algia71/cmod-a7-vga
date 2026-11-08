# Cmod A7-35T VGA — modo 13h (320x200, RGB222)

Controller VGA in Verilog per la Digilent Cmod A7-35T, con un connettore VGA
breakout su breadboard. L'uscita è 320x200 in stile "mode 13h", e ogni pixel
è nel formato `0b00rrggbb` (2 bit per colore, 64 colori).

## Stato

| Passo | Contenuto | Verificato sul monitor |
|-------|-----------|------------------------|
| 1 | HSync/VSync 640x400 @ 70 Hz, schermo nero | sì |
| 2 | Immagine di test statica (barre, rampe, griglia a 64 colori, bordo) | sì |
| — | LED RGB spento, reset con BTN0, avvio da flash all'accensione | sì |

## Circuito

Pin DIP della Cmod collegati direttamente all'FPGA (senza resistenze in serie
sulla scheda). Ogni canale colore è un DAC a 2 bit con resistenze pesate:
con il carico di 75 Ω del monitor dà circa 0 / 0,24 / 0,48 / 0,70 V.

| DIP Cmod | Pin FPGA | Segnale    | Resistenza | Pin VGA |
|----------|----------|------------|------------|---------|
| 1        | M3       | `vga_vs`   | 100 Ω      | 14 VSync |
| 2        | L3       | `vga_hs`   | 100 Ω      | 13 HSync |
| 3        | A16      | `vga_b[1]` | 390 Ω      | 3 Blue (MSB) |
| 4        | K3       | `vga_b[0]` | 820 Ω      | 3 Blue (LSB) |
| 5        | C15      | `vga_g[1]` | 390 Ω      | 2 Green (MSB) |
| 6        | H1       | `vga_g[0]` | 820 Ω      | 2 Green (LSB) |
| 7        | A15      | `vga_r[1]` | 390 Ω      | 1 Red (MSB) |
| 8        | B15      | `vga_r[0]` | 820 Ω      | 1 Red (LSB) |
| 25 (GND) | —        | massa      | —          | 5, 6, 7, 8, 10 |

Pin VGA non collegati: 4, 9, 11, 12, 15.

## Temporizzazione

320x200 viene mostrato come 640x400 a 70 Hz, con ogni pixel logico raddoppiato
in 2x2 pixel fisici. Alcuni monitor riportano la modalità come 720x400.

| | Visibile | Front porch | Sync | Back porch | Totale | Polarità |
|---|---|---|---|---|---|---|
| Orizzontale (pixel) | 640 | 16 | 96 | 48 | 800 | negativa |
| Verticale (righe)   | 400 | 12 | 2  | 35 | 449 | positiva |

Il pixel clock è 25,2 MHz, ricavato dai 12 MHz della scheda con un MMCM
(12 × 63 / 30, VCO a 756 MHz): 31,5 kHz di riga e 70,16 Hz di quadro.

## File

| File | Contenuto |
|------|-----------|
| `rtl/vga_top.v` | Top level: reset, pipeline colore/sync, LED |
| `rtl/vga_clk_gen.v` | MMCM 12 → 25,2 MHz |
| `rtl/vga_timing.v` | Contatori e segnali HSync/VSync/active |
| `rtl/test_pattern.v` | Immagine di test 320x200 |
| `cmod_a7_vga.xdc` | Pin, clock e opzioni di boot da Quad-SPI |
| `sim/tb_vga_timing.v` | Testbench auto-verificante della temporizzazione |
| `sim/tb_vga_top.v` | Testbench "monitor virtuale" dell'intero chip; scrive `frame.ppm` |
| `sim/test_pattern_sim.png` | Fotogramma simulato di riferimento |
| `build.tcl` | Sintesi e implementazione; genera `.bit` e `.bin` |
| `program.tcl` | Caricamento via JTAG (volatile) |
| `program_flash.tcl` | Scrittura nella flash Quad-SPI e riavvio dalla flash |

LED della scheda: `led[0]` acceso quando l'MMCM è agganciato, `led[1]`
lampeggia a 1 Hz contando i quadri. Il LED RGB è tenuto spento.
BTN0 tiene il circuito in reset finché è premuto.

## Uso (Vivado 2026.1)

Compilazione (crea `build/vga_top.bit`, `build/vga_top.bin` e i report):

```
vivado -mode batch -source build.tcl
```

Caricamento temporaneo via JTAG (si perde allo spegnimento):

```
vivado -mode batch -source program.tcl
```

Scrittura permanente nella flash, così il progetto parte da solo all'accensione:

```
vivado -mode batch -source program_flash.tcl
```

La flash di questa scheda è una Macronix MX25L3273F
(`mx25l3273f-spi-x1_x2_x4`), non la Micron N25Q032A indicata nel manuale.
Su schede con un'altra flash si passa il nome della parte come argomento:
`-tclargs <parte cfgmem>`.

## Simulazione (xsim)

Da eseguire in una cartella di lavoro fuori dal progetto, perché xsim crea
`xsim.dir` nella cartella corrente. `<repo>` è il percorso di questo progetto.

Temporizzazione:

```
xvlog <repo>/rtl/vga_timing.v <repo>/sim/tb_vga_timing.v
xelab tb_vga_timing -s tb_timing
xsim tb_timing -R
```

Intero chip (MMCM incluso, circa 3 minuti):

```
xvlog <repo>/rtl/*.v <repo>/sim/tb_vga_top.v $XILINX_VIVADO/data/verilog/src/glbl.v
xelab tb_vga_top glbl -L unisims_ver -s tb_top
xsim tb_top -R
```

Entrambi i testbench stampano `PASS` o `FAIL` con il numero di errori.
