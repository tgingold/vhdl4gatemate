library ieee;
use ieee.std_logic_1164.all;

entity pll is
  generic (
    --  Input frequency in Mhz.
    freq : real);
  port (
    clk_ref_i : in std_logic;
    clk_o : out std_logic;
    rst_n_o : out std_logic
    );
end pll;

architecture sim of pll is
  constant period : time := 1 us / freq;
  signal clk : std_logic := '0';
begin
  clk <= not clk after period / 2;
  rst_n_o <= '0', '1' after 2 * period;

  clk_o <= clk;
end sim;
