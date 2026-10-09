// SPDX-License-Identifier: GPL-2.0-or-later
// Original pin-driven WR5 transmitter-disable regression. No forced DUT state.
`timescale 1ns/1ps
module sio_tx_disable_tb;
    reg clk=0, ce=0, reset=1;
    always #5 clk=~clk;
    integer period=1, edges=0;
    always @(negedge clk) begin edges=edges+1; ce=(edges%period)==0; end
    reg cpu_cs=0, cpu_rd_n=1, cpu_wr_n=1;
    reg [1:0] address=0;
    reg [7:0] cpu_din=0;
    wire [7:0] cpu_dout;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3,cts_n=3,dcd_n=3;
    wire [1:0] txd,rts_n,dtr_n;
    wire unsupported;
    x1_sio_async dut(.*);
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put(input reg [1:0] port_number,input reg [7:0] value);
        @(negedge clk); #1;
        address=port_number; cpu_din=value; cpu_cs=1; cpu_wr_n=0;
        repeat(5) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic get(input reg [1:0] port_number,output reg [7:0] value);
        @(negedge clk); #1;
        address=port_number; cpu_cs=1; cpu_rd_n=0;
        step(); value=cpu_dout;
        repeat(3) begin step(); if(cpu_dout!==value) $fatal(1,"held status changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
    endtask
    task automatic wr5(input reg [7:0] value);
        put(1,5); put(1,value);
    endtask
    task automatic config_channel(input reg channel);
        reg [1:0] ctrl;
        ctrl={channel,1'b1};
        put(ctrl,4); put(ctrl,8'h44);
        put(ctrl,5); put(ctrl,8'hea);
    endtask
    reg [7:0] value;
    reg [9:0] frame_a,frame_b;
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        for(integer seam=0;seam<4;seam=seam+1) begin
            reset=1; tx_tick=0; repeat(8) step(); reset=0;
            config_channel(0); config_channel(1);
            put(0,8'h69); put(2,8'h96);
            tx_tick=3; step(); tx_tick=0;
            put(0,8'ha5); // Only A has queued data; B is an independent control.
            frame_a={1'b1,8'h69,1'b0}; frame_b={1'b1,8'h96,1'b0};
            for(integer bit_number=0;bit_number<10;bit_number=bit_number+1) begin
                if(bit_number==(seam==0 ? 0 : seam==2 ? 9 : 4)) wr5(8'he2);
                if(seam==3 && bit_number==6) wr5(8'hea);
                tx_tick=3;
                repeat(16) begin
                    if(txd!=={frame_b[bit_number],frame_a[bit_number]})
                        $fatal(1,"active character truncated seam=%0d bit=%0d pins=%b",seam,bit_number,txd);
                    step();
                end
                tx_tick=0;
            end
            if(unsupported) $fatal(1,"enable-only active WR5 change rejected");
            if(seam==3) wr5(8'he2); // Pause queued data after mid-frame re-enable.
            get(1,value); if(value!==0) $fatal(1,"queued A holding register lost");
            put(1,1); get(1,value); if(value!==0) $fatal(1,"queued A falsely all sent");
            put(3,1); get(3,value); if(value!==1) $fatal(1,"B all-sent disturbed");
            tx_tick=3;
            repeat(200) begin step(); if(txd!==3) $fatal(1,"disabled A started queued byte"); end
            tx_tick=0;
            wr5(8'hea);
            tx_tick=3; step(); tx_tick=0;
            frame_a={1'b1,8'ha5,1'b0};
            tx_tick=3;
            for(integer bit_number=0;bit_number<10;bit_number=bit_number+1)
                repeat(16) begin
                    if(txd!=={1'b1,frame_a[bit_number]}) $fatal(1,"queued frame changed on resume");
                    step();
                end
            tx_tick=0;
            put(1,1); get(1,value); if(value!==1) $fatal(1,"resumed A not all sent");
            if(unsupported) $fatal(1,"supported resume rejected");
        end
        $display("PASS: WR5 disable drains active start/data/stop seams; queued byte pauses and resumes; B isolation CE=%0d",period);
        $finish;
    end
    initial begin #10000000; $fatal(1,"watchdog"); end
endmodule
