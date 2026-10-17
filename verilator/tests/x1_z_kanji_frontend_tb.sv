// SPDX-License-Identifier: GPL-2.0-only
// Original generated-font/public-pin fixture; no hierarchy or private assets.
`timescale 1ns/1ps
module x1_z_kanji_frontend_tb #(
    parameter integer HALF_PERIOD_PS=15625,
    // 1/2/3: cold reset CPU SEND/RETURN/HELD; 4: final write ACK cold
    // reset; 5/6: final write ACK permission/index loss; 7: excess byte.
    // Every reset/error profile must recover through a new complete upload.
    parameter integer RESET_CASE=0,
    parameter integer PREEMPT_PHASE=0,
    parameter integer HOLD_CANCEL=0
);
    integer reset_case=RESET_CASE,preempt_phase=PREEMPT_PHASE,hold_cancel=HOLD_CANCEL;
    initial begin
        if($value$plusargs("RESET_CASE=%d",reset_case)) begin end
        if($value$plusargs("PREEMPT_PHASE=%d",preempt_phase)) begin end
        if($value$plusargs("HOLD_CANCEL=%d",hold_cancel)) begin end
        assert(reset_case>=0 && reset_case<=7 && preempt_phase>=0 && preempt_phase<=3 &&
               hold_cancel>=0 && hold_cancel<=1)
            else $fatal(1,"Z_FRONTEND_BAD_PROFILE");
    end
    localparam logic [28:0] BASE=29'h06123400;
    localparam realtime DEADLINE=60000000.0*HALF_PERIOD_PS*1ps;
    bit clk=0;
    initial forever #(HALF_PERIOD_PS*1ps) clk=~clk;
    logic cold_reset=0,consumer_cancel=0,cpu_read=0,cpu_response_ack=0;
    logic [17:0] cpu_address=0;
    wire cpu_wait,cpu_valid;
    wire [7:0] cpu_data;
    logic ioctl_download=0,ioctl_wr=0,upload_permitted=1;
    logic [7:0] ioctl_index=5,ioctl_data=0;
    logic [24:0] ioctl_address=0;
    wire ioctl_wait,loaded,upload_error,upload_active;
    wire DDRAM_CLK,DDRAM_RD,DDRAM_WE;
    wire [7:0] DDRAM_BURSTCNT,DDRAM_BE;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DIN;
    logic DDRAM_BUSY=0,DDRAM_DOUT_READY=0;
    logic [63:0] DDRAM_DOUT=0;
    x1_z_kanji_frontend #(.BASE_WORD_ADDRESS(BASE)) dut(.*);
    byte unsigned memory[0:262143],ledger[0:262143];
    bit pending=0,force_busy=0;
    integer delay_left=0,read_delay=4;
    logic [28:0] pending_address=BASE;
    longint unsigned cycles=0,commands=0,writes=0,reads=0,accepted=0,consumed=0;
    integer expected_write_address=0;
    logic [17:0] expected_read_address=0;
    bit expected_read_pending=0;
    logic [7:0] expected_write_data=0;
    bit expected_write_pending=0,check_upload_order=0;
    integer sequence_address=0,full_reads=0,cases=0;
    bit held_response=0,ack_eligible=1;
    logic [7:0] held_data=0;
    function automatic [7:0] font(input integer a);
        return 8'((a*43)^(a>>7)^(a>>16)^8'ha7);
    endfunction
    function automatic [7:0] retry_font(input integer a);
        return font(a)^8'hff;
    endfunction
    function automatic [63:0] word_at(input logic [28:0] a);
        integer first;
        first=(int'(a)-int'(BASE))*8;
        for(integer i=0;i<8;i++) word_at[i*8+:8]=memory[first+i];
    endfunction
    // Memory inputs are settled on the falling edge, never changed by the
    // rising-edge observer. Immediate and delayed returns share this rule.
    initial forever begin
        @(negedge clk); #1;
        DDRAM_BUSY=force_busy || cycles%9==0;
        DDRAM_DOUT=word_at(pending ? pending_address : DDRAM_ADDR);
        DDRAM_DOUT_READY=(pending && delay_left==0) ||
            (DDRAM_RD && !DDRAM_BUSY && read_delay==0);
    end
    initial forever begin
        @(posedge clk);
        cycles++;
        assert(DDRAM_CLK==clk && DDRAM_BURSTCNT==1 && !(DDRAM_RD&&DDRAM_WE))
            else $fatal(1,"Z_FRONTEND_DDR_SHAPE");
        if(held_response && !consumer_cancel && !cold_reset && !ioctl_download)
            assert(cpu_valid && cpu_data==held_data) else $fatal(1,"Z_FRONTEND_HELD_DATA");
        if(consumer_cancel || cold_reset)
            assert(!cpu_valid) else $fatal(1,"Z_FRONTEND_CANCEL_VALID");
        if(cpu_valid && cpu_response_ack && ack_eligible && !cold_reset && !consumer_cancel) consumed++;
        if(!cpu_response_ack) ack_eligible=1;
        if(cold_reset || consumer_cancel || ioctl_download || (cpu_valid && cpu_response_ack)) ack_eligible=0;
        held_response=cpu_valid && !cpu_response_ack;
        held_data=cpu_data;
        if(ioctl_download && ioctl_index==5 && ioctl_wr && !ioctl_wait) begin
            accepted++;
            if(check_upload_order) begin
                assert(int'(ioctl_address)==sequence_address)
                    else $fatal(1,"Z_FRONTEND_STIMULUS_ORDER");
                assert(!expected_write_pending) else $fatal(1,"Z_FRONTEND_WRITE_QUEUE");
                expected_write_pending=1;
                expected_write_address=int'(ioctl_address);expected_write_data=ioctl_data;
                ledger[expected_write_address]=ioctl_data;sequence_address++;
            end
        end
        if(pending) begin
            if(delay_left==0) pending=0;
            else delay_left--;
        end
        if((DDRAM_RD || DDRAM_WE) && !DDRAM_BUSY) begin
            commands++;
            if(DDRAM_WE) begin
                writes++;
                assert(expected_write_pending) else $fatal(1,"Z_FRONTEND_WRITE_REPLAY");
                assert(DDRAM_ADDR==BASE+29'(expected_write_address/8) &&
                       DDRAM_BE==(8'd1 << (expected_write_address%8)) &&
                       DDRAM_DIN=={8{expected_write_data}})
                    else $fatal(1,"Z_FRONTEND_WRITE_METADATA");
                expected_write_pending=0;
                for(integer i=0;i<8;i++) if(DDRAM_BE[i])
                    memory[(int'(DDRAM_ADDR)-int'(BASE))*8+i]=DDRAM_DIN[i*8+:8];
            end else begin
                reads++;
                assert(expected_read_pending) else $fatal(1,"Z_FRONTEND_READ_REPLAY");
                assert(DDRAM_ADDR==BASE+29'(expected_read_address/8) && DDRAM_BE==8'hff)
                    else $fatal(1,"Z_FRONTEND_READ_METADATA");
                expected_read_pending=0;
                assert(!pending) else $fatal(1,"Z_FRONTEND_READ_REPLAY");
                if(!DDRAM_DOUT_READY) begin
                    pending=1;pending_address=DDRAM_ADDR;delay_left=read_delay;
                end
            end
        end
    end
    task automatic tick;
        @(posedge clk); #2;
    endtask
    task automatic bounded_idle;
        // Public transport settled, not a private state test.
        for(integer i=0;i<40;i++) tick();
        assert(!DDRAM_RD && !DDRAM_WE && !pending) else $fatal(1,"Z_FRONTEND_DRAIN");
    endtask
    task automatic send_byte(input integer a,input logic [7:0] d,input integer held);
        integer n;
        longint unsigned before_accept;
        assert(a>=0 && a<262144) else $fatal(1,"Z_FRONTEND_STIMULUS_RANGE");
        @(negedge clk);ioctl_address=25'(a);ioctl_data=d;ioctl_wr=1;
        n=0;before_accept=accepted;
        while(ioctl_wait) begin tick();n++;assert(n<100) else $fatal(1,"Z_FRONTEND_UPLOAD_READY");end
        tick();
        assert(accepted==before_accept+1) else $fatal(1,"Z_FRONTEND_UPLOAD_CAPTURE");
        repeat(held) tick();
        assert(accepted==before_accept+1) else $fatal(1,"Z_FRONTEND_HELD_WR_REPLAY");
        @(negedge clk);ioctl_wr=0;
        tick();
    endtask
    task automatic read_byte(input integer a,input bit hold_level);
        integer n;
        longint unsigned before_reads,before_consumed;
        assert(a>=0 && a<262144) else $fatal(1,"Z_FRONTEND_STIMULUS_RANGE");
        before_reads=reads;before_consumed=consumed;
        @(negedge clk);cpu_read=1;cpu_address=18'(a);cpu_response_ack=0;
        expected_read_address=18'(a);expected_read_pending=1;
        n=0;
        tick(); // public capture; address may change after this edge
        @(negedge clk);cpu_address=18'(a)^18'h15555;
        while(!cpu_valid) begin tick();n++;assert(n<100) else $fatal(1,"Z_FRONTEND_CPU_DEADLINE");end
        assert(cpu_data==ledger[a] && !cpu_wait) else $fatal(1,"Z_FRONTEND_CPU_BYTE");
        repeat(3) tick();
        @(negedge clk);cpu_response_ack=1;
        tick();
        @(negedge clk);cpu_response_ack=0;
        if(!hold_level) cpu_read=0;
        repeat(5) tick();
        assert(reads==before_reads+1 && consumed==before_consumed+1 && !cpu_valid)
            else $fatal(1,"Z_FRONTEND_CPU_LEVEL_REPLAY");
        @(negedge clk);cpu_read=0;
        tick();
    endtask
    task automatic failed_session(input integer kind);
        longint unsigned before_writes;
        logic [24:0] bad_address;
        before_writes=writes;
        @(negedge clk);ioctl_download=1;ioctl_index=5;
        tick();
        case(kind)
            0: begin // full public address overflow cannot truncate to byte0
                @(negedge clk);ioctl_wr=1;ioctl_address=25'h040000;ioctl_data=8'h33;
                tick();
                assert(upload_error) else $fatal(1,"Z_FRONTEND_OVERFLOW_REJECTION");
                @(negedge clk);ioctl_wr=0;
            end
            1: begin @(negedge clk);upload_permitted=0;tick();end
            2: begin @(negedge clk);ioctl_index=6;tick();end
            3: begin @(negedge clk);cold_reset=1;tick();end
            5,6,7: begin
                if(kind!=6) begin
                    check_upload_order=1;sequence_address=0;
                    send_byte(0,8'h3c,0);
                    while(ioctl_wait) tick();
                end
                check_upload_order=0;
                // Missing byte1 (0,2); reordered start (1); duplicate (0,0).
                bad_address=(kind==5)?2:((kind==6)?1:0);
                @(negedge clk);ioctl_wr=1;ioctl_address=bad_address;ioctl_data=8'h82;
                tick();
                assert(upload_error) else $fatal(1,"Z_FRONTEND_ORDER_REJECTION");
                @(negedge clk);ioctl_wr=0;
            end
            default: begin end // short upload ends below
        endcase
        @(negedge clk);ioctl_download=0;
        bounded_idle();
        assert(upload_error && !loaded && !upload_active)
            else $fatal(1,"Z_FRONTEND_FAILED_PUBLICATION");
        if(kind>=5) assert(writes==before_writes+((kind==6)?0:1))
            else $fatal(1,"Z_FRONTEND_BAD_BYTE_WRITTEN");
        @(negedge clk);upload_permitted=1;cold_reset=0;ioctl_index=5;
        tick();cases++;
    endtask
    task automatic complete_retry;
        // New generation changes every byte. Restore pins only, never DUT
        // state or mock memory; prove the cancelled owner cannot deadlock it.
        @(negedge clk);cold_reset=0;upload_permitted=1;ioctl_index=5;
        ioctl_download=0;ioctl_wr=0;cpu_read=0;cpu_response_ack=0;
        consumer_cancel=1'(hold_cancel);
        tick();
        check_upload_order=1;sequence_address=0;
        @(negedge clk);ioctl_download=1;
        tick();
        for(integer a=0;a<262144;a++) send_byte(a,retry_font(a),(a%65536==0)?12:0);
        @(negedge clk);ioctl_download=0;
        begin
            integer n;
            n=0;
            while(upload_active) begin tick();n++;assert(n<100)
                else $fatal(1,"Z_FRONTEND_RETRY_COMMIT_DEADLINE");end
        end
        assert(loaded && !upload_error) else $fatal(1,"Z_FRONTEND_RETRY_COMMIT");
        @(negedge clk);consumer_cancel=0;
        tick();
        for(integer a=0;a<262144;a++) begin
            assert(memory[a]==retry_font(a) && ledger[a]==retry_font(a))
                else $fatal(1,"Z_FRONTEND_RETRY_WHOLE_MEDIUM");
            read_delay=(a%8==0)?0:4;
            read_byte(a,a%65536==0);full_reads++;
        end
        cases++;
    endtask
    task automatic terminal;
        for(integer a=0;a<262144;a++)
            assert(memory[a]==ledger[a]) else $fatal(1,"Z_FRONTEND_FINAL_LEDGER");
        assert(!expected_write_pending && !expected_read_pending && !pending && !DDRAM_RD && !DDRAM_WE)
            else $fatal(1,"Z_FRONTEND_FINAL_OWNER");
        $display("PASS Z_FRONTEND reset=%0d full_uploads=2 full_reads=%0d cases=%0d writes=%0d reads=%0d accepted=%0d consumed=%0d half_ps=%0d preempt=%0d hold_cancel=%0d cycles=%0d",reset_case,full_reads,cases,writes,reads,accepted,consumed,HALF_PERIOD_PS,preempt_phase,hold_cancel,cycles);
        $finish;
    endtask
    initial begin
        for(integer a=0;a<262144;a++) begin memory[a]=0;ledger[a]=0;end
        tick();
        // Unloaded request never manufactures a valid byte or DDR command.
        @(negedge clk);cpu_read=1;cpu_address=17;
        expected_read_address=17;expected_read_pending=1;
        repeat(8) tick();
        assert(cpu_wait && !cpu_valid && commands==0) else $fatal(1,"Z_FRONTEND_UNLOADED");
        @(negedge clk);consumer_cancel=1;
        tick();
        @(negedge clk);consumer_cancel=1'(hold_cancel); // keep CPU level through upload
        tick();cases++;
        // Clean START must apply WAIT even before any sticky error exists.
        // End with no bytes, then recover through the later complete image.
        @(negedge clk);ioctl_download=1;
        #2;assert(ioctl_wait) else $fatal(1,"Z_FRONTEND_START_WAIT");
        tick();
        @(negedge clk);ioctl_download=0;
        bounded_idle();
        assert(upload_error && !loaded && !upload_active && writes==0)
            else $fatal(1,"Z_FRONTEND_EMPTY_UPLOAD");
        cases++;
        // Download edge under reset is explicitly rejected, not silent stall.
        @(negedge clk);cold_reset=1;ioctl_download=1;ioctl_wr=1;ioctl_address=0;
        tick();
        @(negedge clk);cold_reset=0;
        repeat(4) tick();
        assert(upload_error && ioctl_wait && !upload_active && writes==0)
            else $fatal(1,"Z_FRONTEND_RESET_START_REJECTION");
        @(negedge clk);ioctl_download=0;ioctl_wr=0;
        tick();cases++;
        // A different index's existing download cannot become a new session.
        @(negedge clk);ioctl_download=1;ioctl_index=4;
        tick();
        @(negedge clk);ioctl_index=5;
        tick();
        assert(upload_error && ioctl_wait && !upload_active && writes==0)
            else $fatal(1,"Z_FRONTEND_MID_INDEX_REJECTION");
        @(negedge clk);ioctl_download=0;
        tick();cases++;
        check_upload_order=1;sequence_address=0;
        // Initial download and first wr simultaneous: wr held obeying wait.
        @(negedge clk);ioctl_download=1;ioctl_wr=1;ioctl_address=0;ioctl_data=font(0);
        #2;assert(ioctl_wait) else $fatal(1,"Z_FRONTEND_START_WAIT");
        tick(); // creates ownership; first byte remains offered
        while(ioctl_wait) tick();
        tick();repeat(3) tick();
        assert(accepted==1) else $fatal(1,"Z_FRONTEND_INITIAL_WR_CAPTURE");
        @(negedge clk);ioctl_wr=0;
        tick();
        for(integer a=1;a<262144;a++) send_byte(a,font(a),(a%65536==0)?12:0);
        if(reset_case>=4 && reset_case<=7) begin
            // Final command already staged; find actual public acceptance
            // edge, not private state, and inject before its rising edge.
            @(negedge clk);#2;
            begin
                integer n;
                n=0;
                while(!(DDRAM_WE && !DDRAM_BUSY)) begin
                    @(negedge clk);#2;n++;
                    assert(n<20) else $fatal(1,"Z_FRONTEND_LAST_ACK_WITNESS");
                end
            end
            assert(writes==262143) else $fatal(1,"Z_FRONTEND_LAST_ACK_WITNESS");
            if(reset_case==4) cold_reset=1;
            else if(reset_case==5) upload_permitted=0;
            else if(reset_case==6) ioctl_index=6;
            else begin
                ioctl_wr=1;ioctl_address=25'd262144;ioctl_data=8'h99;
                assert(ioctl_wait) else $fatal(1,"Z_FRONTEND_EXCESS_WAIT");
                tick();
                assert(upload_error) else $fatal(1,"Z_FRONTEND_EXCESS_REJECTION");
                @(negedge clk);ioctl_wr=0;
            end
            ioctl_download=0;
            tick();bounded_idle();
            assert(!loaded && upload_error && !upload_active && writes==262144)
                else $fatal(1,"Z_FRONTEND_LAST_ACK_CANCEL");
            for(integer a=0;a<262144;a++)
                assert(memory[a]==ledger[a]) else $fatal(1,"Z_FRONTEND_FINAL_LEDGER");
            complete_retry();terminal();
        end
        // Main cannot send FILE_TX=0 until the final SPI ACK falls. The real
        // framework holds ACK while ioctl_wait is high, even with WR low.
        // A terminal count must not deadlock an otherwise complete image.
        begin
            integer n;
            n=0;
            while(ioctl_wait) begin
                tick();n++;
                assert(n<100) else $fatal(1,"Z_FRONTEND_END_COMMAND_WAIT");
            end
        end
        @(negedge clk);ioctl_download=0;
        assert(!loaded && upload_active) else $fatal(1,"Z_FRONTEND_EARLY_COMMIT");
        begin
            integer n;
            n=0;
            while(upload_active) begin tick();n++;assert(n<100) else $fatal(1,"Z_FRONTEND_COMMIT_DEADLINE");end
        end
        assert(loaded && !upload_error && writes==262144) else $fatal(1,"Z_FRONTEND_FULL_COMMIT");
        repeat(8) tick();
        assert(cpu_wait && !cpu_valid && reads==0) else $fatal(1,"Z_FRONTEND_UPLOAD_CPU_LEVEL");
        @(negedge clk);cpu_read=0;consumer_cancel=0;
        tick();
        for(integer a=0;a<262144;a++) begin
            assert(memory[a]==font(a)) else $fatal(1,"Z_FRONTEND_WHOLE_MEDIUM");
            read_delay=(a%8==0)?0:4;
            read_byte(a,a%65536==0);full_reads++;
        end
        cases++;
        if(reset_case>=1 && reset_case<=3) begin
            @(negedge clk);cpu_read=1;cpu_address=29;cpu_response_ack=1;
            expected_read_address=29;expected_read_pending=1;
            force_busy=reset_case==1;read_delay=20;
            if(reset_case==1) tick(); // frontend staged SEND, not yet backend captured
            else if(reset_case==2) begin
                while(!pending) tick(); // accepted DDR read, return outstanding
            end else while(!cpu_valid) tick();
            @(negedge clk);cold_reset=1;
            tick();
            @(negedge clk);cold_reset=0;force_busy=0;
            bounded_idle();
            assert(!loaded && !cpu_valid && cpu_wait) else $fatal(1,"Z_FRONTEND_COLD_CPU_DRAIN");
            complete_retry();terminal();
        end
        // Warm cancellation of a held response: stale ACK and held request
        // cannot unlock a fresh owner; only a SYS-observed request low can.
        @(negedge clk);cpu_read=1;cpu_address=9;read_delay=8;
        expected_read_address=9;expected_read_pending=1;
        while(!cpu_valid) tick();
        @(negedge clk);consumer_cancel=1;cpu_response_ack=1;
        begin
            longint unsigned old_consumed;
            old_consumed=consumed;tick();
            assert(consumed==old_consumed) else $fatal(1,"Z_FRONTEND_CANCEL_ACK_COLLISION");
        end
        @(negedge clk);consumer_cancel=0;
        begin
            longint unsigned saved_reads;
            saved_reads=reads;
            repeat(12) tick();
            assert(!cpu_valid && loaded && reads==saved_reads)
                else $fatal(1,"Z_FRONTEND_WARM_LEVEL_SUPPRESSION");
        end
        @(negedge clk);cpu_read=0; // ACK deliberately remains stale high
        tick();
        @(negedge clk);cpu_read=1;cpu_address=10;
        expected_read_address=10;expected_read_pending=1;
        while(!cpu_valid) tick();
        repeat(8) tick();
        assert(cpu_valid && cpu_data==ledger[10]) else $fatal(1,"Z_FRONTEND_STALE_ACK_OWNER");
        @(negedge clk);cpu_response_ack=0;
        tick();
        @(negedge clk);cpu_response_ack=1;
        tick();
        assert(!cpu_valid) else $fatal(1,"Z_FRONTEND_FRESH_ACK");
        @(negedge clk);cpu_read=0;cpu_response_ack=0;
        tick();read_byte(10,0);cases++;
        // Upload rising + byte0 in each publicly witnessed CPU owner phase.
        @(negedge clk);cpu_read=1;cpu_address=11;force_busy=preempt_phase==0;read_delay=20;
        expected_read_address=11;expected_read_pending=1;
        case(preempt_phase)
            0: begin repeat(3) tick();assert(DDRAM_RD && DDRAM_BUSY)
                else $fatal(1,"Z_FRONTEND_PREEMPT_COMMAND_WITNESS");end
            1: begin tick();assert(!DDRAM_RD && !pending && !cpu_valid)
                else $fatal(1,"Z_FRONTEND_PREEMPT_SEND_WITNESS");end
            2: begin while(!pending) tick();assert(!cpu_valid)
                else $fatal(1,"Z_FRONTEND_PREEMPT_RETURN_WITNESS");end
            3: begin while(!cpu_valid) tick();end
            default: $fatal(1,"Z_FRONTEND_PREEMPT_PROFILE");
        endcase
        @(negedge clk);ioctl_download=1;ioctl_wr=1;ioctl_address=0;ioctl_data=8'h5e;
        #2;assert(ioctl_wait) else $fatal(1,"Z_FRONTEND_PREEMPT_WAIT");
        tick();
        assert(!cpu_valid && !loaded) else $fatal(1,"Z_FRONTEND_QUIESCE");
        if(preempt_phase==0) begin
            repeat(5) tick();assert(ioctl_wait) else $fatal(1,"Z_FRONTEND_QUIESCE");
        end
        @(negedge clk);force_busy=0;
        begin
            integer n;
            n=0;
            while(ioctl_wait) begin
                tick();n++;
                assert(n<100) else $fatal(1,"Z_FRONTEND_QUIESCE_DEADLINE");
                assert(!cpu_valid) else $fatal(1,"Z_FRONTEND_STALE_UPLOAD_CPU");
            end
        end
        sequence_address=0;
        tick();repeat(10) tick();
        assert(memory[0]==8'h5e) else $fatal(1,"Z_FRONTEND_REPLACEMENT_BYTE");
        @(negedge clk);ioctl_wr=0;ioctl_download=0;cpu_read=0;
        bounded_idle();
        assert(!loaded && upload_error) else $fatal(1,"Z_FRONTEND_SHORT_REPLACEMENT");
        check_upload_order=0;cases++;
        for(integer k=0;k<8;k++) failed_session(k);
        // Complete retry uses a different value at EVERY byte, then reads
        // every byte through the CPU interface; no restoring private state.
        complete_retry();terminal();
    end
    initial begin #(DEADLINE);$fatal(1,"Z_FRONTEND_TEST_TIMEOUT");end
endmodule
