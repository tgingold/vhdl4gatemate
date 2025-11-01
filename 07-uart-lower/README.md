# 07-uart-lower

Implement UART receiver (RX)

Any received character will be echoed but upper case letter A-Z will be echoed
in lower case.

The led will blink when a character is received.

## Variations

* Invert case

* Convert LF (or CR) to CR/LF, so that pressing Enter moves the cursor
  to the beginning of the next line
