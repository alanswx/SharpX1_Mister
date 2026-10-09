-- Sharp X1 experimental board integration, GPL-2.0-or-later.
-- Asynchronous active-low assertion, two local rising edges to release.
-- Digital protocol only: placement, pulse width and MTBF need FPGA review.
library ieee;
use ieee.std_logic_1164.all;

entity x1_scaler_reset_release is
    port (clk : in std_logic; async_reset_na : in std_logic;
          reset_na : out std_logic);
end entity;

architecture rtl of x1_scaler_reset_release is
    signal release_pipe : std_logic_vector(1 downto 0) := "00";
    attribute preserve : boolean;
    attribute preserve of release_pipe : signal is true;
begin
    process (clk, async_reset_na)
    begin
        if async_reset_na = '0' then
            release_pipe <= "00";
        elsif rising_edge(clk) then
            release_pipe <= release_pipe(0) & '1';
        end if;
    end process;
    reset_na <= release_pipe(1);
end architecture;
