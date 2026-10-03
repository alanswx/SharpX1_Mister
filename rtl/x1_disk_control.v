// Original base-X1 drive/density glue. Reference: local MAME x1.cpp fdc_r/w.
// 0FFC write: drive bits 1:0, side bit 4, motor bit 7. Motor runs for 1.2 s
// after a falling motor command. Reads 0FFC/0FFD select FM/MFM respectively.
module x1_disk_control #(parameter MOTOR_HOLD_CYCLES = 38400000) (
    input clk, reset, io_read, io_write,
    input [15:0] address,
    input [7:0] data,
    output [1:0] drive,
    output side,
    output reg motor_on,
    output reg fm_mode
);
    reg [7:0] control;
    reg [25:0] hold_count;
    localparam [25:0] MOTOR_HOLD_TICKS = MOTOR_HOLD_CYCLES;
    assign drive = control[1:0];
    assign side = control[4];
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            control <= 0; hold_count <= 0; motor_on <= 0; fm_mode <= 0;
        end else begin
            if (hold_count != 0) begin
                hold_count <= hold_count - 1'b1;
                if (hold_count == 1) motor_on <= 0;
            end
            if (io_write && address == 16'h0ffc) begin
                control <= data;
                if (data[7]) begin motor_on <= 1; hold_count <= 0; end
                else if (control[7]) hold_count <= MOTOR_HOLD_TICKS;
            end
            if (io_read && address == 16'h0ffc) fm_mode <= 1;
            if (io_read && address == 16'h0ffd) fm_mode <= 0;
        end
    end
endmodule
