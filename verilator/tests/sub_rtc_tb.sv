// SPDX-License-Identifier: GPL-2.0-only
// Actual x1_sub with public firmware upload/host pins and running timer IRQs.
// No internal ROM/RAM/register injection. Not shared-machine/native acceptance.
`timescale 1ps/1ps
module sub_rtc_tb #(parameter CLOCK_HZ=32000000);
    bit clk=0,reset=1,power_reset=1,cs=0,rd=0,wr=0,fcs=0;
    bit bad_power=0;
    logic [7:0] data=0;
    logic [12:0] firmware_address=0;
    wire [7:0] response;
    wire doe,tx_busy,rx_busy;
    logic [15:0] source_rom[4096];
    byte received[3];
    string rom_path;
    integer timer_acks=0;
    x1_sub #(.CLOCK_HZ(CLOCK_HZ),.PS2_RECEIVE_ONLY(1),.IRQ_ACK_ONCE(1),.RTC_ENABLE(1)) dut(
        .I_reset(reset),.I_rtc_power_reset(power_reset || (bad_power && reset)),.I_clk(clk),
        .I_cs(cs),.I_rd(rd),.I_wr(wr),.I_M1_n(1'b1),.I_D(data),.O_D(response),.O_DOE(doe),
        .O_clk1(),.O_FDC_DRQ_n(),.I_FDCS(1'b0),.I_RFSH_n(1'b1),.I_RFSH_STB_n(1'b1),
        .I_DMA_CS(1'b0),.O_DMA_BANK(),.O_DMA_A(),.I_DMA_D(8'hff),.O_DMA_D(),
        .O_DMA_MREQ_n(),.O_DMA_IORQ_n(),.O_DMA_RD_n(),.O_DMA_WR_n(),
        .O_DMA_BUSRQ_n(),.I_DMA_BUSAK_n(1'b1),.I_DMA_RDY(1'b0),.I_DMA_WAIT_n(1'b1),
        .I_DMA_IEI(1'b1),.O_DMA_INT_n(),.O_DMA_IEO(),.O_PCM(),.O_FD_LAMP(),
        .I_fa(firmware_address),.I_fcs(fcs),.I_PS2C(1'b1),.I_PS2D(1'b1),
        .O_PS2CT(),.O_PS2DT(),.O_TX_BSY(tx_busy),.O_RX_BSY(rx_busy),.O_KEY_BRK_n(),
        .I_SPM1(1'b0),.I_RETI(1'b0),.I_IEI(1'b1),.O_INT_n(),.O_JOY_A(),.O_JOY_B(),
        .dot_7seg(),.num_7seg());
    always @(posedge clk) if(!reset && dut.sub_cpu.timer_ack) timer_acks++;
    task automatic step;
        clk=0;#5;clk=1;#5;
    endtask
    task automatic upload;
        fcs=1;wr=1;
        for(integer a=0;a<8192;a++) begin
            firmware_address=13'(a);
            data=a%2==0 ? source_rom[a/2][7:0] : source_rom[a/2][15:8];
            step();
        end
        wr=0;
        for(integer a=0;a<8192;a++) begin
            firmware_address=13'(a);repeat(2) step();
            assert(doe && response==(a%2==0 ? source_rom[a/2][7:0] : source_rom[a/2][15:8]))
                else $fatal(1,"sub RTC public firmware readback mismatch at %h",a);
        end
        fcs=0;
    endtask
    task automatic send(input byte value);
        for(integer i=0;i<2000000 && tx_busy;i++) step();
        assert(!tx_busy) else $fatal(1,"sub RTC host TX full timeout");
        cs=1;wr=1;data=value;repeat(8) step();cs=0;wr=0;
        for(integer i=0;i<2000000 && tx_busy;i++) step();
        assert(!tx_busy) else $fatal(1,"sub RTC host receive timeout byte=%h",value);
        repeat(8) step();
    endtask
    task automatic receive_byte(input integer n);
        for(integer i=0;i<2000000 && rx_busy;i++) step();
        assert(!rx_busy) else $fatal(1,"sub RTC reply timeout index=%0d",n);
        cs=1;repeat(4) step();
        assert(doe) else $fatal(1,"sub RTC missing public reply output enable");
        received[n]=response;rd=1;repeat(8) step();rd=0;cs=0;repeat(4) step();
    endtask
    task automatic receive3;
        for(integer n=0;n<3;n++) receive_byte(n);
    endtask
    initial begin
        bad_power=$test$plusargs("NEGATIVE_POWER");
        assert($value$plusargs("ROM=%s",rom_path)) else $fatal(1,"missing sub RTC source ROM");
        $readmemh(rom_path,source_rom);
        repeat(8) step();upload();power_reset=0;reset=0;
        repeat(CLOCK_HZ/200) step();
        send(8'he7);send(8'h55);send(8'he8);receive_byte(0);
        assert(received[0]==8'h55) else $fatal(1,"sub RTC unrelated E7/E8 regression");
        send(8'hec);send(8'h31);send(8'hc6);send(8'h99);
        send(8'hee);send(8'h12);send(8'h34);send(8'h56);
        send(8'hed);receive3();
        assert(received[0]==8'h31 && received[1]==8'hc6 && received[2]==8'h99)
            else $fatal(1,"sub RTC date readback mismatch %h %h %h",received[0],received[1],received[2]);
        send(8'hef);receive3();
        assert(received[0]==8'h12 && received[1]==8'h34 && received[2]==8'h56)
            else $fatal(1,"sub RTC initial time mismatch %h %h %h",received[0],received[1],received[2]);
        assert(timer_acks>10) else $fatal(1,"sub RTC missing real timer IRQ execution");
        // A running upload must not overwrite firmware. Use actual upload
        // pins, then verify the reset-vector byte through the same interface.
        fcs=1;firmware_address=0;wr=1;data=8'hff;repeat(8) step();wr=0;repeat(2) step();
        assert(response==source_rom[0][7:0]) else $fatal(1,"sub RTC active firmware upload was not rejected");
        fcs=0;
        reset=1;repeat(2*CLOCK_HZ) step();reset=0;
        repeat(CLOCK_HZ/200) step();
        send(8'hef);receive3();
        assert(received[0]==8'h12 && received[1]==8'h34 && received[2]==8'h58)
            else $fatal(1,"sub RTC retained ticking mismatch %h %h %h",received[0],received[1],received[2]);
        send(8'hed);receive3();
        assert(received[0]==8'h31 && received[1]==8'hc6 && received[2]==0)
            else $fatal(1,"sub RTC retained date/software YEAR reset mismatch");
        $display("PASS: actual x1_sub RTC CLOCK_HZ=%0d public 8192-byte upload/readback, running-upload rejection, EC..EF and E7/E8, real timer IRQs=%0d, retained firmware/calendar and two seconds during warm reset; shared Z80/native/hardware gates separate",CLOCK_HZ,timer_acks);
        $finish;
    end
endmodule
