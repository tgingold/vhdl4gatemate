library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vga_pkg.all;

entity mouse_pixel is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    vga_red_o : out std_logic_vector(3 downto 0);
    vga_green_o : out std_logic_vector(3 downto 0);
    vga_blue_o : out std_logic_vector(3 downto 0);
    vga_hsync_o : out std_logic;
    vga_vsync_o : out std_logic;
    led_o : out std_logic;
    tx_o: out std_logic;
    rx_i: in std_logic;
    ps2_clk_b : inout std_logic;
    ps2_data_b : inout std_logic
    );
end entity;

architecture rtl of mouse_pixel is
  signal clk_video    : std_logic;
  signal rst_n : std_logic;

  signal vga_x, vga_y : unsigned(9 downto 0);
  signal xpos, ypos : unsigned(9 downto 0);
  signal vga_hsync, vga_vsync, in_frame, end_frame : std_logic;
  signal but_d : std_logic;

  signal ps2_rx_byte : std_logic_vector(7 downto 0);
  signal ps2_rx_valid : std_logic;

  --  Timer for 100us (0.1 ms).
  signal ps2_tx_byte : std_logic_vector(7 downto 0);
  signal ps2_tx_req : std_logic;
  signal ps2_tx_rdy : std_logic;

  signal ps2_data_in, ps2_data_out, ps2_data_tri : std_logic;
  signal ps2_clk_in, ps2_clk_tri : std_logic;

  type t_ps2_state is (S_IDLE, S_CMD, S_X, S_Y);
  signal ps2_state : t_ps2_state;
  signal ps2_but_byte : std_logic_vector(7 downto 0);

  signal uart_tx_byte, uart_tx_dir : std_logic_vector(7 downto 0);
  signal uart_tx_hex : std_logic_vector(3 downto 0);
  type t_uart_tx_state is (S_IDLE, S_HIGH, S_LOW, S_SPACE);
  signal uart_tx_state : t_uart_tx_state;
  signal uart_tx_stb, uart_tx_stb_int, uart_tx_done, uart_tx_last : std_logic;
begin
  inst_vga: entity work.vga
    port map (
      clk_ref_i => clk_i,
      clk_o => clk_video,
      rst_n_o => rst_n,
      hsync_o => vga_hsync,
      vsync_o => vga_vsync,
      in_frame_o => in_frame,
      end_frame_o => end_frame,
      unsigned(x_o) => vga_x,
      unsigned(y_o) => vga_y);

  process(clk_video)
  begin
    if rising_edge(clk_video) then
      vga_red_o <= (others => '0');
      vga_green_o <= (others => '0');
      vga_blue_o <= (others => '0');
      vga_hsync_o <= vga_hsync;
      vga_vsync_o <= vga_vsync;

      if rst_n = '0' then
      else
        if in_frame = '1'
          and vga_x = xpos
          and vga_y = ypos
        then
          vga_red_o <= (others => '1');
          vga_green_o <= (others => '1');
          vga_blue_o <= (others => '1');
        end if;
      end if;
    end if;
  end process;

  inst_ps2: entity work.ps2
    generic map (
      g_clk_freq => vga_clk_freq
    )
    port map (
      clk_i => clk_video,
      rst_n_i => rst_n,
      tx_byte_i => ps2_tx_byte,
      tx_req_i => ps2_tx_req,
      tx_rdy_o => ps2_tx_rdy,
      rx_byte_o => ps2_rx_byte,
      rx_valid_o => ps2_rx_valid,
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

  process(clk_video)
    variable diff : unsigned(7 downto 0);
  begin
    if rising_edge(clk_video) then
      if rst_n = '0' then
        ps2_state <= S_IDLE;
        xpos <= to_unsigned(vga_hframe / 2 + 4, xpos'length);
        ypos <= to_unsigned(vga_vframe / 2, ypos'length);
        led_o <= '1';
      else
        case ps2_state is
          when S_IDLE =>
            if ps2_tx_req = '1' then
              ps2_state <= S_CMD;
            elsif ps2_rx_valid = '1' then
              ps2_but_byte <= ps2_rx_byte;
              led_o <= not ps2_rx_byte(0);  -- Left button
              ps2_state <= S_X;
            end if;

          when S_CMD =>
            if ps2_rx_valid = '1' then
              ps2_state <= S_IDLE;
            end if;

          when S_X =>
            if ps2_rx_valid = '1' then
              --  X
              if ps2_but_byte(4) = '1' then
                -- Move left, negative value
                diff := not unsigned(ps2_rx_byte) + 1;
                if diff <= xpos then
                  xpos <= xpos - diff;
                else
                  xpos <= (others => '0');
                end if;
              else
                --  Move right, positive value
                diff := unsigned(ps2_rx_byte);
                if xpos + diff < to_unsigned(vga_hframe - 1, xpos'length) then
                  xpos <= xpos + diff;
                else
                  xpos <= to_unsigned(vga_hframe - 1, xpos'length);
                end if;
              end if;
              ps2_state <= S_Y;
            end if;

          when S_Y =>
            if ps2_rx_valid = '1' then
              if ps2_but_byte(5) = '1' then
                --  Move down, negative value
                diff := not unsigned(ps2_rx_byte) + 1;
                if ypos + diff < to_unsigned(vga_vframe - 1, ypos'length) then
                  ypos <= ypos + diff;
                else
                  ypos <= to_unsigned(vga_vframe - 1, ypos'length);
                end if;
              else
                --  Move up, positive value
                diff := unsigned(ps2_rx_byte);
                if diff < ypos then
                  ypos <= ypos - diff;
                else
                  ypos <= (others => '0');
                end if;
              end if;
              ps2_state <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  --  Button press to send F4 to enable the keyboard/mouse.
  process(clk_video)
  begin
    if rising_edge(clk_video) then
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

  inst_uart: entity work.uart
  generic map (
    g_clk_freq => vga_clk_freq,
    g_baudrate => 115200)
  port map (
    clk_i      => clk_video,
    rst_n_i    => rst_n,
    tx_o       => tx_o,
    rx_i       => rx_i,
    tx_byte_i  => uart_tx_byte,
    tx_stb_i   => uart_tx_stb,
    tx_done_o  => uart_tx_done,
    rx_byte_o  => open,
    rx_stb_o   => open);

  --  Byte to UART.
  process (clk_video)
  begin
    if rising_edge(clk_video) then
      uart_tx_stb_int <= '0';
      if rst_n = '0' then
        uart_tx_dir <= x"00";
        uart_tx_state <= S_IDLE;
      else
        case uart_tx_state is
          when S_IDLE =>
            if ps2_rx_valid = '1' then
              uart_tx_hex <= ps2_rx_byte(7 downto 4);
              uart_tx_stb_int <= '1';
              uart_tx_state <= S_HIGH;
              if ps2_state = S_Y then
                uart_tx_last <= '1';
              else
                uart_tx_last <= '0';
              end if;
            end if;
          when S_HIGH =>
            if uart_tx_done = '1' then
              uart_tx_hex <= ps2_rx_byte(3 downto 0);
              uart_tx_stb_int <= '1';
              uart_tx_state <= S_LOW;
            end if;
          when S_LOW =>
            if uart_tx_done = '1' then
              if uart_tx_last = '1' then
                uart_tx_state <= S_SPACE;
                uart_tx_dir <= x"20";
                uart_tx_stb_int <= '1';
              else
                uart_tx_state <= S_IDLE;
              end if;
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
  process (clk_video)
  begin
    if rising_edge(clk_video) then
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
