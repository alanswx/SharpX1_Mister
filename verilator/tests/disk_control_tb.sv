`timescale 1ns/1ps
module disk_control_tb;
    reg clk = 0, reset = 1, rd = 0, wr = 0;
    always #5 clk = !clk;
    reg [15:0] address = 0;
    reg [7:0] data = 0;
    wire [1:0] drive;
    wire side, motor, fm;
    wire dual_motor;
    x1_disk_control #(.MOTOR_HOLD_CYCLES(12)) dut(clk,reset,rd,wr,address,data,drive,side,motor,fm);
    x1_disk_control #(.MOTOR_HOLD_CYCLES(12),.PHYSICAL_DRIVES(2)) dual_dut(
        .clk(clk),.reset(reset),.io_read(rd),.io_write(wr),.address(address),.data(data),
        .drive(),.side(),.motor_on(dual_motor),.fm_mode());
    task write_control(input [7:0] value);
        begin
            @(negedge clk); address = 16'h0ffc; data = value; wr = 1;
            @(negedge clk); wr = 0;
        end
    endtask
    task read_control(input [15:0] port);
        begin
            @(negedge clk); address = port; rd = 1;
            @(negedge clk); rd = 0;
        end
    endtask
    initial begin
        repeat (3) @(negedge clk); reset = 0;
        assert (!motor && !fm && !side && drive == 0) else $fatal(1, "disk control reset");
        write_control(8'h92);
        assert (motor && side && drive == 2) else $fatal(1, "drive/side/motor decode");
        read_control(16'h0ffc); assert (fm) else $fatal(1, "FM selection");
        read_control(16'h0ffd); assert (!fm) else $fatal(1, "MFM selection");
        write_control(8'h10);
        repeat (11) begin
            @(negedge clk); assert (motor) else $fatal(1, "motor stopped before hold timeout");
        end
        @(negedge clk); assert (!motor) else $fatal(1, "motor did not stop on hold timeout");
        write_control(8'h80);
        write_control(8'h00);
        repeat (4) @(negedge clk);
        write_control(8'h80);  // Restart cancels shutdown.
        repeat (20) @(negedge clk);
        assert (motor) else $fatal(1, "restart failed to cancel timeout");
        reset = 1;
        @(negedge clk);
        assert (!motor && drive == 0 && !side && !fm) else $fatal(1, "reset did not clear drive state");
        reset=0;
        write_control(8'h80); assert(dual_motor) else $fatal(1,"A motor start");
        write_control(8'h01); assert(!dual_motor) else $fatal(1,"A motor aliased unstarted B");
        write_control(8'h81); assert(dual_motor) else $fatal(1,"B motor start");
        write_control(8'h00); assert(dual_motor) else $fatal(1,"A motor did not retain state");
        repeat(12) @(negedge clk); assert(!dual_motor) else $fatal(1,"A motor hold timeout");
        write_control(8'h81); assert(dual_motor) else $fatal(1,"A shutdown stopped B");
        write_control(8'h01);
        repeat(4) @(negedge clk);
        write_control(8'h81);
        repeat(20) @(negedge clk); assert(dual_motor) else $fatal(1,"B restart failed");
        write_control(8'h82); assert(!dual_motor) else $fatal(1,"unsupported motor aliased A/B");
        reset=1; @(negedge clk); assert(!dual_motor) else $fatal(1,"dual motor reset");
        $display("PASS: X1 drive/side, FM/MFM selects, delayed motor stop/restart and reset");
        $display("PASS: independent A/B motor state, hold expiry/restart and unsupported-drive isolation");
        $finish;
    end
endmodule
