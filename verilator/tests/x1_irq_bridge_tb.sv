`timescale 1ns/1ps
module x1_irq_bridge_tb;
    reg clk=0; always #5 clk=~clk;
    reg reset=1, m1_n=1, mreq_n=1, iorq_n=1, rd_n=1;
    reg [7:0] data=0, ctc_vector=8'hd4, keyboard_vector=8'h52;
    reg keyboard_irq=0, ctc_irq=0, ctc_ieo=1;
    wire irq,keyboard_ack,ctc_ack,ctc_iei,ctc_reti,ctc_selected;
    wire [7:0] ack_vector;
    x1_irq_bridge dut(.*);
    task tick; @(posedge clk); #1; @(negedge clk); endtask
    task check(input bit ok,input string msg);
        if(!ok) $fatal(1,"%s",msg);
    endtask
    task opcode(input [7:0] value);
        data=value; m1_n=0; mreq_n=0; rd_n=0;
        repeat(6) tick();
        mreq_n=1; rd_n=1; #1;
    endtask
    task complete_fetch; tick(); m1_n=1; tick(); endtask
    initial begin
        repeat(2) tick(); reset=0; tick();
        ctc_irq=1; keyboard_irq=1; ctc_ieo=0; #1; check(irq&&ctc_iei,"CTC request wins simultaneous keyboard");
        m1_n=0; iorq_n=0; #1;
        check(ctc_ack&&ctc_selected&&!keyboard_ack,"CTC ACK start");
        tick(); ctc_irq=0; ctc_vector=8'hde; keyboard_irq=1; #1;
        check(!ctc_ack&&ctc_selected&&ack_vector==8'hd4&&!keyboard_ack,"ACK owner/vector held");
        repeat(8) tick(); m1_n=1; iorq_n=1; tick();
        check(!irq,"CTC service blocks downstream keyboard");
        opcode(8'hed); complete_fetch(); opcode(8'h4d);
        check(ctc_reti,"RETI routed to upstream CTC"); complete_fetch();
        ctc_ieo=1;
        m1_n=0; iorq_n=0; #1;
        check(keyboard_ack&&!ctc_ack&&!ctc_selected,"eligible keyboard ACK");
        repeat(3) tick(); keyboard_vector=8'hb7; keyboard_irq=0;
        ctc_irq=1; ctc_ieo=0; #1;
        check(keyboard_ack&&!ctc_ack&&ack_vector==8'h52,"held keyboard owner/vector despite new CTC and reply");
        repeat(20) tick(); m1_n=1; iorq_n=1; tick();
        check(ctc_iei&&irq,"keyboard creates no service latch");
        ctc_irq=0; ctc_ieo=1;
        m1_n=0; iorq_n=0; #1;
        check(!keyboard_ack&&!ctc_ack&&ack_vector==8'hff,"spurious ACK cannot consume mailbox");
        repeat(4) tick(); m1_n=1; iorq_n=1; tick();
        opcode(8'hed); complete_fetch(); opcode(8'h45);
        check(!ctc_reti,"RETN is not RETI"); complete_fetch();
        opcode(8'hcb); complete_fetch(); opcode(8'hed); complete_fetch(); opcode(8'h4d);
        check(!ctc_reti,"CB ED operand not prefix"); complete_fetch();
        opcode(8'hed); complete_fetch(); opcode(8'h4d);
        check(ctc_reti,"RETI decoded without keyboard service invention"); complete_fetch();
        opcode(8'hed); complete_fetch();
        // Ordinary memory read of 4D must not consume opcode prefix.
        data=8'h4d; mreq_n=0; rd_n=0; repeat(5) tick();
        mreq_n=1; rd_n=1; tick(); check(!ctc_reti,"data read is not RETI");
        opcode(8'h4d); check(ctc_reti,"real CTC RETI pulse");
        complete_fetch(); check(!ctc_reti,"RETI one pulse despite held fetch");
        opcode(8'hed); complete_fetch(); opcode(8'hed); complete_fetch(); opcode(8'h4d);
        check(!ctc_reti,"ED ED consumes second byte, not repeated prefix"); complete_fetch();
        opcode(8'hdd); complete_fetch(); opcode(8'hfd); complete_fetch();
        opcode(8'hcb); complete_fetch();
        data=8'hed; mreq_n=0; rd_n=0; repeat(4) tick();
        data=8'h4d; repeat(4) tick(); mreq_n=1; rd_n=1; tick();
        opcode(8'hed); complete_fetch(); opcode(8'h4d);
        check(ctc_reti,"indexed CB tail does not swallow next real RETI"); complete_fetch();
        reset=1; tick(); reset=0; tick();
        check(ctc_iei&&!irq,"reset clears service/prefix");
        $display("PASS: CTC-first IRQ ownership/vector hold, keyboard ACK continuity, spurious ACK, stretched fetch RETI and indexed CB/RETN/data exclusions");
        $finish;
    end
endmodule
