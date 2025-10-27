library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ps2 is
  generic (
    g_clk_freq : natural);
  port (
    --  System clock (at g_clk_freq).
    clk_i : in std_logic;
    rst_n_i : in std_logic;

    --  Data to send to the device.
    tx_byte_i : in std_logic_vector(7 downto 0);
    tx_req_i : in std_logic;
    tx_rdy_o : out std_logic;

    --  Data received from the device
    rx_byte_o : out std_logic_vector(7 downto 0);
    rx_valid_o : out std_logic;

    --  PS/2 clock pin.  Not driven (ie HZ) when clk_tri_o = '1'.
    clk_in_i : in std_logic;
    clk_tri_o : out std_logic;

    --  PS/2 data pin.  Not driven when data_tri_o = '1'.
    data_in_i : in std_logic;
    data_out_o : out std_logic;
    data_tri_o : out std_logic);
end entity;

architecture rtl of ps2 is
  signal ps2_rx_byte : std_logic_vector(8 downto 0);
  signal ps2_rx_ready : std_logic;
  signal ps2_rx_cnt : natural range 0 to 9;
  
  --  Timer for 100us (0.1 ms).
  subtype t_ps2_tx_timer is natural range 0 to (g_clk_freq / 10_000) - 1;
  signal ps2_tx_timer : t_ps2_tx_timer;
  signal ps2_tx_buf : std_logic_vector(7 downto 0);
  signal ps2_tx_parity : std_logic;
  signal ps2_tx_cnt : natural range 0 to 10;
  type t_ps2_tx_state is (S_PS2_TX_IDLE, S_PS2_TX_RTS, S_PS2_TX_DATA, S_PS2_TX_STOP, S_PS2_TX_ACK);
  signal ps2_tx_state : t_ps2_tx_state;

  signal ps2_clk_sync, ps2_clk, ps2_clk_d : std_logic;
  signal ps2_clk_raise, ps2_clk_fall : boolean;
begin
  --  Resynchronize ps2_clk to avoid metastability.
  --  TODO: add a constraint to place both FF close.
  proc_sync_data: process(clk_i)
  begin
    if rising_edge(clk_i) then
      ps2_clk_d <= ps2_clk;
      ps2_clk <= ps2_clk_sync;
      ps2_clk_sync <= clk_in_i;
    end if;
  end process;

  ps2_clk_raise <= ps2_clk_d = '0' and ps2_clk = '1';
  ps2_clk_fall <= ps2_clk_d = '1' and ps2_clk = '0';

  --  PS2 data receiver.
  proc_rx: process(clk_i)
  begin
    if rising_edge(clk_i) then
      rx_valid_o <= '0';
      
      if rst_n_i = '0' then
        ps2_rx_ready <= '1';
      else
        if ps2_clk_raise and ps2_tx_state = S_PS2_TX_IDLE then
          --  Rising edge on the clock when not transmitting.
          if ps2_rx_ready = '1' and data_in_i = '0' then
            --  Start
            ps2_rx_cnt <= 0;
            ps2_rx_ready <= '0';
          elsif ps2_rx_ready = '0' then
            if ps2_rx_cnt = 9 then
              --  Stop
              rx_valid_o <= '1';
              ps2_rx_ready <= '1';
            else
              ps2_rx_byte <= data_in_i & ps2_rx_byte(8 downto 1);
              --  TODO: parity check
              ps2_rx_cnt <= ps2_rx_cnt + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  rx_byte_o <= ps2_rx_byte(7 downto 0);

  proc_tx: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        ps2_tx_state <= S_PS2_TX_IDLE;
        tx_rdy_o <= '1';
        clk_tri_o <= '1';
        data_tri_o <= '1';
      else
        case ps2_tx_state is
          when S_PS2_TX_IDLE =>
            tx_rdy_o <= '1';
            if tx_req_i = '1' then
              ps2_tx_state <= S_PS2_TX_RTS;
              ps2_tx_timer <= 0;
              tx_rdy_o <= '0';
              ps2_tx_buf <= tx_byte_i;
              ps2_tx_parity <= '0';
            end if;
          when S_PS2_TX_RTS =>
            --  Clock down.
            clk_tri_o <= '0';
            if ps2_tx_timer = t_ps2_tx_timer'high then
              ps2_tx_state <= S_PS2_TX_DATA;
              --  The start bit: data down
              data_tri_o <= '0';
              data_out_o <= '0';
              ps2_tx_cnt <= 0;
            else
              ps2_tx_timer <= ps2_tx_timer + 1;
            end if;
          when S_PS2_TX_DATA =>
            --  Release clock.
            clk_tri_o <= '1';
            if ps2_clk_fall then
              --  Falling edge of clock, send next bit.
              if ps2_tx_cnt = 9 then
                --  Parity bit sent, next is stop.
                data_out_o <= '1';
                ps2_tx_state <= S_PS2_TX_STOP;
              elsif ps2_tx_cnt = 8 then
                --  All data bits sent, next is parity.
                data_out_o <= not ps2_tx_parity;
              else
                data_out_o <= ps2_tx_buf(0);
                ps2_tx_parity <= ps2_tx_parity xor ps2_tx_buf(0);
                ps2_tx_buf <= '0' & ps2_tx_buf(7 downto 1);
              end if;
              ps2_tx_cnt <= ps2_tx_cnt + 1;
            end if;
          when S_PS2_TX_STOP =>
            data_out_o <= '1';
            if ps2_clk_fall then
              ps2_tx_state <= S_PS2_TX_ACK;
            end if;
          when S_PS2_TX_ACK =>
            data_tri_o <= '1';
            if ps2_clk_fall then
              ps2_tx_state <= S_PS2_TX_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
