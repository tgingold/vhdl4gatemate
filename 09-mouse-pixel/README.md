# 09-mouse-pixel

Decode the PS2 data from a mouse and move a pixel.

Show how to decode PS2 mouse data (which is also displayed on the UART port).


On reset (but also when the button is pressed), the pixel is moved to the
middle of the screen and the tx_enable command is sent to the mouse.
Then the received bytes are decoded and the position of the pixel is updated.

The position update is saturated: the pixel cannot move outside the bounds
of the screen.

Each time the state of the mouse changes (because it moved or a button is
pressed), the mouse sends 3 bytes for its state.

## Variations

* Handle keyboard arrow keys instead of a mouse

* Also handle home/end/page up/page down

* Add a background (test pattern)

* With a backgroun, do a xor with the background so that the pixel is
  always visible
