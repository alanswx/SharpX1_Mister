`timescale 1ns/1ps
// Original synthetic media and pin-level standalone SD/register fixture.
// No CPU, force, private assets or injected index/state. Digital timing policy
// only: SYS=32MHz; explicit CHIP_DIV=16/32 gives nominal 2/1MHz MFM CLK.
module fdc_strict_timing_tb;
    parameter CHIP_DIV=16, HIGH=0;
    localparam HEADER=1016+(HIGH ? 1048576 : 0), TOTAL=HEADER+1984;
    reg clk=0, reset=1, mounted=0, rd=0, wr=0, bus_run=1;
    reg [1:0] address=0;
    reg [7:0] din=0, host_data=0;
    reg ack=0, host_wr=0;
    reg [8:0] host_address=0;
    wire [7:0] dout, host_read;
    wire [31:0] lba;
    wire prepare, sd_rd, sd_wr, drq, busy, idle;
    integer ticks=0, chip_edges=0, requests=0, writes=0, cases=0;
    integer arrival_count=0, emit_count=0, start_edge=0, arm_edge=0, last_emit_edge=0;
    integer offsets[4], lengths[4];
    reg [7:0] media[TOTAL], expected[TOTAL];
    reg [7:0] planned[TOTAL];
    reg verify_transport=0;
    integer hold_mode=0, hold_lba=0;
    reg hold_writing=0, hold_reached=0, hold_release=0;
    always #15.625 clk=!clk;
    always @(negedge clk) ticks++;
    wire ce=bus_run && ticks%8==0;
    wire fdc_ce=ticks%CHIP_DIV==0;
    wd1793 #(.RWMODE(1), .EDSK(1), .D88_ONLY(1), .ADDRESS_BITS(24),
              .MAX_SECTORS(4095), .STRICT_D88_TIMING(1)) dut (
        .clk_sys(clk), .ce(ce), .reset(reset), .io_en(1'b1), .rd(rd), .wr(wr),
        .addr(address), .din(din), .dout(dout), .drq(drq), .busy(busy), .intrq(),
        .wp(1'b0), .fmt_wp(), .size_code(3'd0), .layout(1'b0), .side(1'b0),
        .ready(1'b1), .fm_mode(1'b0), .drive_select(1'b0), .drive_connected(1'b1),
        .transport_idle(idle), .img_mounted(mounted), .img_size(24'(TOTAL)),
        .img_size_id(24'(TOTAL)), .disk_index(3'd0), .prepare(prepare), .sd_lba(lba),
        .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(ack), .sd_buff_addr(host_address),
        .sd_buff_dout(host_data), .sd_buff_din(host_read), .sd_buff_wr(host_wr),
        .input_active(1'b0), .input_addr(24'd0), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0), .hd_selected(1'b0), .fdc_ce(fdc_ce)
    );
    // Independent chip-edge cadence oracle. Bus accepts never reset these
    // counters. The observed intents/events are checked, never used to
    // manufacture an accepted CPU transaction or preload the controller.
    always @(posedge clk) begin
        if(fdc_ce) chip_edges++;
        if(dut.strict_timing.begin_read) begin start_edge=chip_edges; arrival_count=0; end
        if(dut.strict_timing.arm_write) begin arm_edge=chip_edges; emit_count=0; end
        if(dut.strict_timing.launch)
            assert(chip_edges-arm_edge==32) else $fatal(1,"initial prefill not 32 future chip edges");
        if(dut.timing_read_load) begin
            arrival_count++;
            assert(chip_edges-start_edge==32*arrival_count)
                else $fatal(1,"read cadence rephased by bus/CE i=%0d",arrival_count);
        end
        if(dut.timing_replace)
            assert(!dut.timing_taken && !dut.timing_buffer_store && !dut.timing_read_load)
                else $fatal(1,"command replacement consumed stale completion/store/arrival");
    end
    always @(negedge clk) if(dut.strict_timing.write_emit) begin
        assert(chip_edges-arm_edge==32*(emit_count+1))
            else $fatal(1,"DSR cadence/prefill changed i=%0d",emit_count);
        assert(dut.strict_timing.write_index==11'(emit_count)) else $fatal(1,"DSR index");
        emit_count++; last_emit_edge=chip_edges;
    end
    reg [31:0] random_state=32'h31570193;
    function automatic integer jitter;
        random_state=(random_state<<1)^((random_state[31])?32'h04c11db7:32'd0);
        return int'(random_state & 31);
    endfunction
    initial forever begin
        bit writing;
        integer owned, at, delay_edges;
        wait(sd_rd || sd_wr);
        writing=sd_wr; owned=int'(lba); requests++; if(writing) writes++;
        assert(!(sd_rd && sd_wr)) else $fatal(1,"both SD directions");
        delay_edges=jitter()+1;
        if(hold_mode==1 && writing==hold_writing && owned==hold_lba) begin
            hold_reached=1; wait(hold_release); hold_mode=0;
        end
        repeat(delay_edges) begin
            @(negedge clk); assert(lba==32'(owned)) else $fatal(1,"pre-ACK LBA moved");
        end
        ack=1;
        if(hold_mode==2 && writing==hold_writing && owned==hold_lba) begin
            hold_reached=1; wait(hold_release); hold_mode=0;
        end
        for(int i=0;i<512;i++) begin
            host_address=9'(i); at=owned*512+i;
            if(writing) begin
                repeat(2) @(negedge clk);
                if(at<TOTAL) begin
                    if(verify_transport) begin
                        assert(host_read==planned[at]) else $fatal(1,"ACK buffer changed at=%0d got=%h want=%h",at,host_read,planned[at]);
                        expected[at]=planned[at]; // independent planned bytes, not observed output
                    end
                    media[at]=host_read;
                end
                else assert(host_read==0) else $fatal(1,"out of extent write");
            end else begin
                host_data=(at<TOTAL)?media[at]:8'd0;
                host_wr=1; @(negedge clk);
            end
            assert(lba==32'(owned)) else $fatal(1,"ACK-owned LBA moved");
        end
        host_wr=0; repeat(8+jitter()) @(negedge clk); ack=0;
        repeat(12) @(negedge clk);
    end
    task send(input [1:0] port, input [7:0] value);
        @(negedge clk); address=port; din=value; wr=1;
        repeat(16) @(negedge clk); wr=0;
        repeat(16) @(negedge clk);
    endtask
    task data_read(output reg [7:0] value, input integer hold_edges=16);
        @(negedge clk); address=3; rd=1;
        repeat(16) @(negedge clk); value=dout;
        repeat(hold_edges) begin
            @(negedge clk); assert(dout==value) else $fatal(1,"held response changed");
        end
        rd=0; repeat(16) @(negedge clk);
    endtask
    task compare_medium;
        for(int i=0;i<TOTAL;i++)
            assert(media[i]==expected[i]) else $fatal(1,"full-medium corruption offset=%0d got=%h want=%h",i,media[i],expected[i]);
    endtask
    task finished(input bit lost, input [7:0] status_bits=0);
        wait(!busy && idle); address=0; #1;
        assert((dout & 8'hfd)==(status_bits | (lost ? 8'h04 : 8'h00))) else $fatal(1,"completion status=%h expected lost=%0d bits=%h",dout,lost,status_bits);
        cases++;
    endtask
    function automatic [7:0] payload(input integer sector, index);
        return 8'(index*37+(index>>8)*53+sector*19+7);
    endfunction
    task read_sector(input integer sector, miss=-1, final_hold=16, service_delay=0);
        reg [7:0] value;
        integer read_requests, arrived_edge;
        send(2,8'(sector+1)); read_requests=requests; send(0,8'h80);
        for(int i=0;i<lengths[sector];i++) begin
            wait(drq);
            if(service_delay!=0 && (i==0 || i==lengths[sector]/2)) begin
                arrived_edge=chip_edges;
                wait(chip_edges>=arrived_edge+service_delay);
            end
            if(i==miss) begin
                if(i==lengths[sector]-1) begin
                    wait(!dut.strict_timing.active); break;
                end
                // Miss exactly one arrival; DRQ stays high across overwrite.
                wait(arrival_count>=i+2);
                i++;
            end
            data_read(value, i==lengths[sector]-1 ? final_hold : 16+jitter());
            assert(value==expected[offsets[sector]+i]) else $fatal(1,"read sector=%0d i=%0d got=%h want=%h",sector,i,value,expected[offsets[sector]+i]);
        end
        finished(miss>=0, (expected[offsets[sector]-9]==8'h10 ? 8'h20 : 0) |
                         (expected[offsets[sector]-8]==8'hb0 ? 8'h08 : 0));
        assert(requests-read_requests==((offsets[sector]%512+lengths[sector]-1)/512+1))
            else $fatal(1,"full-sector prefetch block count");
        compare_medium();
        address=3; #1;
        assert(dout==expected[offsets[sector]+lengths[sector]-1]) else $fatal(1,"last physical DR readback");
    endtask
    task write_sector(input integer sector, miss=-1, input bit deleted=0);
        integer before_writes;
        send(2,8'(sector+1)); before_writes=writes; send(0,deleted ? 8'ha1 : 8'ha0);
        for(int i=0;i<lengths[sector];i++) begin
            wait(drq);
            if(i==miss) begin
                wait(emit_count>=i+1);
                expected[offsets[sector]+i]=0;
            end else begin
                send(3,payload(sector,i)); expected[offsets[sector]+i]=payload(sector,i);
            end
            if(i+1<lengths[sector]) wait(emit_count>=i+1);
        end
        expected[offsets[sector]-9]=deleted ? 8'h10 : 0;
        if(expected[offsets[sector]-8]==8'hb0) expected[offsets[sector]-8]=0;
        finished(miss>=0);
        assert(writes>before_writes) else $fatal(1,"write never flushed SD");
        compare_medium();
    endtask
    function automatic [15:0] crc_byte(input [15:0] crc, input [7:0] value);
        reg [15:0] result;
        result=crc ^ {value,8'd0};
        for(int i=0;i<8;i++) result=result[15] ? (result<<1)^16'h1021 : result<<1;
        return result;
    endfunction
    task read_address;
        reg [7:0] value, record[6];
        reg [15:0] crc;
        // Most recent sector search was index 0; actual READ ADDRESS begins
        // at the next indexed ID, sector 2/N=1. CRC oracle is independent.
        record[0]=0; record[1]=0; record[2]=2; record[3]=1;
        crc=16'hffff;
        repeat(3) crc=crc_byte(crc,8'ha1);
        crc=crc_byte(crc,8'hfe);
        for(int i=0;i<4;i++) crc=crc_byte(crc,record[i]);
        record[4]=crc[15:8]; record[5]=crc[7:0];
        send(0,8'hc0);
        for(int i=0;i<6;i++) begin
            wait(drq); data_read(value);
            assert(value==record[i]) else $fatal(1,"six-byte READ ADDRESS i=%0d got=%h want=%h",i,value,record[i]);
        end
        finished(0); address=2; #1;
        assert(dout==0) else $fatal(1,"READ ADDRESS did not copy C to SCR");
    endtask
    task cancel_local(input bit resetting, input integer phase);
        integer before_writes;
        send(2,1); before_writes=writes; send(0,phase==2 ? 8'h80 : 8'ha0); wait(drq);
        if(phase==1) begin send(3,8'h73); wait(emit_count>=2); end
        if(phase==2) begin
            @(negedge clk); bus_run=0;
            wait(dut.strict_timing.done); repeat(32) @(negedge clk);
            assert(dut.strict_timing.completion.valid) else $fatal(1,"pending completion absent");
        end
        if(resetting) begin
            @(negedge clk); reset=1; bus_run=0;
            repeat(40) @(negedge clk); reset=0; bus_run=1;
        end else begin
            // Put command on the bus BEFORE resuming CE: cancellation and
            // slow-consumer completion then compete on the same first edge.
            @(negedge clk); address=0; din=8'hd0; wr=1; bus_run=1;
            repeat(16) @(negedge clk); wr=0; repeat(32) @(negedge clk);
        end
        wait(!busy && idle); repeat(16) @(negedge clk);
        assert(!drq && !dut.strict_timing.completion.valid && !dut.strict_timing.active && !dut.strict_timing.armed)
            else $fatal(1,"local cancel retained stream/lease");
        assert(writes==before_writes) else $fatal(1,"prefill/stream cancel wrote SD");
        compare_medium(); cases++; read_sector(0);
    endtask
    task cancel_transport(input bit resetting, input integer phase, ack_phase);
        // phase 0=prefetch, 1=payload write, 2=metadata read, 3=metadata write.
        // One owned host write may commit despite cancellation. Only its
        // independent planned block is allowed to alter expected medium.
        integer owned, before_requests;
        for(int i=0;i<TOTAL;i++) planned[i]=expected[i];
        for(int i=0;i<lengths[0];i++) planned[offsets[0]+i]=8'(i*23+phase*11+ack_phase*7+resetting);
        planned[offsets[0]-9]=8'h10;
        hold_mode=ack_phase; hold_release=0; hold_reached=0;
        hold_lba=(phase>=2) ? (offsets[0]-9)/512 : offsets[0]/512;
        hold_writing=(phase==1 || phase==3);
        verify_transport=1;
        send(2,1); before_requests=requests; send(0,phase==0 ? 8'h80 : 8'ha1);
        if(phase!=0) for(int i=0;i<lengths[0];i++) begin
            wait(drq); send(3,planned[offsets[0]+i]);
            if(i+1<lengths[0]) wait(emit_count>=i+1);
        end
        wait(hold_reached); @(negedge clk); owned=int'(lba);
        assert(requests>before_requests && lba==32'(hold_lba)) else $fatal(1,"wrong transport phase held");
        if(resetting) begin
            reset=1; bus_run=0;
        end else send(0,8'hd0);
        repeat(40) @(negedge clk);
        assert(lba==32'(owned) && !drq && !idle) else $fatal(1,"cancel relinquished host lease");
        assert(resetting ? !busy : busy) else $fatal(1,"cancel busy/drain contract");
        hold_release=1;
        wait(!dut.transport_active); repeat(32) @(negedge clk);
        if(resetting) begin
            assert(!busy) else $fatal(1,"held reset failed SYS ACK drain");
            reset=0; bus_run=1;
        end
        wait(!busy && idle); repeat(32) @(negedge clk);
        assert(!dut.strict_timing.completion.valid && !dut.strict_timing.active && !dut.strict_timing.armed)
            else $fatal(1,"transport cancel retained stream/lease");
        verify_transport=0; compare_medium(); cases++;
        // Read result comes from retained real medium, not a fresh mount or
        // injected sector table. It includes any already-published block.
        read_sector(0);
        // Restore a normal mark for the next independent metadata abort.
        write_sector(0);
    endtask
    initial begin
        integer at, before_writes;
        reg [7:0] value;
        for(int i=0;i<TOTAL;i++) media[i]=0;
        for(int i=0;i<4;i++) begin
            media[28+i]=8'(TOTAL>>(8*i)); media[32+i]=8'(HEADER>>(8*i));
        end
        at=HEADER;
        for(int s=0;s<4;s++) begin
            lengths[s]=128<<s; offsets[s]=at+16;
            media[at+2]=8'(s+1); media[at+3]=8'(s); media[at+4]=4;
            if(s==0) begin media[at+7]=8'h10; media[at+8]=8'hb0; end
            media[at+14]=8'(lengths[s]); media[at+15]=8'(lengths[s]>>8);
            for(int i=0;i<lengths[s];i++) media[at+16+i]=8'(i*13+s*29+(i>>8));
            at+=16+lengths[s];
        end
        assert(at==TOTAL) else $fatal(1,"fixture extent");
        for(int i=0;i<TOTAL;i++) expected[i]=media[i];
        repeat(32) @(negedge clk); reset=0;
        mounted=1; repeat(32) @(negedge clk); mounted=0;
        wait(!prepare && idle && !dut.mount_pending); repeat(32) @(negedge clk);
        read_sector(0); read_address();
        for(int s=0;s<4;s++) begin read_sector(s); write_sector(s); read_sector(s); end
        // Service after real chip edges have elapsed, not just before the
        // first future chip edge. A service-reloaded slot counter must fail
        // the unchanged independent 32-edge arrival oracle on the next byte.
        for(int s=0;s<4;s++) read_sector(s,-1,16,17);
        write_sector(3,-1,1); read_sector(3); write_sector(3); read_sector(3);
        read_sector(1,0); read_sector(2,127);
        write_sector(0,64); read_sector(0);
        write_sector(1,255); read_sector(1);
        // No initial service: stop bus/controller CE while chip clock runs.
        send(2,1); before_writes=writes; send(0,8'ha0); wait(drq);
        @(negedge clk); bus_run=0;
        wait(dut.strict_timing.done); repeat(40) @(negedge clk);
        assert(busy && !drq && dut.strict_timing.completion.valid)
            else $fatal(1,"stopped CE completion not held");
        assert(writes==before_writes && emit_count==0) else $fatal(1,"initial missing byte wrote SD");
        bus_run=1; finished(1); compare_medium(); read_sector(0);
        // Early first service clears DRQ but cannot rephase fixed launch.
        send(2,1); send(0,8'ha0); wait(drq); send(3,8'h91);
        expected[offsets[0]]=8'h91; assert(!drq && emit_count==0) else $fatal(1,"early service launched/rephased");
        @(negedge clk); bus_run=0;
        wait(dut.strict_timing.done);
        for(int i=1;i<lengths[0];i++) expected[offsets[0]+i]=0;
        repeat(32) @(negedge clk); assert(busy) else $fatal(1,"slow consumer not held");
        bus_run=1; finished(1); compare_medium();
        address=3; #1;
        assert(dout==8'h91) else $fatal(1,"DSR underrun zero overwrote physical DR");
        read_sector(0);
        read_sector(0,127); read_sector(0);
        read_sector(0,-1,3*32*CHIP_DIV); read_sector(1);
        // Every accepted DATA store updates physical DR, including idle and
        // DRQ-low stores. Full validity is separate: second store is NOT a
        // second request service, but its new DR supplies the first DSR load.
        send(3,8'h37); address=3; #1;
        assert(dout==8'h37) else $fatal(1,"idle DATA store lost");
        send(2,1); send(0,8'ha0); wait(drq); send(3,8'h81);
        assert(!drq && emit_count==0) else $fatal(1,"first prefill contract");
        send(3,8'hd2); expected[offsets[0]]=8'hd2;
        assert(!drq && emit_count==0 && dut.wdreg_data==8'hd2) else $fatal(1,"non-DRQ DATA store lost/serviced");
        for(int i=1;i<lengths[0];i++) begin
            wait(drq); send(3,payload(0,i)); expected[offsets[0]+i]=payload(0,i);
            if(i+1<lengths[0]) wait(emit_count>=i+1);
        end
        finished(0); compare_medium(); read_sector(0);
        // STATUS reads are captured too, but never acknowledge a DATA
        // generation. Poll response stays held as DRQ/lost-data evolve.
        send(2,2); send(0,8'h80); wait(drq);
        @(negedge clk); address=0; rd=1; repeat(16) @(negedge clk); value=dout;
        repeat(3*32*CHIP_DIV) begin @(negedge clk); assert(dout==value) else $fatal(1,"held STATUS response changed"); end
        assert(drq && dut.timing_lost) else $fatal(1,"STATUS acceptance acknowledged DATA");
        rd=0; repeat(16) @(negedge clk); send(0,8'hd0); wait(!busy && idle); cases++;
        compare_medium(); read_sector(1);
        // A held raw DATA read cannot acknowledge later generations; physical
        // DR changes while the all-register bus helper retains its response.
        send(2,2); send(0,8'h80); wait(drq);
        data_read(value,3*32*CHIP_DIV);
        assert(value==expected[offsets[1]]) else $fatal(1,"first held read response");
        send(0,8'hd0); wait(!busy && idle); compare_medium(); cases++;
        read_sector(1);
        for(int resetting=0;resetting<2;resetting++) begin
            for(int phase=0;phase<3;phase++) cancel_local(1'(resetting),phase);
            for(int phase=0;phase<4;phase++)
                for(int ack_phase=1;ack_phase<=2;ack_phase++)
                    cancel_transport(1'(resetting),phase,ack_phase);
        end
        $display("PASS strict D88 timing cases=%0d chip_div=%0d high=%0d requests=%0d writes=%0d",cases,CHIP_DIV,HIGH,requests,writes);
        $finish;
    end
    initial begin #20000000000; $fatal(1,"fixture watchdog"); end
endmodule
