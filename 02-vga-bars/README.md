# 02-vga-bars

Blinking led is fun but limited. The GateMateA1-EVB board has a vga
connector.  So if you still have a screen with a VGA connector (or a
DVI connector with the analog pin), it could be used bwith the board.

This first example generates color bars (a very simple test pattern).

VGA requires specific timing and a specific pixel frequency. You can
easily find the timing spec on internet.

The main part of the Makefile has now been moved to
`common/common.make` to factorize them.  So the Makefile is now much
smaller but also a little bit less readable.

Also, instead of declaring the components of the GateMate, they have been put
in common/cc_components.vhdl.  This file has been automatically generated from
the verilog file.  It is still in the `work` library and you still get
the `binding` warning.

## Variations

* Change the pattern, or the colors

* Use different VGA mode
