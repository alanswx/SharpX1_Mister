`timescale 1ps/1ps
// Original output-boundary fixture. Synthetic colors bypass the renderer;
// this tests the actual emu wiring, not native palette/PLL/scaler operation.
module rgb12_wrapper_tb;
    wire [48:0] hps_bus;
    assign hps_bus = 49'd0;
    wire [7:0] red, green, blue;
    wire [3:0] adc_bus;
    wire [15:0] sdram_data;
    emu dut (.CLK_50M(1'b0), .RESET(1'b1), .HPS_BUS(hps_bus),
             .CLK_VIDEO(), .CE_PIXEL(), .VIDEO_ARX(), .VIDEO_ARY(),
             .VGA_R(red), .VGA_G(green), .VGA_B(blue),
             .VGA_HS(), .VGA_VS(), .VGA_DE(), .VGA_F1(), .VGA_SL(),
             .VGA_SCALER(), .VGA_DISABLE(), .HDMI_WIDTH(12'd0),
             .HDMI_HEIGHT(12'd0), .HDMI_FREEZE(), .LED_USER(),
             .LED_POWER(), .LED_DISK(), .BUTTONS(), .CLK_AUDIO(1'b0),
             .AUDIO_L(), .AUDIO_R(), .AUDIO_S(), .AUDIO_MIX(),
             .ADC_BUS(adc_bus), .SD_SCK(), .SD_MOSI(), .SD_MISO(1'b1),
             .SD_CS(), .SD_CD(1'b1), .DDRAM_CLK(), .DDRAM_BUSY(1'b0),
             .DDRAM_BURSTCNT(), .DDRAM_ADDR(), .DDRAM_DOUT(64'd0),
             .DDRAM_DOUT_READY(1'b0), .DDRAM_RD(), .DDRAM_DIN(),
             .DDRAM_BE(), .DDRAM_WE(), .SDRAM_CLK(), .SDRAM_CKE(),
             .SDRAM_A(), .SDRAM_BA(), .SDRAM_DQ(sdram_data),
             .SDRAM_DQML(), .SDRAM_DQMH(), .SDRAM_nCS(), .SDRAM_nCAS(),
             .SDRAM_nRAS(), .SDRAM_nWE(), .UART_CTS(1'b1), .UART_RTS(),
             .UART_RXD(1'b1), .UART_TXD(), .UART_DTR(), .UART_DSR(1'b1),
             .USER_IN(7'h7f), .USER_OUT(), .OSD_STATUS(1'b0));
    initial begin
        for (integer color = 0; color < 4096; color++) begin
            force dut.machine_rgb12 = 12'(color);
            #1000;
            assert (red == 8'((color / 256) * 17)
                 && green == 8'(((color / 16) % 16) * 17)
                 && blue == 8'((color % 16) * 17))
                else $fatal(1, "RGB12 wrapper color=%03x actual=%02x%02x%02x",
                            color, red, green, blue);
        end
        release dut.machine_rgb12;
        $display("PASS RGB12 actual emu output boundary: all 4096 component combinations; synthetic injection, not palettes/PLL/scaler");
        $finish;
    end
endmodule
