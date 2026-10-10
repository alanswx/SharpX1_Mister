`timescale 1ns/1ps
module fdc_byte_slots_tb;
    reg clk=0;
    always #15.625 clk=~clk; // explicit 32-MHz SYS clock
    reg reset=0, ce=0, start=0, stop=0, fm=0;
    wire boundary, active;
    x1_fdc_byte_slots dut(clk, reset, ce, start, stop, fm, boundary, active);
    integer countdown=0, period=32, pulses=0, edges=0;
    integer consumed=0;
    always @(posedge clk) if(boundary) consumed++;
    bit running=0;
    task automatic step(input bit r, c, s, t, f);
        bit expected;
        @(negedge clk);
        reset=r; ce=c; start=s; stop=t; fm=f;
        #1;
        expected=running && c && countdown==1 && !r && !t && !s;
        assert(boundary===expected) else
            $fatal(1,"byte boundary mismatch edge=%0d expected=%0d got=%0d countdown=%0d",edges,expected,boundary,countdown);
        if(expected) pulses++;
        @(posedge clk);
        if(r || t) begin running=0; countdown=0; period=32; end
        else if(s) begin running=1; period=f ? 64 : 32; countdown=period; end
        else if(running && c) begin
            countdown--;
            if(countdown==0) countdown=period;
        end
        #1;
        assert(active===running) else $fatal(1,"byte active mismatch");
        assert(consumed==pulses) else $fatal(1,"synchronous consumer mismatch");
        edges++;
    endtask
    initial begin
        step(1,1,1,0,1); // reset beats start
        for(integer mode=0;mode<2;mode++) begin
            for(integer divider=1;divider<=32;divider*=2) begin
                realtime previous_boundary, expected_ns;
                previous_boundary=0;
                expected_ns=(mode!=0 ? 64.0 : 32.0)*divider*31.25;
                step(0,1,1,0,mode!=0); // start edge never counts as slot edge
                for(integer i=0;i<5*((mode!=0) ? 64 : 32)*divider;i++) begin
                    integer previous_pulses;
                    previous_pulses=pulses;
                    step(0,(i%divider)==0,0,0,mode==0); // live FM changes cannot rephase
                    if(pulses!=previous_pulses) begin
                        if(previous_boundary!=0)
                            assert(($realtime-previous_boundary)==expected_ns) else
                                $fatal(1,"byte physical interval mismatch divider=%0d",divider);
                        previous_boundary=$realtime;
                    end
                end
                // Stopped enables hold a partially elapsed slot.
                for(integer i=0;i<11;i++) step(0,1,0,0,mode!=0);
                for(integer i=0;i<97;i++) step(0,0,0,0,mode==0);
                for(integer i=0;i<2*((mode!=0) ? 64 : 32);i++) step(0,1,0,0,mode!=0);
                step(0,1,0,1,mode!=0);
                for(integer i=0;i<70;i++) step(0,1,0,0,mode!=0);
            end
        end
        // Coincident stop/start always cancels, even on an eligible boundary.
        step(0,0,1,0,0);
        repeat(31) step(0,1,0,0,0);
        step(0,1,1,1,1);
        step(0,1,0,0,1);
        // Restart explicitly begins a fresh slot; reset suppresses pending due.
        step(0,1,1,0,1);
        repeat(63) step(0,1,0,0,0);
        step(1,1,0,0,0);
        step(0,1,0,0,0);
        // Independently check start-to-first-boundary physical time at every
        // SYS phase of explicit 1/2-MHz FDC enables, for both densities.
        for(integer mode=0;mode<2;mode++)
            for(integer divider=16;divider<=32;divider*=2)
                for(integer phase=0;phase<divider;phase++) begin
                    realtime started;
                    integer duration;
                    duration=phase+1+((mode!=0 ? 64 : 32)-1)*divider;
                    step(0,0,1,0,mode!=0);
                    started=$realtime;
                    for(integer i=0;i<duration;i++)
                        step(0,(i%divider)==phase,0,0,mode==0);
                    assert(($realtime-started)==duration*31.25) else
                        $fatal(1,"first byte physical phase mismatch");
                    assert(countdown==period) else $fatal(1,"first byte not completed");
                    step(0,1,0,1,0);
                end
        // Pause at terminal count, then explicitly restart while active.
        step(0,1,1,0,0);
        repeat(31) step(0,1,0,0,0);
        repeat(5) step(0,0,0,0,0);
        step(0,1,1,0,1);
        repeat(63) step(0,1,0,0,0);
        step(0,1,0,0,0);
        step(0,0,0,1,0);
        assert(pulses==181) else $fatal(1,"coverage count mismatch %0d",pulses);
        $display("PASS byte slots: 12 rate profiles, 96 start phases, 181 synchronous boundaries, active restart/terminal pause/reset/stop");
        $finish;
    end
endmodule
