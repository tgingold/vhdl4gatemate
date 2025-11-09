# 13-psram-read-qspi

Small modification to 12-psram-read-spi to read using qspi
commands: 4 bits are read at a time.  This is much faster!

## Variations

* Rewrite 11-psram-write to use qspi write command