`timescale 1ns/1ps
module pyrocore_core_tb;
    localparam CPB=10;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,uart_rx_pin=1;
    wire uart_tx_pin,mem_we,mem_wbank,mem_re,mem_rbank,led;
    wire [11:0] mem_waddr,mem_raddr;
    wire [2:0] mem_wdata;
    reg [2:0] mem_rdata=0;
    reg [2:0] bank0[0:4095],bank1[0:4095];
    pyrocore_core #(.CLKS_PER_BIT(CPB),.FRAME_CYCLES(5000),.COMMAND_TIMEOUT(200)) dut(.*);
    always @(posedge clk) begin
        if(mem_we) begin
            if(mem_wbank)bank1[mem_waddr]<=mem_wdata;
            else bank0[mem_waddr]<=mem_wdata;
        end
        if(mem_re)mem_rdata<=mem_rbank ? bank1[mem_raddr] : bank0[mem_raddr];
        if(!rst && mem_we && dut.stream_busy && mem_wbank==mem_rbank)
            $fatal(1,"renderer wrote the framebuffer being transmitted");
    end

    reg stream_was_busy=0,locked_bank=0;
    reg [15:0] locked_sequence=0;
    always @(posedge clk) begin
        if(rst)stream_was_busy<=0;
        else begin
            stream_was_busy<=dut.stream_busy;
            if(dut.stream_busy && !stream_was_busy)begin
                locked_bank<=dut.front_bank;locked_sequence<=dut.front_sequence;
            end
            if(dut.stream_busy && stream_was_busy &&
               (dut.front_bank!=locked_bank || dut.front_sequence!=locked_sequence))
                $fatal(1,"front buffer changed during transfer");
        end
    end

    task send_byte;
        input [7:0] value;
        integer b;
        begin
            @(negedge clk);uart_rx_pin=0;
            repeat(CPB)@(negedge clk);
            for(b=0;b<8;b=b+1)begin
                uart_rx_pin=value[b];repeat(CPB)@(negedge clk);
            end
            uart_rx_pin=1;repeat(CPB)@(negedge clk);
        end
    endtask
    task command;
        input [7:0] opcode;
        begin send_byte(opcode);send_byte(~opcode);end
    endtask
    task receive_byte;
        output [7:0] value;
        integer b;
        begin
            @(negedge uart_tx_pin);
            repeat(CPB+CPB/2)@(posedge clk);
            for(b=0;b<8;b=b+1)begin
                value[b]=uart_tx_pin;
                repeat(CPB)@(posedge clk);
            end
            if(!uart_tx_pin)$fatal(1,"UART stop bit missing");
        end
    endtask
    function [7:0] crc_next;
        input [7:0] c,d;
        reg [7:0] v;integer b;
        begin
            v=c^d;
            for(b=0;b<8;b=b+1)v=v[7] ? (v<<1)^8'h07 : v<<1;
            crc_next=v;
        end
    endfunction
    reg [7:0] packet[0:1544];
    reg [2:0] snapshot[0:4095];
    reg [15:0] first_sequence,second_sequence,pistil_sequence;
    reg expect_pistil=0;
    integer lit_pixels,shell_pixels,core_pixels;
    task receive_frame;
        input integer save_packet;
        output [15:0] seq_out;
        integer i,g,j,fd;
        reg [7:0] c,byte_value;
        reg [23:0] group_word;
        reg [2:0] pixel;
        begin
            wait(dut.stream_busy);
            for(i=0;i<4096;i=i+1)snapshot[i]=mem_rbank ? bank1[i] : bank0[i];
            for(i=0;i<1545;i=i+1)begin receive_byte(byte_value);packet[i]=byte_value;end
            if(packet[0]!=8'h50 || packet[1]!=8'h59 || packet[2]!=1 || packet[3]!=8'h46)
                $fatal(1,"frame sync/version/type incorrect");
            if(packet[6]!=0 || packet[7]!=6)$fatal(1,"payload length incorrect");
            seq_out={packet[5],packet[4]};
            c=0;for(i=2;i<1544;i=i+1)c=crc_next(c,packet[i]);
            if(c!=packet[1544])$fatal(1,"frame CRC mismatch");
            lit_pixels=0;shell_pixels=0;core_pixels=0;
            for(g=0;g<512;g=g+1)begin
                group_word={packet[8+g*3+2],packet[8+g*3+1],packet[8+g*3]};
                for(j=0;j<8;j=j+1)begin
                    pixel=(group_word>>(j*3))&3'b111;
                    if(pixel!==snapshot[g*8+j])$fatal(1,"frame packing/RAM latency mismatch at pixel %0d",g*8+j);
                    if(pixel!=0)begin
                        if(expect_pistil)begin
                            if(pixel==4)shell_pixels=shell_pixels+1;
                            else if(pixel==6)core_pixels=core_pixels+1;
                            else $fatal(1,"Pistil frame contained an unexpected colour");
                        end else if(pixel!=2)$fatal(1,"material selection was not green");
                        lit_pixels=lit_pixels+1;
                    end
                end
            end
            if(lit_pixels<4)$fatal(1,"launch did not produce visible FPGA particles");
            if(expect_pistil && (shell_pixels==0 || core_pixels==0))
                $fatal(1,"Pistil frame must contain selected yellow shell and white core pixels");
            if(save_packet)begin
                if(save_packet==2)fd=$fopen("pistil_frame_packet.bin","wb");
                else fd=$fopen("frame_packet.bin","wb");
                if(!fd)$fatal(1,"cannot open frame_packet.bin");
                for(i=0;i<1545;i=i+1)$fwrite(fd,"%c",packet[i]);
                $fclose(fd);
            end
            $display("PASS: UART frame seq=%0d, CRC and4096 pixels match immutable RAM snapshot, lit=%0d",seq_out,lit_pixels);
            if(expect_pistil)$display("PASS: Pistil packed frame contains %0d yellow shell and %0d white core pixels",shell_pixels,core_pixels);
        end
    endtask
    integer i;
    initial begin
        repeat(5)@(negedge clk);rst=0;
        wait(dut.front_valid);
        // An invalid complement must leave the scene empty.
        send_byte(8'h01);send_byte(8'h00);
        repeat(6000)@(negedge clk);
        for(i=0;i<4096;i=i+1)
            if((dut.front_bank ? bank1[i] : bank0[i])!=0)$fatal(1,"malformed launch command executed");
        command(8'h11);command(8'h21);command(8'h01);
        repeat(11000)@(negedge clk);
        // Request directly: following the opcode pair, receiver decoding precedes
        // transmission by only a few cycles, so receive_frame begins immediately.
        send_byte(8'hf0);
        fork
            send_byte(8'h0f);
            receive_frame(1,first_sequence);
        join
        wait(!dut.stream_busy);
        repeat(6000)@(negedge clk);
        send_byte(8'hf0);
        fork
            send_byte(8'h0f);
            receive_frame(0,second_sequence);
        join
        if(second_sequence<=first_sequence)$fatal(1,"front sequence did not advance");
        wait(!dut.stream_busy);
        command(8'h23);
        if(dut.pattern!=3)$fatal(1,"Pistil opcode 0x23 was not accepted");
        command(8'h24);
        if(dut.pattern!=3)$fatal(1,"unknown pattern opcode changed the selection");
        command(8'h13);command(8'h01);
        repeat(11000)@(negedge clk);
        expect_pistil=1;
        send_byte(8'hf0);
        fork
            send_byte(8'h0f);
            receive_frame(2,pistil_sequence);
        join
        if(pistil_sequence<=second_sequence)$fatal(1,"Pistil frame sequence did not advance");
        $display("PASS: malformed/unknown commands rejected, opcode 0x23 accepted, three complete UART frames including dual-colour Pistil");
        $finish;
    end
    initial begin #10000000;$fatal(1,"end-to-end UART test timeout");end
endmodule
