-- Actual release entities at three concurrent, independent clock rates.
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity scaler_reset_domains_tb is
    generic (COUPLED_CONTROL : boolean := false);
end entity;
architecture test of scaler_reset_domains_tb is
    type periods is array (0 to 2) of positive;
    constant HALF_PS : periods := (11640, 3366, 10000);
    signal clocks : std_logic_vector(0 to 2) := "000";
    signal running : std_logic_vector(0 to 2) := "101";
    signal raw_na : std_logic := '0';
    signal released : std_logic_vector(0 to 2);
    signal expected : std_logic_vector(0 to 2) := "000";
begin
    domains: for domain in 0 to 2 generate
        process
        begin
            wait for HALF_PS(domain) * 1 ps;
            if running(domain) = '1' then
                clocks(domain) <= not clocks(domain);
            else
                clocks(domain) <= '0';
            end if;
        end process;
        actual: if domain /= 1 or not COUPLED_CONTROL generate
            dut: entity work.x1_scaler_reset_release
                port map (clocks(domain), raw_na, released(domain));
        end generate;
        coupled: if domain = 1 and COUPLED_CONTROL generate
            released(domain) <= released(0);
        end generate;
        process(clocks(domain), raw_na)
            variable edges : natural range 0 to 2 := 0;
        begin
            if raw_na = '0' then
                edges := 0;
                expected(domain) <= '0';
            elsif rising_edge(clocks(domain)) then
                if edges < 2 then edges := edges + 1; end if;
                if edges = 2 then expected(domain) <= '1'; end if;
            end if;
        end process;
        process
        begin
            wait on clocks(domain), raw_na, released(domain);
            wait for 1 ps;
            assert released(domain) = expected(domain)
                report "domain-local release mismatch " & integer'image(domain)
                severity failure;
        end process;
    end generate;
    process
    begin
        wait for 1 ps;
        assert released = "000" report "initial domains assertion" severity failure;
        raw_na <= '1';
        wait for 100 ns;
        assert released = "101" report "stopped HDMI released by other domain" severity failure;
        running(1) <= '1';
        wait for 50 ns;
        assert released = "111" report "HDMI failed independent restart" severity failure;
        for paused in 0 to 2 loop
            running(paused) <= '0';
            wait for 50 ns;
            raw_na <= '0';
            wait for 1 ps;
            assert released = "000" report "assertion with stopped domain" severity failure;
            raw_na <= '1';
            wait for 100 ns;
            for domain in 0 to 2 loop
                if domain = paused then
                    assert released(domain) = '0' report "stopped domain released" severity failure;
                else
                    assert released(domain) = '1' report "running domain failed release" severity failure;
                end if;
            end loop;
            running(paused) <= '1';
            wait for 50 ns;
            assert released = "111" report "independent restart" severity failure;
        end loop;
        report "PASS: three independent scaler reset domains and every stopped-domain restart";
        stop;
        wait;
    end process;
end architecture;
