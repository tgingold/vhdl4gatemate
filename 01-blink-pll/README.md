# 01-blink-pll

A very simple and standalone example which instantiate the PLL.  This
hard block is probably the main one you would instantiate in most of
your designs.  The PLL compoment is declared within the top-level.

The PLL is very simple to use: you just have to specify the reference
frequency (10Mhz for Olimex GateMateA1-EVB) and the output frequency.

If you need further details, go to the FPGA datasheet and library guide!

The button is used as a reset, we will see later how to do a reset using
the PLL lock indicator.
