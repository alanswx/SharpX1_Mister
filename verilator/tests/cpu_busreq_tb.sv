`timescale 1ns / 1ps
// Original Sharp X1 bring-up fixture. No firmware/game bytes or state injection.
// Exercise the actual rtl/cpu.v wrapper and its active TV80 dependency.
module cpu_busreq_tb;
    logic clk = 0, cen = 0, reset_n = 0;
    logic wait_n = 1, busrq_n = 1;
    wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
    wire [15:0] address;
    wire [7:0] dout;
    logic [7:0] memory [0:65535];
    wire [7:0] di = !iorq_n ? 8'h5c : memory[address];
    int phase = 0, enable_period = 1;
    int memory_writes = 0, io_writes = 0, grants = 0, cases = 0;
    logic memory_written = 0, io_written = 0;
    logic [7:0] last_io = 0;

    cpu dut (
        .clock(clk), .cep(cen), .cen(1'b0), .reset_n(reset_n),
        .wait_n(wait_n), .busrq_n(busrq_n), .int_n(1'b1),
        .dir(16'b0), .dirset(1'b0), .di(di), .a(address), .data_out(dout),
        .m1(m1_n), .mreq(mreq_n), .iorq(iorq_n),
        .rd(rd_n), .wr(wr_n), .rfsh_n(rfsh_n),
        .halt_n(halt_n), .busak_n(busak_n)
    );

    // Read-only hierarchical observations diagnose enable stability/boundaries;
    // CPU inputs, ROM fetches and external buses are the only stimulus.
    function automatic logic [101:0] observed_state();
        return {dut.Z80CPU.i_tv80_core.PC, dut.Z80CPU.i_tv80_core.SP,
                dut.Z80CPU.i_tv80_core.ACC, dut.Z80CPU.i_tv80_core.F,
                dut.Z80CPU.i_tv80_core.mcycle, dut.Z80CPU.i_tv80_core.tstate,
                address, dout, dut.Z80CPU.di_reg,
                m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n};
    endfunction

    task automatic tick(input bit enabled);
        bit old_ack, boundary;
        cen = enabled;
        #5;
        old_ack = busak_n;
        boundary = enabled && dut.Z80CPU.i_tv80_core.T_Res &&
                   !(dut.Z80CPU.i_tv80_core.tstate[2] && !wait_n) &&
                   dut.Z80CPU.i_tv80_core.BusReq_s;
        // External target accepts a write once per strobe, only with WAIT
        // released and CE active. Sparse CE/WAIT must not multiply side effects.
        if (reset_n && enabled && wait_n && busak_n && !wr_n) begin
            if (!mreq_n && !memory_written) begin
                if (address < 16'h8000)
                    $fatal(1, "CPU wrote original ROM at %h", address);
                memory[address] = dout;
                memory_writes++;
                memory_written = 1;
            end
            if (!iorq_n && !io_written) begin
                if (address[7:0] != 8'h10 || dout != 8'h36)
                    $fatal(1, "bad native OUT: address=%h data=%h", address, dout);
                last_io = dout;
                io_writes++;
                io_written = 1;
            end
        end
        clk = 1;
        #2; // Retain inherited #1ps assignments: use --timing, not --no-timing.
        if (mreq_n || wr_n) memory_written = 0;
        if (iorq_n || wr_n) io_written = 0;
        if (reset_n && !busak_n) begin
            if ({m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n} != 6'b111111)
                $fatal(1, "active CPU strobes during BUSACK: %b%b%b%b%b%b",
                       m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n);
            if (old_ack) begin
                if (!boundary) $fatal(1, "BUSACK asserted before cycle boundary");
                grants++;
            end
        end
        #3;
        clk = 0;
    endtask

    task automatic step();
        tick((phase % enable_period) == 0);
        phase++;
    endtask

    task automatic install_original_rom();
        for (int i = 0; i < 65536; i++) memory[i] = 0;
        // DI; LD SP,C000; LD A,35; LD (8000),A; LD A,(8000); INC A;
        // OUT (10),A; IN A,(11); LD (8001),A; LD A,AA; LD (8002),A;
        // LD A,(8003); LD (8004),A; HALT.
        memory[0] = 8'hf3;
        memory[1] = 8'h31; memory[2] = 0; memory[3] = 8'hc0;
        memory[4] = 8'h3e; memory[5] = 8'h35;
        memory[6] = 8'h32; memory[7] = 0; memory[8] = 8'h80;
        memory[9] = 8'h3a; memory[10] = 0; memory[11] = 8'h80;
        memory[12] = 8'h3c;
        memory[13] = 8'hd3; memory[14] = 8'h10;
        memory[15] = 8'hdb; memory[16] = 8'h11;
        memory[17] = 8'h32; memory[18] = 1; memory[19] = 8'h80;
        memory[20] = 8'h3e; memory[21] = 8'haa;
        memory[22] = 8'h32; memory[23] = 2; memory[24] = 8'h80;
        memory[25] = 8'h3a; memory[26] = 3; memory[27] = 8'h80;
        memory[28] = 8'h32; memory[29] = 4; memory[30] = 8'h80;
        memory[31] = 8'h76;
        memory[16'h8003] = 8'h12;
    endtask

    task automatic reset_cpu();
        reset_n = 0;
        wait_n = 1;
        busrq_n = 1;
        repeat (4) tick(0);
        if (!busak_n || address != 0 || !halt_n ||
            {mreq_n, iorq_n, rd_n, wr_n} != 4'b1111)
            $fatal(1, "asynchronous reset failed with CE stopped");
        phase = 0;
        memory_writes = 0;
        io_writes = 0;
        memory_written = 0;
        io_written = 0;
        last_io = 0;
        reset_n = 1;
    endtask

    task automatic finish_program(input logic [7:0] owner_byte);
        bit finished;
        finished = 0;
        for (int i = 0; i < 4000; i++) begin
            step();
            if (!halt_n) begin
                finished = 1;
                break;
            end
        end
        if (!finished) $fatal(1, "original fixture did not reach HALT");
        if (memory[16'h8000] != 8'h35 || memory[16'h8001] != 8'h5c ||
            memory[16'h8002] != 8'haa || memory[16'h8004] != owner_byte ||
            memory_writes != 4 || io_writes != 1 || last_io != 8'h36)
            $fatal(1, "continuation lost/duplicated memory or I/O transfer");
    endtask

    // 0=fetch, 1=memory read, 2=memory write, 3=I/O read, 4=I/O write.
    function automatic bit target_cycle(input int kind);
        case (kind)
            0: return !m1_n && !mreq_n && !rd_n && address == 16'h0004;
            1: return m1_n && !mreq_n && !rd_n && address == 16'h8000;
            2: return !mreq_n && !wr_n && address == 16'h8000;
            3: return !iorq_n && !rd_n && address[7:0] == 8'h11;
            4: return !iorq_n && !wr_n && address[7:0] == 8'h10;
            default: return 0;
        endcase
    endfunction

    task automatic freeze_check(input int master_edges);
        logic [101:0] saved;
        logic sampled_request;
        int writes_before, io_before;
        saved = observed_state();
        sampled_request = dut.Z80CPU.i_tv80_core.BusReq_s;
        writes_before = memory_writes;
        io_before = io_writes;
        repeat (master_edges) begin
            tick(0);
            if (observed_state() !== saved ||
                dut.Z80CPU.i_tv80_core.BusReq_s !== sampled_request ||
                memory_writes != writes_before || io_writes != io_before)
                $fatal(1, "CPU changed while CE stopped");
        end
    endtask

    task automatic exercise(input int kind, input bit reset_owner);
        bit found;
        int writes_before, io_before;
        logic [15:0] pc_owned;
        install_original_rom();
        reset_cpu();
        found = 0;
        for (int i = 0; i < 4000; i++) begin
            step();
            if (target_cycle(kind)) begin
                found = 1;
                break;
            end
        end
        if (!found) $fatal(1, "target cycle %0d never occurred", kind);
        wait_n = 0;
        busrq_n = 0;
        freeze_check(20); // Request and WAIT transitions cannot bypass CE.
        writes_before = memory_writes;
        io_before = io_writes;
        // Hold the current cycle in WAIT long enough to sample pending BUSRQ.
        for (int i = 0; i < 16 * enable_period; i++) begin
            step();
            if (!busak_n || !target_cycle(kind) ||
                memory_writes != writes_before || io_writes != io_before)
                $fatal(1, "premature grant/cycle change during WAIT kind=%0d", kind);
        end
        if (!dut.Z80CPU.i_tv80_core.BusReq_s)
            $fatal(1, "request was not sampled on enabled edges");
        freeze_check(20);
        wait_n = 1;
        found = 0;
        for (int i = 0; i < 100 * enable_period; i++) begin
            step();
            if (!busak_n) begin found = 1; break; end
        end
        if (!found) $fatal(1, "no grant after WAIT released kind=%0d", kind);
        if (memory_writes != writes_before + ((kind == 2) ? 1 : 0) ||
            io_writes != io_before + ((kind == 4) ? 1 : 0))
            $fatal(1, "in-flight write did not finish exactly once before grant");
        pc_owned = dut.Z80CPU.i_tv80_core.PC;
        repeat (24 * enable_period) begin
            step();
            if (busak_n || dut.Z80CPU.i_tv80_core.PC != pc_owned ||
                memory_writes != writes_before + ((kind == 2) ? 1 : 0) ||
                io_writes != io_before + ((kind == 4) ? 1 : 0))
                $fatal(1, "CPU executed or wrote while external owner held bus");
        end
        freeze_check(20);
        // Synthetic external owner writes ordinary RAM only while granted.
        // This models bus ownership, not an implemented DMA controller.
        memory[16'h8003] = 8'hc7;
        if (reset_owner) begin
            reset_cpu(); // Asynchronous reset must revoke ACK even with CE=0.
        end else begin
            busrq_n = 1;
            freeze_check(20); // Release is also sampled on enabled edges.
            found = 0;
            for (int i = 0; i < 100 * enable_period; i++) begin
                step();
                if (busak_n) begin found = 1; break; end
            end
            if (!found) $fatal(1, "BUSACK did not release");
        end
        finish_program(8'hc7);
        cases++;
        $display("PASS period=%0d kind=%0d reset_owner=%0d", enable_period, kind, reset_owner);
    endtask

    initial begin
        for (int profile = 0; profile < 3; profile++) begin
            case (profile)
                0: enable_period = 1;
                1: enable_period = 4;
                2: enable_period = 7;
            endcase
            install_original_rom();
            reset_cpu();
            finish_program(8'h12); // Control run: no request/grant required.
            for (int kind = 0; kind < 5; kind++) exercise(kind, 0);
            exercise(2, 1);
        end
        if (grants != 18 || cases != 18)
            $fatal(1, "coverage count mismatch grants=%0d cases=%0d", grants, cases);
        $display("PASS TV80 BUSRQ/BUSACK: 18 WAIT/ownership/release/reset cases, 3 native controls");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "global CPU arbitration timeout");
    end
endmodule
