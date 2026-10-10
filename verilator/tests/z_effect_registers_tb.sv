// SPDX-License-Identifier: GPL-2.0-only
`timescale 1ns/1ps
module z_effect_registers_tb #(parameter BAD_ENABLE=0,BAD_ALIAS=0);
    bit clk=0,reset=1,enabled=1,rd=0,wr=0,clear_read=0;
    always #5 clk=~clk;
    logic [15:0] address=0;
    logic [7:0] data=0;
    wire selected,hold_read;
    wire [7:0] value,held,p,m,c,s;
    wire [15:0] held_address;
    x1_z_effect_registers dut(.clk(clk),.reset(reset),.enabled(enabled || BAD_ENABLE!=0),
        .io_read(rd),.io_write(wr),.clear_read(clear_read),
        .address(address ^ (BAD_ALIAS!=0 ? 16'h0100:16'h0000)),.data(data),
        .selected(selected),.read_data(value),.held_data(held),.read_hold(hold_read),
        .held_address(held_address),.position_control(p),.mosaic_control(m),.chroma_control(c),.scroll_control(s));
    function automatic [7:0] stored(input integer slot);
        case(slot) 0:return p;1:return m;2:return c;default:return s;endcase
    endfunction
    task automatic tick;@(posedge clk);#1;endtask
    task automatic idle;@(negedge clk);rd=0;wr=0;clear_read=1;tick();@(negedge clk);clear_read=0;endtask
    initial begin
        repeat(2) tick();@(negedge clk);reset=0;idle();
        // Disabled attempts must not change storage or select the port.
        enabled=0;address=16'h1fc1;data=8'ha5;wr=1;tick();
        assert(p==0 && !selected) else $fatal(1,"effect disabled write changed storage");
        idle();enabled=1;
        for(integer slot=0;slot<4;slot++) for(integer byte_value=0;byte_value<256;byte_value++) begin
            address=16'h1fc1+16'(slot);data=8'(byte_value);wr=1;tick();
            assert(stored(slot)==8'(byte_value)) else $fatal(1,"effect control readback mismatch");
            // A held write is one transaction, even if bundled data moves.
            data=~8'(byte_value);repeat(3) tick();
            assert(stored(slot)==8'(byte_value)) else $fatal(1,"effect held write repeated");
            idle();rd=1;tick();
            assert(selected && value==8'(byte_value) && hold_read && held==8'(byte_value) && held_address==address)
                else $fatal(1,"effect retained response mismatch");
            @(negedge clk);rd=0;address=16'h2fc1;tick();
            assert(!selected && value==8'hff && hold_read && held==8'(byte_value))
                else $fatal(1,"effect response retention corrupted");
            idle();assert(!hold_read && held==8'hff) else $fatal(1,"effect read clear failed");
        end
        for(integer a=0;a<65536;a++) begin
            address=16'(a);rd=1;tick();
            assert(selected==(a>=16'h1fc1 && a<=16'h1fc4)) else $fatal(1,"effect address alias selected");
            idle();wr=1;data=(a>=16'h1fc1 && a<=16'h1fc4)?8'hff:8'ha5;tick();idle();
            assert(p==8'hff && m==8'hff && c==8'hff && s==8'hff) else $fatal(1,"effect address sweep corrupted");
        end
        address=16'h1fc2;rd=1;wr=1;data=0;tick();
        assert(!selected && m==8'hff) else $fatal(1,"effect simultaneous strobes admitted");
        @(negedge clk);reset=1;tick();
        assert(p==0 && m==0 && c==0 && s==0 && !hold_read && !selected)
            else $fatal(1,"effect reset storage/tail mismatch");
        $display("PASS: effect CPU storage 1024 full-byte values, held transactions, 65536 exact addresses, disabled/ambiguous/reset/read-tail gates; not native effects");
        $finish;
    end
endmodule
