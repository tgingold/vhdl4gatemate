# 05-uart-loopback

A very very simple design to test UART.

The GateMateA1-EVB board has RP2040 chip connected through USB to your
PC and through pins to the gatemate FPGA.  In addition to be able to program
the fpga through the JTAG interface, it also provide a UART interface between
the host and the fpga.

This simple design is just a loopback: it connects RX and TX.

The purpose is to test the connection.  You need to use a terminal emulator
and I recommend picocom as it is very simple.

Just do:

```
$ sudo picocom -b 115200 /dev/ttyACM0
```

When you connect the GateMateA1-EVB board to the PC, the USB driver will
automatically create /dev/ttyACM* devices.  It should be ttyACM0 if the
board is the only one to provide USB UART.

You probably need to use `sudo` for permissions.

Any baudrate would work, but we will standardize on 115200.
