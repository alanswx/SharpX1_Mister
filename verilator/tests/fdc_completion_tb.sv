`timescale 1ns/1ps
// Actual stream producer, independent per-edge completion lease oracle.
module fdc_completion_tb;
    reg clk=0;
    always #15.625 clk=~clk;
    reg reset=0, cancel=0, consume=0;
    reg begin_read=0, arm_write=0, launch_write=0, stop=0, write_accept=0;
    reg [7:0] write_value=8'hb5;
    reg [10:0] length=1;
    integer ticks=0, phase=0, divider=16, cases=0, captures=0;
    integer capture_phases=0;
    integer read_phases=0,write_phases=0;
    wire fdc_ce=(ticks%divider)==phase;
    wire done,lost,initial_abort,active,armed,valid,result_lost,result_abort;
    wire taken;
    integer consumed=0;
    bit expected_take=0,consume_lost=0,consume_abort=0;
    always @(posedge clk) if(taken) begin
        consumed++;
        consume_lost=result_lost; consume_abort=result_abort;
    end
    x1_fdc_stream_adapter stream(
        .clk(clk),.reset(reset),.fdc_ce(fdc_ce),.begin_read(begin_read),
        .arm_write(arm_write),.launch_write(launch_write),.stop(stop),
        .length(length),.source_byte(8'ha6),.read_accept(1'b0),.read_release(1'b1),
        .write_accept(write_accept),.write_value(write_value),.physical_dr(8'd0),
        .read_dr_load(),.read_dr_value(),.dr_value(),.drq(),.active(active),.armed(armed),
        .lost(lost),.done(done),.initial_abort(initial_abort),.byte_index(),.generation(),
        .response_valid(),.response_data(),.response_generation(),.read_ack(),
        .arrival(),.write_emit(),.write_byte(),.write_index());
    x1_fdc_completion lease(clk,reset,cancel,done,lost,initial_abort,consume,
                             valid,result_lost,result_abort,taken);
    bit expected_valid=0,expected_lost=0,expected_abort=0;
    task automatic step;
        @(negedge clk);
        expected_take=expected_valid && consume && !reset && !cancel;
        #1;
        assert(taken==expected_take) else $fatal(1,"completion consumption qualifier mismatch");
        if(expected_take) begin
            assert(result_lost==expected_lost && result_abort==expected_abort)
                else $fatal(1,"completion pre-edge result mismatch");
        end
        if(reset || cancel) begin expected_valid=0; expected_lost=0; expected_abort=0; end
        else if(done) begin
            expected_valid=1; expected_lost=lost; expected_abort=initial_abort;
            captures++; capture_phases|=1<<(ticks%8);
            if(!initial_abort) begin
                if(lost) read_phases|=1<<(ticks%8);
                else write_phases|=1<<(ticks%8);
            end
        end else if(consume) expected_valid=0;
        @(posedge clk); #1;
        assert(valid==expected_valid && result_lost==expected_lost && result_abort==expected_abort)
            else $fatal(1,"completion lease mismatch SYS=%0d",ticks);
        ticks++;
    endtask
    task automatic capture_result(input bit writing,missing);
        integer deadline;
        cancel=1; step(); cancel=0;
        if(writing) begin
            arm_write=1; step(); arm_write=0;
            if(!missing) begin write_accept=1; step(); write_accept=0; end
            launch_write=1; step(); launch_write=0;
        end else begin begin_read=1; step(); begin_read=0; end
        deadline=ticks+150*divider;
        while(!valid && ticks<deadline) step();
        assert(valid && result_lost==(!writing || missing) && result_abort==missing)
            else $fatal(1,"actual stream completion missing/wrong result");
        // CPU/controller CE stopped for longer than a byte. Result cannot
        // follow a later cleared producer pulse or disappear before consume.
        repeat(73) step();
        assert(!done && valid) else $fatal(1,"completion did not retain stopped-CE result");
        while((ticks%8)!=0) step();
        consume=1; step(); consume=0;
        assert(!valid) else $fatal(1,"completion not consumed once");
        repeat(17) step(); assert(!valid) else $fatal(1,"stale completion replayed");
        cases++;
    endtask
    initial begin
        reset=1; step(); reset=0;
        for(integer d=16;d<=32;d*=2) for(integer p=0;p<8;p++) begin
            divider=d; phase=p;
            capture_result(0,0); capture_result(1,0); capture_result(1,1);
            // Cancel the actual source pulse before the lease captures it.
            arm_write=1; step(); arm_write=0;
            launch_write=1; step(); launch_write=0;
            assert(done && initial_abort) else $fatal(1,"cancel fixture lacked source pulse");
            cancel=1; stop=1; step(); cancel=0; stop=0;
            repeat(19) step(); assert(!valid) else $fatal(1,"cancelled result published");
            // Cancel a result already pending, with no controller CE.
            arm_write=1; step(); arm_write=0;
            launch_write=1; step(); launch_write=0; step();
            assert(valid) else $fatal(1,"pending cancellation fixture lacked lease");
            cancel=1; consume=1; step(); cancel=0; consume=0;
            repeat(19) step(); assert(!valid) else $fatal(1,"pending cancellation failed");
        end
        reset=1; step(); reset=0;
        assert(capture_phases==255 && read_phases==255 && write_phases==255 && cases==48 && captures==64)
            else $fatal(1,"completion phase/count coverage mismatch mask=%h cases=%0d captures=%0d",capture_phases,cases,captures);
        // Actual initial-abort completion exchanged with an older pending
        // successful-write result. Consumer reads old fields before NBA.
        arm_write=1; step(); arm_write=0; write_accept=1; step(); write_accept=0;
        launch_write=1; step(); launch_write=0;
        while(!valid) step();
        assert(!result_lost && !result_abort) else $fatal(1,"exchange old result setup");
        arm_write=1; step(); arm_write=0; launch_write=1; step(); launch_write=0;
        assert(done && !result_lost && !result_abort) else $fatal(1,"exchange source setup");
        consume=1; step(); consume=0;
        assert(valid && result_lost && result_abort) else $fatal(1,"completion exchange lost new result");
        assert(!consume_lost && !consume_abort) else $fatal(1,"exchange consumed new instead of old result");
        consume=1; step(); consume=0; assert(!valid) else $fatal(1,"exchange consume failed");
        // Reset at an actual pending source event, independently of bus CE.
        arm_write=1; step(); arm_write=0; launch_write=1; step(); launch_write=0;
        assert(done) else $fatal(1,"reset source setup");
        reset=1; step(); reset=0;
        repeat(19) step(); assert(!valid) else $fatal(1,"reset source replayed");
        assert(consumed==50) else $fatal(1,"completion consumer count mismatch %0d",consumed);
        if($test$plusargs("overwrite")) begin
            // Deliberately violate one-outstanding-result contract using two
            // actual stream initial aborts, not a forced completion register.
            arm_write=1; step(); arm_write=0; launch_write=1; step(); launch_write=0; step();
            assert(valid) else $fatal(1,"overwrite fixture lacked first result");
            arm_write=1; step(); arm_write=0; launch_write=1; step(); launch_write=0; step();
            $fatal(1,"overwrite contract was not rejected");
        end
        $display("PASS actual-stream completion lease: 48 transfers, 64 captures, all eight CE phases, stopped enables/cancellation");
        $finish;
    end
    initial begin #100000000; $fatal(1,"completion fixture timeout"); end
endmodule
