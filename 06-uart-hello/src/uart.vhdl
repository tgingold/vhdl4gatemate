library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library colognechip;
use colognechip.cc_components.all;

entity uart is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    led_o : out std_logic;
    tx_o: out std_logic;
    rx_i: in std_logic
    );
end entity;

architecture rtl of uart is
  signal clk0    : std_logic;
  signal counter : unsigned(26 downto 0);

  constant c_baudrate : natural := 115200;

  subtype t_baudrate is natural range 0 to (50_000_000 + c_baudrate / 2) / c_baudrate;
  signal baudgen_cnt : t_baudrate;
  signal baudgen_p : std_logic;

  signal char : std_logic_vector(8 downto 0);
  signal char_cnt : natural range 0 to 9;

  constant msg : string := "Hello GateMate" & CR & LF;
  signal msg_cnt : natural range 0 to msg'length;
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
      CLK0                => clk0,
      CLK90               => open,
      CLK180              => open,
      CLK270              => open,
      CLK_REF_OUT         => open
      );

  process(clk0)
  begin
    if rising_edge(clk0) then
      if but_i = '0' then
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
    end if;
  end process;

  process(clk0)
  begin
    if rising_edge(clk0) then
      baudgen_p <= '0';
      
      if but_i = '0' then
        baudgen_cnt <= t_baudrate'high;
      else
        if baudgen_cnt = 0 then
          baudgen_cnt <= t_baudrate'high;
          baudgen_p <= '1';
        else
          baudgen_cnt <= baudgen_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  process(clk0)
  begin
    if rising_edge(clk0) then
      if but_i = '0' then
        tx_o <= '1';
        char <= (others => '1');
        char_cnt <= 0;
        msg_cnt <= 0;
      else
        if baudgen_p = '1' then
          --  Next bit (LSB first)
          tx_o <= char(0);
          if char_cnt = 9 then
            --  End of the character (Start + 8b + Stop)
            if msg_cnt < msg'length then
              --  Next character of the message
              --  Prepend start bit.
              char <= std_logic_vector(to_unsigned (character'pos(msg(msg_cnt + 1)), 8)) & '0';
              msg_cnt <= msg_cnt + 1;
              char_cnt <= 0;
            else
              --  Stay with 'stop' bit.
              null;
            end if;
          else
            --  Next bit of the character
            char_cnt <= char_cnt + 1;
            --  Shift (and push the stop bit)
            char <= '1' & char(8 downto 1);
          end if;
        end if;
      end if;
    end if;
  end process;
  
  led_o <= counter(25);
end architecture;
