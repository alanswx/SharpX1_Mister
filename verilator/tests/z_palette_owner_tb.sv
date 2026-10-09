// SPDX-License-Identifier: GPL-2.0-only
// Original connected ownership/adapter/RAM fixture; not native ASIC timing.
`timescale 1ps/1ps
module z_palette_owner_tb #(parameter LOCAL_RESET_RELEASE = 0);
    reg cpu_clk=0,video_clk=0,reset=1,video_blank=0;
    integer half=17500;
    reg run_cpu=1,run_video=1;
    always #15625 if(run_cpu) cpu_clk=~cpu_clk;
    always #(half) if(run_video) video_clk=~video_clk;
    reg io_read=0,io_write=0,read_mode=0;
    reg [15:0] address=16'h10ab;
    reg [7:0] data=8'hc7;
    wire selected,wait_n,read_valid,ram_access,ram_write,ram_valid;
    wire [3:0] read_nibble,ram_nibble,ram_data;
    wire [11:0] ram_address;
    wire [1:0] ram_component;
    wire cpu_permit,display_allowed;
    wire cpu_request=selected && !wait_n;
    wire [11:0] display_rgb12;
    wire display_valid;
    x1_z_palette_owner #(.LOCAL_RESET_RELEASE(LOCAL_RESET_RELEASE)) owner(.*);
    x1_z_palette_access access(.clk(cpu_clk),.reset(reset),.external_enabled(1'b1),
        .read_mode(read_mode),.permit(cpu_permit),.io_read(io_read),.io_write(io_write),
        .address(address),.data(data),.selected(selected),.wait_n(wait_n),
        .read_valid(read_valid),.read_nibble(read_nibble),.ram_access(ram_access),
        .read_hold(),.read_hold_nibble(),
        .ram_write(ram_write),.ram_address(ram_address),.ram_component(ram_component),
        .ram_nibble(ram_nibble),.ram_valid(ram_valid),.ram_data(ram_data));
    x1_z_palette_ram store(.cpu_clk(cpu_clk),.video_clk(video_clk),
        .cpu_reset(reset),.video_reset(reset),.cpu_access(ram_access),.cpu_write(ram_write),
        .cpu_address(ram_address),.cpu_component(ram_component),.cpu_nibble(ram_nibble),
        .cpu_data(ram_data),.cpu_valid(ram_valid),.display_read(display_allowed),
        .display_address(12'habc),.display_rgb12(display_rgb12),.display_valid(display_valid));
    integer operations=0,writes=0;
    integer leases=0;
    reg previous_display=0;
    always @(posedge video_clk) begin
        #1;
        if(reset) previous_display=0;
        else begin
            if(previous_display && !display_allowed) leases=leases+1;
            previous_display=display_allowed;
        end
    end
    always @(posedge cpu_clk) begin
        if(!reset) begin
            assert(!(cpu_permit && display_allowed)) else $fatal(1,"simultaneous ownership");
            if(ram_access) begin
                assert(cpu_permit && !display_allowed) else $fatal(1,"ungranted physical RAM access");
                operations<=operations+1;
                if(ram_write) writes<=writes+1;
            end
        end
    end
    always @(posedge video_clk) if(!reset)
        assert(!(cpu_permit && display_allowed)) else $fatal(1,"video/CPU overlap");
    task automatic cpu_tick;
        @(posedge cpu_clk);#1;
    endtask
    task automatic inactive;
        @(negedge cpu_clk);io_read=0;io_write=0;
        repeat(40) cpu_tick();
        assert(display_allowed && !cpu_permit) else $fatal(1,"ownership did not drain");
    endtask
    task automatic wait_done;
        integer edges;
        edges=0;
        while(!wait_n) begin cpu_tick();edges=edges+1;
            assert(edges<80) else $fatal(1,"grant/response timeout");
        end
    endtask
    task automatic write_value(input [3:0] value);
        @(negedge cpu_clk);read_mode=0;address=16'h10ab;data={4'hc,value};io_write=1;
        cpu_tick();wait_done();
        repeat(12) cpu_tick(); // Held DONE strobes must not repeat a write.
        inactive();
    endtask
    task automatic check_display(input [3:0] expected);
        repeat(3) begin @(posedge video_clk);#1;end
        assert(display_valid && display_rgb12=={4'hb,4'ha,expected})
            else $fatal(1,"display value after lease %h expected nibble %h",display_rgb12,expected);
    endtask
    initial begin
        if($value$plusargs("video_half=%d",half)) begin end
        repeat(4) cpu_tick();@(negedge cpu_clk);reset=0;
        repeat(4) cpu_tick();
        check_display(4'hc);
        // A real adapter write waits throughout active video and stopped video.
        @(negedge cpu_clk);io_write=1;
        repeat(20) begin cpu_tick();assert(!wait_n && writes==0) else $fatal(1,"active-display write escaped");end
        @(negedge video_clk);run_video=0;
        video_blank=1;
        repeat(20) begin cpu_tick();assert(!wait_n && writes==0) else $fatal(1,"stopped-video fake grant");end
        run_video=1;
        wait_done();
        assert(writes==1 && operations==1) else $fatal(1,"write count");
        repeat(12) cpu_tick();assert(writes==1) else $fatal(1,"held write duplicated");
        inactive();check_display(7);
        // Consecutive leases and a grant held across stopped CPU/video clocks.
        for(integer value=0;value<16;value=value+1) begin
            write_value(4'(value));check_display(4'(value));
        end
        assert(writes==17) else $fatal(1,"consecutive leases lost/duplicated");
        // Selector OUT is not a physical write. Its IN response must still
        // come from the RAM and remain held after lease release.
        @(negedge cpu_clk);read_mode=1;io_write=1;data=8'hcf;
        cpu_tick();wait_done();inactive();
        @(negedge cpu_clk);io_read=1;
        cpu_tick();wait_done();
        assert(read_valid && read_nibble==15 && writes==17) else $fatal(1,"read/selector lease");
        repeat(20) begin cpu_tick();assert(read_valid && read_nibble==15) else $fatal(1,"read response lost");end
        inactive();
        // Reset a denied request. No old operation may appear on fresh grant.
        video_blank=0;
        @(negedge cpu_clk);read_mode=0;data=8'hc1;io_write=1;
        repeat(10) cpu_tick();
        @(negedge cpu_clk);reset=1;#1;
        assert(!cpu_permit && !display_allowed) else $fatal(1,"reset ownership mask");
        repeat(2) cpu_tick();io_write=0;
        @(negedge cpu_clk);reset=0;video_blank=1;
        inactive();check_display(15);
        assert(writes==17) else $fatal(1,"reset request replayed");
        write_value(3);check_display(3);
        // Acquire a real lease, then stop CPU before its physical write edge.
        @(negedge cpu_clk);data=8'hc4;io_write=1;
        cpu_tick();
        while(!cpu_permit) cpu_tick();
        @(negedge cpu_clk);run_cpu=0;video_blank=0;
        repeat(20) begin
            @(posedge video_clk);#1;
            assert(cpu_permit && !display_allowed && writes==18)
                else $fatal(1,"lease lost across stopped CPU/blank exit");
        end
        reset=1;#1;
        assert(!cpu_permit && !display_allowed) else $fatal(1,"stopped CPU reset mask");
        repeat(4) @(posedge video_clk);
        io_write=0;reset=0;run_cpu=1;inactive();check_display(3);
        assert(writes==18) else $fatal(1,"owned reset replayed physical write");
        // One inactive CPU edge between operations: the old video grant may
        // still be crossing back. Every write needs a fresh lease, not that
        // delayed old acknowledgment. This deliberately avoids idle padding.
        video_blank=1;
        for(integer value=0;value<16;value=value+1) begin
            integer before_leases;
            before_leases=leases;
            @(negedge cpu_clk);read_mode=0;data={4'hc,4'(value)};io_write=1;
            cpu_tick();wait_done();
            assert(writes==19+value && leases==before_leases+1)
                else $fatal(1,"new write reused old grant or operation count");
            @(negedge cpu_clk);io_write=0;cpu_tick();
        end
        inactive();check_display(15);
        $display("PASS connected palette ownership: active/stopped-video WAIT, exact physical writes, read-response retention, consecutive leases/reset and retained display; half=%0d",half);
        $finish;
    end
endmodule
