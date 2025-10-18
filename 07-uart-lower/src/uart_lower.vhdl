library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library colognechip;
use colognechip.cc_components.all;

entity uart_lower is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    led_o : out std_logic;
    tx_o: out std_logic;
    rx_i: in std_logic
    );
end entity;

architecture rtl of uart_lower is
  signal clk_50m    : std_logic;
  signal counter : unsigned(26 downto 0);

  signal tx_byte, rx_byte : std_logic_vector(7 downto 0);
  signal tx_stb, rx_stb, tx_done : std_logic;
  
  signal tx_msg : std_logic := '0';

  signal led_count : natural range 0 to 5_000_000 := 0;
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
      CLK_REF             => clk_i,
      USR_CLK_REF         => '0',
      CLK_FEEDBACK        => '0',
      USR_LOCKED_STDY_RST => '0',
      USR_PLL_LOCKED_STDY => open,
      USR_PLL_LOCKED      => open,
      CLK0                => clk_50m,
      CLK90               => open,
      CLK180              => open,
      CLK270              => open,
      CLK_REF_OUT         => open
      );

  uart_1: entity work.uart
    generic map (
      g_clk_freq => 50_000_000,
      g_baudrate => 115200)
    port map (
      clk_i      => clk_50m,
      rst_n_i    => '1',
      tx_o       => tx_o,
      rx_i       => rx_i,
      tx_byte_i  => tx_byte,
      tx_stb_i   => tx_stb,
      tx_done_o  => tx_done,
      rx_byte_o  => rx_byte,
      rx_stb_o   => rx_stb);

  process (clk_50m)
  begin
    if rising_edge (clk_50m) then
      tx_stb <= '0';

      if tx_msg = '1' then
        if tx_done = '1' then
          tx_msg <= '0';
        end if;
      else
        if rx_stb = '1' then
          if unsigned(rx_byte) >= x"41" and unsigned(rx_byte) <= x"5A" then
            tx_byte <= rx_byte or x"20";
          else
            tx_byte <= rx_byte;
          end if;
          tx_msg <= '1';
          tx_stb <= '1';
        end if;
      end if;
    end if;
  end process;

  led_o <= '1' when led_count = 0 else '0';

  process (clk_50m)
  begin
    if rising_edge(clk_50m) then
      if led_count /= 0 then
        led_count <= led_count - 1;
      end if;
      if rx_stb = '1' then
        led_count <= 5_000_000;
      end if;
    end if;
  end process;
end architecture;
