`timescale 1ps/1ps
// Original synthetic register/audio fixture, no CPU/BIOS/game or forced state.
module fm_tb #(parameter integer MASTER_HZ = 32000000, parameter bit MIXED_PSG=0);
    localparam longint unsigned HALF_PS = 64'd500000000000 / 64'(MASTER_HZ);
    logic clk=0, reset=1, enable=1;
    always #(HALF_PS) clk=!clk;
    logic cs=0, rd_n=1, wr_n=1, a0=0;
    logic [7:0] data=0;
    wire [7:0] status;
    wire wait_n, irq_n, ct1, ct2, sample, ce4, ce2, fault;
    wire signed [15:0] left, right;
    logic psg_bdir=0, psg_bc1=0;
    logic [7:0] psg_din=0;
    wire [9:0] psg_raw;
    wire signed [15:0] audio_left, audio_right, audio_mono;
    generate if(MIXED_PSG) begin: mixed
        jt49_bus psg(.rst_n(!reset),.clk(clk),.clk_en(ce2),
            .bdir(psg_bdir),.bc1(psg_bc1),.din(psg_din),.sel(1'b1),
            .sound(psg_raw),.dout(),.A(),.B(),.C(),.sample(),
            .IOA_in(8'hff),.IOB_in(8'hff),.IOA_out(),.IOB_out(),.IOA_oe(),.IOB_oe());
        x1_audio_mix mix(.clk(clk),.reset(reset),.sample_ce(sample),.psg(psg_raw),
            .fm_left(left),.fm_right(right),.left(audio_left),.right(audio_right),.mono(audio_mono));
    end else begin: unmixed
        assign psg_raw=0;
        assign audio_left=left;
        assign audio_right=right;
        assign audio_mono=0;
    end endgenerate
    x1_fm #(.MASTER_HZ(MASTER_HZ)) dut (
        .clk(clk), .reset(reset), .enable(enable), .cpu_cs(cs),
        .cpu_rd_n(rd_n), .cpu_wr_n(wr_n), .cpu_a0(a0), .cpu_data_in(data),
        .cpu_data_out(status), .wait_n(wait_n), .irq_n(irq_n),
        .ct1(ct1), .ct2(ct2), .sample(sample), .left(left), .right(right),
        .cen_chip(ce4), .cen_half(ce2), .protocol_error(fault)
    );
    longint unsigned enabled_edges=0, chip_ticks=0, half_ticks=0;
    integer dispatches=0, edges=0;
    integer busy_half_edges=0;
    logic old_busy=0;
    always @(posedge clk or posedge reset) begin
        if(reset) begin busy_half_edges=0; old_busy=0; end
        else begin
            if(dut.dispatch && dut.saved_a0) begin
                assert(!dut.status[7]) else $fatal(1,"fixture wrote data while YM busy");
                busy_half_edges=0;
            end else if(ce2 && old_busy) busy_half_edges++;
            #1;
            if(old_busy && !dut.status[7])
                assert(busy_half_edges==32) else $fatal(1,"JT51 busy interval=%0d half-chip ticks",busy_half_edges);
            old_busy=dut.status[7];
        end
    end
    always @(posedge clk or posedge reset) begin
        edges++;
        assert(edges < (MIXED_PSG ? 100000000 : 40000000)) else $fatal(1,"FM watchdog");
        if (reset) begin
            enabled_edges=0; chip_ticks=0; half_ticks=0; dispatches=0;
        end else begin
            if (dut.dispatch) dispatches++;
            assert(!ce2 || ce4) else $fatal(1,"half-rate enable without chip enable");
            if (enable) begin
                enabled_edges++;
                if (ce4) chip_ticks++;
                if (ce2) half_ticks++;
                assert(chip_ticks == (enabled_edges * 64'd4000000) / 64'(MASTER_HZ)
                    && half_ticks == chip_ticks / 2)
                    else $fatal(1,"FM enable count/phase mismatch");
            end else assert(!ce4 && !ce2 && !sample)
                else $fatal(1,"stopped FM advanced");
        end
    end
    task automatic ticks(input integer count);
        repeat(count) @(negedge clk);
    endtask
    task automatic restart;
        @(negedge clk); reset=1; cs=0; rd_n=1; wr_n=1; enable=1;
        psg_bdir=0; psg_bc1=0;
        ticks(40); reset=0; ticks(2000);
        assert(irq_n && !ct1 && !ct2 && wait_n && !fault)
            else $fatal(1,"FM reset/interface not idle");
    endtask
    task automatic psg_register(input logic [7:0] regno, value);
        @(negedge clk); psg_bdir=1; psg_bc1=1; psg_din=regno;
        ticks(4); psg_bdir=0; psg_bc1=0; ticks(4);
        psg_bdir=1; psg_din=value; ticks(4);
        psg_bdir=0; ticks(4);
    endtask
    task automatic write_bus(input logic select, input logic [7:0] value,
                             input integer hold_extra=0);
        integer before_count;
        before_count=dispatches;
        @(negedge clk); cs=1; rd_n=1; wr_n=0; a0=select; data=value;
        #1; assert(!wait_n) else $fatal(1,"write latency not asserted");
        ticks(1);
        // Prove the bundled data was latched, not sampled late at dispatch.
        a0=!select; data=~value;
        while(!wait_n) ticks(1);
        ticks(hold_extra+32);
        assert(dispatches == before_count+1) else $fatal(1,"held write repeated/lost");
        cs=0; wr_n=1; ticks(1);
    endtask
    task automatic busy_clear;
        integer count;
        @(negedge clk); cs=1; wr_n=1; rd_n=0; a0=1;
        count=0;
        while(status[7]) begin
            ticks(1); count++;
            assert(count < 2000) else $fatal(1,"busy timeout");
        end
        cs=0; rd_n=1; ticks(1);
    endtask
    task automatic register_write(input logic [7:0] regno, input logic [7:0] value);
        busy_clear(); write_bus(0,regno); write_bus(1,value); busy_clear();
    endtask
    task automatic timer_period(input integer which, input integer preset);
        longint unsigned previous_tick, current_tick, expected;
        register_write(8'h14,8'h30);
        if(which==0) begin
            register_write(8'h10,8'(preset >> 2));
            register_write(8'h11,8'(preset & 3));
            expected=64'd64*(64'd1024-64'(preset));
            register_write(8'h14,8'h05);
        end else begin
            register_write(8'h12,8'(preset));
            expected=64'd1024*(64'd256-64'(preset));
            register_write(8'h14,8'h0a);
        end
        previous_tick=0;
        for(integer period=0; period<5; period++) begin
            while(irq_n) ticks(1);
            current_tick=chip_ticks;
            cs=1; rd_n=0; #1;
            assert(status[which] && !status[1-which])
                else $fatal(1,"timer status isolation");
            cs=0; rd_n=1;
            if(period!=0) assert(current_tick-previous_tick==expected)
                else $fatal(1,"timer period which=%0d actual=%0d expected=%0d",
                            which,current_tick-previous_tick,expected);
            previous_tick=current_tick;
            // Clear only this flag, preserving the running timer/IRQ enable.
            register_write(8'h14,which==0 ? 8'h15 : 8'h2a);
            assert(irq_n) else $fatal(1,"timer flag clear did not release IRQ");
        end
        register_write(8'h14,8'h30);
        ticks(20000);
        assert(irq_n) else $fatal(1,"stopped timers raised IRQ");
        $display("PASS FM timer=%0d preset=%0d period=%0d chip ticks MASTER=%0d",
                 which,preset,expected,MASTER_HZ);
    endtask
    task automatic note(input logic [7:0] pan);
        restart();
        for(integer channel=0; channel<8; channel++) begin
            register_write(8'h08,8'(channel)); // key off, all operators
            register_write(8'(8'h20+channel),8'h07); // no channel routed
            register_write(8'(8'h28+channel),8'h4a); // A4 reference key
            register_write(8'(8'h30+channel),0);
            register_write(8'(8'h38+channel),0);
        end
        for(integer op=0; op<32; op++) begin
            register_write(8'(8'h40+op),8'h01); // MUL=1, DT1=0
            register_write(8'(8'h60+op),8'h7f); // mute all operators initially
            register_write(8'(8'h80+op),8'h1f); // fastest attack, KS=0
            register_write(8'(8'ha0+op),8'h00); // no decay/AM
            register_write(8'(8'hc0+op),8'h00); // no secondary decay/DT2
            register_write(8'(8'he0+op),8'h0f); // sustain level zero, fast release
        end
        register_write(8'h20,pan|8'h07); // algorithm 7, no feedback
        register_write(8'h60,8'h20); // one carrier, bounded level
        register_write(8'h08,8'h08); // channel 0 operator M1 on
        if(MIXED_PSG) begin
            for(integer r=0;r<16;r++) psg_register(8'(r),0);
            // 2 MHz / (16 * 125) = 1 kHz, A only; no noise/envelope.
            psg_register(0,125); psg_register(1,0);
            psg_register(7,8'h3e); psg_register(8,8'h0f);
        end
    endtask
    integer output_file=0, samples=0;
    string prefix, output_name;
    longint unsigned last_sample_tick;
    longint signed dc_ref=0, psg_ref=0, delta_ref;
    integer raw_l, raw_r, raw_psg;
    logic signed [15:0] mix_fm_l=0, mix_fm_r=0, mix_psg=0;
    wire signed [15:0] mix_l, mix_r, mix_m;
    x1_fm_mix mixer(mix_fm_l,mix_fm_r,mix_psg,mix_l,mix_r,mix_m);
    integer mix_values[0:8]='{-32768,-32767,-16384,-1,0,1,16384,32766,32767};
    function automatic integer expected_clip(input integer value);
        return value>32767 ? 32767 : value < -32768 ? -32768 : value;
    endfunction
    initial begin
        if(!$value$plusargs("OUTPUT=%s",prefix)) prefix="fm";
        for(integer l=0;l<9;l++) for(integer r=0;r<9;r++) for(integer p=0;p<9;p++) begin
            mix_fm_l=16'(mix_values[l]); mix_fm_r=16'(mix_values[r]); mix_psg=16'(mix_values[p]);
            #1;
            assert(int'(mix_l)==expected_clip(mix_values[l]+mix_values[p])
                && int'(mix_r)==expected_clip(mix_values[r]+mix_values[p])
                && int'(mix_m)==expected_clip(mix_values[l]+mix_values[r]+mix_values[p]))
                else $fatal(1,"FM/PSG signed stereo/mono saturation mismatch");
        end
        $display("PASS FM/PSG mixer: 729 signed boundary stereo/mono cases");
        restart();
        assert(status==8'hff) else $fatal(1,"inactive status mux");
        // Queue while enables stop: immutable byte and WAIT survive 100 edges.
        enable=0; cs=1; wr_n=0; a0=0; data=8'h1b; ticks(1);
        a0=1; data=0; ticks(100);
        assert(!wait_n && dispatches==0 && !fault) else $fatal(1,"stopped queue changed");
        enable=1;
        while(!wait_n) ticks(1);
        cs=0; wr_n=1; ticks(1);
        write_bus(1,8'hc0,100);
        assert(ct1 && ct2 && !fault) else $fatal(1,"latched register/data or CT outputs wrong");
        // Busy is genuine chip status, not synthesized from the adapter queue.
        cs=1; rd_n=0; enable=0; ticks(1);
        assert(status[7]) else $fatal(1,"busy absent");
        ticks(100); assert(status[7]) else $fatal(1,"busy ran with enables stopped");
        enable=1; busy_clear();
        timer_period(0,1020); timer_period(0,1000);
        timer_period(1,254); timer_period(1,240);
        // Short raw reset while a write is queued and the FM enables stop.
        enable=0; cs=1; wr_n=0; a0=1; data=0; ticks(1);
        #1000; reset=1; #2000; reset=0;
        cs=0; wr_n=1; ticks(40);
        assert(wait_n && !ct1 && !ct2 && irq_n && !fault)
            else $fatal(1,"short reset did not cancel queued write/clear control");
        enable=1; ticks(2000);
        $display("PASS FM bus/held writes/bundled data, stopped-enable queue/busy, raw reset MASTER=%0d",MASTER_HZ);
        restart(); enable=0;
        cs=1; wr_n=0; a0=0; data=8'h1b; ticks(1);
        cs=0; wr_n=1; ticks(1);
        cs=1; wr_n=0; a0=0; data=8'h08; ticks(1);
        assert(fault && !wait_n) else $fatal(1,"illegal queue overwrite not diagnosed");
        cs=0; wr_n=1; enable=1;
        while(!wait_n) ticks(1);
        assert(dispatches==1) else $fatal(1,"queue overwrite was dispatched");
        write_bus(1,8'hc0);
        assert(ct1 && ct2 && fault) else $fatal(1,"queue overwrite changed original address or cleared fault");
        busy_clear(); restart();
        $display("PASS FM queue-overrun rejection and reset recovery MASTER=%0d",MASTER_HZ);
        for(integer profile=0; profile<5; profile++) begin
            case(profile)
                0,4: note(8'h40); // identical reset/programming for repeatability
                1: note(8'h80);
                2: note(8'hc0);
                3: note(8'h00);
            endcase
            // Warm up coupling to remove the initial PSG DC transient.
            samples=0;
            // The mix updates from reset, including programming time; the
            // capture oracle starts by tracking every sample in the separate
            // always block below, not by reading or seeding the DUT estimate.
            while(samples<(MIXED_PSG ? 20000 : 200)) begin @(negedge clk); if(sample) samples++; end
            output_name=$sformatf("%s-%0d.csv",prefix,profile);
            output_file=$fopen(output_name,"w");
            assert(output_file!=0) else $fatal(1,"cannot create FM waveform");
            samples=0; last_sample_tick=0;
            while(samples<6250) begin
                @(negedge clk);
                if(sample) begin
                    if(samples>0) assert(chip_ticks-last_sample_tick==64)
                        else $fatal(1,"FM sample cadence changed");
                    last_sample_tick=chip_ticks;
                    if(MIXED_PSG) begin
                        raw_l=int'(left); raw_r=int'(right); raw_psg=int'(psg_raw);
                        @(posedge clk); #1;
                        assert(int'(audio_left)==expected_clip(raw_l+int'(psg_ref))
                            && int'(audio_right)==expected_clip(raw_r+int'(psg_ref))
                            && int'(audio_mono)==expected_clip(raw_l+raw_r+int'(psg_ref)))
                            else $fatal(1,"genuine chip sample alignment/mix mismatch");
                        $fwrite(output_file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                            raw_l,raw_r,raw_psg,psg_ref,audio_left,audio_right,audio_mono);
                    end else $fwrite(output_file,"%0d,%0d\n",left,right);
                    samples++;
                end
            end
            $fclose(output_file);
        end
        $display("PASS FM register/timers/enable/sample diagnostics MASTER=%0d; external waveform verifier required",MASTER_HZ);
        $finish;
    end
    // Independent reference runs throughout reset/programming/warm-up. No
    // state injection: only the publicly driven raw PSG and sample pulse.
    always @(posedge clk or posedge reset) begin
        if(reset) begin dc_ref=0; psg_ref=0; end
        else if(MIXED_PSG && sample) begin
            psg_ref=longint'(psg_raw)*32-dc_ref/65536;
            delta_ref=longint'(psg_raw)*32*65536-dc_ref;
            if(delta_ref<0) delta_ref=-((-delta_ref+2047)/2048);
            else delta_ref=delta_ref/2048;
            dc_ref=dc_ref+delta_ref;
        end
    end
endmodule
