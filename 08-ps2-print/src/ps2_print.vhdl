library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library colognechip;
use colognechip.cc_components.all;

entity ps2_print is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    led_o : out std_logic;
    tx_o: out std_logic;
    rx_i: in std_logic;
    ps2_clk_b : in std_logic;
    ps2_data_b : in std_logic
    );
end entity;

architecture rtl of ps2_print is
  signal clk_50m : std_logic;
  signal rst_n   : std_logic;
  signal counter : unsigned(26 downto 0);

  signal rx_byte : std_logic_vector(8 downto 0);
  signal rx_ready, rx_done : std_logic;
  signal rx_cnt : natural range 0 to 9;
  
  signal led_count : natural range 0 to 5_000_000 := 0;

  signal tx_byte, tx_dir : std_logic_vector(7 downto 0);
  signal tx_hex : std_logic_vector(3 downto 0);
  type t_tx_state is (S_IDLE, S_HIGH, S_LOW, S_SPACE);
  signal tx_state : t_tx_state;
  signal tx_stb, tx_stb_int, tx_done : std_logic;

  signal ps2_clk, ps2_clk_d : std_logic;
begin
  inst_pll : entity work.pll
    generic map (freq => 50.0)
    port map (
      clk_ref_i => clk_i,
      clk_o => clk_50m,
      rst_n_o => rst_n);

   inst_uart: entity work.uart
     generic map (
       g_clk_freq => 50_000_000,
       g_baudrate => 115200)
     port map (
       clk_i      => clk_50m,
       rst_n_i    => rst_n,
       tx_o       => tx_o,
       rx_i       => rx_i,
       tx_byte_i  => tx_byte,
       tx_stb_i   => tx_stb,
       tx_done_o  => tx_done,
       rx_byte_o  => open,
       rx_stb_o   => open);


  proc_sync_data: process(clk_50m)
  begin
    if rising_edge(clk_50m) then
      ps2_clk_d <= ps2_clk;
      ps2_clk <= ps2_clk_b;
    end if;
  end process;

  proc_rx: process(clk_50m)
  begin
    if rising_edge(clk_50m) then
      rx_done <= '0';
      
      if rst_n = '0' then
        rx_ready <= '1';
      else
        if ps2_clk_d = '0' and ps2_clk = '1' then
          --  Rising edge on the clock.
          if rx_ready = '1' and ps2_data_b = '0' then
            --  Start
            rx_cnt <= 0;
            rx_ready <= '0';
          elsif rx_ready = '0' then
            if rx_cnt = 9 then
              --  Stop
              rx_done <= '1';
              rx_ready <= '1';
            else
              rx_byte <= ps2_data_b & rx_byte(8 downto 1);
              rx_cnt <= rx_cnt + 1;
            end if;
          end if;
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
      if rx_done = '1' then
        led_count <= 5_000_000;
      end if;
    end if;
  end process;

  process (clk_50m)
  begin
    if rising_edge(clk_50m) then
      tx_stb_int <= '0';
      if rst_n = '0' then
        tx_dir <= x"00";
        tx_state <= S_IDLE;
      else
        case tx_state is
          when S_IDLE =>
            if rx_done = '1' then
              tx_hex <= rx_byte(7 downto 4);
              tx_stb_int <= '1';
              tx_state <= S_HIGH;
            end if;
          when S_HIGH =>
            if tx_done = '1' then
              tx_hex <= rx_byte(3 downto 0);
              tx_stb_int <= '1';
              tx_state <= S_LOW;
            end if;
          when S_LOW =>
            if tx_done = '1' then
              tx_dir <= x"20";
              tx_stb_int <= '1';
              tx_state <= S_SPACE;
            end if;
          when S_SPACE =>
            if tx_done = '1' then
              tx_dir <= x"00";
              tx_state <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  process (clk_50m)
  begin
    if rising_edge(clk_50m) then
      tx_stb <= '0';
      if rst_n = '1' and tx_stb_int = '1' then
        if tx_dir /= x"00" then
          tx_byte <= tx_dir;
        else
          if unsigned(tx_hex) <= 9 then
            tx_byte(7 downto 4) <= x"3";
            tx_byte(3 downto 0) <= tx_hex;
          else
            tx_byte(7 downto 4) <= x"6";
            tx_byte(3 downto 0) <= std_logic_vector(unsigned(tx_hex) - 9);
          end if;
        end if;
        tx_stb <= '1';
      end if;
    end if;
  end process;
end architecture;
