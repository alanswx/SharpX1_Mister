`timescale 1ns / 1ps
// Original Sharp X1 bring-up fixture: the TV80 refresh register through the
// rtl/cpu.v wrapper. R counts opcode fetches (bit 7 kept), LD A,R returns
// it with S/Z from R, LD R,A loads it. Games seed random numbers from R;
// Thunder Force loops forever when it always reads 0.
module cpu_refresh_tb;
    logic clk = 0, reset_n = 0;
    wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
    wire [15:0] address;
    wire [7:0] dout;
    logic [7:0] memory [0:65535];
    wire [7:0] di = memory[address];

    cpu dut (
        .clock(clk), .cep(1'b1), .cen(1'b0), .reset_n(reset_n),
        .wait_n(1'b1), .busrq_n(1'b1), .int_n(1'b1),
        .dir(16'b0), .dirset(1'b0), .di(di), .a(address), .data_out(dout),
        .m1(m1_n), .mreq(mreq_n), .iorq(iorq_n),
        .rd(rd_n), .wr(wr_n), .rfsh_n(rfsh_n),
        .halt_n(halt_n), .busak_n(busak_n)
    );

    always #5 clk = !clk;
    // One store per write strobe, taken at its end.
    logic [15:0] write_address;
    logic [7:0] write_data;
    logic writing = 0;
    always @(posedge clk) begin
        writing <= reset_n && !mreq_n && !wr_n;
        if (reset_n && !mreq_n && !wr_n) begin write_address <= address; write_data <= dout; end
        else if (writing) begin memory[write_address] <= write_data; end
    end

    // Fetches counted from reset: LD A,R reads R after both of its own.
    localparam logic [7:0] PROGRAM [0:30] = '{
        8'h31, 8'h00, 8'h91,    // 0000 LD SP,9100        R=1
        8'hED, 8'h5F,           // 0003 LD A,R            R=3 -> A=03
        8'h32, 8'h00, 8'h90,    // 0005 LD (9000),A       R=4
        8'h00, 8'h00, 8'h00,    // 0008 NOP x3            R=7
        8'hED, 8'h5F,           // 000B LD A,R            R=9 -> A=09
        8'h32, 8'h01, 8'h90,    // 000D LD (9001),A       R=A
        8'h3E, 8'hFE,           // 0010 LD A,FE           R=B
        8'hED, 8'h4F,           // 0012 LD R,A            R=FE
        8'hED, 8'h5F,           // 0014 LD A,R            R=80 -> A=80 (bit 7 kept, 7F+1 wraps)
        8'hF5,                  // 0016 PUSH AF           flags of LD A,R at 90FE
        8'h32, 8'h02, 8'h90,    // 0017 LD (9002),A
        8'h76,                  // 001A HALT
        8'h00, 8'h00, 8'h00, 8'h00
    };

    initial begin
        foreach (memory[i]) memory[i] = 8'h00;
        foreach (PROGRAM[i]) memory[i] = PROGRAM[i];
        repeat (4) @(posedge clk);
        reset_n = 1;
        fork
            wait (!halt_n);
            begin repeat (2000) @(posedge clk); $fatal(1, "no HALT"); end
        join_any
        disable fork;
        repeat (4) @(posedge clk);
        assert (memory[16'h9000] == 8'h03) else $fatal(1, "first LD A,R %h, want 03", memory[16'h9000]);
        assert (memory[16'h9001] == 8'h09) else $fatal(1, "second LD A,R %h, want 09", memory[16'h9001]);
        assert (memory[16'h9002] == 8'h80) else $fatal(1, "LD R,A then LD A,R %h, want 80", memory[16'h9002]);
        // F: S (bit 7) from R=80 set, Z (bit 6) clear.
        assert (memory[16'h90FE][7:6] == 2'b10) else $fatal(1, "LD A,R flags %h", memory[16'h90FE]);
        $display("PASS: R counts fetches (03, 09), LD R,A keeps bit 7 (FE -> 80), LD A,R flags S/Z from R");
        $finish;
    end
endmodule
