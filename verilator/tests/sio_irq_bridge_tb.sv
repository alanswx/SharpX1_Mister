// SPDX-License-Identifier: GPL-2.0-or-later
// Real SIO priority engine; downstream DMA/CTC are explicit service models.
// This fixture does not establish serial sources or CPU/device integration.
`timescale 1ns/1ps
module sio_irq_bridge_tb;
    reg clk=0, reset=1;
    always #5 clk=~clk;
    reg m1_n=1,mreq_n=1,iorq_n=1,rd_n=1,upstream_iei=1;
    reg [7:0] data=0;
    reg [5:0] request=0;
    reg [1:0] reset_channel=0;
    wire sio_irq,sio_ieo,sio_in_service,sio_ack,sio_iei,sio_reti;
    wire [7:0] sio_vector;
    reg dma_pending=0,ctc_pending=0,dma_in_service=0,ctc_in_service=0;
    wire dma_iei,ctc_iei,dma_ack,ctc_ack,dma_reti,ctc_reti;
    wire dma_irq=dma_iei && dma_pending && !dma_in_service;
    wire dma_ieo=dma_iei && !dma_pending && !dma_in_service;
    wire ctc_irq=ctc_iei && ctc_pending && !ctc_in_service;
    wire ctc_ieo=ctc_iei && !ctc_pending && !ctc_in_service;
    reg keyboard_irq=1;
    wire irq,keyboard_ack;
    wire [7:0] ack_vector;
    reg bad_service=0;
    wire sio_service_input=bad_service ? !sio_ieo : sio_in_service;
    integer sa=0,da=0,ca=0,sr=0,dr=0,cr=0;
    x1_sio_irq sio(.clk(clk),.reset(reset),.iei(sio_iei),.acknowledge(sio_ack),
        .reti(sio_reti),.reset_channel(reset_channel),.request(request),
        .special_rx(2'b00),.vector_base(8'he0),.status_vector(1'b1),
        .irq(sio_irq),.ieo(sio_ieo),.pending(),.service_active(sio_in_service),
        .rr2(),.ack_vector(sio_vector));
    x1_sio_irq_bridge dut(.sio_in_service(sio_service_input),.dma_vector(8'hc4),.ctc_vector(8'ha0),
        .keyboard_vector(8'hb0),.*);
    always @(posedge clk) begin
        if(reset) begin dma_in_service<=0;ctc_in_service<=0; end
        else begin
            if(sio_ack) sa<=sa+1;
            if(dma_ack) begin da<=da+1;dma_pending<=0;dma_in_service<=1;end
            if(ctc_ack) begin ca<=ca+1;ctc_pending<=0;ctc_in_service<=1;end
            if(sio_reti) sr<=sr+1;
            if(dma_reti) begin dr<=dr+1;dma_in_service<=0;end
            if(ctc_reti) begin cr<=cr+1;ctc_in_service<=0;end
            if((int'(sio_ack)+int'(dma_ack)+int'(ctc_ack)+int'(keyboard_ack))>1)
                $fatal(1,"multiple ACK owners");
            if((int'(sio_reti)+int'(dma_reti)+int'(ctc_reti))>1)
                $fatal(1,"multiple RETI owners");
        end
    end
    task automatic tick; @(posedge clk); #1; endtask
    task automatic idle; m1_n=1;iorq_n=1;rd_n=1;mreq_n=1;tick(); endtask
    task automatic ack(input [7:0] vector,input integer owner);
        m1_n=0;iorq_n=0; #1;
        if(ack_vector!==vector || {sio_ack,dma_ack,ctc_ack,keyboard_ack}!==4'(1<<owner))
            $fatal(1,"ACK vector/owner %h expected %h",ack_vector,vector);
        tick();
        // A higher SIO request arriving after a DMA ACK must not steal the
        // still-held transaction. It becomes eligible only for the next ACK.
        if(owner==2) request[4]=1;
        repeat(40) begin
            if(ack_vector!==vector || sio_ack || dma_ack || ctc_ack)
                $fatal(1,"held vector or repeated ACK");
            tick();
        end
        idle();
    endtask
    task automatic opcode(input [7:0] value);
        data=value;m1_n=0;mreq_n=0;rd_n=0;
        repeat(5) tick();idle();tick();
    endtask
    task automatic reti; opcode(8'hed);opcode(8'h4d); endtask
    initial begin
        bad_service=$test$plusargs("BAD_SERVICE");
        repeat(8) tick();reset=0;idle();
        // Lower CTC service, nested DMA service, two nested real SIO slots.
        ctc_pending=1;#1;ack(8'ha0,1);
        dma_pending=1;#1;ack(8'hc4,2);
        request[4]=1;#1;ack(8'he0,3);request[4]=0;
        request[0]=1;#1;ack(8'hec,3);request[0]=0;
        // Low upstream IEI cannot suppress returns of actual local service.
        upstream_iei=0;reti();
        if(!sio_in_service || !dma_in_service || !ctc_in_service || sr!=1 || dr!=0 || cr!=0)
            $fatal(1,"first SIO RETI disturbed nested service");
        reti();
        if(sio_in_service || !dma_in_service || !ctc_in_service || sr!=2)
            $fatal(1,"second SIO RETI wrong owner");
        // A pending SIO request must NOT steal RETI from the serviced DMA.
        request[2]=1;reti();
        if(dma_in_service || !ctc_in_service || dr!=1 || sr!=2)
            $fatal(1,"pending SIO stole DMA RETI");
        request=0;reti();
        if(ctc_in_service || cr!=1) $fatal(1,"CTC return failed");
        upstream_iei=1;#1;ack(8'hb0,0);
        // SIO channel reset during held ACK cannot replace the bus vector.
        request[3]=1;m1_n=0;iorq_n=0;tick();
        if(ack_vector!=8'he4) $fatal(1,"B RX vector");
        reset_channel=1;request=0;tick();reset_channel=0;
        repeat(20) begin tick();if(ack_vector!=8'he4 || keyboard_ack || sio_ack)
            $fatal(1,"channel reset changed held owner");end
        // Global reset must quarantine the old held ACK until release.
        reset=1;tick();reset=0;
        repeat(20) begin tick();if(keyboard_ack || sio_ack || dma_ack || ctc_ack)
            $fatal(1,"stale ACK replay after reset");end
        idle();ack(8'hb0,0);
        // Prefix operands are not a RETI, even when they contain ED/4D.
        request[1]=1;#1;ack(8'he8,3);request=0;
        opcode(8'hcb);opcode(8'hed);opcode(8'h4d);
        if(!sio_in_service || sr!=2) $fatal(1,"false prefixed RETI");
        reti();if(sio_in_service || sr!=3) $fatal(1,"final SIO RETI");
        if(sa!=4 || da!=1 || ca!=1) $fatal(1,"ACK totals %d %d %d",sa,da,ca);
        $display("PASS: SIO chain nested ownership, held/reset ACK and qualified RETI");$finish;
    end
    initial begin #100000; $fatal(1,"watchdog");end
endmodule
