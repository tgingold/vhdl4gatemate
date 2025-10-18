 library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    rx_i  : in std_logic;
    tx_o  : out std_logic;
    led_o : out std_logic
    );
end entity;

architecture rtl of uart is
begin
  tx_o <= rx_i;
end architecture;
