# 00-blink

Blinking leds.

A very simple and standalone example.  Useful to test your
installation.  If `make load` fails with a message such as `cannot
find board`, it might be because you need to be root to access to the
USB port.  However, if you simply try `sudo openFPGALoader ...`, it
would probably fail as `PATH` is not preserved (or overwritten) and
thus `openFPGALoader` would not be found.  You need to do: `sudo
/<extracted_location>/oss-cad-suite/bin/openFPGALoader ...`
