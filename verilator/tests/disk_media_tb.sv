`timescale 1ns/1ps
// Original descriptor/owner fixture. transport_idle comes from the FDC's
// full ACK drain, not just the host ACK pin; no assumption of cancellation.
module disk_media_tb;
    reg clk=0;
    always #5 clk=!clk;
    reg [1:0] selected=0, mounted=0, present=2'b11, readonly=2'b10;
    reg idle=1;
    reg [23:0] size_a=976, size_b=1232;
    wire [1:0] active;
    wire changing, ready, wp;
    wire [23:0] size;
    x1_disk_media dut(clk,selected,mounted,present,readonly,size_a,size_b,
                      idle,active,changing,ready,wp,size);
    task settle;
        repeat(3) @(negedge clk);
    endtask
    initial begin
        settle();
        assert(active==0 && ready && !wp && size==976) else $fatal(1,"initial A descriptor");
        // Selection before ACK: A remains the host owner until complete drain.
        idle=0; selected=1; settle();
        assert(active==0 && changing && !ready && size==976) else $fatal(1,"pending A was rerouted");
        repeat(100) @(negedge clk);
        assert(active==0) else $fatal(1,"stalled request lost owner");
        idle=1; settle();
        assert(active==1 && ready && wp && size==1232) else $fatal(1,"B descriptor after drain");
        // Unrelated A mount must not interrupt a B transaction.
        idle=0; mounted=1; settle();
        assert(active==1 && ready && !changing) else $fatal(1,"unrelated mount aborted B");
        mounted=0; settle();
        // Active replacement/eject remains quarantined even after mount falls.
        mounted=2; present=1; size_b=0; settle();
        assert(active==1 && changing && !ready) else $fatal(1,"active eject escaped quarantine");
        mounted=0; selected=0; settle();
        assert(active==1 && changing && !ready) else $fatal(1,"ACK-high selection rerouted B");
        idle=1; settle();
        assert(active==0 && ready && size==976) else $fatal(1,"A recovery after B eject");
        // New B descriptor can arrive while its mount pulse is held.
        selected=1; mounted=2; present=3; size_b=1504; settle();
        assert(active==0 && changing) else $fatal(1,"scan started during mount pulse");
        mounted=0; settle();
        assert(active==1 && ready && size==1504) else $fatal(1,"B replacement descriptor");
        readonly=0; settle(); assert(!wp) else $fatal(1,"live write policy ignored");
        selected=2; settle();
        assert(active==2 && !ready && wp && size==0) else $fatal(1,"unsupported drive aliased A");
        selected=3; settle();
        assert(active==3 && !ready && wp && size==0) else $fatal(1,"unsupported drive aliased B");
        selected=0; settle(); assert(ready && size==976) else $fatal(1,"recovery from unsupported drive");
        $display("PASS: A/B descriptors, owner holds before/during ACK drain, mount isolation/eject/replacement, invalid drives and live protection");
        $finish;
    end
endmodule
