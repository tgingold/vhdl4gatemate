library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_module is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    vga_red_o : out std_logic_vector(3 downto 0);
    vga_green_o : out std_logic_vector(3 downto 0);
    vga_blue_o : out std_logic_vector(3 downto 0);
    vga_hsync_o : out std_logic;
    vga_vsync_o : out std_logic;
    led_o : out std_logic
    );
end entity;

architecture rtl of vga_module is
  constant hframe : natural := 800;
  constant vframe : natural := 600;

  signal clk_video    : std_logic;
  signal pll_locked : std_logic;
  signal rst_n : std_logic;

  signal vga_x, vga_y : unsigned(9 downto 0);
  signal xpos, ypos : unsigned(9 downto 0);
  signal vga_hsync, vga_vsync, in_frame, end_frame : std_logic;
  signal hpre, hvideo, vpre, vvideo : std_logic;
  signal xdir, ydir : std_logic;
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
        xpos <= to_unsigned(hframe / 2 + 4, xpos'length);
        ypos <= to_unsigned(vframe / 2, ypos'length);
        xdir <= '1';
        ydir <= '1';
      else
        if in_frame = '1'
          and vga_x(vga_x'left downto 2) = xpos(xpos'left downto 2)
          and vga_y(vga_y'left downto 2) = ypos(ypos'left downto 2)
        then
          vga_red_o <= (others => '1');
          vga_green_o <= (others => '1');
          vga_blue_o <= (others => '1');
        end if;

        if end_frame = '1' then
          if xdir = '1' then
            if xpos = hframe - 2 or but_i = '0' then
              xdir <= '0';
            else
              xpos <= xpos + 2;
            end if;
          else
            if xpos = 0 or but_i = '0' then
              xdir <= '1';
            else
              xpos <= xpos - 2;
            end if;
          end if;

          if ydir = '1' then
            if ypos = vframe - 2 then
              ydir <= '0';
            else
              ypos <= ypos + 2;
            end if;
          else
            if ypos = 0 then
              ydir <= '1';
            else
              ypos <= ypos - 2;
            end if;
          end if;

        end if;
      end if;
    end if;
  end process;

  led_o <= ydir; -- but_i;
end architecture;
