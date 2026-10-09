// Minimal build-driver fixture, not Sharp X1 behavioral evidence.
module top #(parameter TAG = 0)(output wire ready, output wire [7:0] tag);
    assign ready = 1'b1;
    assign tag = TAG;
endmodule
