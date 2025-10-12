library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cc_components.all;

entity vga is
  port (
    clk_i : in std_logic;
    rst : in std_logic;
    vga_red_o : out std_logic_vector(3 downto 0);
    vga_green_o : out std_logic_vector(3 downto 0);
    vga_blue_o : out std_logic_vector(3 downto 0);
    vga_hsync_o : out std_logic;
    vga_vsync_o : out std_logic;
    led : out std_logic
    );
end entity;

architecture rtl of vga is
  --  VGA 640x480 72Hz 31.5MHz
  --  H: Sync + Back-Porch + Frame + Front-Porch
  --      40  +  128       + 640   + 24            = 832
  --  V: Sync + Back-Proch + Frame + Front-Porch
  --     3   +  28         + 480   + 9             = 520
  --

  constant hsync : natural := 40;
  constant hbporch : natural := 128;
  constant hframe : natural := 640;
  constant hfporch : natural := 24;

  constant vsync : natural := 3;
  constant vbporch : natural := 28;
  constant vframe : natural := 480;
  constant vfporch : natural := 9;

  signal clk_video    : std_logic;
  signal pll_locked : std_logic;

  signal vcount, hcount : unsigned(9 downto 0);
  signal hpre, hvideo, vpre, vvideo : std_logic;
begin
  inst_pll : CC_PLL
    generic map (
      REF_CLK         => "10.0",
      OUT_CLK         => "31.5",
      PERF_MD         => "ECONOMY",
      LOW_JITTER      => 1,
      CI_FILTER_CONST => 2,
      CP_FILTER_CONST => 4
      )
    port map (
      CLK_REF             => clk_i,
      USR_CLK_REF         => '0',
      CLK_FEEDBACK        => '0',
      USR_LOCKED_STDY_RST => '0',
      USR_PLL_LOCKED_STDY => open,
      USR_PLL_LOCKED      => pll_locked,
      CLK0                => clk_video,
      CLK90               => open,
      CLK180              => open,
      CLK270              => open,
      CLK_REF_OUT         => open
      );

  process(clk_video)
  begin
    if rising_edge(clk_video) then
      if rst = '0' or pll_locked = '0' then
        vcount <= (others => '0');
        hcount <= (others => '0');
        vpre <= '1';
        hpre <= '1';
        hvideo <= '0';
        vvideo <= '0';
        vga_hsync_o <= '1';
        vga_vsync_o <= '1';
      else
        hcount <= hcount + 1;

        if hpre = '1' then
          if hcount = 0 then
            vga_hsync_o <= '0';
          elsif hcount = hsync - 1 then
            vga_hsync_o <= '1';
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

          vcount <= vcount + 1;

          if vpre = '1' then
            if vcount = 0 then
              vga_vsync_o <= '0';
            elsif vcount = vsync - 1 then
              vga_vsync_o <= '1';
            elsif vcount = vsync + vbporch - 1 then
              vpre <= '0';
              vvideo <= '1';
              vcount <= (others => '0');
            end if;
          elsif vvideo = '1' then
            if vcount = vframe - 1 then
              vvideo <= '0';
              vcount <= (others => '0');
            end if;
          elsif vcount = vfporch - 1 then
            vpre <= '1';
            vcount <= (others => '0');
          end if;
        end if;

        if hvideo = '1' and vvideo = '1' then
          vga_red_o <= std_logic_vector(hcount(2 downto 0) & '0');
          vga_green_o <= std_logic_vector(hcount(5 downto 3) & '0');
          vga_blue_o <= std_logic_vector(hcount(8 downto 6) & '0');
        else
          vga_red_o <= (others => '0');
          vga_green_o <= (others => '0');
          vga_blue_o <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  led <= pll_locked;
end architecture;
