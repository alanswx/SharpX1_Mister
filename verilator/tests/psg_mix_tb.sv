// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original scalar reference, no private assets or forced DUT state.
module psg_mix_tb;
    logic clk=0, reset=1, sample_ce=0;
    always #5 clk=~clk;
    logic [9:0] psg=0;
    wire signed [15:0] sound;
    logic signed [15:0] fm_left=0, fm_right=0;
    wire signed [15:0] left, right, mono;
    x1_psg_signed dut(.*);
    x1_fm_mix mix(.fm_left(fm_left),.fm_right(fm_right),.psg(sound),
                  .left(left),.right(right),.mono(mono));
    longint signed dc_ref=0, sound_ref=0, target, step;
    integer checks=0;
    function automatic integer clip(input longint signed value);
        if (value > 32767) return 32767;
        if (value < -32768) return -32768;
        return int'(value);
    endfunction
    function automatic integer boundary(input integer n);
        case(n)
            0: return -32768;
            1: return -32767;
            2: return -16384;
            3: return -1;
            4: return 0;
            5: return 1;
            6: return 16384;
            7: return 32766;
            default: return 32767;
        endcase
    endfunction
    task automatic tick(input bit rst, input bit ce, input integer value);
        @(negedge clk);
        reset=rst; sample_ce=ce; psg=10'(value);
        if(rst) begin dc_ref=0; sound_ref=0; end
        else if(ce) begin
            target=longint'(value)*32;
            sound_ref=target-(dc_ref/65536);
            // Independent signed division with explicit floor for negative
            // delta: SV division truncates toward zero, unlike arithmetic shift.
            step=target*65536-dc_ref;
            if(step < 0) step=-((-step+2047)/2048);
            else step=step/2048;
            dc_ref=dc_ref+step;
        end
        @(posedge clk); #1;
        assert(longint'($signed(sound))==sound_ref)
            else $fatal(1,"PSG sample mismatch got=%0d expected=%0d",sound,sound_ref);
        assert(longint'(dut.dc)==dc_ref)
            else $fatal(1,"PSG estimator mismatch got=%0d expected=%0d",dut.dc,dc_ref);
        assert(int'(left)==clip(longint'(fm_left)+sound_ref)) else $fatal(1,"left mix");
        assert(int'(right)==clip(longint'(fm_right)+sound_ref)) else $fatal(1,"right mix");
        assert(int'(mono)==clip(longint'(fm_left)+longint'(fm_right)+sound_ref))
            else $fatal(1,"mono mix (PSG must occur once)");
        checks++;
    endtask
    initial begin
        tick(1,0,0);
        for(integer gap=1;gap<=7;gap+=3) begin
            // All 1024 input values, ascending and descending; saturation
            // boundary cross-products exercise both signs of DC subtraction.
            for(integer direction=0;direction<2;direction++) begin
                for(integer v=0;v<1024;v++) begin
                    for(integer a=0;a<9;a++) begin
                        for(integer b=0;b<9;b++) begin
                            fm_left=16'(boundary(a)); fm_right=16'(boundary(b));
                            tick(0,1,direction != 0 ? 1023-v : v);
                            for(integer g=1;g<gap;g++) tick(0,0,(v+503)%1024);
                        end
                    end
                end
            end
            fm_left=0; fm_right=0;
            tick(1,0,1023);
            repeat(40960) tick(0,1,1023);
            assert(sound >= 0 && sound <= 1) else $fatal(1,"constant PSG did not settle");
            repeat(40960) tick(0,1,0);
            assert(sound >= -1 && sound <= 0) else $fatal(1,"zero PSG did not settle");
            // Asynchronous reset clears DC/output even while sample CE stops.
            tick(0,1,1023);
            @(negedge clk); sample_ce=0; #2; reset=1; #1;
            assert(sound==0 && dut.dc==0) else $fatal(1,"asynchronous reset failed");
            tick(1,0,1023);
            repeat(20) tick(0,1,0);
            assert(left==0 && right==0 && mono==0) else $fatal(1,"reset silence");
            $display("PASS PSG signed conversion + stereo/mono clipping CE gap=%0d",gap);
        end
        $display("PASS %0d independent scalar sample/mixer checks",checks);
        $finish;
    end
endmodule
