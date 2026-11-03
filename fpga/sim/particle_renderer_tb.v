`timescale 1ns/1ps
module particle_renderer_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,start=0,launch=0,clear=0;
    reg [2:0] material=0;
    reg [1:0] pattern=0;
    wire busy,done,pixel_we;
    wire [11:0] pixel_addr;
    wire [2:0] pixel_data;
    particle_renderer dut(.*);
    integer cleared,drawn,cycles,expected_clear;
    integer verify_frame=0;
    integer trail_for_pair=0;
    function [11:0] first_head;
        input integer i;
        begin
            case(i)
                0:first_head=1632;1:first_head=1633;2:first_head=1762;3:first_head=1825;
                4:first_head=1888;5:first_head=1822;6:first_head=1758;default:first_head=1630;
            endcase
        end
    endfunction
    function [11:0] second_head;
        input integer i;
        begin
            case(i)
                0:second_head=1504;1:second_head=1570;2:second_head=1764;3:second_head=1890;
                4:second_head=2016;5:second_head=1885;6:second_head=1756;default:second_head=1565;
            endcase
        end
    endfunction
    always @(posedge clk) if (!rst && pixel_we) begin
        if(pixel_data==0) begin
            if(pixel_addr!==expected_clear[11:0])$fatal(1,"clear address order");
            expected_clear=expected_clear+1;cleared=cleared+1;
        end else begin
            if(verify_frame!=0)begin
                if(pixel_data!=2)$fatal(1,"green head/trail colour incorrect");
                if(!drawn[0])begin
                    if(pixel_addr !== (verify_frame==1 ? 12'd1760 : first_head(drawn>>1)))
                        $fatal(1,"trail does not match previous frame particle position");
                end else if(pixel_addr !== (verify_frame==1 ? first_head(drawn>>1) : second_head(drawn>>1)))
                    $fatal(1,"head motion/gravity changed while adding trail");
            end
            if(!drawn[0])trail_for_pair={29'd0,pixel_data};
            else if(pixel_data!==trail_for_pair[2:0])$fatal(1,"head/trail colour mismatch");
            drawn=drawn+1;
            if(drawn>16)$fatal(1,"more than two writes per particle");
        end
    end
    task frame;
        begin
            @(negedge clk);cleared=0;drawn=0;cycles=0;expected_clear=0;
            start=1;@(negedge clk);start=0;
            while(!done)begin
                @(negedge clk);cycles=cycles+1;
                if(cycles>4300)$fatal(1,"renderer timeout");
            end
            if(cleared!=4096)$fatal(1,"full framebuffer clear missing");
            if(drawn[0])$fatal(1,"head/trail visibility not paired");
            if(pixel_we)$fatal(1,"done overlaps uncommitted pixel write");
            @(negedge clk);
        end
    endtask
    initial begin
        cleared=0;drawn=0;cycles=0;expected_clear=0;
        repeat(3)@(negedge clk);rst=0;
        frame();if(drawn!=0)$fatal(1,"unlaunched particles drawn");
        @(negedge clk);launch=1;pattern=1;material=1;
        @(negedge clk);launch=0;
        verify_frame=1;frame();if(drawn!=16)$fatal(1,"ring did not draw eight heads and trails");
        verify_frame=2;frame();if(drawn!=16)$fatal(1,"second ring frame missing paired writes");
        verify_frame=0;
        @(negedge clk);start=1;cleared=0;drawn=0;expected_clear=0;
        @(negedge clk);start=0;repeat(10)@(negedge clk);
        launch=1;material=3;pattern=2;
        @(negedge clk);launch=0;
        wait(done);@(negedge clk);@(negedge clk);
        frame();if(drawn!=16)$fatal(1,"queued willow launch missing");
        @(negedge clk);launch=1;material=4;pattern=1;
        @(negedge clk);launch=0;
        frame();if(drawn==0)$fatal(1,"aluminium visibility unexpectedly empty");
        @(negedge clk);clear=1;
        @(negedge clk);clear=0;
        frame();if(drawn!=0)$fatal(1,"clear left live particles");
        frame();if(drawn!=0)$fatal(1,"cleared particles revived");
        $display("PASS: full clears,16 head/trail writes, exact previous positions and unchanged gravity, queued launch, paired glitter, clear/done ordering");
        $finish;
    end
    initial begin #1000000;$fatal(1,"test timeout");end
endmodule
