# 12-psram-read-spi

Read PSRAM content, one byte at a time using SPI read command.
Display the byte on the UART and wait for a button push to display
the next byte.

The output should look like:
```
ff fe fd fc fb fa f9 f8-f7 f6 f5 f4 f3 f2 f1 f0
ef ee ed ec eb ea e9 ff-e7 e6 e5 e4 e3 e2 e1 ff
```

## Variations

* Use fast read.

* The PSRAMs usually have an ID command (0x9f) which returns the ID
  of the chip (on 64b).  It is not documented in the LS68S3200 datasheet,
  but it looks implemented by the chip.  Modify the design to display
  the full ID.

* Display the content of both PSRAM.
