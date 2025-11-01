package vga_pkg is
  constant vga_hframe : natural := 800;
  constant vga_vframe : natural := 600;
  constant vga_clk_freq : natural := 40_000_000;
end vga_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library colognechip;
use colognechip.cc_components.all;

use work.vga_pkg.all;

entity vga2 is
  port (
    clk_ref_i : in std_logic;
    --  Clock and reset output (defined by the video frequency).
    clk_o : out std_logic;
    rst_n_o : out std_logic;
    --  VGA signals
    hsync_o : out std_logic;
    vsync_o : out std_logic;
    x_o : out signed(10 downto 0);
    y_o : out signed(10 downto 0);
    --  Set when x_o and y_o are within the visible frame.
    in_frame_o : out std_logic;
    --  Pulse at the end of the frame.
    end_frame_o : out std_logic
    );
end entity;

architecture rtl of vga2 is
  --  VGA 800x600 40Mhz

  --  Order: hsync, hbporch, frame, hfporch
  constant hsync : natural := 128;
  constant hbporch : natural := 88;
  constant hframe : natural := 800;
  constant hfporch : natural := 40;

  --  Order: vsync, vbporch, frame, vfporch
  constant vsync : natural := 4;
  constant vbporch : natural := 23;
  constant vframe : natural := 600;
  constant vfporch : natural := 1;

  signal clk_pll : std_logic;
  signal clk_video    : std_logic;
  signal pll_locked : std_logic;
  signal rst_n : std_logic;

  signal x, y : signed(10 downto 0);
  constant x0 : signed(10 downto 0) := to_signed(-hsync-hbporch, x'length);
  constant y0 : signed(10 downto 0) := to_signed(-vsync-vbporch, x'length);

  signal vvideo : std_logic;
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
      end_frame_o <= '0';

      if rst_n = '0' then
        x <= x0;
        y <= y0;
        hsync_o <= '0';
        vsync_o <= '0';
        in_frame_o <= '0';
      else
        x <= x + 1;

        if x = -hbporch then
          hsync_o <= '1';
        elsif x = -1 then
          in_frame_o <= vvideo;
        elsif x = vga_hframe - 1 - 1 then
          in_frame_o <= '0';
        elsif x = vga_hframe + hfporch - 1 - 1 then
          hsync_o <= '0';
          x <= x0;

          y <= y + 1;

          if y = -vbporch then
            vsync_o <= '1';
          elsif y = -1 then
            vvideo <= '1';
          elsif y = vframe - 1 - 1 then
            vvideo <= '0';
          elsif y = vga_vframe + vfporch - 1 - 1 then
            vsync_o <= '0';
            y <= y0;
            end_frame_o <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  x_o <= x;
  y_o <= y;
end architecture;
