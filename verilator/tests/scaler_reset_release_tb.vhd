-- Actual board release entity; negative control reproduces inherited one edge.
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity scaler_reset_release_tb is
    generic (HALF_PS : positive := 11640; EARLY_CONTROL : boolean := false);
end entity;
architecture test of scaler_reset_release_tb is
    signal clk : std_logic := '0';
    signal running : boolean := true;
    signal raw_na : std_logic := '0';
    signal local_na : std_logic;
begin
    process
    begin
        wait for HALF_PS * 1 ps;
        if running then clk <= not clk; else clk <= '0'; end if;
    end process;
    actual: if not EARLY_CONTROL generate
        dut: entity work.x1_scaler_reset_release port map (clk, raw_na, local_na);
    end generate;
    early: if EARLY_CONTROL generate
        local_na <= '0' when raw_na = '0' else '1' when rising_edge(clk);
    end generate;
    process
        procedure verify_release is
        begin
            wait until rising_edge(clk);
            wait for 1 ps;
            assert local_na = '0' report "release before second local edge" severity failure;
            wait until rising_edge(clk);
            wait for 1 ps;
            assert local_na = '1' report "failed second-edge release" severity failure;
        end procedure;
    begin
        wait for 1 ps;
        assert local_na = '0' report "initial assertion" severity failure;
        -- Deassert one ps before an edge, never exactly on the edge.
        wait for (HALF_PS - 2) * 1 ps;
        raw_na <= '1';
        verify_release;
        -- Short pulses at several distinct phases; assertion has no CE gate.
        for phase in 1 to 4 loop
            wait for phase * 7 ps;
            raw_na <= '0';
            wait for 1 ps;
            assert local_na = '0' report "asynchronous assertion" severity failure;
            raw_na <= '1';
            verify_release;
            -- Reassert between the first and second release edges.
            raw_na <= '0';
            wait for 2 ps;
            raw_na <= '1';
            wait until rising_edge(clk);
            wait for 1 ps;
            raw_na <= '0';
            wait for 1 ps;
            assert local_na = '0' report "reassertion" severity failure;
            raw_na <= '1';
            verify_release;
        end loop;
        running <= false;
        wait for HALF_PS * 3 ps;
        raw_na <= '0';
        wait for 1 ps;
        assert local_na = '0' report "stopped-clock assertion" severity failure;
        raw_na <= '1';
        wait for HALF_PS * 6 ps;
        assert local_na = '0' report "stopped-clock release" severity failure;
        running <= true;
        verify_release;
        report "PASS: scaler two-edge release, short pulse, reassertion, near edge and stopped clock";
        stop;
        wait;
    end process;
end architecture;
