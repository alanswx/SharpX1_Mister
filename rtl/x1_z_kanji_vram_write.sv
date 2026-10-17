// SPDX-License-Identifier: GPL-2.0-only
// Original standalone cached-VRAM write transaction experiment.
// Outside machine.qip. Provisional refill-before-write WAIT, not native ASIC
// write visibility. No raw reset: an admitted write MUST finish publication
// and its one VRAM strobe before cache invalidation/reset/font replacement.
// Block admission first and wait for idle. SYS, VID and font service must run
// until idle; stopped clocks intentionally retain ownership/backpressure.
// Three x1_video_ram CPU ports must share ram_address; their synchronous old
// bytes are captured on the edge after admission. No other writer may modify
// those cells while a transaction is owned. Ram retention and known masks
// survive consumer warm reset. Initial masks describe unwritten cold cells.
// Descriptor = {5'b0, known[kan,attr,text], kan, attr, text}; glyph = {kan[4:0],text}.
// Unknown bytes are zero-masked; consumers MUST honor the known mask. Only an
// explicitly mode-qualified base ANK consumer may use mask 03 without Kanji.
// Other interpretations require all three bits. No native power-on RAM policy.
// All writes refill 32 bytes, even ANK/PCG/incomplete entries. Caller admission
// must guarantee a loaded/stable font and a serviceable cache completion.
// A held write_valid is accepted once and completes only in the reply state.
// Retire it after WAIT release; observe low before issuing another request.
`timescale 1ns/1ps
module x1_z_kanji_vram_write #(parameter integer CELL_BITS=11) (
    input wire clk, admit_enable,
    input wire write_valid,
    input wire [2:0] write_select,
    input wire [CELL_BITS-1:0] write_cell,
    input wire [7:0] write_data,
    output wire wait_n, idle, write_accepted,
    output wire [CELL_BITS-1:0] ram_address,
    output wire [7:0] ram_data,
    output wire [2:0] ram_write,
    input wire [7:0] ram_text, ram_attr, ram_kan,
    output wire update_valid,
    input wire update_ready,
    output wire [CELL_BITS-1:0] update_cell,
    output wire [12:0] update_glyph,
    output wire [31:0] update_descriptor,
    input wire update_done,
    output wire update_done_ready,
    input wire [CELL_BITS-1:0] update_done_cell,
    input wire [12:0] update_done_glyph,
    input wire [31:0] update_done_descriptor
);
    localparam logic [2:0] IDLE=0, CAPTURE=1, OFFER=2, DRAIN=3, REPLY=4;
    reg [2:0] state;
    reg armed;
    reg [CELL_BITS-1:0] held_cell;
    reg [2:0] held_select, held_known;
    reg [7:0] held_data;
    reg [31:0] held_descriptor;
    reg [12:0] held_glyph;
    reg [2:0] known[0:(1<<CELL_BITS)-1];
    reg [2:0] known_read;
    wire [2:0] merged_known=known_read | held_select;
    wire [7:0] merged_text=held_select[0] ? held_data : (known_read[0] ? ram_text : 8'd0);
    wire [7:0] merged_attr=held_select[1] ? held_data : (known_read[1] ? ram_attr : 8'd0);
    wire [7:0] merged_kan=held_select[2] ? held_data : (known_read[2] ? ram_kan : 8'd0);
    initial begin
        assert(CELL_BITS>=1 && CELL_BITS<=11) else $fatal(1,"Z_VRAM_PARAMETERS");
        state=IDLE;armed=1;held_cell=0;held_select=0;held_data=0;
        held_known=0;held_descriptor=0;held_glyph=0;
        for(integer c=0;c<(1<<CELL_BITS);c++) known[c]=0;
    end
    assign idle=state==IDLE;
    assign write_accepted=state==IDLE && write_valid && armed && admit_enable;
    assign wait_n=!write_valid || state==REPLY;
    assign ram_address=state==IDLE ? write_cell : held_cell;
    assign ram_data=held_data;
    assign ram_write=(state==DRAIN && update_done) ? held_select : 3'd0;
    assign update_valid=state==OFFER;
    assign update_cell=held_cell;
    assign update_glyph=held_glyph;
    assign update_descriptor=held_descriptor;
    assign update_done_ready=state==DRAIN;
    always @(posedge clk) begin
        known_read<=known[ram_address];
        if(!write_valid) armed<=1;
        case(state)
            IDLE: if(write_accepted) begin
                assert($onehot(write_select)) else $fatal(1,"Z_VRAM_WRITE_SELECT");
                held_cell<=write_cell;held_data<=write_data;held_select<=write_select;
                armed<=0;state<=CAPTURE;
            end
            CAPTURE: begin
                held_known<=merged_known;
                held_descriptor<={5'd0,merged_known,merged_kan,merged_attr,merged_text};
                held_glyph<={merged_kan[4:0],merged_text};
                state<=OFFER;
            end
            OFFER: if(update_ready) state<=DRAIN;
            DRAIN: if(update_done) begin
                assert(update_done_cell==held_cell && update_done_glyph==held_glyph &&
                       update_done_descriptor==held_descriptor)
                    else $fatal(1,"Z_VRAM_COMPLETION_OWNER");
                known[held_cell]<=held_known;
                state<=REPLY;
            end
            REPLY: if(!write_valid) state<=IDLE;
            default: state<=IDLE;
        endcase
    end
endmodule
