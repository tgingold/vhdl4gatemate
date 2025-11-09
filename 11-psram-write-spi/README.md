# 11-psram-write-spi

The board has 2 PSRAM chips (pseudo SRAM), connected using QSPI (Quad Serial
Peripheral Interface).  SPI is very common to connect simple chips like
sensors and QSPI is the higher bandwidth version used mostly for EEPROM.

This design writes the first 256 bytes of the PSRAM (with the same content)
using SPI commands.  SPI uses only 1 wire for data while QSPI uses 4 wires.
As SPI is much simpler, we start with it.

Is it working ?  We will check with the next design.

## Variations

* Write different data to both chips

* One command can write multiple bytes.  Write more than 1 byte.  Be careful
  with the length (check tCE time on the datasheet: the busy time is limited
  so that the PSRAM can be refreshed).

* Use fast write command.
