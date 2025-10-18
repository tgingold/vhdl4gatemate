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
  
  signal clk_video    : std_logic;
  signal pll_locked : std_logic;

  signal vcount, hcount : unsigned(9 downto 0);
  signal hpulse : std_logic;

  constant htotal : natural := 832;
  constant vtotal : natural := 520;
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
        vga_hsync_o <= '1';
        vga_vsync_o <= '1';
      else
        if hcount = 0 then
          vga_hsync_o <= '0';
        elsif hcount = 40 - 1 then
          vga_hsync_o <= '1';
        end if;

        if vcount = 0 then
          vga_vsync_o <= '0';
        elsif vcount = 3 - 1 then
          vga_vsync_o <= '1';
        end if;

        if hcount >= 40 + 128
          and hcount < 40 + 128 + 640
          and vcount >= 3 + 28
          and vcount < 3 + 28 + 480
        then
          vga_red_o <= std_logic_vector(hcount(2 downto 0) & '0');
          vga_green_o <= std_logic_vector(hcount(5 downto 3) & '0');
          vga_blue_o <= std_logic_vector(hcount(8 downto 6) & '0');
        else
          vga_red_o <= x"0";
          vga_green_o <= x"0";  
          vga_blue_o <= x"0";
        end if;

        if hcount = htotal - 1 then
          hcount <= (others => '0');
          if vcount = vtotal - 1 then
            vcount <= (others => '0');
          else
            vcount <= vcount + 1;
          end if;
        else
          hcount <= hcount + 1;
        end if;
      end if;
    end if;
  end process;

  led <= vcount(vcount'left);
end architecture;
