// Original base-X1 drive/density glue. Reference: local MAME x1.cpp fdc_r/w.
// 0FFC write: drive bits 1:0, side bit 4, motor bit 7. Motor runs for 1.2 s
// after a falling motor command. Reads 0FFC/0FFD select FM/MFM respectively.
module x1_disk_control #(parameter MOTOR_HOLD_CYCLES = 38400000, PHYSICAL_DRIVES = 1) (
    input clk, reset, io_read, io_write,
    input [15:0] address,
    input [7:0] data,
    output [1:0] drive,
    output side,
    output motor_on,
    output reg fm_mode
);
    reg [7:0] control;
    localparam [25:0] MOTOR_HOLD_TICKS = MOTOR_HOLD_CYCLES;
    assign drive = control[1:0];
    assign side = control[4];
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            control <= 0; fm_mode <= 0;
        end else begin
            if (io_write && address == 16'h0ffc) begin
                control <= data;
            end
            if (io_read && address == 16'h0ffc) fm_mode <= 1;
            if (io_read && address == 16'h0ffd) fm_mode <= 0;
        end
    end
    generate if (PHYSICAL_DRIVES == 2) begin : motors
        reg [1:0] running, commanded;
        reg [25:0] hold_count [0:1];
        assign motor_on = control[1] ? 1'b0 : running[control[0]];
        always @(posedge clk or posedge reset) begin
            if (reset) begin
                running <= 0; commanded <= 0;
                hold_count[0] <= 0; hold_count[1] <= 0;
            end else begin
                for(integer d=0; d<2; d=d+1) if(hold_count[d] != 0) begin
                    hold_count[d] <= hold_count[d] - 1'b1;
                    if(hold_count[d] == 1) running[d] <= 0;
                end
                if(io_write && address == 16'h0ffc && !data[1]) begin
                    commanded[data[0]] <= data[7];
                    if(data[7]) begin
                        running[data[0]] <= 1;
                        hold_count[data[0]] <= 0;
                    end else if(commanded[data[0]]) hold_count[data[0]] <= MOTOR_HOLD_TICKS;
                end
            end
        end
    end else begin : single_motor
        reg running;
        reg [25:0] hold_count;
        assign motor_on = running;
        always @(posedge clk or posedge reset) begin
            if(reset) begin running <= 0; hold_count <= 0; end
            else begin
                if(hold_count != 0) begin
                    hold_count <= hold_count - 1'b1;
                    if(hold_count == 1) running <= 0;
                end
                if(io_write && address == 16'h0ffc) begin
                    if(data[7]) begin running <= 1; hold_count <= 0; end
                    else if(control[7]) hold_count <= MOTOR_HOLD_TICKS;
                end
            end
        end
    end endgenerate
endmodule
