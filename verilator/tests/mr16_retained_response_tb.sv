// SPDX-License-Identifier: GPL-2.0-or-later
// Original standalone public-bus MR16 diagnostic. No hierarchical core access.
`timescale 1ns/1ps
module mr16_retained_response_tb #(parameter CE_DIVISOR=1, RESET_KIND=0);
    bit clk=0,reset=1,paused=0,warm=0;
    integer cycle=0,cursor=0,store_count=0,ack_count=0,read_count=0;
    wire ce=!paused && cycle%CE_DIVISOR==0;
    wire [15:0] address,data_out,p0;
    logic [15:0] data_in=0;
    wire memcs,wr;
    logic [3:0] irq=0;
    wire [3:0] ack;
    logic [15:0] rom[2048],ram[2048];
    logic [63:0] expected[64];
    integer expected_count=0,issue_cursor=0,check_cursor=0;
    logic [15:0] issued_address=0,issued_value=0;
    logic [15:0] last_store_address=0,last_store_value=0;
    bit old_write=0;
    bit old_ack=0,target_seen=0,done=0;
    string rom_file,oracle_file;
    mr16_x1 #(.RETAIN_RESPONSE(1)) dut (
        .I_RESET(reset),.I_CLK(clk),.I_CLKEN(ce),
        .O_A(address),.O_D(data_out),.I_D(data_in),.O_WR(wr),.O_MEMCS(memcs),
        .I_TMRG(1'b0),.O_P0(p0),.O_P1(),.O_P2(),.O_P3(),.O_P4(),.O_P5(),
        .O_P6(),.O_P7(),.O_P8(),.O_P9(),.O_PA(),.O_PB(),
        .I_P0(16'd0),.I_P1(warm?16'h5aa5:16'ha55a),.I_P2(16'd0),.I_P3(16'd0),
        .O_I4(),.O_I5(),.O_I6(),.O_I7(),.O_I8(),.O_I9(),.O_IA(),.O_IB(),
        .I_INT(irq),.O_ACK(ack)
    );
    // Independent external synchronous memory, with SYS write strobes exactly
    // as exposed by the wrapper. Never assume WR requires an instruction CE.
    always @(posedge clk) begin
        data_in <= address[12]?ram[address[11:1]]:rom[address[11:1]];
        if(!reset && memcs && wr) begin
            // WR is a level during sparse CE, not a transaction pulse. Every
            // SYS strobe must agree; only the first advances the ordered plan.
            check_cursor=old_write?cursor-1:cursor;
            if(old_write) assert(address==last_store_address && data_out==last_store_value)
                else $fatal(1,"held public WR address/data changed");
            assert(address[12] && !address[0]) else $fatal(1,"illegal public RAM store");
            assert(check_cursor>=0 && check_cursor<expected_count && address==expected[check_cursor][63:48])
                else $fatal(1,"MR16 control/store-address oracle cursor=%0d actual=%h",check_cursor,address);
            assert((data_out & expected[check_cursor][31:16])==expected[check_cursor][15:0] ||
                   (expected[check_cursor][47:32]!=0 && data_out==expected[check_cursor][47:32]))
                else $fatal(1,"MR16 data/return oracle cursor=%0d address=%h actual=%h",check_cursor,address,data_out);
            ram[address[11:1]]<=data_out;store_count++;
            if(!old_write) begin cursor++;last_store_address=address;last_store_value=data_out;end
        end
        old_write<=!reset && memcs && wr;
        if(!reset && memcs && !wr && address[12]) read_count++;
        if(!reset && ack[0] && !old_ack) begin
            assert(warm && p0==16'h0011 && ack==4'b0001 && ack_count==0)
                else $fatal(1,"MR16 IRQ ACK control oracle");
            ack_count++;
        end
        old_ack=ack[0];
        if(!reset && !warm && !wr &&
           ((RESET_KIND==0 && memcs && address==16'h1100 && ce) ||
            (RESET_KIND==1 && !memcs && address==16'h2002 && ce) ||
            (RESET_KIND==2 && memcs && address==16'h17fe && ce))) begin
            assert(cursor==(RESET_KIND==0?1:RESET_KIND==1?11:3))
                else $fatal(1,"read issuance preceding-store witness wrong");
            issued_address=address;issue_cursor=cursor;
            issued_value=RESET_KIND==0?16'h1357:RESET_KIND==1?16'ha55a:16'h2468;
            target_seen=1;
            $display("EVENT issued read kind=%0d address=%h ce=%b cursor=%0d input=%h",RESET_KIND,address,ce,cursor,data_in);
        end
    end
    task automatic step;
        clk=0;#5;clk=1;#5;cycle++;
    endtask
    initial begin
        assert($value$plusargs("ROM=%s",rom_file) && $value$plusargs("ORACLE=%s",oracle_file) &&
               $value$plusargs("COUNT=%d",expected_count)) else $fatal(1,"frozen firmware/oracle required");
        assert(CE_DIVISOR==1 || CE_DIVISOR==3 || CE_DIVISOR==17 || CE_DIVISOR==32)
            else $fatal(1,"invalid cadence");
        assert(RESET_KIND>=0 && RESET_KIND<=2 && expected_count>0 && expected_count<=64)
            else $fatal(1,"invalid reset kind/oracle count");
        for(int i=0;i<2048;i++) ram[i]=16'hdead;
        $readmemh(rom_file,rom);$readmemh(oracle_file,expected,0,expected_count-1);
        repeat(8) step();reset=0;
        // Observe the issued public read, then stop CE through the first
        // stopped capture edge. Three stopped SYS edges establish the held
        // response without inspecting any private retention/core register.
        for(int i=0;i<10000*CE_DIVISOR && !target_seen;i++) step();
        assert(target_seen) else $fatal(1,"held-response reset target absent");
        assert(address!=issued_address) else $fatal(1,"issued read did not return bus to instruction fetch");
        if(RESET_KIND!=1) assert(data_in==issued_value)
            else $fatal(1,"synchronous issued RAM response witness wrong");
        paused=1;#1; // Settle the public combinational CE before sampling it.
        repeat(3) begin
            assert(!ce && cursor==issue_cursor) else $fatal(1,"response consumed during stopped issuance window");
            step();
        end
        assert(cursor==issue_cursor) else $fatal(1,"response store escaped stopped window");
        $display("EVENT held-window reset kind=%0d issued=%h fetch=%h value=%h stopped_SYS=3 cursor=%0d",RESET_KIND,issued_address,address,issued_value,cursor);
        assert(cursor<expected_count) else $fatal(1,"cold program unexpectedly completed");
        reset=1;warm=1;irq=0;repeat(8) step();
        assert(p0==0 && ack==0) else $fatal(1,"reset public GPIO/ACK oracle");
        cursor=0;old_ack=0;reset=0;repeat(3) step();paused=0;
        for(int i=0;i<20000*CE_DIVISOR && !done;i++) begin
            if(p0==16'h0011 && ack_count==0) irq=4'b0001;
            if(ack_count!=0) irq=0;
            step();done=p0==16'h00dd;
        end
        assert(done && cursor==expected_count && ack_count==1 && read_count>0)
            else $fatal(1,"MR16 completion/IRQ return control oracle cursor=%0d ack=%0d",cursor,ack_count);
        assert(ram[0]==16'h1357 && ram[1]==16'h2468 && ram[2]==16'haced &&
               ram[3]==16'h5aa5 && ram[4]==16'hbeef && ram[5]==16'h2468 &&
               ram[6]==16'h9876 && ram[7]==16'h1357 && ram[8]==16'h5aa5)
            else $fatal(1,"MR16 final RAM oracle");
        $display("PASS retained MR16 cadence=%0d reset_kind=%0d warm_stores=%0d total_stores=%0d irq=%0d",CE_DIVISOR,RESET_KIND,cursor,store_count,ack_count);
        $finish;
    end
endmodule
