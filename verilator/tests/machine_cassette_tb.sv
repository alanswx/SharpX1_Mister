// SPDX-License-Identifier: GPL-2.0-only
// Original generated-IPL/public-upload cassette integration diagnostic.
// Hierarchy is observation ONLY. No private ROM, forced state, RAM injection,
// host mailbox substitution, native STOP/PB0 equivalence or software-loader claim.
`timescale 1ps/1ps
module machine_cassette_tb #(parameter bit CASSETTE_ENABLED=1, RTC_ENABLED=0);
    bit clk=0,video_clk=0,reset=1,download=0,upload_wr=0;
    always #15625 clk=~clk;
    always #17500 video_clk=~video_clk;
    logic [7:0] index=0,upload_data=0;
    logic [24:0] upload_address=0;
    wire upload_wait;
    bit ps2_clock=1,ps2_data=1;
    bit mount=0,present=0,empty=0;
    wire ready,underflow;
    wire [7:0] mode,sensor;
    integer scenario=0,sample_count=256,cursor=0;
    bit producer=0,stimuli_done=0;
    wire sample_valid=producer && cursor<sample_count;
    // Original waveform, no TAP/private recording embedded. Long enough runs
    // of both levels for a real 4-MHz CPU polling PPI to observe both.
    wire sample_level=((cursor/5)%2)!=0;
    wire sample_last=cursor==sample_count-1;
    logic [15:0] controller_rom[4096];
    logic [7:0] ipl[8192];
    string firmware_path,ipl_path,trace_path;
    integer trace_fd,cycles=0,commands=0,accepted=0,timer_ack_edges=0,timer_ack_rises=0;
    integer warm_resets=0,tie_witnesses=0,stop_cycles=0,held_commit_cycles=0;
    logic [7:0] expected_mode=0;
    integer slot_age=0;
    bit inserted=0,ended=0,have_sample=0,held_level=0,held_last=0;
    bit previous_commit=0,previous_timer_ack=0;
    bit bus_read_seen=0,bus_write_seen=0;
    bit debug_trace=0;
    logic [7:0] previous_marker=0;
    sharpx1 #(.CASSETTE_ENABLE(CASSETTE_ENABLED),.RTC_ENABLE(RTC_ENABLED)) dut(
        .clk_sys(clk),.clk_28636(video_clk),.reset(reset),.pal(1'b0),.scandouble(1'b0),
        .ioctl_download(download),.ioctl_index(index),.ioctl_wr(upload_wr),
        .ioctl_addr(upload_address),.ioctl_dout(upload_data),.ioctl_wait(upload_wait),
        .ps2_clk_in(ps2_clock),.ps2_data_in(ps2_data),.joya_n(8'hff),.joyb_n(8'hff),
        .tape_mount(mount),.tape_present(present),.tape_empty(empty),
        .tape_sample_valid(sample_valid),.tape_sample_level(sample_level),.tape_sample_last(sample_last),
        .tape_sample_ready(ready),.tape_underflow(underflow),.tape_mode(mode),.tape_sensor(sensor),
        .sio_external_rx_clock(1'b0),.sio_external_tx_clock(1'b0),.sio_rxd(2'b11),
        .sio_cts_n(2'b11),.sio_dcd_n(2'b11),.sio_txd(),.sio_rts_n(),.sio_dtr_n(),
        .disk_ready(1'b0),.img_mounted(1'b0),.disk_wp(1'b1),.img_size(24'd0),
        .disk_ready_b(1'b0),.img_mounted_b(1'b0),.disk_wp_b(1'b1),.img_size_b(24'd0),
        .sd_drive(),.sd_lba(),.sd_rd(),.sd_wr(),.sd_ack(1'b0),
        .sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_din(),.sd_buff_wr(1'b0),
        .ce_pix(),.HBlank(),.HSync(),.VBlank(),.VSync(),.video(),.rgb(),.rgb12(),
        .audio(),.audio_left(),.audio_right(),.audio_mono(),.audio_sample());

    // Independent integer slot-age ledger (4000 physical SYS edges/sample),
    // not the production phase accumulator. Its inputs are accepted public
    // samples, mount/reset and observed executed GPIO commits; no deck state read.
    // Supported command edges freeze the slot; unsupported requests do not.
    always @(posedge clk) begin : ledger
        bit commit,accept_now,expect_accept;
        logic [7:0] cmd,expected_sensor;
        commit=!dut.core_reset && dut.cassette_command[8] && !previous_commit;
        cmd=dut.cassette_command[7:0];
        accept_now=sample_valid && ready;
        cycles++;
        if(debug_trace && !dut.core_reset && dut.subCPU.wram_cs && dut.subCPU.mem_we &&
            dut.subCPU.sub_addr>=16'h1092 && dut.subCPU.sub_addr<=16'h109e)
            $fdisplay(trace_fd,"%0d,mr16-work-store,%0d,%0d,0",cycles,dut.subCPU.sub_addr,dut.subCPU.wdata);
        if(!dut.core_reset && dut.subCPU.sub_cpu.timer_ack) begin
            timer_ack_edges++;
            if(!previous_timer_ack) timer_ack_rises++;
        end
        previous_timer_ack=!dut.core_reset && dut.subCPU.sub_cpu.timer_ack;
        if(dut.core_reset) previous_commit=0;
        else previous_commit=dut.cassette_command[8];
        if(!dut.io_read) bus_read_seen=0;
        if(!dut.io_write) bus_write_seen=0;
        if(!dut.core_reset && dut.io_read && !bus_read_seen) begin
            bus_read_seen=1;
            if(dut.a==16'h1900)
                $fdisplay(trace_fd,"%0d,host-read,%0d,0,0",cycles,dut.di);
        end
        if(!dut.core_reset && dut.io_write && !bus_write_seen) begin
            bus_write_seen=1;
            if(dut.a==16'h1900)
                $fdisplay(trace_fd,"%0d,host-write,%0d,0,0",cycles,dut.data_out);
        end
        if(commit) begin
            commands++;
            $fdisplay(trace_fd,"%0d,command,%0d,%0d,%0d",cycles,cmd,cursor,mount);
        end else if(dut.cassette_command[8] && !dut.core_reset) held_commit_cycles++;
        if(CASSETTE_ENABLED && !RTC_ENABLED) begin
            expect_accept=0;
            if(commit && cmd==0) begin
                inserted=0;ended=0;have_sample=0;held_level=0;slot_age=0;expected_mode=0;
            end else if(mount) begin
                inserted=present;ended=present && empty;have_sample=0;held_level=0;slot_age=0;
                expected_mode=present ? 1 : 0;
                if(commit && cmd==2) tie_witnesses++;
                $fdisplay(trace_fd,"%0d,mount,%0d,%0d,%0d",cycles,present,empty,commit);
            end else if(dut.core_reset) begin
                expected_mode=inserted ? 1 : 0;
            end else if(commit && cmd<=2) begin
                if(cmd==1 && inserted) expected_mode=1;
                if(cmd==2 && inserted && !ended) expected_mode=2;
            end else if(expected_mode==2) begin
                if(!have_sample) expect_accept=1;
                else begin
                    slot_age++;
                    if(slot_age==4000) begin
                        slot_age=0;
                        if(held_last) begin ended=1;have_sample=0;expected_mode=1;end
                        else expect_accept=1;
                    end
                end
            end
            assert(accept_now==expect_accept)
                else $fatal(1,"CASSETTE_SAMPLE_CADENCE cycle=%0d age=%0d cursor=%0d actual=%0d expected=%0d",cycles,slot_age,cursor,accept_now,expect_accept);
            if(expect_accept) begin
                assert(sample_valid) else $fatal(1,"CASSETTE_PRODUCER_NOT_PREBUFFERED");
                have_sample=1;held_level=sample_level;held_last=sample_last;accepted++;
                $fdisplay(trace_fd,"%0d,sample,%0d,%0d,%0d",cycles,cursor,sample_level,sample_last);
            end
            if(expected_mode==1 && have_sample && !dut.core_reset) stop_cycles++;
            expected_sensor=!inserted ? 8'h00 : ended ? 8'h02 : 8'h03;
            #1;
            assert(mode==expected_mode && sensor==expected_sensor)
                else $fatal(1,"CASSETTE_MODE_SENSOR_LEDGER cycle=%0d actual=%h/%h expected=%0d/%h",cycles,mode,sensor,expected_mode,expected_sensor);
            assert(!underflow) else $fatal(1,"CASSETTE_UNEXPECTED_UNDERFLOW");
            assert(dut.cassette_waveform==(expected_mode==2 && have_sample && held_level))
                else $fatal(1,"CASSETTE_WAVEFORM_LEDGER");
            if(mount) cursor=0;
            else if(accept_now) cursor++;
        end else #1;
        if(dut.RAM.mem['hf010]!=previous_marker) begin
            previous_marker=dut.RAM.mem['hf010];
            $fdisplay(trace_fd,"%0d,cpu-marker,%0d,%0d,%0d",cycles,previous_marker,cursor,mode);
        end
    end
    task automatic tick;@(posedge clk);#2;endtask
    task automatic marker(input [7:0] value);
        while(dut.RAM.mem['hf010]!=value) tick();
    endtask
    task automatic upload_byte(input [7:0] kind,input integer address,input [7:0] value);
        @(negedge clk);index=kind;upload_address=25'(address);upload_data=value;
        download=1;upload_wr=1;
        while(upload_wait) tick();
        tick();@(negedge clk);upload_wr=0;
    endtask
    task automatic mount_media;
        @(negedge clk);present=1;empty=scenario==4;producer=!empty;mount=1;
        tick();@(negedge clk);mount=0;
    endtask
    task automatic ps2_byte(input [7:0] value);
        logic [10:0] packet;
        packet={1'b1,~^value,value,1'b0};
        for(integer b=0;b<11;b++) begin
            @(negedge clk);ps2_data=packet[b];
            repeat(1600) tick(); // 50 us setup/high
            @(negedge clk);ps2_clock=0;
            repeat(1600) tick(); // 50 us low, independently of MR16 CE
            @(negedge clk);ps2_clock=1;
        end
        @(negedge clk);ps2_data=1;
        repeat(3200) tick();
        $fdisplay(trace_fd,"%0d,ps2,%0d,0,0",cycles,value);
        if(debug_trace) $display("DEBUG ps2=%h sft=%h sreg=%h scnt=%h key=%h op1=%h",
            value,dut.subCPU.sub_w_ram.mem['h94/2],dut.subCPU.sub_w_ram.mem['h9a/2],
            dut.subCPU.sub_w_ram.mem['h9c/2],dut.subCPU.sub_w_ram.mem['hb8/2],dut.subCPU.OP1);
    endtask

    initial begin : stimuli
        assert($value$plusargs("ROM=%s",firmware_path) && $value$plusargs("IPL=%s",ipl_path) &&
            $value$plusargs("TRACE=%s",trace_path) && $value$plusargs("CASE=%d",scenario))
            else $fatal(1,"CASSETTE_MISSING_ARGUMENTS");
        assert(scenario>=0 && scenario<=5) else $fatal(1,"CASSETTE_INVALID_CASE");
        sample_count=(scenario==1 || scenario==2 || scenario==3) ? 4096 : 256;
        debug_trace=$test$plusargs("DEBUG");
        trace_fd=$fopen(trace_path,"w");assert(trace_fd!=0) else $fatal(1,"CASSETTE_TRACE_OPEN");
        $fdisplay(trace_fd,"sys_edge,event,value,a,b");
        $readmemh(firmware_path,controller_rom);$readmemh(ipl_path,ipl);
        repeat(8) tick();
        for(integer a=0;a<8192;a++) upload_byte(6,a,a%2==0 ? controller_rom[a/2][7:0] : controller_rom[a/2][15:8]);
        for(integer a=0;a<8192;a++) upload_byte(0,a,ipl[a]);
        download=0;upload_wr=0;repeat(8) tick();@(negedge clk);reset=0;
        marker(8'h10);mount_media();
        if(!CASSETTE_ENABLED) begin
            repeat(100) tick();
            assert(sensor==3 && mode==1) else $fatal(1,"CASSETTE_MOUNT_SENSOR_MISSING");
        end
        if(scenario==1) begin
            marker(8'h50);
            // Startup JOY_EN consumes C and A before key_ascii. The actual
            // F12 (07) make/release toggles it off, no private work-RAM write.
            ps2_byte(8'h07);ps2_byte(8'hf0);ps2_byte(8'h07);
            ps2_byte(8'h14);ps2_byte(8'h21);
            repeat(160000) tick();
            assert(mode==1) else $fatal(1,"CASSETTE_CTRL_C_STOP_MISSING");
            assert(!dut.ppi.ipb[0]) else $fatal(1,"CASSETTE_CTRL_C_BREAK_PB0_MISSING");
            marker(8'h60);ps2_byte(8'hf0);ps2_byte(8'h21);ps2_byte(8'hf0);ps2_byte(8'h14);
            marker(8'h70);ps2_byte(8'h1c);
            marker(8'h80);ps2_byte(8'hf0);ps2_byte(8'h1c);
        end else if(scenario==2) begin
            marker(8'h50);ps2_byte(8'h07);ps2_byte(8'hf0);ps2_byte(8'h07);
            ps2_byte(8'h21);ps2_byte(8'hf0);ps2_byte(8'h21);
            repeat(160000) tick();
            assert(mode==2 && dut.ppi.ipb[0]) else $fatal(1,"CASSETTE_PLAIN_C_FALSE_BREAK");
        end else if(scenario==3) begin
            marker(8'h50);while(cursor<16) tick();
            @(negedge clk);reset=1;warm_resets++;
            repeat(128) tick();upload_byte(7,0,1);download=0;upload_wr=0;
            repeat(32) tick();
            assert(sensor==3 && mode==1 && cursor==16)
                else $fatal(1,"CASSETTE_RESET_INDEX7_RETENTION");
            @(negedge clk);reset=0;
            marker(8'h01);marker(8'h50);
        end else if(scenario==5) begin
            marker(8'h15);
            // Observe executed GPIO, schedule mount before the SAME consuming
            // SYS edge. No CE/state/command forcing. Mount wins PLAY, not EJECT.
            do @(negedge clk); while(!(dut.cassette_command[8] && !previous_commit &&
                dut.cassette_command[7:0]==2 && !dut.core_reset));
            mount=1;tick();@(negedge clk);mount=0;
        end
        stimuli_done=1;
    end

    initial begin : completion
        wait(reset==0);
        for(integer i=0;i<8000000 && dut.halt_n;i++) tick();
        assert(!dut.halt_n) else $fatal(1,"CASSETTE_CPU_DEADLINE case=%0d marker=%h cursor=%0d mode=%h",scenario,dut.RAM.mem['hf010],cursor,mode);
        assert(dut.RAM.mem['hf000]==8'h43 && dut.RAM.mem['hf001]==8'h41 &&
            dut.RAM.mem['hf002]==8'h53 && dut.RAM.mem['hf003]==8'h53 && dut.RAM.mem['hf010]==8'h90)
            else $fatal(1,"CASSETTE_CPU_DATA_ORACLE case=%0d phase=%h result=%h",scenario,dut.RAM.mem['hf011],dut.RAM.mem['hf000]);
        // Let release frames finish; HALT is not a synthetic host completion.
        if(scenario==1) begin
            wait(stimuli_done);repeat(160000) tick();
            assert(dut.ppi.ipb[0]) else $fatal(1,"CASSETTE_BREAK_RELEASE_MISSING");
        end
        assert(timer_ack_rises>=1 && held_commit_cycles>100 && commands>=3)
            else $fatal(1,"CASSETTE_EXECUTED_CONTROLLER_WITNESS");
        // Independently emitted requests: unsupported requests cause NO commit;
        // repeated STOPs each cause one, a held GPIO high causes no extra. Reset
        // has two executed startup STOPs and cancels the first boot before STOP.
        case(scenario)
            0: assert(commands==8) else $fatal(1,"CASSETTE_COMMAND_COUNT");
            1,2: assert(commands==3) else $fatal(1,"CASSETTE_COMMAND_COUNT");
            3: assert(commands==5) else $fatal(1,"CASSETTE_COMMAND_COUNT");
            4: assert(commands==4) else $fatal(1,"CASSETTE_COMMAND_COUNT");
            5: assert(commands==9) else $fatal(1,"CASSETTE_COMMAND_COUNT");
            default: $fatal(1,"CASSETTE_INVALID_CASE");
        endcase
        if(scenario==0) begin
            assert(accepted==256 && stop_cycles>1000 && dut.RAM.mem['hf020]==3)
                else $fatal(1,"CASSETTE_EOF_RESUME_PPI_COVERAGE");
        end
        if(scenario==3) assert(warm_resets==1 && accepted>16)
            else $fatal(1,"CASSETTE_WARM_RESTART_COVERAGE");
        if(scenario==4) assert(accepted==0) else $fatal(1,"CASSETTE_EMPTY_ACCEPTED_SAMPLE");
        if(scenario==5) assert(tie_witnesses==1 && accepted==256)
            else $fatal(1,"CASSETTE_MOUNT_PLAY_PRIORITY_COVERAGE");
        $display("PASS cassette machine case=%0d accepted=%0d commits=%0d timer_ack_edges=%0d timer_ack_rises=%0d held_commit_edges=%0d stopped_sample_edges=%0d reset=%0d mount_play_ties=%0d; generated Z80/MR16, public upload/mailbox/PS2; ACK rises are witnesses, not handler counts; PB0 is experimental BREAK, NOT native tape STOP",scenario,accepted,commands,timer_ack_edges,timer_ack_rises,held_commit_cycles,stop_cycles,warm_resets,tie_witnesses);
        $fclose(trace_fd);$finish;
    end
endmodule
