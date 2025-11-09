library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity psram_write is
  port (
    clk_i : in std_logic;
    but_i : in std_logic;
    led_o : out std_logic;

    --  psram interface
    psram_cs_n_o : out std_logic;
    psram_clk_o : out std_logic;
    psram_l_mosi_o : out std_logic;
    psram_h_mosi_o : out std_logic;
    psram_l_miso_i : in std_logic;
    psram_h_miso_i : in std_logic
    );
end psram_write;

architecture rtl of psram_write is
  signal clk : std_logic;
  signal rst_n : std_logic := '1';

  signal psram_cs_n : std_logic;
  signal psram_mosi, psram_miso : std_logic;

  signal but_d : std_logic;

  signal shiftreg : std_logic_vector(23 downto 0);
  signal addr : unsigned(23 downto 0);

  type t_bstate is (
    S_RESET, S_START,
    S_CMDL, S_CMDH,
    S_ADDRL, S_ADDRH,
    S_DATAL, S_DATAH,
    S_DONE);
  signal bstate : t_bstate := S_RESET;
  signal blen : natural range 0 to 31;
begin
  inst_pll: entity work.pll
    generic map (
      freq => 5.0
      )
    port map (
      clk_ref_i => clk_i,
      clk_o => clk,
      rst_n_o => rst_n
      );

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
      if rst_n = '0' then
        --  Power-up state, assume it stays long enough.
        --  (The FPGA bitstream needs to be loaded).
        bstate <= S_RESET;
        psram_clk_o <= '0';
        psram_cs_n <= '1';
        addr <= (others => '0');
      else
        case bstate is
          when S_RESET =>
            --  Initial clock cycle after powerup.
            psram_clk_o <= '0';
            bstate <= S_START;
          when S_START =>
            psram_clk_o <= '1';
            psram_cs_n <= '1';
            --  Prepare for command (8b)
            shiftreg (23 downto 16) <= x"02"; -- Write command.
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
              --  Prepare the address (24b)
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
              --  Prepare the data (8b)
              shiftreg(23 downto 16) <= not std_logic_vector(addr(7 downto 0));
              blen <= 8;
              bstate <= S_DATAL;
            else
              bstate <= S_ADDRL;
            end if;
          when S_DATAL =>
            psram_clk_o <= '0';
            psram_mosi <= shiftreg(23);
            shiftreg <= shiftreg(22 downto 0) & '0';
            blen <= blen - 1;
            bstate <= S_DATAH;
          when S_DATAH =>
            psram_clk_o <= '1';
            if blen = 0 then
              bstate <= S_DONE;
            else
              bstate <= S_DATAL;
            end if;
          when S_DONE =>
            psram_clk_o <= '0';
            psram_cs_n <= '1';
            if addr(7 downto 0) /= x"FF" then
              addr <= addr + 1;
              bstate <= S_START;
            elsif but_i = '0' and but_d = '1' then
              --  Write again.
              addr <= (others => '0');
              bstate <= S_START;
            end if;
        end case;
      end if;
    end if;
  end process;

  led_o <= '0' when bstate = S_DONE else '1';

end rtl;
