`timescale 1ns/1ps
// Compare the actual frame serializer at the old and new link rates. This models
// a polling bridge, not ESP32 execution time, native USB, or physical wiring.
module stream_rate_case #(
    parameter CPB=10, TARGET_FPS=18
)(input clk, output reg finished=0);
    localparam REQUEST_CYCLES=(1000/TARGET_FPS)*3125;
    localparam FRAME_COUNT=6;
    reg rst=1,uart_rx_pin=1;
    wire uart_tx_pin,mem_we,mem_wbank,mem_re,mem_rbank,led;
    wire [11:0] mem_waddr,mem_raddr;
    wire [2:0] mem_wdata;
    reg [2:0] mem_rdata=0;
    reg [2:0] bank0[0:4095],bank1[0:4095],snapshot[0:4095];
    pyrocore_core #(.CLKS_PER_BIT(CPB)) dut(.*);
    always @(posedge clk) begin
        if(mem_we) begin
            if(mem_wbank)bank1[mem_waddr]<=mem_wdata;
            else bank0[mem_waddr]<=mem_wdata;
        end
        if(mem_re)mem_rdata<=mem_rbank ? bank1[mem_raddr] : bank0[mem_raddr];
        if(!rst && mem_we && dut.stream_busy && mem_wbank==mem_rbank)
            $fatal(1,"rate test: write to transmitting bank");
    end

    task send_byte(input [7:0] value);
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
    task command(input [7:0] opcode);
        begin send_byte(opcode);send_byte(~opcode);end
    endtask
    task receive_byte(output [7:0] value);
        integer b;
        begin
            @(negedge uart_tx_pin);
            repeat(CPB+CPB/2)@(posedge clk);
            for(b=0;b<8;b=b+1)begin
                value[b]=uart_tx_pin;repeat(CPB)@(posedge clk);
            end
            if(!uart_tx_pin)$fatal(1,"rate test: UART stop bit missing");
        end
    endtask
    function [7:0] crc_next(input [7:0] c,d);
        reg [7:0] v;
        integer b;
        begin
            v=c^d;
            for(b=0;b<8;b=b+1)v=v[7] ? (v<<1)^8'h07 : v<<1;
            crc_next=v;
        end
    endfunction
    reg [7:0] packet[0:1544];
    reg [15:0] previous_sequence=0;
    time stream_started,stream_finished,first_arrival,last_arrival,requested;
    integer stream_cycles,reference_cycles=0;
    integer frame_index;
    real measured_fps;
    task receive_frame;
        integer i,g,j;
        reg [7:0] c,byte_value;
        reg [23:0] packed_group;
        reg [15:0] sequence_number;
        reg locked_bank;
        begin
            wait(dut.stream_busy);
            stream_started=$time;
            locked_bank=mem_rbank;
            for(i=0;i<4096;i=i+1)snapshot[i]=mem_rbank ? bank1[i] : bank0[i];
            for(i=0;i<1545;i=i+1)begin receive_byte(byte_value);packet[i]=byte_value;end
            wait(!dut.stream_busy);
            stream_finished=$time;
            stream_cycles=integer'((stream_finished-stream_started)/320);
            if(reference_cycles==0)reference_cycles=stream_cycles;
            else if(stream_cycles!=reference_cycles)$fatal(1,"rate test: frame duration varied");
            if(stream_cycles>=REQUEST_CYCLES-20*CPB)
                $fatal(1,"rate test: requested cadence exceeds serialized frame budget");
            if(mem_rbank!=locked_bank)$fatal(1,"rate test: read bank changed during transfer");
            if(packet[0]!=8'h50 || packet[1]!=8'h59 || packet[2]!=1 || packet[3]!=8'h46 ||
               packet[6]!=0 || packet[7]!=6)$fatal(1,"rate test: bad frame header");
            c=0;for(i=2;i<1544;i=i+1)c=crc_next(c,packet[i]);
            if(c!=packet[1544])$fatal(1,"rate test: frame CRC mismatch");
            sequence_number={packet[5],packet[4]};
            if(frame_index>0 && sequence_number<=previous_sequence)
                $fatal(1,"rate test: packets repeated the same rendered frame");
            previous_sequence=sequence_number;
            for(g=0;g<512;g=g+1)begin
                packed_group={packet[8+g*3+2],packet[8+g*3+1],packet[8+g*3]};
                for(j=0;j<8;j=j+1)
                    if(((packed_group>>(3*j))&7)!=={21'd0,snapshot[g*8+j]})
                        $fatal(1,"rate test: pixel/RAM snapshot mismatch");
            end
            if(frame_index==0)first_arrival=stream_finished;
            last_arrival=stream_finished;
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        command(8'h11);command(8'h21);command(8'h01);
        repeat(125000)@(negedge clk);
        for(frame_index=0;frame_index<FRAME_COUNT;frame_index=frame_index+1)begin
            requested=$time;
            fork command(8'hf0);receive_frame();join
            while($time<requested+REQUEST_CYCLES*320)@(negedge clk);
        end
        measured_fps=real'(FRAME_COUNT-1)*1.0e9/real'(last_arrival-first_arrival);
        if(measured_fps<real'(TARGET_FPS)*0.99)$fatal(1,"rate test: failed requested frame cadence");
        $display("PASS: CPB=%0d target=%0d, %0d CRC-valid advancing frames; all4096 pixels match RAM",CPB,TARGET_FPS,FRAME_COUNT);
        $display("MEASURE: CPB=%0d stream_cycles=%0d transfer_ms=%0.6f serializer_ceiling_fps=%0.6f polling_fps=%0.6f (simulation only)",
                 CPB,reference_cycles,real'(reference_cycles)*0.00032,
                 3125000.0/real'(reference_cycles),measured_fps);
        finished=1;
    end
endmodule

module pyrocore_stream_rate_tb;
    reg clk=0;always #160 clk=~clk; // Production 3.125 MHz core clock.
    wire fast_done,baseline_done;
    stream_rate_case #(.CPB(10),.TARGET_FPS(18)) faster(clk,fast_done);
    stream_rate_case #(.CPB(27),.TARGET_FPS(7)) baseline(clk,baseline_done);
    initial begin
        wait(fast_done && baseline_done);
        $display("PASS: faster link meets18 target versus7 baseline without repeated frame sequences or ownership violations; MCU/USB/hardware unmeasured");
        $finish;
    end
    initial begin #2000000000;$fatal(1,"stream-rate test timeout");end
endmodule
