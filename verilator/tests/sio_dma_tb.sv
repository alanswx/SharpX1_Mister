// SPDX-License-Identifier: GPL-2.0-or-later
// Original standalone SIO/DMA integration fixture. Synthetic retained grant,
// no CPU, firmware, machine wiring or physical W/RDY timing claim.
`timescale 1ns/1ps
module sio_dma_tb;
    reg clk=0,ce=0,reset=1,pause_ce=0;
    always #5 clk=~clk;
    integer period=1,edges=0,grants=0,reads=0,writes=0,io_reads=0,io_writes=0;
    reg busak_n=1;
    wire busrq_n,mreq_n,iorq_n,rd_n,wr_n;
    wire [15:0] address;
    wire [7:0] data_out,data_in,dma_cpu_out;
    reg dma_cs=0,dma_rd_n=1,dma_wr_n=1;
    reg [7:0] host_data=0;
    wire dma_bad,sio_bad;
    reg selected_channel=0;
    reg host_sio_cs=0,host_sio_rd_n=1,host_sio_wr_n=1;
    reg [1:0] host_address=0;
    wire dma_io=!iorq_n && (!rd_n || !wr_n);
    wire sio_cs=dma_io || host_sio_cs;
    wire sio_rd_n=dma_io ? rd_n : host_sio_rd_n;
    wire sio_wr_n=dma_io ? wr_n : host_sio_wr_n;
    wire [1:0] sio_address=dma_io ? address[1:0] : host_address;
    wire [7:0] sio_din=dma_io ? data_out : host_data;
    wire [7:0] sio_dout;
    wire [1:0] ready_n,flow_wait_n,txd,rts_n,dtr_n;
    reg [1:0] rx_tick=0,tx_tick=0,rxd=3;
    wire irq,ieo;
    wire [7:0] ack_vector;
    reg [7:0] memory[0:65535];
    assign data_in=dma_io ? sio_dout : memory[address];
    x1_dma dma(.clk(clk),.ce(ce),.reset(reset),.cpu_cs(dma_cs),
        .cpu_rd_n(dma_rd_n),.cpu_wr_n(dma_wr_n),.cpu_data_in(host_data),
        .cpu_data_out(dma_cpu_out),.busrq_n(busrq_n),.busak_n(busak_n),
        .mreq_n(mreq_n),.iorq_n(iorq_n),.rd_n(rd_n),.wr_n(wr_n),
        .address(address),.data_out(data_out),.data_in(data_in),
        .wait_n(1'b1),.rdy(ready_n[selected_channel]),.unsupported(dma_bad));
    x1_sio_interrupt #(.FLOW_ENABLE(1)) sio(.clk(clk),.ce(ce),.reset(reset),
        .cpu_cs(sio_cs),.cpu_rd_n(sio_rd_n),.cpu_wr_n(sio_wr_n),
        .address(sio_address),.cpu_din(sio_din),.cpu_dout(sio_dout),
        .rx_tick(rx_tick),.tx_tick(tx_tick),.rxd(rxd),.cts_n(2'b11),.dcd_n(2'b11),
        .txd(txd),.rts_n(rts_n),.dtr_n(dtr_n),.unsupported(sio_bad),
        .iei(1'b1),.acknowledge(1'b0),.reti(1'b0),.irq(irq),.ieo(ieo),
        .ack_vector(ack_vector),.wait_n(flow_wait_n),.ready_n(ready_n));
    reg old_rd_n=1,old_wr_n=1,old_io=0;
    reg [15:0] old_address=0;
    reg [7:0] old_data=0;
    // Grant only at idle bus, retain until request releases. Side effects at
    // completed strobes, rather than once per stretched SYS/CE edge.
    always @(negedge clk) begin
        edges=edges+1; ce=!pause_ce && edges%period==0;
        if(!rd_n || !wr_n) begin
            if(busak_n || busrq_n || mreq_n==iorq_n || (!rd_n && !wr_n))
                $fatal(1,"invalid owned bus");
            if(host_sio_cs || dma_cs) $fatal(1,"host access during DMA ownership");
            if(dma_io && address!==(selected_channel ? 16'h1f92 : 16'h1f90))
                $fatal(1,"wrong SIO port %h",address);
            if((!old_rd_n && !rd_n) || (!old_wr_n && !wr_n))
                if(address!==old_address || data_out!==old_data || dma_io!==old_io)
                    $fatal(1,"held DMA bus changed");
        end
        if(!old_rd_n && rd_n) begin reads=reads+1; if(old_io) io_reads=io_reads+1; end
        if(!old_wr_n && wr_n) begin
            writes=writes+1;
            if(old_io) io_writes=io_writes+1; else memory[old_address]=old_data;
        end
        old_rd_n=rd_n; old_wr_n=wr_n; old_io=dma_io;
        old_address=address; old_data=data_out;
        if(busrq_n) busak_n=1;
        else if(busak_n) begin busak_n=0; grants=grants+1; end
    end
    task automatic step;
        do begin @(posedge clk); #1; end while(!ce);
    endtask
    task automatic put_dma(input reg [7:0] value);
        @(negedge clk); #1; host_data=value; dma_cs=1; dma_wr_n=0;
        repeat(4) step();
        @(negedge clk); #1; dma_cs=0; dma_wr_n=1; step();
    endtask
    task automatic put_sio(input reg [1:0] port,input reg [7:0] value);
        if(!busak_n || !busrq_n) $fatal(1,"host SIO access without ownership");
        @(negedge clk); #1; host_address=port; host_data=value; host_sio_cs=1; host_sio_wr_n=0;
        repeat(4) step();
        @(negedge clk); #1; host_sio_cs=0; host_sio_wr_n=1; step();
    endtask
    task automatic wr_sio(input reg [7:0] index,value);
        put_sio({selected_channel,1'b1},index); put_sio({selected_channel,1'b1},value);
    endtask
    task automatic check_sio(input reg control,input reg [7:0] value);
        if(!busak_n || !busrq_n) $fatal(1,"host SIO read without ownership");
        @(negedge clk); #1; host_address={selected_channel,control}; host_sio_cs=1; host_sio_rd_n=0;
        repeat(4) begin step();
            if(sio_dout!==value || !flow_wait_n[selected_channel])
                $fatal(1,"locked character/status inspection %h != %h",sio_dout,value);
        end
        @(negedge clk); #1; host_sio_cs=0; host_sio_rd_n=1; step();
    endtask
    task automatic fresh(input reg channel);
        @(negedge clk); #1; reset=1; pause_ce=0; rx_tick=0; tx_tick=0; rxd=3;
        repeat(8) step(); reset=0; repeat(4) step();
        selected_channel=channel; reads=0; writes=0; io_reads=0; io_writes=0; grants=0;
        for(integer i=0;i<65536;i=i+1) memory[i]=8'hcc;
        wr_sio(4,8'h44); wr_sio(3,8'hc1); wr_sio(5,8'hea);
    endtask
    task automatic configure(input reg receive_mode,input reg [7:0] mode,input reg [15:0] count);
        // A=fixed I/O, B=incrementing memory. Reverse source/load first when
        // A is destination, per documented fixed-destination workaround.
        put_dma(8'h7d); put_dma(selected_channel ? 8'h92 : 8'h90); put_dma(8'h1f);
        put_dma(count[7:0]); put_dma(count[15:8]);
        put_dma(8'h2c); put_dma(8'h10); put_dma(8'h80);
        put_dma(8'h8d|mode); put_dma(0); put_dma(8'h50); put_dma(8'h82);
        put_dma(8'hcf);
        if(!receive_mode) begin put_dma(8'h01); put_dma(8'hcf); end
        if(dma_bad) $fatal(1,"DMA configuration rejected");
        put_dma(8'h87);
    endtask
    task automatic receive_byte(input reg [7:0] value,input reg bad_stop);
        rx_tick=selected_channel ? 2 : 1; rxd[selected_channel]=0; repeat(16) step();
        for(integer i=0;i<8;i=i+1) begin rxd[selected_channel]=value[i]; repeat(16) step(); end
        rxd[selected_channel]=!bad_stop; repeat(16) step();
        rxd[selected_channel]=1; repeat(32) step(); rx_tick=0;
    endtask
    task automatic transmit_byte(input reg [7:0] value);
        reg [9:0] frame;
        frame={1'b1,value,1'b0};
        tx_tick=selected_channel ? 2 : 1; step(); tx_tick=0;
        if(txd[selected_channel]!==0) $fatal(1,"TX did not start");
        tx_tick=selected_channel ? 2 : 1;
        for(integer i=0;i<10;i=i+1) repeat(16) begin
            if(txd[selected_channel]!==frame[i]) $fatal(1,"TX %h bit %0d wrong",value,i);
            step();
        end
        tx_tick=0;
    endtask
    task automatic idle;
        wait(busrq_n && busak_n); repeat(4) step();
    endtask
    task automatic freeze_read;
        reg [15:0] held_address;
        integer held_reads,held_writes;
        wait(dma_io && !rd_n);
        @(negedge clk); #1; pause_ce=1; ce=0;
        held_address=address; held_reads=reads; held_writes=writes;
        repeat(80) begin @(posedge clk); #1;
            if(ce || rd_n || !dma_io || busak_n || busrq_n || address!==held_address ||
               reads!=held_reads || writes!=held_writes)
                $fatal(1,"stopped-enable owned SIO read changed/completed");
        end
        @(negedge clk); #1; pause_ce=0;
    endtask
    task automatic finish_block(input integer n);
        wait(dma.end_of_block); idle();
        if(reads!=n || writes!=n || dma_bad || sio_bad || irq || !ieo)
            $fatal(1,"block effects/error r=%0d w=%0d n=%0d DMA=%b SIO=%b",reads,writes,n,dma_bad,sio_bad);
        // Actual stopped count readback, not internal count alone.
        put_dma(8'hbb); put_dma(8'h06); put_dma(8'ha7);
        @(negedge clk); #1; dma_cs=1; dma_rd_n=0; step();
        if(dma_cpu_out!==8'(n-1)) $fatal(1,"terminal low count mismatch");
        @(negedge clk); #1; dma_cs=0; dma_rd_n=1; step();
        @(negedge clk); #1; dma_cs=1; dma_rd_n=0; step();
        if(dma_cpu_out!==0) $fatal(1,"terminal high count mismatch");
        @(negedge clk); #1; dma_cs=0; dma_rd_n=1; step();
    endtask
    initial begin
        if(!$value$plusargs("CE_PERIOD=%d",period)) period=1;
        for(integer ch=0;ch<2;ch=ch+1) for(integer burst=0;burst<2;burst=burst+1) begin
            fresh(1'(ch)); wr_sio(1,8'he0); configure(1,burst!=0 ? 8'h80 : 0,3);
            repeat(80) begin step(); if(!busrq_n || reads!=0 || writes!=0) $fatal(1,"empty RX requested DMA"); end
            for(integer i=0;i<4;i=i+1) begin
                if(i==0) fork
                    receive_byte(8'h53,0);
                    freeze_read();
                join
                else receive_byte(8'h53+8'(i*17),0);
                wait(writes==i+1); idle();
                if(memory[16'(32'h5000+i)]!==8'h53+8'(i*17)) $fatal(1,"RX byte/order wrong");
                repeat(80) begin step(); if(reads!=i+1 || writes!=i+1 || !busrq_n) $fatal(1,"RX repeated without Ready"); end
            end
            finish_block(4);
            if(io_reads!=4 || io_writes!=0 || grants!=4) $fatal(1,"RX ownership/effects");
            fresh(1'(ch)); wr_sio(1,8'hc0);
            for(integer i=0;i<4;i=i+1) memory[16'(32'h5000+i)]=8'h69+8'(i*19);
            configure(0,burst!=0 ? 8'h80 : 0,3);
            wait(io_writes==1); idle();
            repeat(80) begin step(); if(writes!=1 || !busrq_n) $fatal(1,"full TX not paced"); end
            for(integer i=0;i<4;i=i+1) begin
                transmit_byte(8'h69+8'(i*19));
                if(i<3) begin wait(io_writes==i+2); idle(); end
            end
            finish_block(4);
            if(io_writes!=4 || io_reads!=0 || grants!=4 || txd!==3) $fatal(1,"TX ownership/effects");
        end
        // First-character framing lock permits one transfer of the error word,
        // then must stop DMA until CPU error inspection/reset. A later good
        // character cannot replace or bypass the locked head.
        for(integer ch=0;ch<2;ch=ch+1) begin
            fresh(1'(ch)); wr_sio(1,8'he8); configure(1,0,1);
            receive_byte(8'h37,1); wait(writes>=1); idle();
            receive_byte(8'hb6,0);
            repeat(80) begin step();
                if(reads!=1 || writes!=1 || !busrq_n || !ready_n[selected_channel] || !irq ||
                   memory[16'h5000]!==8'h37 || memory[16'h5001]!==8'hcc)
                    $fatal(1,"locked RX repeated/bypassed DMA error word r=%0d w=%0d",reads,writes);
            end
            put_sio({selected_channel,1'b1},1); check_sio(1,8'h41);
            check_sio(0,8'h37); check_sio(0,8'h37);
            if(reads!=1 || writes!=1 || !ready_n[selected_channel])
                $fatal(1,"CPU inspection restarted locked-error DMA");
            put_sio({selected_channel,1'b1},8'h30); // genuine WR0 Error Reset
            finish_block(2);
            if(memory[16'h5001]!==8'hb6 || io_reads!=2 || grants!=2)
                $fatal(1,"error reset did not resume next queued byte");
        end
        $display("PASS: standalone SIO/DMA A/B RX/TX pins/count, byte/burst Ready pacing, stopped-CE owned read, framing lock/reset recovery CE=%0d",period);
        $finish;
    end
    initial begin #20000000; $fatal(1,"SIO DMA watchdog r=%0d w=%0d io=%0d/%0d a=%h",reads,writes,io_reads,io_writes,address); end
endmodule
