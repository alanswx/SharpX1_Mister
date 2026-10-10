`timescale 1ns/1ps
// Original synthetic, sparse-media fixture. No private disk bytes, force,
// injected index entries, or geometry/rate claims. All scans use real SD I/O.
module fdc_address_width_tb;
    parameter ADDRESS_BITS=20;
    parameter MAX_SECTORS=1992;
    reg clk=0, reset=1, mounted=0, ack=0, host_wr=0, wr=0, rd=0;
    reg [1:0] address=0;
    reg [7:0] data=0, host_data=0;
    reg [8:0] host_address=0;
    reg [23:0] size=0;
    reg [2:0] selected=0;
    wire [7:0] dout, host_read_data;
    wire [31:0] lba;
    wire prepare, sd_rd, sd_wr, busy, drq, idle;
    integer base=0, header=688, volume_size=832, first_size=0;
    integer track_offset=688, mode=0, writes=0, groups=0;
    integer highest_lba=0;
    integer payload_length=128, sector_count=1, track_sectors=1, target_sector=1;
    reg physical_side=0;
    reg [7:0] sector_bytes[272];
    always #5 clk=!clk;
    wd1793 #(.RWMODE(1), .EDSK(1), .D88_ONLY(1), .ADDRESS_BITS(ADDRESS_BITS), .MAX_SECTORS(MAX_SECTORS)) dut(
        .drive_select(1'b0), .drive_connected(1'b1), .transport_idle(idle),
        .clk_sys(clk), .ce(!reset), .reset(reset), .io_en(1'b1),
        .rd(rd), .wr(wr), .addr(address), .din(data), .dout(dout),
        .drq(drq), .intrq(), .busy(busy), .wp(1'b0), .fmt_wp(),
        .size_code(3'd1), .layout(1'b0), .side(physical_side), .ready(1'b1), .fm_mode(1'b0),
        .img_mounted(mounted), .img_size(size[ADDRESS_BITS-1:0]), .img_size_id(size),
        .disk_index(selected), .prepare(prepare), .sd_lba(lba), .sd_rd(sd_rd), .sd_wr(sd_wr),
        .sd_ack(ack), .sd_buff_addr(host_address), .sd_buff_dout(host_data),
        .sd_buff_din(host_read_data), .sd_buff_wr(host_wr), .input_active(1'b0),
        .input_addr(ADDRESS_BITS'(0)), .input_data(8'd0), .input_wr(1'b0),
        .buff_addr(), .buff_read(), .buff_din(8'd0));

    // Only sector storage is mutable. Every other host-written byte must be
    // preserved by the actual payload and split-header read/modify/write path.
    function automatic [7:0] media_byte(input integer a);
        integer relative, entry, position, sector_position;
        relative=a-base;
        if(a>=header && a<header+16+payload_length) return sector_bytes[a-header];
        if(base!=0 && a>=28 && a<32) return 8'(first_size>>(8*(a-28)));
        if(relative>=28 && relative<32) return 8'(volume_size>>(8*(relative-28)));
        if(sector_count>1) begin
            if(relative>=32 && relative<688) begin
                entry=(relative-32)/4;
                if(entry*track_sectors<sector_count)
                    return 8'((688+entry*track_sectors*(16+payload_length))>>(8*((relative-32)%4)));
            end
            if(relative>=688 && relative<volume_size) begin
                position=(relative-688)/(16+payload_length);
                sector_position=(relative-688)%(16+payload_length);
                case(sector_position)
                    0: return 8'((position/track_sectors)/2);
                    1: return 8'((position/track_sectors)%2);
                    2: return 8'(position%track_sectors+1);
                    3: return payload_length==256 ? 1 : 0;
                    4: return 8'((sector_count-position+position%track_sectors<track_sectors) ?
                                sector_count-position+position%track_sectors : track_sectors);
                    14: return 8'(payload_length);
                    15: return 8'(payload_length>>8);
                    default: return sector_position>=16 ? 8'((sector_position-16)*7+3) : 0;
                endcase
            end
            return 0;
        end
        if(relative>=32 && relative<36) return 8'(track_offset>>(8*(relative-32)));
        return 0;
    endfunction
    initial forever begin
        bit writing;
        integer owned_lba, at;
        wait(sd_rd || sd_wr);
        writing=sd_wr; owned_lba=int'(lba);
        assert(!(sd_rd && sd_wr)) else $fatal(1,"simultaneous SD requests");
        if(owned_lba>highest_lba) highest_lba=owned_lba;
        @(negedge clk); ack=1;
        if(writing) writes++;
        for(int i=0;i<512;i++) begin
            host_address=9'(i); at=owned_lba*512+i;
            if(writing) begin
                repeat(2) @(negedge clk);
                if(at>=header && at<header+16+payload_length) sector_bytes[at-header]=host_read_data;
                else assert(host_read_data==media_byte(at))
                    else $fatal(1,"RMW changed surrounding media at=%h",at);
            end else begin
                host_data=media_byte(at); host_wr=1; @(negedge clk);
            end
            assert(lba==32'(owned_lba)) else $fatal(1,"published LBA changed during ACK");
        end
        host_wr=0; repeat(10) @(negedge clk); ack=0;
        repeat(12) @(negedge clk);
    end
    task send(input [1:0] port, input [7:0] value);
        @(negedge clk); address=port; data=value; wr=1;
        repeat(3) @(negedge clk); wr=0; repeat(3) @(negedge clk);
    endtask
    task configure(input integer b, input integer h, input integer total,
                   input integer file_size, input integer table_offset);
        base=b; first_size=b; header=h; volume_size=total;
        size=24'(file_size); track_offset=table_offset; selected=(b!=0)?1:0;
        payload_length=128; sector_count=1; track_sectors=1; target_sector=1; physical_side=0;
        highest_lba=0;
        for(int i=0;i<272;i++) sector_bytes[i]=0;
        sector_bytes[2]=1; sector_bytes[4]=1; sector_bytes[8]=8'hb0;
        sector_bytes[14]=128;
        for(int i=0;i<128;i++) sector_bytes[16+i]=8'(i*7+3);
    endtask
    task scan(input bit accepted, input string label_text);
        @(negedge clk); mounted=1;
        repeat(3) @(negedge clk); mounted=0;
        repeat(4) @(negedge clk);
        wait(!prepare && !dut.mount_pending && idle);
        repeat(4) @(negedge clk);
        assert(dut.media_ready==accepted) else $fatal(1,"width=%0d %s admission=%b",ADDRESS_BITS,label_text,dut.media_ready);
        if(accepted) begin
            assert(dut.edsk_size==sector_count && dut.d88_end==(base+volume_size))
                else $fatal(1,"wrong selected extent/index count");
            assert(dut.image_index.edsk_ram.ram[sector_count-1]==
                   {7'(sector_bytes[0]),physical_side,sector_bytes[0],sector_bytes[1],8'(target_sector),
                    2'(sector_bytes[3]),2'b01,1'b0,ADDRESS_BITS'(header+16)})
                else $fatal(1,"index packing/high address mismatch");
        end else begin
            send(2,1); send(0,8'h80);
            repeat(16) @(negedge clk); address=0; #1;
            assert(!busy && !drq && dout[7]) else $fatal(1,"rejected medium became accessible");
        end
        $display("PASS width=%0d %s admitted=%b max_sd_lba=%h",ADDRESS_BITS,label_text,accepted,highest_lba);
        groups++;
    endtask
    task read_sector(input bit written);
        reg [7:0] value;
        send(2,8'(target_sector)); send(0,8'h80);
        for(int i=0;i<payload_length;i++) begin
            wait(drq || !busy); assert(drq) else $fatal(1,"read truncated byte=%0d",i);
            @(negedge clk); address=3; rd=1;
            repeat(2) @(negedge clk); value=dout;
            rd=0; repeat(3) @(negedge clk);
            assert(value==(written ? (8'(i)^8'h5a) : 8'(i*7+3)))
                else $fatal(1,"high-address SD read byte=%0d got=%h",i,value);
        end
        wait(!busy); address=0; #1;
        assert(dout==(written ? 8'h20 : 8'h08)) else $fatal(1,"CRC/deleted status got=%h",dout);
    endtask
    task exercise;
        integer before_writes;
        // Real SEEK sets the physical cylinder; never inject search state.
        send(3,sector_bytes[0]); send(0,8'h10); wait(!busy);
        read_sector(0); before_writes=writes;
        send(2,8'(target_sector)); send(0,8'ha1);
        for(int i=0;i<payload_length;i++) begin
            wait(drq || !busy); assert(drq) else $fatal(1,"write truncated byte=%0d",i);
            send(3,8'(i)^8'h5a);
        end
        wait(!busy && idle); address=0; #1;
        assert(dout==0) else $fatal(1,"write failed status=%h",dout);
        assert(sector_bytes[7]==8'h10 && sector_bytes[8]==0) else $fatal(1,"split metadata repair failed");
        for(int i=0;i<payload_length;i++) assert(sector_bytes[16+i]==(8'(i)^8'h5a)) else $fatal(1,"payload write mismatch");
        assert(dut.image_index.edsk_ram.ram[sector_count-1]==
               {7'(sector_bytes[0]),physical_side,sector_bytes[0],sector_bytes[1],8'(target_sector),
                2'(sector_bytes[3]),2'b00,1'b1,ADDRESS_BITS'(header+16)})
            else $fatal(1,"metadata commit corrupted packed index");
        assert(writes-before_writes==(((header+16)%512+payload_length+511)/512)+
                                     (((header+7)%512==511)?2:1)) else $fatal(1,"unexpected payload/metadata SD count");
        read_sector(1);
        $display("PASS width=%0d live read/write/header RMW at=%h sd_lba=%h",ADDRESS_BITS,header,highest_lba);
    endtask
    initial begin
        assert($bits(dut.buff_a)==ADDRESS_BITS && $bits(dut.d88_end)==ADDRESS_BITS+1 &&
               $bits(dut.metadata_entry)==37+ADDRESS_BITS &&
               $bits(dut.metadata_index)==((MAX_SECTORS<=2047)?11:12) &&
               $bits(dut.edsk_addr)==((MAX_SECTORS<=2047)?11:12) &&
               $bits(dut.image_index.d77_pres[0])==8+ADDRESS_BITS &&
               $bits(dut.img_size_id)==24) else $fatal(1,"address/index shape mismatch");
        repeat(10) @(negedge clk); reset=0;
        configure(0,1016,1160,1160,1016); scan(1,"default low extent"); exercise();
        configure(0,'h1001f8,'h100288,'h100288,'h1001f8);
        scan(ADDRESS_BITS>=21,"sector offset beyond 1MiB"); if(ADDRESS_BITS>=21) exercise();
        configure('h100080,'h2001f8,'h100208,'h200288,'h100178);
        scan(ADDRESS_BITS>=22,"selected base and relative sector both beyond 1MiB"); if(ADDRESS_BITS>=22) exercise();
        // Exercise the highest representable address byte, not only bit 20.
        if(ADDRESS_BITS>=22) begin
            configure(0,(1<<(ADDRESS_BITS-1))+504,(1<<(ADDRESS_BITS-1))+648,
                      (1<<(ADDRESS_BITS-1))+648,(1<<(ADDRESS_BITS-1))+504);
            scan(1,"highest address bit"); exercise();
        end
        configure(0,688,'h1000000,'hffffff,688); scan(0,"D88 size byte3 overflow");
        configure(0,688,4096,4096,'h1000000); scan(0,"D88 table byte3 overflow");
        configure(0,688,4096,4096,1<<ADDRESS_BITS); scan(0,"table address-width overflow");
        configure('h100080,'h2001f8,(1<<ADDRESS_BITS)-1024,(1<<ADDRESS_BITS)-1,'h100178);
        scan(0,"base plus size carry overflow");
        configure(0,'h1001f8,'h100287,'h100288,'h1001f8);
        scan(0,"payload outside selected volume");
        // Synthetic 4004-entry image: count and address gates are independent.
        // No assertion about native density, transfer rate, FM or spindle speed.
        for(int n=0;n<4;n++) begin
            int count, length, track;
            count=(n<2)?4004:(4093+n); length=(n==1)?256:128;
            configure(0,688+(count-1)*(16+length),688+count*(16+length),
                      688+count*(16+length),688);
            payload_length=length; sector_count=count; track_sectors=26; target_sector=(count-1)%26+1;
            track=(count-1)/26; physical_side=1'(track%2);
            sector_bytes[0]=8'(track/2); sector_bytes[1]=8'(physical_side); sector_bytes[2]=8'(target_sector);
            sector_bytes[3]=(n==1)?1:0; sector_bytes[4]=8'(target_sector);
            sector_bytes[14]=8'(payload_length); sector_bytes[15]=8'(payload_length>>8);
            for(int i=0;i<payload_length;i++) sector_bytes[16+i]=8'(i*7+3);
            scan(MAX_SECTORS>=count && (ADDRESS_BITS>=21 || n!=1),
                 $sformatf("%0d entries length=%0d (last index %0d)",count,payload_length,count-1));
            if(MAX_SECTORS>=count && (ADDRESS_BITS>=21 || n!=1)) exercise();
        end
        $display("PASS standalone ADDRESS_BITS=%0d MAX_SECTORS=%0d groups=%0d",ADDRESS_BITS,MAX_SECTORS,groups); $finish;
    end
    initial begin #3000000000; $fatal(1,"width fixture timeout width=%0d scan=%h",ADDRESS_BITS,dut.scan_addr); end
endmodule
