// SPDX-License-Identifier: GPL-2.0-only
// Original transaction-bound DAM arming. A PPI C5 transition cannot redirect
// the already-started control OUT into GRAM. Physical ASIC phase is unqualified.
module x1_dam_control(
    input wire clk, reset, mode5, io_read, io_write,
    output reg dam=0
);
    reg old_mode5=1, pending=0;
    wire falling=old_mode5 && !mode5;
    always @(posedge clk or posedge reset) begin
        if(reset) begin old_mode5<=1;pending<=0;dam<=0;end
        else begin
            old_mode5<=mode5;
            if(io_read) begin dam<=0;pending<=0;end
            else begin
                if(falling) pending<=1;
                if(!io_write && (pending || falling)) begin dam<=1;pending<=0;end
            end
        end
    end
endmodule
