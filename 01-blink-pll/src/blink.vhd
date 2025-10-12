library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  port (
    clk : in std_logic;
    rst : in std_logic;
    led : out std_logic
    );
end entity;

architecture rtl of blink is
  component CC_PLL is
    generic (
      REF_CLK         : string;  -- reference input in MHz
      OUT_CLK         : string;  -- pll output frequency in MHz
      PERF_MD         : string;  -- LOWPOWER, ECONOMY, SPEED
      LOW_JITTER      : integer; -- 0: disable, 1: enable low jitter mode
      CI_FILTER_CONST : integer; -- optional CI filter constant
      CP_FILTER_CONST : integer  -- optional CP filter constant
      );
    port (
      CLK_REF             : in  std_logic;
      USR_CLK_REF         : in  std_logic;
      CLK_FEEDBACK        : in  std_logic;
      USR_LOCKED_STDY_RST : in  std_logic;
      USR_PLL_LOCKED_STDY : out std_logic;
      USR_PLL_LOCKED      : out std_logic;
      CLK0                : out std_logic;
      CLK90               : out std_logic;
      CLK180              : out std_logic;
      CLK270              : out std_logic;
      CLK_REF_OUT         : out std_logic
      );
  end component;

  signal clk_100    : std_logic;
  signal counter : unsigned(27 downto 0);
  constant c_period : unsigned(counter'range) :=
    to_unsigned(25_000_000 - 1, counter'length);
  signal ledo : std_logic := '0';
  signal pll_locked : std_logic;
begin
  inst_pll : CC_PLL
    generic map (
      REF_CLK         => "10.0",
      OUT_CLK         => "50.0",
      PERF_MD         => "ECONOMY",
      LOW_JITTER      => 1,
      CI_FILTER_CONST => 2,
      CP_FILTER_CONST => 4
      )
    port map (
      CLK_REF             => clk,
      USR_CLK_REF         => '0',
      CLK_FEEDBACK        => '0',
      USR_LOCKED_STDY_RST => '0',
      USR_PLL_LOCKED_STDY => open,
      USR_PLL_LOCKED      => pll_locked,
      CLK0                => clk_100,
      CLK90               => open,
      CLK180              => open,
      CLK270              => open,
      CLK_REF_OUT         => open
      );

  process(clk_100)
  begin
    if rising_edge(clk_100) then
      if rst = '0' or pll_locked = '0' or counter = 0 then
        counter <= c_period - 1;
        ledo <= not ledo;
      else
        counter <= counter - 1;
      end if;
    end if;
  end process;

  led <= ledo;
end architecture;
