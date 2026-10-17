// SPDX-License-Identifier: GPL-2.0-only
// Original standalone public-pin qualification; real frontend and DDR backend.
`timescale 1ns/1ps
module x1_z_kanji_arbiter_tb #(parameter integer SYS_HALF_PS=15625);
    bit clk=0;
    initial forever begin #(SYS_HALF_PS*1ps);clk=~clk;end
    localparam logic [28:0] BASE=29'h06123400;
    logic cpu_enabled=0,cache_enabled=0,cpu_cancel=0;
    logic cpu_read=0,cache_read=0,cpu_response_ack=0,cache_response_ack=0;
    logic [17:0] cpu_address=0,cache_address=0;
    wire cpu_wait,cpu_valid,cache_valid,idle,font_read,font_valid,font_response_ack;
    wire [7:0] cpu_data,cache_data,font_data;
    wire [17:0] font_address;
    x1_z_kanji_arbiter dut(.*);
    logic cold_reset=0,consumer_cancel=0,ioctl_download=0,ioctl_wr=0;
    logic [24:0] ioctl_address=0;
    logic [7:0] ioctl_data=0;
    wire ioctl_wait,loaded,upload_error,upload_active,frontend_wait;
    wire DDRAM_CLK,DDRAM_RD,DDRAM_WE;
    wire [7:0] DDRAM_BURSTCNT,DDRAM_BE;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DIN;
    logic DDRAM_BUSY=0,DDRAM_DOUT_READY=0;
    logic [63:0] DDRAM_DOUT=0;
    x1_z_kanji_frontend #(.BASE_WORD_ADDRESS(BASE)) frontend(
        .clk(clk),.cold_reset(cold_reset),.consumer_cancel(consumer_cancel),
        .cpu_read(font_read),.cpu_address(font_address),.cpu_wait(frontend_wait),
        .cpu_valid(font_valid),.cpu_data(font_data),.cpu_response_ack(font_response_ack),
        .ioctl_download(ioctl_download),.ioctl_index(8'd5),.ioctl_address(ioctl_address),
        .ioctl_wr(ioctl_wr),.ioctl_data(ioctl_data),.ioctl_wait(ioctl_wait),
        .upload_permitted(1'b1),.loaded(loaded),.upload_error(upload_error),.upload_active(upload_active),
        .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DOUT(DDRAM_DOUT),.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE)
    );
    byte unsigned memory_image[0:262143];
    integer intent_address[0:255];
    bit intent_cache[0:255];
    integer offers=0,requests=0,reads=0,writes=0,acks=0,cases=0;
    integer cpu_replies=0,cache_replies=0;
    bit previous_read=0,previous_ack=0;
    bit force_busy=0,hold_response=0,pending=0;
    integer response_delay=0;
    logic [28:0] pending_word=BASE;
    bit allowed_cpu=0,allowed_cache=0;
    integer expected_cpu=0,expected_cache=0;
    longint unsigned edges=0;
    function automatic [7:0] pattern(input integer a);
        return 8'((a*43)^(a>>7)^(a>>14)^8'ha7);
    endfunction
    function automatic [63:0] word_at(input logic [28:0] a);
        integer first;
        first=(int'(a)-int'(BASE))*8;
        for(integer b=0;b<8;b++) word_at[b*8+:8]=memory_image[first+b];
    endfunction
    task automatic tick(input integer count=1);
        repeat(count) begin @(posedge clk);#3;end
    endtask
    task automatic drive();
        @(negedge clk);#3;
    endtask
    task automatic expect_read(input bit cache_owner,input integer address_value);
        assert(offers<256) else $fatal(1,"Z_ARB_INTENT_OVERFLOW");
        intent_cache[offers]=cache_owner;intent_address[offers]=address_value;offers++;
    endtask
    task automatic await_reply(input bit cache_owner,input string marker="Z_ARB_REPLY_PROGRESS");
        integer deadline;
        deadline=0;
        while(!(cache_owner ? cache_valid : cpu_valid) && deadline<150) begin tick();deadline++;end
        assert(cache_owner ? cache_valid : cpu_valid) else $fatal(1,"%s",marker);
    endtask
    task automatic await_idle();
        integer deadline;
        deadline=0;
        while(!idle && deadline<150) begin tick();deadline++;end
        assert(idle) else $fatal(1,"Z_ARB_DRAIN_PROGRESS");
    endtask
    task automatic finish_owner(input bit cache_owner);
        drive();
        if(cache_owner) begin cache_response_ack=1;cache_read=0;end
        else begin cpu_response_ack=1;cpu_read=0;end
        tick();drive();
        if(cache_owner) begin cache_response_ack=0;allowed_cache=0;end
        else begin cpu_response_ack=0;allowed_cpu=0;end
    endtask
    task automatic offer_cpu(input integer address_value);
        drive();expect_read(0,address_value);expected_cpu=address_value;
        allowed_cpu=1;cpu_address=18'(address_value);cpu_read=1;
    endtask
    task automatic offer_cache(input integer address_value);
        drive();expect_read(1,address_value);expected_cache=address_value;
        allowed_cache=1;cache_address=18'(address_value);cache_read=1;
    endtask
    initial forever begin
        @(negedge clk);#1;
        DDRAM_BUSY=force_busy || edges%11==0;
        DDRAM_DOUT=word_at(pending ? pending_word : DDRAM_ADDR);
        DDRAM_DOUT_READY=pending && response_delay==0 && !hold_response;
    end
    initial forever begin
        @(posedge clk);
        edges++;
        assert(DDRAM_CLK==clk && DDRAM_BURSTCNT==1 && !(DDRAM_RD&&DDRAM_WE))
            else $fatal(1,"Z_ARB_DDR_SHAPE");
        assert(cpu_wait==(cpu_read&&!cpu_valid)) else $fatal(1,"Z_ARB_WAIT");
        assert(frontend_wait==(font_read&&!font_valid)) else $fatal(1,"Z_ARB_FRONTEND_WAIT");
        assert(!(cpu_valid&&cache_valid)) else $fatal(1,"Z_ARB_DUAL_REPLY");
        if(cpu_valid) begin
            assert(allowed_cpu) else $fatal(1,"Z_ARB_CPU_OWNER");
            assert(cpu_data==pattern(expected_cpu)) else $fatal(1,"Z_ARB_CPU_PAYLOAD");
        end else assert(cpu_data==0) else $fatal(1,"Z_ARB_IDLE_CPU_DATA");
        if(cache_valid) begin
            assert(allowed_cache) else $fatal(1,"Z_ARB_CACHE_OWNER");
            assert(cache_data==pattern(expected_cache)) else $fatal(1,"Z_ARB_CACHE_PAYLOAD");
        end else assert(cache_data==0) else $fatal(1,"Z_ARB_IDLE_CACHE_DATA");
        if(cpu_valid && cpu_response_ack) cpu_replies++;
        if(cache_valid && cache_response_ack) cache_replies++;
        if(font_read && !previous_read) begin
            assert(requests<offers && font_address==18'(intent_address[requests]))
                else $fatal(1,"Z_ARB_REQUEST_ORDER_ADDRESS");
            requests++;
        end
        if(font_read) begin
            assert(requests>0 && font_address==18'(intent_address[requests-1]))
                else $fatal(1,"Z_ARB_ADDRESS_HELD");
            if(cpu_valid) assert(!intent_cache[requests-1]) else $fatal(1,"Z_ARB_CPU_ROUTE");
            if(cache_valid) assert(intent_cache[requests-1]) else $fatal(1,"Z_ARB_CACHE_ROUTE");
        end
        if(font_response_ack) begin
            assert(font_read && font_valid && !previous_ack) else $fatal(1,"Z_ARB_ACK_OWNER");
            acks++;
        end
        if(idle) assert(!font_read && !font_response_ack) else $fatal(1,"Z_ARB_FALSE_IDLE");
        previous_read=font_read;previous_ack=font_response_ack;
        if(pending) begin
            if(DDRAM_DOUT_READY) pending=0;
            else if(response_delay>0) response_delay--;
        end
        if((DDRAM_RD||DDRAM_WE)&&!DDRAM_BUSY) begin
            if(DDRAM_WE) begin
                assert(writes<262144 && DDRAM_ADDR==BASE+29'(writes/8) &&
                    DDRAM_BE==(8'd1<<(writes%8)) && DDRAM_DIN=={8{pattern(writes)}})
                    else $fatal(1,"Z_ARB_UPLOAD_INTENT");
                for(integer b=0;b<8;b++) if(DDRAM_BE[b])
                    memory_image[(int'(DDRAM_ADDR)-int'(BASE))*8+b]=DDRAM_DIN[b*8+:8];
                writes++;
            end else begin
                assert(reads<offers && DDRAM_ADDR==BASE+29'(intent_address[reads]/8) &&
                    DDRAM_BE==8'hff && !pending) else $fatal(1,"Z_ARB_DDR_INTENT");
                reads++;pending=1;pending_word=DDRAM_ADDR;response_delay=3+reads%7;
            end
        end
    end
    initial begin
        tick(4);drive();ioctl_download=1;
        for(integer a=0;a<262144;a++) begin
            while(ioctl_wait) tick();
            drive();ioctl_address=25'(a);ioctl_data=pattern(a);ioctl_wr=1;
            tick();drive();ioctl_wr=0;
        end
        drive();ioctl_download=0;
        while(upload_active) tick();
        assert(loaded && !upload_error && writes==262144) else $fatal(1,"Z_ARB_FONT_LOADED");
        drive();cpu_enabled=1;cache_enabled=1;

        // Both clients continuously compete; one low sample rearms each request.
        // The intent ledger is constructed from the fixture sequence, not DUT data.
        for(integer n=0;n<64;n++) expect_read(1'(n%2),n%2==0 ? 131079+n/2*129 : 260000+n/2*31);
        expected_cpu=intent_address[0];expected_cache=intent_address[1];
        cpu_address=18'(expected_cpu);cache_address=18'(expected_cache);
        allowed_cpu=1;allowed_cache=1;cpu_read=1;cache_read=1;
        for(integer n=0;n<64;n++) begin
            await_reply(1'(n%2));
            repeat(3) begin
                tick();
                assert((n%2==0 ? cpu_valid : cache_valid) &&
                    requests==n+1 && reads==n+1 && acks==n)
                    else $fatal(1,"Z_ARB_HELD_RESPONSE");
            end
            finish_owner(1'(n%2));
            if(n+2<64) begin
                if(n%2==0) begin
                    expected_cpu=intent_address[n+2];cpu_address=18'(expected_cpu);cpu_read=1;allowed_cpu=1;
                end else begin
                    expected_cache=intent_address[n+2];cache_address=18'(expected_cache);cache_read=1;allowed_cache=1;
                end
            end
        end
        await_idle();tick(5);cases++;

        // Captured address survives changing inputs and early request removal.
        offer_cpu(262143);tick();
        drive();cpu_address=0;cpu_read=0;cpu_enabled=0;
        await_reply(0,"Z_ARB_CPU_DISABLED_OWNER");tick(4);finish_owner(0);await_idle();cases++;
        drive();cpu_enabled=1;

        // Stale high ACK cannot consume a fresh response (both clients).
        for(integer c=0;c<2;c++) begin
            if(c==0) offer_cpu(131074);else offer_cache(196613);
            await_reply(1'(c));finish_owner(1'(c));
            // Keep ACK high across the next transaction; read still gets a low sample.
            if(c==0) cpu_response_ack=1;else cache_response_ack=1;
            await_idle();
            if(c==0) offer_cpu(131075);else offer_cache(196614);
            await_reply(1'(c));
            repeat(8) begin
                tick();assert(c==0 ? cpu_valid : cache_valid) else $fatal(1,"Z_ARB_STALE_ACK");
            end
            drive();if(c==0) cpu_response_ack=0;else cache_response_ack=0;
            tick();finish_owner(1'(c));await_idle();
        end
        cases++;

        // A read held high after completion is never admitted twice.
        for(integer c=0;c<2;c++) begin
            if(c==0) offer_cpu(200001);else offer_cache(200002);
            await_reply(1'(c));drive();
            if(c==0) cpu_response_ack=1;else cache_response_ack=1;
            tick();drive();
            if(c==0) begin cpu_response_ack=0;allowed_cpu=0;end
            else begin cache_response_ack=0;allowed_cache=0;end
            await_idle();tick(12);
            assert(requests==offers && idle) else $fatal(1,"Z_ARB_HELD_READ_REPLAY");
            drive();if(c==0) cpu_read=0;else cache_read=0;tick();
        end
        cases++;

        // CPU cancellation while DDR is BUSY, with a waiting cache owner.
        drive();force_busy=1;offer_cpu(131081);tick(6);
        offer_cache(260007);tick(6);
        drive();cpu_cancel=1;cpu_enabled=0;allowed_cpu=0;
        tick();drive();cpu_cancel=0;tick(6);
        assert(!idle && !cpu_valid && !cache_valid && acks==reads)
            else $fatal(1,"Z_ARB_CANCEL_DRAIN_WAIT");
        drive();force_busy=0;
        await_reply(1);finish_owner(1);await_idle();
        drive();cpu_read=0;tick();drive();cpu_enabled=1;cases++;

        // Cancellation after DDR command acceptance must retain its delayed reply.
        drive();hold_response=1;offer_cpu(200008);
        while(!pending) tick();
        drive();cpu_cancel=1;allowed_cpu=0;tick();drive();cpu_cancel=0;
        tick(12);assert(!idle && !cpu_valid) else $fatal(1,"Z_ARB_PENDING_CANCEL_DRAIN");
        drive();hold_response=0;await_idle();drive();cpu_read=0;tick();cases++;

        // Cancellation of a held CPU result also uses one real frontend ACK.
        offer_cpu(200009);await_reply(0);
        drive();cpu_cancel=1;allowed_cpu=0;tick();drive();cpu_cancel=0;
        await_idle();drive();cpu_read=0;tick();cases++;

        // Admission disabling never revokes cache ownership or its held result.
        drive();force_busy=1;offer_cache(262140);tick(6);
        drive();cache_enabled=0;cpu_enabled=0;cpu_cancel=1;
        tick(6);
        assert(!idle && !cache_valid) else $fatal(1,"Z_ARB_CACHE_QUIESCE_DRAIN");
        drive();force_busy=0;await_reply(1,"Z_ARB_CACHE_QUIESCE_REPLY");
        repeat(12) begin
            tick();assert(cache_valid && !idle) else $fatal(1,"Z_ARB_CACHE_QUIESCE_OWNER");
        end
        finish_owner(1);await_idle();
        // Only now is frontend cancellation safe. Cache must still need a new offer.
        drive();consumer_cancel=1;tick();drive();consumer_cancel=0;cpu_cancel=0;
        tick(5);assert(idle && loaded) else $fatal(1,"Z_ARB_QUIESCE_COMPLETE");
        cases++;

        // Both admission gates block new high requests, even while idle.
        drive();cpu_read=1;cache_read=1;tick(12);
        assert(idle && requests==offers) else $fatal(1,"Z_ARB_ADMISSION_BLOCKED");
        drive();cpu_read=0;cache_read=0;tick();drive();cpu_enabled=1;cache_enabled=1;
        offer_cache(262139);await_reply(1);finish_owner(1);await_idle();cases++;
        tick(6);
        assert(requests==offers && reads==offers && acks==offers && !pending &&
            offers==77 && cases==9 && writes==262144 && loaded && !upload_error)
            else $fatal(1,"Z_ARB_FINAL_LEDGER");
        $display("PASS Z_ARB cases=%0d reads=%0d requests=%0d acks=%0d writes=%0d cpu_ack_edges=%0d cache_ack_edges=%0d sys_half=%0d edges=%0d",
            cases,reads,requests,acks,writes,cpu_replies,cache_replies,SYS_HALF_PS,edges);
        $finish;
    end
    initial begin #200ms;$fatal(1,"Z_ARB_TEST_TIMEOUT");end
endmodule
