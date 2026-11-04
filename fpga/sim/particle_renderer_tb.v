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
    integer pistil_init_seen=0;
    integer pistil_particle;
    integer test_material,test_pattern;
    reg stress_glitter=0;
    function [2:0] material_colour;
        input integer m;
        begin
            case(m)
                0:material_colour=1;1:material_colour=2;2:material_colour=3;
                3:material_colour=4;4:material_colour=6;default:material_colour=7;
            endcase
        end
    endfunction
    // Reverse the random gate between TRAIL and DRAW. Every even particle must
    // keep both writes; every odd particle must keep neither. This checks the
    // cached decision with a changing LFSR, not just a constant visible/hidden gate.
    always @(negedge clk) if(stress_glitter)begin
        if(dut.state==4'd9)begin
            if(dut.index[0])force dut.random_state=16'h0000;
            else force dut.random_state=16'h0001;
        end else if(dut.state==4'd6)begin
            if(dut.index[0])force dut.random_state=16'h0001;
            else force dut.random_state=16'h0000;
        end
    end
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
    function signed [6:0] pistil_vx;
        input [2:0] i;
        begin
            case(i)
                0:pistil_vx=0;1:pistil_vx=11;2:pistil_vx=32;3:pistil_vx=11;
                4:pistil_vx=0;5:pistil_vx=-12;6:pistil_vx=-32;default:pistil_vx=-12;
            endcase
        end
    endfunction
    function signed [6:0] pistil_vy;
        input [2:0] i;
        begin
            case(i)
                0:pistil_vy=-32;1:pistil_vy=-12;2:pistil_vy=0;3:pistil_vy=11;
                4:pistil_vy=32;5:pistil_vy=11;6:pistil_vy=0;default:pistil_vy=-12;
            endcase
        end
    endfunction
    function [11:0] pistil_first_head;
        input integer i;
        begin
            case(i)
                0:pistil_first_head=1632;1:pistil_first_head=1696;
                2:pistil_first_head=1762;3:pistil_first_head=1760;
                4:pistil_first_head=1888;5:pistil_first_head=1759;
                6:pistil_first_head=1758;default:pistil_first_head=1695;
            endcase
        end
    endfunction
    function [11:0] pistil_second_head;
        input integer i;
        begin
            case(i)
                0:pistil_second_head=1504;1:pistil_second_head=1633;
                2:pistil_second_head=1764;3:pistil_second_head=1825;
                4:pistil_second_head=2016;5:pistil_second_head=1822;
                6:pistil_second_head=1756;default:pistil_second_head=1630;
            endcase
        end
    endfunction
    always @(posedge clk) if(!rst && dut.state==4'd3 && dut.frame_pattern==2'd3)begin
        if($signed(dut.init_vx)!==pistil_vx(dut.index) ||
           $signed(dut.init_vy)!==pistil_vy(dut.index))
            $fatal(1,"Pistil full/half signed initial velocity incorrect");
        pistil_init_seen=pistil_init_seen+1;
    end
    always @(posedge clk) if (!rst && pixel_we) begin
        if(pixel_data==0) begin
            if(pixel_addr!==expected_clear[11:0])$fatal(1,"clear address order");
            expected_clear=expected_clear+1;cleared=cleared+1;
        end else begin
            if(verify_frame==1 || verify_frame==2)begin
                if(pixel_data!=2)$fatal(1,"green head/trail colour incorrect");
                if(!drawn[0])begin
                    if(pixel_addr !== (verify_frame==1 ? 12'd1760 : first_head(drawn>>1)))
                        $fatal(1,"trail does not match previous frame particle position");
                end else if(pixel_addr !== (verify_frame==1 ? first_head(drawn>>1) : second_head(drawn>>1)))
                    $fatal(1,"head motion/gravity changed while adding trail");
            end
            if(verify_frame==3 || verify_frame==4)begin
                pistil_particle=drawn>>1;
                if(pixel_data!==(pistil_particle[0] ? 3'd6 : 3'd2))
                    $fatal(1,"Pistil outer material / inner white colour incorrect");
                if(!drawn[0])begin
                    if(pixel_addr!==(verify_frame==3 ? 12'd1760 : pistil_first_head(pistil_particle)))
                        $fatal(1,"Pistil previous-position trail incorrect");
                end else if(pixel_addr!==(verify_frame==3 ? pistil_first_head(pistil_particle) : pistil_second_head(pistil_particle)))
                    $fatal(1,"Pistil current head/gravity incorrect");
            end
            if(verify_frame==6 || verify_frame==7)begin
                pistil_particle=verify_frame==6 ? drawn>>1 : (drawn>>1)*2;
                if(pixel_data!==(test_pattern==3 && pistil_particle[0] ? 3'd6 : material_colour(test_material)))
                    $fatal(1,"glitter changed selected material or Pistil core colour");
                if(verify_frame==7 && dut.index[0])
                    $fatal(1,"hidden particle drew after gate changed");
                if((!drawn[0] && dut.state!=4'd6) || (drawn[0] && dut.state!=4'd7))
                    $fatal(1,"glitter split a particle's head/trail writes");
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
        // Geometry regressions deliberately hold the gate visible for all sparks.
        force dut.random_state=16'h0001;
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
        // Fix the random gate in simulation only: this exercises visibility
        // deliberately instead of making the geometry assertions probabilistic.
        force dut.random_state=16'h0001;
        @(negedge clk);launch=1;material=1;pattern=3;
        @(negedge clk);launch=0;material=0;pattern=0;
        // The raw selector changes above must not alter the captured launch.
        verify_frame=3;frame();
        if(drawn!=16 || pistil_init_seen!=8 || dut.frame_pattern!=3)
            $fatal(1,"Pistil launch not captured or incomplete");
        verify_frame=4;frame();
        if(drawn!=16 || dut.frame_pattern!=3)$fatal(1,"Pistil pattern did not remain latched");
        force dut.random_state=16'h0000;
        verify_frame=0;frame();
        if(drawn!=0)$fatal(1,"Pistil outer and inner glitter must hide together");
        verify_frame=0;
        @(negedge clk);launch=1;material=4;pattern=3;
        @(negedge clk);launch=0;
        frame();if(drawn!=0)$fatal(1,"Aluminium outer/inner glitter visibility mismatch");
        // Every material in every pattern uses the same gate, retains its colour,
        // and keeps advancing while hidden. Raw selectors must not alter a burst.
        for(test_material=0;test_material<6;test_material=test_material+1)begin
            for(test_pattern=0;test_pattern<4;test_pattern=test_pattern+1)begin
                force dut.random_state=16'h0001;
                @(negedge clk);launch=1;material=test_material[2:0];pattern=test_pattern[1:0];
                @(negedge clk);launch=0;material=test_material==5 ? 3'd0 : test_material[2:0]+3'd1;pattern=test_pattern[1:0]+2'd1;
                verify_frame=6;frame();
                if(drawn!=16 || dut.active_material!=test_material[2:0] || dut.frame_pattern!=test_pattern[1:0])
                    $fatal(1,"visible glitter launch/selection missing for material %0d pattern %0d",test_material,test_pattern);
                force dut.random_state=16'h0000;
                frame();if(drawn!=0)$fatal(1,"hidden glitter frame drew pixels");
                stress_glitter=1;verify_frame=7;frame();stress_glitter=0;
                if(drawn!=8 || dut.life!=46 || dut.active_material!=test_material[2:0] || dut.frame_pattern!=test_pattern[1:0])
                    $fatal(1,"paired glitter recovery/latched motion failed for material %0d pattern %0d",test_material,test_pattern);
            end
        end
        release dut.random_state;
        $display("PASS: existing renderer/Pistil geometry regressions; all 24 material/pattern combinations glitter with preserved colours, latched selection and paired head/trail visibility under a changing gate");
        $finish;
    end
    initial begin #10000000;$fatal(1,"test timeout");end
endmodule
