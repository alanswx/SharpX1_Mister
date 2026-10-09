// SPDX-License-Identifier: GPL-2.0-only
// Original ordered-list oracle; caller visibility is NOT native opacity.
`timescale 1ps/1ps
module z_layer_order_tb;
    reg enabled=0,two_screen_mode=0,selected_screen=0;
    reg [7:0] priority_control=0;
    reg text_visible=0,screen0_visible=0,screen1_visible=0;
    wire defined;
    wire [1:0] source;
    bit negative_middle=0;
    // Deliberately wrong caller control for the negative test only: make
    // documented field 10 look like text-on-top. The oracle stays unchanged.
    wire [7:0] decoded_control=negative_middle && priority_control[4] && priority_control[1:0]==2 ?
                              priority_control & 8'hfd : priority_control;
    x1_z_layer_order dut(.*,.priority_control(decoded_control));
    integer cases=0;
    initial begin
        negative_middle=$test$plusargs("NEGATIVE_MIDDLE");
        for(integer raw=0;raw<256;raw=raw+1)
        for(integer two=0;two<2;two=two+1)
        for(integer selected=0;selected<2;selected=selected+1)
        for(integer active=0;active<2;active=active+1)
        for(integer visibility=0;visibility<8;visibility=visibility+1) begin
            integer ordering[0:2];
            integer field,front,back,expected;
            bit pair,legal;
            priority_control=8'(raw);two_screen_mode=1'(two);
            selected_screen=1'(selected);enabled=1'(active);
            text_visible=visibility[0];screen0_visible=visibility[1];screen1_visible=visibility[2];
            // Independent arithmetic table of ordered source IDs, not the
            // RTL's ternary visibility mux or a copied emulator procedure.
            pair=two!=0 && (raw/16)%2!=0;
            field=raw%2+(pair ? 2*((raw/2)%2) : 0);
            front=2+(pair ? (raw/8)%2 : selected);
            back=pair ? 5-front : 0;
            ordering[0]=0;ordering[1]=0;ordering[2]=0;
            case(field)
                0: begin ordering[0]=1;ordering[1]=front;ordering[2]=back;end
                1: begin ordering[0]=front;ordering[1]=back;ordering[2]=1;end
                2: begin ordering[0]=front;ordering[1]=1;ordering[2]=back;end
                default: begin end
            endcase
            legal=active!=0 && field!=3;
            expected=0;
            if(legal) begin
                for(integer rank=2;rank>=0;rank=rank-1)
                    if(ordering[rank]!=0 && ((visibility>>(ordering[rank]-1))&1)!=0)
                        expected=ordering[rank];
            end
            #1;
            assert(defined==legal && source==2'(expected))
                else $fatal(1,"order raw=%h two=%0d selected=%0d active=%0d visibility=%h got %0d/%0d expected %0d/%0d",
                    raw,two,selected,active,visibility,defined,source,legal,expected);
            cases=cases+1;
        end
        assert(cases==16384) else $fatal(1,"missing priority cross-product");
        $display("PASS: 16384 priority controls/mode/page/visibility cases; between-screen text, undefined field, single-screen masking; no opacity claim");
        $finish;
    end
endmodule
