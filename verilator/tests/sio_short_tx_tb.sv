// SPDX-License-Identifier: GPL-2.0-or-later
// Original pin oracle for UM0081 table 28. Encodings are formed from the
// requested payload length, not decoded using any DUT helper/state.
`timescale 1ns/1ps
module sio_short_tx_tb;
    reg clk=0,ce=0,reset=1;
    always #5 clk=~clk;
    integer period=1,edges=0,cases=0;
    always @(negedge clk) begin edges++; ce=(edges%period)==0; end
    reg cpu_cs=0,cpu_rd_n=1,cpu_wr_n=1;
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
    task automatic put(input reg [1:0] port_number,input reg [7:0] data_byte);
        @(negedge clk); #1;
        address=port_number; cpu_din=data_byte; cpu_cs=1; cpu_wr_n=0;
        repeat(5) step();
        @(negedge clk); #1; cpu_cs=0; cpu_wr_n=1; step();
    endtask
    task automatic check(input reg [1:0] port_number,input reg [7:0] expected);
        @(negedge clk); #1;
        address=port_number; cpu_cs=1; cpu_rd_n=0;
        step();
        if(cpu_dout!==expected) $fatal(1,"short TX case=%0d port=%0d got=%h expected=%h",cases,port_number,cpu_dout,expected);
        repeat(3) begin step(); if(cpu_dout!==expected) $fatal(1,"held read changed"); end
        @(negedge clk); #1; cpu_cs=0; cpu_rd_n=1; step();
    endtask
    task automatic rr1(input reg channel,input reg [7:0] expected);
        put({channel,1'b1},1); check({channel,1'b1},expected);
    endtask
    function automatic [7:0] encode(input integer bits,payload);
        case(bits)
            1: return 8'hf0|8'(payload);
            2: return 8'he0|8'(payload);
            3: return 8'hc0|8'(payload);
            4: return 8'h80|8'(payload);
            default: return 8'(payload);
        endcase
    endfunction
    function automatic reg parity_bit(input integer bits,payload,parity_mode);
        reg result;
        result=0;
        for(integer i=0;i<bits;i++) result=result^1'(payload>>i);
        return parity_mode==1 ? result : !result;
    endfunction
    function automatic reg expected_bit(input integer bit_number,bits,payload,parity_mode);
        if(bit_number==0) return 0;
        if(bit_number<=bits) return 1'(payload>>(bit_number-1));
        if(parity_mode!=0 && bit_number==bits+1) return parity_bit(bits,payload,parity_mode);
        return 1;
    endfunction
    task automatic configure(input integer parity_mode,stops,rate);
        reg [7:0] format;
        reset=1; tx_tick=0; repeat(8) step(); reset=0;
        format=(8'(rate)<<6)|(8'(stops)<<2);
        if(parity_mode!=0) format=format|1;
        if(parity_mode==1) format=format|2;
        for(integer channel=0;channel<2;channel++) begin
            put({1'(channel),1'b1},4); put({1'(channel),1'b1},format);
            put({1'(channel),1'b1},5); put({1'(channel),1'b1},8'h8a);
        end
        if(unsupported) $fatal(1,"short TX config rejected");
    endtask
    task automatic frame(input integer bits,a,b,parity_mode,stops,divisor,input reg both);
        integer final_bit,duration;
        reg [1:0] expected;
        final_bit=bits+1+(parity_mode!=0 ? 1 : 0);
        for(integer bit_number=0;bit_number<=final_bit;bit_number++) begin
            duration=bit_number==final_bit ? (stops==1 ? divisor : stops==2 ? divisor+divisor/2 : divisor*2) : divisor;
            expected={both ? expected_bit(bit_number,bits,b,parity_mode) : 1'b1,
                      expected_bit(bit_number,bits,a,parity_mode)};
            for(integer tick=0;tick<duration;tick++) begin
                if(txd!==expected) $fatal(1,"short TX case=%0d bits=%0d bit=%0d tick=%0d pins=%b expected=%b",cases,bits,bit_number,tick,txd,expected);
                if(rts_n!==0) $fatal(1,"short TX RTS released before frame drained");
                if(bit_number==final_bit && tick==duration-1) begin
                    tx_tick=0; rr1(0,0); if(both) rr1(1,0);
                end
                tx_tick=3; step();
            end
        end
        tx_tick=0;
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        for(integer bits=1;bits<=5;bits++)
        for(integer payload=0;payload<(1<<bits);payload++)
        for(integer parity_mode=0;parity_mode<3;parity_mode++)
        for(integer stops=1;stops<=3;stops++)
        for(integer rate=1;rate<=3;rate++) begin
            integer other,next_bits,next_payload,divisor;
            other=((1<<bits)-1)^payload;
            next_bits=bits==5 ? 1 : bits+1;
            next_payload=payload&((1<<next_bits)-1);
            divisor=8<<rate; cases++;
            configure(parity_mode,stops,rate);
            put(0,encode(bits,payload)); put(2,encode(bits,other));
            tx_tick=3; step(); tx_tick=0;
            check(1,4); check(3,4); rr1(0,0); rr1(1,0);
            put(0,encode(next_bits,next_payload)); // Different queued length, same WR5.
            put(1,5); put(1,8'h88); // RTS release must wait for both characters.
            frame(bits,payload,other,parity_mode,stops,divisor,1);
            check(1,0); check(3,4); rr1(0,0); rr1(1,1);
            tx_tick=3; step(); tx_tick=0;
            frame(next_bits,next_payload,0,parity_mode,stops,divisor,0);
            if(rts_n!==1 || txd!==3 || unsupported) $fatal(1,"short TX terminal pins/config/all-sent mismatch");
            rr1(0,1); rr1(1,1);
        end
        if(cases!=1674) $fatal(1,"incomplete short TX matrix");
        begin
            integer rejected,long_cases;
            reg valid;
            reg [1:0] length_code;
            rejected=0; long_cases=0;
            // The table specifies 62 encodings, not behavior for all 256.
            // Reject unspecified encodings diagnostically; do not assert a
            // guessed native waveform for them. Channel reset must recover.
            for(integer data_byte=0;data_byte<256;data_byte++) begin
                valid=0;
                for(integer bits=1;bits<=5;bits++)
                    for(integer payload=0;payload<(1<<bits);payload++)
                        if(8'(data_byte)==encode(bits,payload)) valid=1;
                if(!valid) begin
                    configure(0,1,1); put(0,8'(data_byte));
                    tx_tick=1; step(); tx_tick=0;
                    if(!unsupported) $fatal(1,"unspecified short encoding %h accepted",8'(data_byte));
                    put(1,8'h18);
                    if(unsupported || txd!==3 || rts_n!==1 || dtr_n!==1) $fatal(1,"malformed encoding channel-reset recovery/isolation");
                    rejected++;
                end
            end
            // In 6/7/8-bit mode every byte remains data, even those that are
            // length markers in five-or-less mode. Exact A/B pins prove this.
            for(integer bits=6;bits<=8;bits++)
            for(integer payload=0;payload<256;payload++) begin
                configure(0,1,1);
                length_code=bits==6 ? 2'd2 : bits==7 ? 2'd1 : 2'd3;
                for(integer channel=0;channel<2;channel++) begin
                    put({1'(channel),1'b1},5);
                    put({1'(channel),1'b1},{1'b1,length_code,5'b01010});
                end
                put(0,8'(payload)); put(2,8'(payload)^8'hff);
                tx_tick=3; step(); tx_tick=0;
                frame(bits,payload,payload^255,0,1,16,1);
                if(unsupported || txd!==3 || rts_n!==0) $fatal(1,"long-mode marker treated as short encoding");
                rr1(0,1); rr1(1,1); long_cases++;
            end
            if(rejected!=194 || long_cases!=768) $fatal(1,"encoding/control matrix incomplete");
        end
        $display("PASS: 1674 short TX cases; all 62 table-28 encodings, parity/stops/rates, different queued length, exact pins/RR1/RTS CE=%0d",period);
        $display("PASS: 194 unspecified encodings diagnosed/channel-reset recovery; 768 exact 6/7/8-bit marker controls CE=%0d",period);
        $finish;
    end
    initial begin #500000000; $fatal(1,"short TX watchdog"); end
endmodule
