// SPDX-License-Identifier: GPL-2.0-only
// Original asset-free read-only bus decode fixture.
`timescale 1ns/1ps
module turbo_dsw_tb;
    logic io_read, dam;
    logic [15:0] address;
    logic [7:0] switches;
    wire selected, base_selected;
    wire [7:0] data, base_data;
    integer checks=0;
    x1_turbo_dsw #(.ENABLED(1)) dut(.*);
    x1_turbo_dsw #(.ENABLED(0)) base (
        .io_read(io_read), .dam(dam), .address(address), .switches(switches),
        .selected(base_selected), .data(base_data)
    );
    initial begin
        switches=8'hf1;
        for(integer controls=0;controls<4;controls++)
            for(integer port=0;port<65536;port++) begin
                bit expected;
                io_read=1'(controls%2); dam=1'(controls/2);
                address=16'(port); #1;
                expected=controls==1 && port>=8176 && port<8192;
                assert(selected==expected && data==(expected ? 8'hf1 : 8'hff))
                    else $fatal(1,"DIP decode at %04x controls=%0d",address,controls);
                assert(!base_selected && base_data==8'hff)
                    else $fatal(1,"DIP leaked into base X1");
                checks++;
            end
        io_read=1; dam=0;
        for(integer raw=0;raw<256;raw++)
            for(integer mirror=0;mirror<16;mirror++) begin
                switches=8'(raw);address=16'(8176+mirror);#1;
                assert(selected && data==8'(raw) && !base_selected && base_data==8'hff)
                    else $fatal(1,"raw DIP pins or mirror changed");
                checks++;
            end
        assert(checks==266240) else $fatal(1,"incomplete DIP matrix");
        $display("PASS Turbo DIP: 266240 bus/pin cases, all addresses, all raw bytes/mirrors, DAM/read gating and base isolation");
        $finish;
    end
endmodule
