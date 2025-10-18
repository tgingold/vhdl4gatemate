library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
  generic (
    g_clk_freq : natural;
    g_baudrate : natural
    );
  port (
    clk_i : in std_logic;
    rst_n_i : in std_logic;
    tx_o: out std_logic;
    rx_i: in std_logic;
    tx_byte_i : in std_logic_vector(7 downto 0);
    tx_stb_i : in std_logic;
    tx_done_o : out std_logic;
    rx_byte_o : out std_logic_vector(7 downto 0);
    rx_stb_o : out std_logic
    );
end entity;

architecture rtl of uart is
  constant c_baudrate : natural := 8*g_baudrate;

  subtype t_baudrate is natural range 0 to (g_clk_freq + c_baudrate / 2) / c_baudrate;
  signal baudgen_cnt : t_baudrate;
  signal baudgen_p : std_logic;

  signal tx_char, rx_char : std_logic_vector(8 downto 0);
  signal tx_cnt, rx_cnt : unsigned (7 downto 0);
  signal tx_ready, rx_ready : std_logic;
begin
  --  Baudrate*8 generator
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      baudgen_p <= '0';
      
      if rst_n_i = '0' then
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

  proc_tx: process(clk_i)
  begin
    if rising_edge(clk_i) then
      tx_done_o <= '0';
      if rst_n_i = '0' then
        tx_o <= '1';
      else
        if tx_ready = '1' then
          if tx_stb_i = '1' then
            tx_char <= tx_byte_i & '0';
            tx_ready <= '0';
            tx_cnt <= (others => '0');
            --  Stay with 'stop' bit.
            tx_o <= '1';
          end if;
        else
          if baudgen_p = '1' then
            --  Next bit (LSB first)
            tx_o <= tx_char(0);
            tx_cnt <= tx_cnt + 1;
            
            if tx_cnt = 10 * 8 - 1 then
              --  End of the character (Start + 8b + Stop)
              tx_ready <= '1';
              tx_done_o <= '1';
            else
              if tx_cnt(2 downto 0) = "111" then
                --  Shift (and push the stop bit) every 8 periods.
                tx_char <= '1' & tx_char(8 downto 1);
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  proc_rx: process(clk_i)
  begin
    if rising_edge(clk_i) then
      rx_stb_o <= '0';

      if rst_n_i = '0' then
        rx_ready <= '1';
      else
        if baudgen_p = '1' then
          if rx_ready = '1' then
            if rx_i = '0' then
              --  Start
              rx_cnt <= (others => '0');
              rx_ready <= '0';
            end if;
          else
            if rx_cnt(2 downto 0) = "010" then
              rx_char <= rx_i & rx_char(8 downto 1);
            end if;

            if rx_cnt = 10 * 8 - 1 then
              rx_byte_o <= rx_char(7 downto 0);
              rx_stb_o <= '1';
              rx_ready <= '1';
            end if;

            rx_cnt <= rx_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
