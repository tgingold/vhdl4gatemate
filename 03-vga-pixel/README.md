# 03-vga-pixel

Moving pixel on the VGA screen, a little bit more animated than color bars.

There is now a startup reset: `rst_n` is low as long as the PLL is not locked.
The signal `rst_n` can be used a a synchronous reset.

Also, the `cc_components` package has been move to the `colognechip`
library.  Ideally, this package should be provided by the vendor (as
of 2025-10-18, it is not) as it should be ready to use and standard.
And in order not to conflict with user files, it should be put in its
own library.  Arbitrarly, I have choosen `colognechip` as a library.

We can now use the `--vendor-library=` option to ghdl so that it knows
that every components in the `colognechip` library are representing hard IP
(or blackbox) which must not be described.  When you instantiate `cc_pll`,
you don't expect to use a sub design described in HDL, you expect to use
the already present PLL block.

## Variations

* Change the speed

* Instead of a box, draw a diamond or a ball
