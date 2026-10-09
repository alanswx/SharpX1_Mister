// SPDX-License-Identifier: GPL-2.0-or-later
// Original pin-driven WR5 transmitter-disable regression. No forced DUT state.
`timescale 1ns/1ps
module sio_tx_disable_tb;
    reg clk=0, ce=0, reset=1;
    always #5 clk=~clk;
    integer period=1, edges=0, cases=0, modem=0;
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
    task automatic gate_transmitter(input reg [7:0] value);
        if(modem!=0) cts_n[0]=!value[3];
        else wr5(value);
    endtask
    function automatic [1:0] length_code(input integer bits);
        case(bits) 5:length_code=0; 6:length_code=2; 7:length_code=1; default:length_code=3; endcase
    endfunction
    function automatic reg parity_bit(input reg [7:0] data_byte,input integer bits,parity_mode);
        reg result;
        result=0;
        for(integer i=0;i<bits;i=i+1) result=result^data_byte[i];
        return parity_mode==1 ? result : !result;
    endfunction
    function automatic reg serial_bit(input reg [7:0] data_byte,input integer bit_number,bits,parity_mode);
        if(bit_number==0) return 0;
        if(bit_number<=bits) return data_byte[bit_number-1];
        if(parity_mode!=0 && bit_number==bits+1) return parity_bit(data_byte,bits,parity_mode);
        return 1;
    endfunction
    task automatic config_channel(input reg channel,input integer bits,parity_mode,stops,rate);
        reg [1:0] ctrl;
        reg [7:0] format;
        ctrl={channel,1'b1};
        format=(8'(rate)<<6)|(8'(stops)<<2);
        if(parity_mode!=0) format=format|1;
        if(parity_mode==1) format=format|2;
        put(ctrl,4); put(ctrl,format);
        if(modem!=0) begin put(ctrl,3); put(ctrl,8'h20); end
        put(ctrl,5); put(ctrl,{1'b1,length_code(bits),5'b01010});
    endtask
    reg [7:0] value;
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        if(!$value$plusargs("MODEM=%d",modem)) modem=0;
        for(integer bits=5;bits<=8;bits=bits+1)
        for(integer parity_mode=0;parity_mode<3;parity_mode=parity_mode+1)
        for(integer stops=1;stops<=3;stops=stops+1)
        for(integer rate=1;rate<=3;rate=rate+1)
        for(integer seam=0;seam<(parity_mode==0 ? 4 : 5);seam=seam+1) begin
            integer divisor,final_bit,duration,disable_bit;
            reg [7:0] enabled_wr5,disabled_wr5;
            divisor=8<<rate;
            final_bit=bits+1+(parity_mode!=0 ? 1 : 0);
            enabled_wr5={1'b1,length_code(bits),5'b01010};
            disabled_wr5=enabled_wr5 & 8'hf7;
            disable_bit=seam==0 ? 0 : seam==2 ? final_bit : seam==4 ? bits+1 : 4;
            cases=cases+1;
            reset=1; tx_tick=0; cts_n=modem!=0 ? 0 : 3; repeat(8) step(); reset=0;
            config_channel(0,bits,parity_mode,stops,rate);
            config_channel(1,bits,parity_mode,stops,rate);
            put(0,8'h69); put(2,8'h96);
            tx_tick=3; step(); tx_tick=0;
            put(0,8'ha5); // Only A has queued data; B is an independent control.
            for(integer bit_number=0;bit_number<=final_bit;bit_number=bit_number+1) begin
                if(bit_number==disable_bit) gate_transmitter(disabled_wr5);
                if(seam==3 && bit_number==(bits>=6 ? 6 : 5)) gate_transmitter(enabled_wr5);
                duration=bit_number==final_bit ? (stops==1 ? divisor : stops==2 ? divisor+divisor/2 : divisor*2) : divisor;
                tx_tick=3;
                for(integer tick=0;tick<duration;tick=tick+1) begin
                    if(txd!=={serial_bit(8'h96,bit_number,bits,parity_mode),serial_bit(8'h69,bit_number,bits,parity_mode)})
                        $fatal(1,"active character truncated case=%0d seam=%0d bit=%0d tick=%0d pins=%b",cases,seam,bit_number,tick,txd);
                    if(bit_number==final_bit && tick==duration-1) begin
                        tx_tick=0;
                        put(1,1); get(1,value); if(value!==0) $fatal(1,"A all sent before final stop tick");
                        put(3,1); get(3,value); if(value!==0) $fatal(1,"B all sent before final stop tick");
                        tx_tick=3;
                    end
                    step();
                end
                tx_tick=0;
            end
            if(unsupported) $fatal(1,"enable-only active WR5 change rejected");
            if(seam==3) gate_transmitter(disabled_wr5); // Pause queued data after mid-frame re-enable.
            get(1,value); if(value!==0) $fatal(1,"queued A holding register lost");
            put(1,1); get(1,value); if(value!==0) $fatal(1,"queued A falsely all sent");
            put(3,1); get(3,value); if(value!==1) $fatal(1,"B all-sent disturbed");
            tx_tick=3;
            repeat(200) begin step(); if(txd!==3) $fatal(1,"disabled A started queued byte"); end
            tx_tick=0;
            gate_transmitter(enabled_wr5);
            tx_tick=3; step(); tx_tick=0;
            tx_tick=3;
            for(integer bit_number=0;bit_number<=final_bit;bit_number=bit_number+1) begin
                duration=bit_number==final_bit ? (stops==1 ? divisor : stops==2 ? divisor+divisor/2 : divisor*2) : divisor;
                for(integer tick=0;tick<duration;tick=tick+1) begin
                    if(txd!=={1'b1,serial_bit(8'ha5,bit_number,bits,parity_mode)}) $fatal(1,"queued frame changed on resume case=%0d",cases);
                    if(bit_number==final_bit && tick==duration-1) begin
                        tx_tick=0;
                        put(1,1); get(1,value); if(value!==0) $fatal(1,"resumed A all sent before final stop tick");
                        tx_tick=3;
                    end
                    step();
                end
            end
            tx_tick=0;
            put(1,1); get(1,value); if(value!==1) $fatal(1,"resumed A not all sent");
            if(unsupported) $fatal(1,"supported resume rejected");
        end
        if(cases!=504) $fatal(1,"incomplete disable format matrix %0d",cases);
        $display("PASS: 504 disable cases across 108 formats, start/data/parity/stop and re-enable seams; queued resume; B isolation CE=%0d MODEM=%0d",period,modem);
        $finish;
    end
    initial begin #100000000; $fatal(1,"watchdog"); end
endmodule
