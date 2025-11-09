library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_psram_write is
end;

architecture behavior of tb_psram_write is
    signal clk : std_logic := '0';
    signal but : std_logic := '0';
begin
    DUT: entity work.psram_write
      port map (
        clk_i => clk,
        but_i => but,
        led_o => open,
        psram_cs_n_o => open,
        psram_clk_o => open,
        psram_l_mosi_o => open,
        psram_h_mosi_o => open,
        psram_l_miso_i => '0',
        psram_h_miso_i => '0'
      );

    but <= '1', '0' after 300 ns;
    clk <= 'X'; --  Not used
end behavior;
