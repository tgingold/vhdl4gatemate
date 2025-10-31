library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ps2_print is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    led_o : out std_logic;
    tx_o: out std_logic;
    rx_i: in std_logic;
    ps2_clk_b : inout std_logic;
    ps2_data_b : inout std_logic
    );
end entity;

architecture rtl of ps2_print is
  constant c_clk_freq : natural := 50_000_000;

  signal clk_50m : std_logic;
  signal rst_n   : std_logic;

  signal but_d : std_logic;

  signal ps2_rx_byte : std_logic_vector(7 downto 0);
  signal ps2_rx_done : std_logic;

  --  Timer for 100us (0.1 ms).
  signal ps2_tx_byte : std_logic_vector(7 downto 0);
  signal ps2_tx_req : std_logic;
  signal ps2_tx_rdy : std_logic;

  signal ps2_data_in, ps2_data_out, ps2_data_tri : std_logic;
  signal ps2_clk_in, ps2_clk_tri : std_logic;

  signal led_count : natural range 0 to 5_000_000 := 0;

  signal uart_tx_byte, uart_tx_dir : std_logic_vector(7 downto 0);
  signal uart_tx_hex : std_logic_vector(3 downto 0);
  type t_uart_tx_state is (S_IDLE, S_HIGH, S_LOW, S_SPACE);
  signal uart_tx_state : t_uart_tx_state;
  signal uart_tx_stb, uart_tx_stb_int, uart_tx_done : std_logic;
begin
  inst_pll : entity work.pll
    generic map (freq => 50.0)
    port map (
      clk_ref_i => clk_i,
      clk_o => clk_50m,
      rst_n_o => rst_n);

   inst_uart: entity work.uart
     generic map (
       g_clk_freq => c_clk_freq,
       g_baudrate => 115200)
     port map (
       clk_i      => clk_50m,
       rst_n_i    => rst_n,
       tx_o       => tx_o,
       rx_i       => rx_i,
       tx_byte_i  => uart_tx_byte,
       tx_stb_i   => uart_tx_stb,
       tx_done_o  => uart_tx_done,
       rx_byte_o  => open,
       rx_stb_o   => open);


  inst_ps2: entity work.ps2
    generic map (
      g_clk_freq => c_clk_freq
    )
    port map (
      clk_i => clk_50m,
      rst_n_i => rst_n,
      tx_byte_i => ps2_tx_byte,
      tx_req_i => ps2_tx_req,
      tx_rdy_o => ps2_tx_rdy,
      rx_byte_o => ps2_rx_byte,
      rx_valid_o => ps2_rx_done,
      clk_in_i => ps2_clk_in,
      clk_tri_o => ps2_clk_tri,
      data_in_i => ps2_data_in,
      data_out_o => ps2_data_out,
      data_tri_o => ps2_data_tri
    );

  --  Handle tri-state.
  ps2_data_in <= ps2_data_b;
  ps2_data_b <= ps2_data_out when ps2_data_tri = '0' else 'Z';

  ps2_clk_in <= ps2_clk_b;
  ps2_clk_b <= '0' when ps2_clk_tri = '0' else 'Z';

  --  Button press to send F4 to enable the keyboard/mouse.
  process(clk_50m)
  begin
    if rising_edge(clk_50m) then
      ps2_tx_req <= '0';
      if rst_n = '0' then
        ps2_tx_byte <= (others => '0');
        but_d <= '1';
      else
        but_d <= but_i;
        if but_i = '0' and but_d = '1' then
          ps2_tx_byte <= x"F4";  -- tx enable
          ps2_tx_req <= '1';
        end if;
      end if;
    end if;
  end process;

  --  LED control.
  led_o <= '1' when led_count = 0 else '0';

  process (clk_50m)
  begin
    if rising_edge(clk_50m) then
      if led_count /= 0 then
        led_count <= led_count - 1;
      end if;
      if ps2_rx_done = '1' then
        led_count <= 5_000_000;
      end if;
    end if;
  end process;

  --  Byte to UART.
  process (clk_50m)
  begin
    if rising_edge(clk_50m) then
      uart_tx_stb_int <= '0';
      if rst_n = '0' then
        uart_tx_dir <= x"00";
        uart_tx_state <= S_IDLE;
      else
        case uart_tx_state is
          when S_IDLE =>
            if ps2_rx_done = '1' then
              uart_tx_hex <= ps2_rx_byte(7 downto 4);
              uart_tx_stb_int <= '1';
              uart_tx_state <= S_HIGH;
            end if;
          when S_HIGH =>
            if uart_tx_done = '1' then
              uart_tx_hex <= ps2_rx_byte(3 downto 0);
              uart_tx_stb_int <= '1';
              uart_tx_state <= S_LOW;
            end if;
          when S_LOW =>
            if uart_tx_done = '1' then
              uart_tx_dir <= x"20";
              uart_tx_stb_int <= '1';
              uart_tx_state <= S_SPACE;
            end if;
          when S_SPACE =>
            if uart_tx_done = '1' then
              uart_tx_dir <= x"00";
              uart_tx_state <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  --  Binary to hexa converter.
  process (clk_50m)
  begin
    if rising_edge(clk_50m) then
      uart_tx_stb <= '0';
      if rst_n = '1' and uart_tx_stb_int = '1' then
        if uart_tx_dir /= x"00" then
          uart_tx_byte <= uart_tx_dir;
        else
          if unsigned(uart_tx_hex) <= 9 then
            uart_tx_byte(7 downto 4) <= x"3";
            uart_tx_byte(3 downto 0) <= uart_tx_hex;
          else
            uart_tx_byte(7 downto 4) <= x"6";
            uart_tx_byte(3 downto 0) <= std_logic_vector(unsigned(uart_tx_hex) - 9);
          end if;
        end if;
        uart_tx_stb <= '1';
      end if;
    end if;
  end process;
end architecture;
