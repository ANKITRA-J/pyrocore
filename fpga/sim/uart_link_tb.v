`timescale 1ns/1ps
// Digital link coverage only; baud/phase sweeps are not electrical board tests.
module uart_link_tb;
    localparam CPB=10;
    localparam COMMAND_BYTES=14;
    localparam RUN_BYTES=COMMAND_BYTES+256;
    localparam RUNS=12;
    reg clk=0;
    always #160 clk=~clk; // Production 3.125 MHz core clock.
    reg rst=1,rx_serial=1;
    wire [7:0] rx_data;
    wire rx_valid,rx_error,busy;
    uart_rx #(.CLKS_PER_BIT(CPB)) dut(.*);

    reg [7:0] expected[0:RUNS*RUN_BYTES-1];
    integer sent=0,received=0;
    always @(posedge clk) begin
        if(!rst) begin
            if(rx_error)$fatal(1,"UART framing error after byte %0d",received);
            if(rx_valid) begin
                if(received>=sent)$fatal(1,"unexpected UART byte %02x",rx_data);
                if(rx_data!==expected[received])
                    $fatal(1,"UART byte %0d: expected %02x, received %02x",
                           received,expected[received],rx_data);
                received=received+1;
            end
        end
    end

    function [7:0] command_byte;
        input integer index;
        begin
            // Launch, Clear, material endpoints, pattern endpoints, frame request.
            case(index)
                0:command_byte=8'h01;  1:command_byte=8'hfe;
                2:command_byte=8'h02;  3:command_byte=8'hfd;
                4:command_byte=8'h10;  5:command_byte=8'hef;
                6:command_byte=8'h15;  7:command_byte=8'hea;
                8:command_byte=8'h20;  9:command_byte=8'hdf;
                10:command_byte=8'h23;11:command_byte=8'hdc;
                12:command_byte=8'hf0;default:command_byte=8'h0f;
            endcase
        end
    endfunction

    task send_byte;
        input [7:0] value;
        input realtime bit_ns;
        integer bit_index;
        begin
            expected[sent]=value;
            sent=sent+1;
            rx_serial=0;
            #(bit_ns);
            for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin
                rx_serial=value[bit_index];
                #(bit_ns);
            end
            rx_serial=1;
            #(bit_ns); // One stop bit; the next byte starts immediately.
        end
    endtask

    task run_link;
        input integer baud_percent;
        input integer phase_ns;
        realtime bit_ns;
        integer index;
        begin
            // Peer baud is nominal 312500 multiplied by baud_percent / 100.
            bit_ns=3200.0*100.0/baud_percent;
            @(negedge clk);
            #(phase_ns);
            for(index=0;index<COMMAND_BYTES;index=index+1)
                send_byte(command_byte(index),bit_ns);
            // Includes all-zero/all-one, alternating, and single-bit patterns.
            for(index=0;index<256;index=index+1)
                send_byte(index[7:0],bit_ns);
            repeat(5)@(negedge clk);
            if(received!=sent || busy)
                $fatal(1,"UART incomplete at peer baud %0d%%, phase %0d ns: %0d/%0d bytes",
                       baud_percent,phase_ns,received,sent);
            $display("PASS: UART peer baud %0d%%, phase %0d ns, %0d back-to-back bytes",
                     baud_percent,phase_ns,RUN_BYTES);
        end
    endtask

    integer baud_percent;
    initial begin
        repeat(5)@(negedge clk);
        rst=0;
        for(baud_percent=99;baud_percent<=101;baud_percent=baud_percent+1) begin
            run_link(baud_percent,1);
            run_link(baud_percent,73);
            run_link(baud_percent,161);
            run_link(baud_percent,271);
        end
        if(received!=RUNS*RUN_BYTES)
            $fatal(1,"UART regression received %0d bytes, expected %0d",received,RUNS*RUN_BYTES);
        $display("PASS: production 3.125 MHz / CPB10 UART received all %0d bytes; nominal and +/-1%% peer baud, four asynchronous start phases, no extra idle bits",
                 received);
        $finish;
    end
    initial begin
        #200000000;
        $fatal(1,"UART link regression timeout: received %0d/%0d bytes",received,sent);
    end
endmodule
