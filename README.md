# VHDL demo for Gatemate FPGA

## What do you need ?
FPGA board: [Olimex GateMateA1-EVB](https://www.olimex.com/Products/FPGA/GateMate/GateMateA1-EVB/open-source-hardware)(~ 50euro).

Software: [Yosys OSS cad suite](https://colognechip.com/programmable-logic/gatemate/toolchain/#get-latest-builds)(the page contain the link and the instructions)

## How to start ?

Install oss cad suite (download, extract anywhere)

On Linux, update your `PATH`:
```
PATH="<extracted_location>/oss-cad-suite/bin:$PATH"
```

## The examples

* 00-blink: A very simple example (blinking leds)

* 01-blink-pll: A still standalone example that instantiate the PLL.
  This example could be considered as a start point for a design.

* 02-vga-bars: First use of the VGA interface on the board.

## Reference Doc

Not required for the demos, but useful.

* [GateMateA1-EVB schematic](https://github.com/OLIMEX/GateMateA1-EVB/blob/main/HARDWARE/GateMateA1-EVB-Rev.A/GateMateA1-EVB_Rev_A.pdf)
* [GateMateA1-EVB user manual](https://github.com/OLIMEX/GateMateA1-EVB/blob/main/DOCUMENTS/GateMateA1-EVB-user-manual.pdf)
* [GateMate A1 datasheet](https://colognechip.com/docs/ds1001-gatemate1-datasheet-latest.pdf)
* [GateMate A1 Pin Lists](https://www.colognechip.com/docs/ds1001-gatemate1-attachment-latest.zip)
* [GateMate A1 library](https://www.colognechip.com/docs/ug1001-gatemate1-primitives-library-latest.pdf)

## Other references

There are probably much comprehensive projects for the GateMateA1-EVB
or for the GateMate itself.  However, most of them use only verilog.

* [Patrick Urban repos](https://github.com/pu-cc)
* [Extension boards](https://github.com/intergalaktik/Extension_Boards_for_Olimex_GateMate)
* [chili-chips-ba](https://github.com/chili-chips-ba/openCologne)
