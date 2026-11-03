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
    integer cleared,drawn,cycles;
    integer expected_clear;
    integer first_addr;
    integer current_first_addr=0;
    always @(posedge clk) if (!rst && pixel_we) begin
        if(pixel_data==0) begin
            if(pixel_addr!==expected_clear[11:0]) $fatal(1,"clear address order");
            expected_clear=expected_clear+1;
            cleared=cleared+1;
        end else begin
            if(pixel_data>7) $fatal(1,"invalid colour");
            if(drawn==0) current_first_addr={20'd0,pixel_addr};
            drawn=drawn+1;
        end
    end
    task frame;
        begin
            @(negedge clk); cleared=0;drawn=0;cycles=0;expected_clear=0;
            start=1;
            @(negedge clk);start=0;
            while(!done) begin
                @(negedge clk);cycles=cycles+1;
                if(cycles>4300)$fatal(1,"renderer timeout");
            end
            if(cleared!=4096)$fatal(1,"frame must clear every pixel");
            if(pixel_we)$fatal(1,"done overlaps a pending pixel write");
            @(negedge clk);
        end
    endtask
    initial begin
        cleared=0;drawn=0;cycles=0;expected_clear=0;first_addr=-1;
        repeat(3)@(negedge clk);rst=0;
        frame();if(drawn!=0)$fatal(1,"unlaunched particles drawn");
        @(negedge clk);launch=1;pattern=1;material=1;
        @(negedge clk);launch=0;
        frame();if(drawn!=8)$fatal(1,"launch did not draw eight particles");
        if(current_first_addr!=1632)$fatal(1,"first fixed-point integration incorrect");
        first_addr=current_first_addr;
        frame();if(drawn!=8 || current_first_addr==first_addr)$fatal(1,"particles did not move");
        if(current_first_addr!=1504)$fatal(1,"gravity integration incorrect");
        // Launch during framebuffer clear is queued for the following render.
        @(negedge clk);start=1;cleared=0;drawn=0;expected_clear=0;
        @(negedge clk);start=0;
        repeat(10)@(negedge clk);
        launch=1;material=3;pattern=2;
        @(negedge clk);launch=0;
        wait(done);@(negedge clk);@(negedge clk);
        frame();if(drawn!=8)$fatal(1,"queued launch missing");
        @(negedge clk);clear=1;
        @(negedge clk);clear=0;
        frame();if(drawn!=0)$fatal(1,"clear left live particles");
        frame();if(drawn!=0)$fatal(1,"particles revived after clear");
        $display("PASS: full clears, eight-particle launch/motion, queued launch, clear and done ordering");
        $finish;
    end
    initial begin #1000000;$fatal(1,"test timeout");end
endmodule
