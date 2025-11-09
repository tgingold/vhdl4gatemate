library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity psram_read is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    led_o : out std_logic;

    --  UART interface
    tx_o: out std_logic;
    rx_i: in std_logic;

    --  psram interface
    psram_cs_n_o : out std_logic;
    psram_clk_o : out std_logic;
    psram_l_mosi_o : out std_logic;
    psram_h_mosi_o : out std_logic;
    psram_l_miso_i : in std_logic;
    psram_h_miso_i : in std_logic
    );
end psram_read;

architecture rtl of psram_read is
  constant c_freq : natural := 20_000_000;
  signal clk : std_logic;
  signal rst_n : std_logic := '1';
  signal psram_cs_n : std_logic;
  signal psram_mosi, psram_miso : std_logic;

  signal but_d : std_logic;
  signal led : std_logic;

  signal shiftreg : std_logic_vector(23 downto 0);
  signal addr : unsigned(23 downto 0);

  type t_bstate is (
    S_RESET, S_START,
    S_CMDL, S_CMDH,
    S_ADDRL, S_ADDRH,
    S_DATAL, S_DATAH,
    S_DONE, S_DONEH,
    S_UARTH, S_UARTL,
    S_UART_SP, S_UART_LF,
    S_WAIT);
  signal bstate : t_bstate := S_START;
  signal blen : natural range 0 to 31;

  signal uart_tx_byte, uart_tx_dir : std_logic_vector(7 downto 0);
  signal uart_tx_hex : std_logic_vector(3 downto 0);
  signal uart_tx_stb, uart_tx_stb_int, uart_tx_done : std_logic;
begin
  inst_pll: entity work.pll
    generic map (
      freq => real(c_freq) / 1_000_000.0
      )
    port map (
      clk_ref_i => clk_i,
      clk_o => clk,
      rst_n_o => rst_n
      );

  uart_1: entity work.uart
    generic map (
      g_clk_freq => c_freq,
      g_baudrate => 115200)
    port map (
      clk_i      => clk,
      rst_n_i    => rst_n,
      tx_o       => tx_o,
      rx_i       => rx_i,
      tx_byte_i  => uart_tx_byte,
      tx_stb_i   => uart_tx_stb,
      tx_done_o  => uart_tx_done,
      rx_byte_o  => open,
      rx_stb_o   => open);

  process(clk)
  begin
    if rising_edge(clk) then
      but_d <= but_i;
    end if;
  end process;

  psram_cs_n_o <= psram_cs_n;

  psram_miso <= psram_l_miso_i;
  psram_l_mosi_o <= psram_mosi;
  psram_h_mosi_o <= psram_mosi;

  process(clk)
  begin
    if rising_edge(clk) then
      uart_tx_stb_int <= '0';
      if rst_n = '0' then
        --  Power-up state, assume it stays long enough.
        --  (The FPGA bitstream needs to be loaded).
        bstate <= S_RESET;
        psram_clk_o <= '0';
        psram_cs_n <= '1';
        uart_tx_dir <= (others => '0');
        addr <= (others => '0');
      else
        case bstate is
          when S_RESET =>
            psram_clk_o <= '0';
            psram_cs_n <= '1';
            bstate <= S_START;
          when S_START =>
            psram_clk_o <= '1';
            psram_cs_n <= '1';
            shiftreg (23 downto 16) <= x"03"; -- Read command.
            blen <= 8;
            bstate <= S_CMDL;
          when S_CMDL =>
            psram_clk_o <= '0';
            psram_cs_n <= '0';
            psram_mosi <= shiftreg(23);
            shiftreg <= shiftreg(22 downto 0) & '0';
            blen <= blen - 1;
            bstate <= S_CMDH;
          when S_CMDH =>
            psram_clk_o <= '1';
            if blen = 0 then
              blen <= 24;
              shiftreg <= std_logic_vector(addr);
              bstate <= S_ADDRL;
            else
              bstate <= S_CMDL;
            end if;
          when S_ADDRL =>
            psram_clk_o <= '0';
            psram_mosi <= shiftreg(23);
            shiftreg <= shiftreg(22 downto 0) & '0';
            blen <= blen - 1;
            bstate <= S_ADDRH;
          when S_ADDRH =>
            psram_clk_o <= '1';
            if blen = 0 then
              blen <= 8;
              bstate <= S_DATAL;
            else
              bstate <= S_ADDRL;
            end if;
          when S_DATAL =>
            psram_clk_o <= '0';
            blen <= blen - 1;
            bstate <= S_DATAH;
          when S_DATAH =>
            psram_clk_o <= '1';
            shiftreg <= shiftreg(22 downto 0) & psram_miso;
            if blen = 0 then
              bstate <= S_DONE;
            else
              bstate <= S_DATAL;
            end if;
          when S_DONE =>
            psram_clk_o <= '0';
            psram_cs_n <= '1';
            uart_tx_hex <= shiftreg(7 downto 4);
            uart_tx_stb_int <= '1';
            bstate <= S_DONEH;
          when S_DONEH =>
            psram_clk_o <= '1';
            bstate <= S_UARTH;
          when S_UARTH =>
            psram_clk_o <= '0';
            if uart_tx_done = '1' then
              uart_tx_hex <= shiftreg(3 downto 0);
              uart_tx_stb_int <= '1';
              bstate <= S_UARTL;
            end if;
          when S_UARTL =>
            if uart_tx_done = '1' then
              if addr(3 downto 0) = x"f" then
                uart_tx_dir <= x"0A";
              elsif addr(3 downto 0) = x"7" then
                uart_tx_dir <= x"2d";
              else
                uart_tx_dir <= x"20";
              end if;
              uart_tx_stb_int <= '1';
              bstate <= S_UART_SP;
            end if;
          when S_UART_SP =>
            uart_tx_stb_int <= '0';
            if uart_tx_done = '1' then
              addr <= addr + 1;
              if addr(3 downto 0) = x"f" then
                uart_tx_dir <= x"0D";
                uart_tx_stb_int <= '1';
                bstate <= S_UART_LF;
              else
                bstate <= S_WAIT;
              end if;
            end if;
          when S_UART_LF =>
            if uart_tx_done = '1' then
              bstate <= S_WAIT;
            end if;
          when S_WAIT =>
            uart_tx_dir <= x"00";
            if but_i = '0' and but_d = '1' then
              bstate <= S_START;
            end if;
        end case;
      end if;
    end if;
  end process;

  led_o <= led; -- '0' when bstate = S_UARTH else '1';


  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        led <= '0';
      elsif but_i = '0' then
        led <= '1';
      end if;
    end if;
  end process;

  --  Binary to hexa converter.
  process (clk)
  begin
    if rising_edge(clk) then
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
end rtl;
