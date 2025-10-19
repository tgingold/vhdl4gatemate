library ieee;
use ieee.std_logic_1164.all;

library colognechip;
use colognechip.cc_components.all;

entity pll is
  generic (freq : real);
  port (
    clk_ref_i : in std_logic;
    clk_o : out std_logic;
    rst_n_o : out std_logic
    );
end pll;

architecture behav of pll is
  signal clk, rst_n, pll_locked : std_logic;
begin
  inst_pll : CC_PLL
    generic map (
      REF_CLK         => "10.0",
      OUT_CLK         => real'image(freq),
      PERF_MD         => "ECONOMY",
      LOW_JITTER      => 1,
      CI_FILTER_CONST => 2,
      CP_FILTER_CONST => 4
      )
    port map (
      CLK_REF             => clk_ref_i,
      USR_CLK_REF         => '0',
      CLK_FEEDBACK        => '0',
      USR_LOCKED_STDY_RST => '0',
      USR_PLL_LOCKED_STDY => open,
      USR_PLL_LOCKED      => pll_locked,
      CLK0                => clk,
      CLK90               => open,
      CLK180              => open,
      CLK270              => open,
      CLK_REF_OUT         => open
      );

  clk_o <= clk;

  process(clk, pll_locked)
  begin
    if pll_locked = '0' then
      rst_n <= '0';
    elsif rising_edge(clk) then
      rst_n <= '1';
    end if;
  end process;

  rst_n_o <= rst_n;
end behav;
