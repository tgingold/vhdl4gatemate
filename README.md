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

## Reference Doc

Not required for the demos, but useful.

* [GateMateA1-EVB schematic](https://github.com/OLIMEX/GateMateA1-EVB/blob/main/HARDWARE/GateMateA1-EVB-Rev.A/GateMateA1-EVB_Rev_A.pdf)
* [GateMateA1-EVB user manual](https://github.com/OLIMEX/GateMateA1-EVB/blob/main/DOCUMENTS/GateMateA1-EVB-user-manual.pdf)
* [GateMate A1 datasheet](https://colognechip.com/docs/ds1001-gatemate1-datasheet-latest.pdf)
* [GateMate A1 Pin Lists](https://www.colognechip.com/docs/ds1001-gatemate1-attachment-latest.zip)
* [GateMate A1 library](https://www.colognechip.com/docs/ug1001-gatemate1-primitives-library-latest.pdf)

## Examples

### 00-blink

A very simple and standalone example.  Useful to test your
installation.  If `make load` fails with a message such as `cannot
find board`, it might be because you need to be root to access to the
USB port.  However, if you simply try `sudo openFPGALoader ...`, it
would probably fail as `PATH` is not preserved (or overwritten) and
thus `openFPGALoader` would not be found.  You need to do: `sudo
/<extracted_location>/oss-cad-suite/bin/openFPGALoader ...`

### 01-blink-pll

A very simple and standalone example which instantiate the PLL.  This
hard block is probably the main one you would instantiate in most of
your designs.  The PLL compoment is declared within the top-level.

Also, the PLL locked output is used as a reset signal.
