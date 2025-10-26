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
    ps2_clk_b : inout std_logic;
    ps2_data_b : inout std_logic
    );
end entity;

architecture rtl of ps2_print is
  constant c_clk_freq : natural := 50_000_000;

  signal clk_50m : std_logic;
  signal rst_n   : std_logic;

  signal but_d : std_logic;

  signal ps2_rx_byte : std_logic_vector(8 downto 0);
  signal ps2_rx_ready, ps2_rx_done : std_logic;
  signal ps2_rx_cnt : natural range 0 to 9;
  
  --  Timer for 100us (0.1 ms).
  subtype t_ps2_tx_timer is natural range 0 to (c_clk_freq / 10_000) - 1;
  signal ps2_tx_timer : t_ps2_tx_timer;
  signal ps2_tx_byte, ps2_tx_buf : std_logic_vector(7 downto 0);
  signal ps2_tx_parity : std_logic;
  signal ps2_tx_cnt : natural range 0 to 10;
  signal ps2_tx_req : std_logic;
  signal ps2_tx_rdy : std_logic;
  type t_ps2_tx_state is (S_PS2_TX_IDLE, S_PS2_TX_RTS, S_PS2_TX_DATA, S_PS2_TX_STOP, S_PS2_TX_ACK);
  signal ps2_tx_state : t_ps2_tx_state;

  signal ps2_data_in, ps2_data_out, ps2_data_tri : std_logic;
  signal ps2_clk_in, ps2_clk_tri : std_logic;
  
  signal led_count : natural range 0 to 5_000_000 := 0;

  signal uart_tx_byte, uart_tx_dir : std_logic_vector(7 downto 0);
  signal uart_tx_hex : std_logic_vector(3 downto 0);
  type t_uart_tx_state is (S_IDLE, S_HIGH, S_LOW, S_SPACE);
  signal uart_tx_state : t_uart_tx_state;
  signal uart_tx_stb, uart_tx_stb_int, uart_tx_done : std_logic;

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


  --  Resynchronize ps2_clk to avoid metastability.
  --  TODO: add a constraint to place both FF close.
  proc_sync_data: process(clk_50m)
  begin
    if rising_edge(clk_50m) then
      ps2_clk_d <= ps2_clk;
      ps2_clk <= ps2_clk_in;
    end if;
  end process;

  --  PS2 data receiver.
  proc_rx: process(clk_50m)
  begin
    if rising_edge(clk_50m) then
      ps2_rx_done <= '0';
      
      if rst_n = '0' then
        ps2_rx_ready <= '1';
      else
        if (ps2_clk_d = '0' and ps2_clk = '1') and ps2_tx_state = S_PS2_TX_IDLE then
          --  Rising edge on the clock when not transmitting.
          if ps2_rx_ready = '1' and ps2_data_in = '0' then
            --  Start
            ps2_rx_cnt <= 0;
            ps2_rx_ready <= '0';
          elsif ps2_rx_ready = '0' then
            if ps2_rx_cnt = 9 then
              --  Stop
              ps2_rx_done <= '1';
              ps2_rx_ready <= '1';
            else
              ps2_rx_byte <= ps2_data_in & ps2_rx_byte(8 downto 1);
              ps2_rx_cnt <= ps2_rx_cnt + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  inst_ps2_data_iob: CC_IOBUF
    port map (
      A => ps2_data_out,
      T => ps2_data_tri,
      Y => ps2_data_in,
      IO => ps2_data_b);

  inst_ps2_clk_iob: CC_IOBUF
    port map (
      A => '0',
      T => ps2_clk_tri,
      Y => ps2_clk_in,
      IO => ps2_clk_b);

  proc_tx: process(clk_50m)
  begin
    if rising_edge(clk_50m) then
      if rst_n = '0' then
        ps2_tx_state <= S_PS2_TX_IDLE;
        ps2_tx_rdy <= '1';
        ps2_clk_tri <= '1';
        ps2_data_tri <= '1';
      else
        case ps2_tx_state is
          when S_PS2_TX_IDLE =>
            ps2_tx_rdy <= '1';
            if ps2_tx_req = '1' then
              ps2_tx_state <= S_PS2_TX_RTS;
              ps2_tx_timer <= 0;
              ps2_tx_rdy <= '0';
              ps2_tx_buf <= ps2_tx_byte;
              ps2_tx_parity <= '0';
            end if;
          when S_PS2_TX_RTS =>
            --  Clock down.
            ps2_clk_tri <= '0';
            if ps2_tx_timer = t_ps2_tx_timer'high then
              ps2_tx_state <= S_PS2_TX_DATA;
              --  The start bit: data down
              ps2_data_tri <= '0';
              ps2_data_out <= '0';
              ps2_tx_cnt <= 0;
            else
              ps2_tx_timer <= ps2_tx_timer + 1;
            end if;
          when S_PS2_TX_DATA =>
            --  Release clock.
            ps2_clk_tri <= '1';
            if ps2_clk_d = '1' and ps2_clk = '0' then
              --  Falling edge of clock, send next bit.
              if ps2_tx_cnt = 9 then
                --  Parity bit sent, next is stop.
                ps2_data_out <= '1';
                ps2_tx_state <= S_PS2_TX_STOP;
              elsif ps2_tx_cnt = 8 then
                --  All data bits sent, next is parity.
                ps2_data_out <= not ps2_tx_parity;
              else
                ps2_data_out <= ps2_tx_buf(0);
                ps2_tx_parity <= ps2_tx_parity xor ps2_tx_buf(0);
                ps2_tx_buf <= '0' & ps2_tx_buf(7 downto 1);
              end if;
              ps2_tx_cnt <= ps2_tx_cnt + 1;
            end if;
          when S_PS2_TX_STOP =>
            ps2_data_out <= '1';
            if ps2_clk_d = '1' and ps2_clk = '0' then
              ps2_tx_state <= S_PS2_TX_ACK;
            end if;
          when S_PS2_TX_ACK =>
            ps2_data_tri <= '1';
            if ps2_clk_d = '0' and ps2_clk = '1' then
              ps2_tx_state <= S_PS2_TX_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

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
      if ps2_tx_state = S_PS2_TX_RTS then -- ps2_rx_done = '1' then
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
            elsif false and ps2_clk = '1' and ps2_clk_d = '0' then
              if ps2_data_in = '0' then
                uart_tx_dir <= std_logic_vector(to_unsigned(character'pos('0'), 8));
              else
                uart_tx_dir <= std_logic_vector(to_unsigned(character'pos('1'), 8));
              end if;
              uart_tx_stb_int <= '1';
              uart_tx_state <= S_SPACE;
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
