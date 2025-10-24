library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library colognechip;
use colognechip.cc_components.all;

entity vga_generator is
  port (
    clk_ref_i : in std_logic;
    clk_o : out std_logic;
    rst_n_o : out std_logic;
    hsync_o : out std_logic;
    vsync_o : out std_logic;
    in_frame_o : out std_logic;
    end_frame_o : out std_logic;
    x_o : out std_logic_vector(9 downto 0);
    y_o : out std_logic_vector(9 downto 0)
    );
end entity;

architecture rtl of vga_generator is
  --  VGA 800x600 40Mhz

  constant hsync : natural := 128;
  constant hbporch : natural := 88;
  constant hframe : natural := 800;
  constant hfporch : natural := 40;

  constant vsync : natural := 4;
  constant vbporch : natural := 23;
  constant vframe : natural := 600;
  constant vfporch : natural := 1;

  signal clk_pll : std_logic;
  signal clk_video    : std_logic;
  signal pll_locked : std_logic;
  signal rst_n : std_logic;

  signal vcount, hcount, xpos, ypos : unsigned(9 downto 0);
  signal hpre, hvideo, vpre, vvideo : std_logic;
  signal xdir, ydir : std_logic;
begin
  inst_pll : CC_PLL
    generic map (
      REF_CLK         => "10.0",
      OUT_CLK         => "40.0",
      PERF_MD         => "ECONOMY",
      LOW_JITTER      => 1,
      CI_FILTER_CONST => 2,
      CP_FILTER_CONST => 4
      )
    port map (
      CLK_REF             => clk_ref_i,
      USR_CLK_REF         => '0',
      CLK_FEEDBACK        => '0',
      USR_LOCKED_STDY_RST => '0',
      USR_PLL_LOCKED_STDY => open,
      USR_PLL_LOCKED      => pll_locked,
      CLK0                => clk_pll,
      CLK90               => open,
      CLK180              => open,
      CLK270              => open,
      CLK_REF_OUT         => open
      );

  clk_o <= clk_pll;
  clk_video <= clk_pll;

  process(clk_video, pll_locked)
  begin
    if pll_locked = '0' then
      rst_n <= '0';
    elsif rising_edge(clk_video) then
      rst_n <= '1';
    end if;
  end process;

  rst_n_o <= rst_n;

  process(clk_video)
  begin
    if rising_edge(clk_video) then
      in_frame_o <= '0';
      end_frame_o <= '0';

      if rst_n = '0' then
        vcount <= (others => '0');
        hcount <= (others => '0');
        vpre <= '1';
        hpre <= '1';
        hvideo <= '0';
        vvideo <= '0';
        hsync_o <= '0';
        vsync_o <= '0';
      else
        hcount <= hcount + 1;

        if hpre = '1' then
          if hcount = hsync - 1 then
            hsync_o <= '1';
          elsif hcount = hsync + hbporch - 1 then
            hpre <= '0';
            hvideo <= '1';
            hcount <= (others => '0');
          end if;
        elsif hvideo = '1' then
          if hcount = hframe - 1 then
            hvideo <= '0';
            hcount <= (others => '0');
          end if;
        elsif hcount = hfporch - 1 then
          hpre <= '1';
          hcount <= (others => '0');
          hsync_o <= '0';
          vcount <= vcount + 1;

          if vpre = '1' then
            if vcount = vsync - 1 then
              vsync_o <= '1';
            elsif vcount = vsync + vbporch - 1 then
              vpre <= '0';
              vvideo <= '1';
              vcount <= (others => '0');
            end if;
          elsif vvideo = '1' then
            if vcount = vframe - 1 then
              vvideo <= '0';
              vcount <= (others => '0');
              end_frame_o <= '1';
            end if;
          elsif vcount = vfporch - 1 then
            vpre <= '1';
            vcount <= (others => '0');
            vsync_o <= '0';
          end if;
        end if;

        if hvideo = '1' and vvideo = '1' then
          in_frame_o <= '1';
        else
          in_frame_o <= '0';
        end if;

      end if;
    end if;
  end process;

  x_o <= std_logic_vector(hcount);
  y_o <= std_logic_vector(vcount);
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga is
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

architecture rtl of vga is
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
  inst_vga: entity work.vga_generator
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
