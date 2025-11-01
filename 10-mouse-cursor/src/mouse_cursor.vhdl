library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vga_pkg.all;

entity mouse_cursor is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    vga_red_o : out std_logic_vector(3 downto 0);
    vga_green_o : out std_logic_vector(3 downto 0);
    vga_blue_o : out std_logic_vector(3 downto 0);
    vga_hsync_o : out std_logic;
    vga_vsync_o : out std_logic;
    led_o : out std_logic;
    ps2_clk_b : inout std_logic;
    ps2_data_b : inout std_logic
    );
end entity;

architecture rtl of mouse_cursor is
  function to_bin (s : string) return std_logic_vector is
    alias as : string(s'length downto 1) is s;
    variable res : std_logic_vector(s'length - 1 downto 0);
  begin
    for i in as'range loop
      if as(i) = ' ' then
        res(i - 1) := '0';
      else
        res(i - 1) := '1';
      end if;
    end loop;
    return res;
  end to_bin;

  constant cur_xlen : natural := 8;
  constant cur_ylen : natural := 8;

  type t_cursor is array(0 to cur_ylen - 1) of std_logic_vector(cur_xlen - 1 downto 0);
  constant c_cursor : t_cursor := (
    to_bin("   **   "),
    to_bin(" **  ** "),
    to_bin(" *    * "),
    to_bin("*      *"),
    to_bin("*      *"),
    to_bin(" *    * "),
    to_bin(" **  ** "),
    to_bin("   **   ")
  );

  --  Cursor active point.
  constant cur_xoff : natural := 4;
  constant cur_yoff : natural := 4;

  signal clk_video : std_logic;
  signal rst_n : std_logic;

  signal vga_x, vga_y : signed(10 downto 0);
  signal xpos, ypos : unsigned(9 downto 0);
  signal vga_hsync, vga_vsync, in_frame, end_frame : std_logic;
  signal cur_xcnt, cur_ycnt : unsigned(3 downto 0);
  signal cur_line : std_logic_vector(cur_xlen - 1 downto 0);
  signal but_d : std_logic;

  signal ps2_rx_byte : std_logic_vector(7 downto 0);
  signal ps2_rx_valid : std_logic;

  --  Timer for 100us (0.1 ms).
  signal ps2_tx_byte : std_logic_vector(7 downto 0);
  signal ps2_tx_req : std_logic;
  signal ps2_tx_rdy : std_logic;

  signal ps2_data_in, ps2_data_out, ps2_data_tri : std_logic;
  signal ps2_clk_in, ps2_clk_tri : std_logic;

  type t_ps2_state is (S_INIT, S_CMD, S_IDLE, S_X, S_Y);
  signal ps2_state : t_ps2_state;
  signal ps2_but_byte : std_logic_vector(7 downto 0);
begin
  inst_vga: entity work.vga2
    port map (
      clk_ref_i => clk_i,
      clk_o => clk_video,
      rst_n_o => rst_n,
      hsync_o => vga_hsync,
      vsync_o => vga_vsync,
      in_frame_o => in_frame,
      end_frame_o => end_frame,
      x_o => vga_x,
      y_o => vga_y);

  process(clk_video)
    variable pix : std_logic;
  begin
    if rising_edge(clk_video) then
      vga_red_o <= (others => '0');
      vga_green_o <= (others => '0');
      vga_blue_o <= (others => '0');
      vga_hsync_o <= vga_hsync;
      vga_vsync_o <= vga_vsync;

      if rst_n = '0' then
      else
        if vga_x = signed('0' & xpos) - to_signed(cur_xoff, vga_x'length) then
          if vga_y = signed('0' & ypos) - to_signed(cur_yoff, vga_y'length) then
            --  Start of the cursor
            cur_ycnt <= to_unsigned(1, cur_ycnt'length);
            cur_line <= c_cursor(0);
            cur_xcnt <= (others => '0');
          elsif cur_ycnt (3) = '0' then
            --  Next line
            cur_line <= c_cursor(to_integer(cur_ycnt));
            cur_ycnt <= cur_ycnt + 1;
            cur_xcnt <= (others => '0');
          end if;
        end if;

        if cur_xcnt(3) = '0' then
          --  Still in the cursor, draw it.
          pix := cur_line(7);
          cur_line <= cur_line(6 downto 0) & '0';
          cur_xcnt <= cur_xcnt + 1;
        else
          --  After the cursor.
          pix := '0';
        end if;

        if pix = '1' then
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
      ps2_tx_req <= '0';
      but_d <= but_i;

      if rst_n = '0' or (but_i = '0' and but_d = '1') then
        ps2_state <= S_INIT;
        xpos <= to_unsigned(vga_hframe / 2 + 4, xpos'length);
        ypos <= to_unsigned(vga_vframe / 2, ypos'length);
        led_o <= '1';
      else
        case ps2_state is
          when S_INIT =>
            --  Send the tx_enable command
            ps2_tx_byte <= x"F4";
            ps2_tx_req <= '1';
            ps2_state <= S_CMD;

          when S_CMD =>
            --  Wait for mouse reply to the tx_enable command.
            if ps2_rx_valid = '1' then
              ps2_state <= S_IDLE;
            end if;

          when S_IDLE =>
            if ps2_rx_valid = '1' then
              ps2_but_byte <= ps2_rx_byte;
              led_o <= not ps2_rx_byte(0);  -- Left button
              ps2_state <= S_X;
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

end architecture;
