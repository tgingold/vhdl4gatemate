library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  port (
    clk : in std_logic;
    rst : in std_logic;
    led : out std_logic
    );
end entity;

architecture rtl of blink is
  --  Input clock (CLK0) is 10Mhz.
  --  Use a frequency ~ 1.2Hz
  signal counter : unsigned(22 downto 0);
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
    end if;
  end process;

  led <= counter(counter'left);
end architecture;
