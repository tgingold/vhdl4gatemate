# 13-psram-read-qspi

Small modification to 12-psram-read-spi to read using qpi
commands: 4 bits are read at a time.  This is much faster!

There is a little trick: we need to switch to QPI mode, but
we don't know the initial state of the PSRAM.  After reset
it is in SPI mode, but once the bistream has been run, it is
in QPI mode.

So we use a safe initialization: we first send the exit QPI
command.  If the chip is in SPI mode, it should see only
2 command bits and therefore ignore that command.  If the
chip is in QPI mode, it leaves the QPI mode for the SPI mode.
At this point, the chip is in SPI mode and we send the
QPI enter command.

After the initialization sequence, we stay in QPI mode.

## Variations

* Rewrite 11-psram-write to use qpi write command
