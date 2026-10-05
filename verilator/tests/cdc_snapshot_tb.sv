`timescale 1ns/1ps
// Independent counter/complement words detect tearing without presuming a
// particular clock phase. Stopped clocks exercise handshake backpressure.
module cdc_snapshot_case #(parameter SOURCE_HALF = 5, DEST_HALF = 7) (output reg done = 0);
    reg source_clk = 0, destination_clk = 0;
    reg source_running = 1, destination_running = 1;
    always #(SOURCE_HALF) if(source_running) source_clk = !source_clk;
    always #(DEST_HALF) if(destination_running) destination_clk = !destination_clk;
    reg [31:0] counter = 0;
    always @(posedge source_clk) counter <= counter + 1;
    wire [63:0] result;
    wire valid;
    x1_cdc_snapshot #(.WIDTH(64)) dut(source_clk,destination_clk,{counter,~counter},result,valid);
    integer publications = 0;
    reg [63:0] previous = 0;
    always @(negedge destination_clk) begin
        if(valid) begin
            assert(result[31:0] == ~result[63:32]) else $fatal(1,"torn snapshot %h",result);
            assert(result[63:32] <= counter) else $fatal(1,"future data");
            if(result != previous) begin
                if(publications != 0) assert(result[63:32] > previous[63:32]) else $fatal(1,"snapshot regressed");
                publications = publications + 1;
                previous = result;
            end
        end
    end
    initial begin
        reg [63:0] frozen;
        reg request_before;
        repeat(100) @(negedge destination_clk);
        assert(valid && publications > 5) else $fatal(1,"initial snapshot never progressed");
        // Allow the already-issued request/ACK to settle before checking
        // that no further publication is possible with source clock stopped.
        @(negedge source_clk); source_running = 0;
        repeat(12) @(negedge destination_clk);
        frozen = result;
        repeat(20) begin
            @(negedge destination_clk);
            assert(result == frozen) else $fatal(1,"stopped source changed data");
        end
        source_running = 1;
        repeat(100) @(negedge destination_clk);
        assert(result != frozen) else $fatal(1,"source restart did not recover");
        // Destination stop may let one in-flight capture finish in source;
        // no later overwrite is permitted until a new request is issued.
        @(negedge destination_clk); destination_running = 0;
        repeat(12) @(negedge source_clk);
        frozen = dut.held_data; request_before = dut.request;
        repeat(20) begin
            @(negedge source_clk);
            assert(dut.held_data == frozen && dut.request == request_before)
                else $fatal(1,"source overwrote an unconsumed publication");
        end
        destination_running = 1;
        repeat(100) @(negedge destination_clk);
        assert(result != frozen && publications > 15) else $fatal(1,"destination restart did not recover");
        done = 1;
    end
endmodule

module cdc_snapshot_tb;
    wire [3:0] done;
    cdc_snapshot_case #(5,17) a(done[0]);
    cdc_snapshot_case #(23,7) b(done[1]);
    cdc_snapshot_case #(11,13) c(done[2]);
    cdc_snapshot_case #(7,7) d(done[3]);
    initial begin
        wait(&done);
        $display("PASS: atomic snapshot at four clock ratios, initialization, monotonic refresh and both stopped-clock recoveries");
        $finish;
    end
    initial begin #100000; $fatal(1,"snapshot handshake timeout"); end
endmodule
