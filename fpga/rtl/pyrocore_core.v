// Board-independent engine: command decoder, renderer ownership and frame UART.
module pyrocore_core #(
    parameter CLKS_PER_BIT=27,
    parameter FRAME_CYCLES=125000,
    parameter COMMAND_TIMEOUT=312500
)(
    input clk,input rst,input uart_rx_pin,output uart_tx_pin,
    output mem_we,output mem_wbank,output [11:0] mem_waddr,output [2:0] mem_wdata,
    output mem_re,output mem_rbank,output [11:0] mem_raddr,input [2:0] mem_rdata,
    output led
);
    wire [7:0] rx_data;wire rx_valid,rx_error,rx_busy;
    wire tx_busy,tx_start;wire [7:0] tx_data;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) receiver(
      .clk(clk),.rst(rst),.rx_serial(uart_rx_pin),.rx_data(rx_data),
      .rx_valid(rx_valid),.rx_error(rx_error),.busy(rx_busy));
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) transmitter(
      .clk(clk),.rst(rst),.tx_start(tx_start),.tx_data(tx_data),
      .tx_serial(uart_tx_pin),.busy(tx_busy));
    reg pair_pending,command_valid;
    reg [7:0] pending_opcode,command;
    localparam TIMEOUT_BITS=$clog2(COMMAND_TIMEOUT+1);
    reg [TIMEOUT_BITS-1:0] pair_timer;
    wire opcode_known=rx_data==8'h01 || rx_data==8'h02 || rx_data==8'hf0 ||
        (rx_data>=8'h10 && rx_data<=8'h15) || rx_data[7:2]==6'h08;
    always @(posedge clk) begin
      if(rst) begin pair_pending<=0;command_valid<=0;pending_opcode<=0;command<=0;pair_timer<=0;end
      else begin
        command_valid<=0;
        if(pair_pending) begin
          if(pair_timer==COMMAND_TIMEOUT-1) begin pair_pending<=0;pair_timer<=0;end
          else pair_timer<=pair_timer+1'b1;
        end
        if(rx_error) pair_pending<=0;
        if(rx_valid) begin
          if(pair_pending && rx_data==~pending_opcode) begin
            command<=pending_opcode;command_valid<=1;pair_pending<=0;
          end else begin
            pair_pending<=opcode_known;pending_opcode<=rx_data;
          end
          pair_timer<=0;
        end
      end
    end
    reg [2:0] material;
    reg [1:0] pattern;
    reg launch,clear,render_start;
    wire render_busy,render_done;
    particle_renderer renderer(.clk(clk),.rst(rst),.start(render_start),
      .launch(launch),.clear(clear),.material(material),.pattern(pattern),
      .busy(render_busy),.done(render_done),.pixel_we(mem_we),
      .pixel_addr(mem_waddr),.pixel_data(mem_wdata));

    reg front_bank,render_bank,front_valid,back_ready,render_inflight;
    reg [15:0] front_sequence;
    reg stream_start;
    wire stream_busy;
    localparam FRAME_BITS=$clog2(FRAME_CYCLES+1);
    reg [FRAME_BITS-1:0] frame_timer;
    wire frame_tick=frame_timer==FRAME_CYCLES-1;
    wire request=command_valid && command==8'hf0;
    assign mem_wbank=render_bank;
    assign mem_re=stream_busy;
    assign led=front_valid && (stream_busy || front_sequence[3]);
    frame_streamer streamer(.clk(clk),.rst(rst),.start(stream_start),
      .frame_bank(front_bank),.frame_seq(front_sequence),.mem_data(mem_rdata),
      .mem_bank(mem_rbank),.mem_addr(mem_raddr),.tx_busy(tx_busy),
      .tx_start(tx_start),.tx_data(tx_data),.busy(stream_busy));
    always @(posedge clk) begin
      if(rst) begin
        material<=0;pattern<=0;launch<=0;clear<=0;render_start<=0;
        front_bank<=0;render_bank<=0;front_valid<=0;back_ready<=0;
        render_inflight<=0;front_sequence<=0;stream_start<=0;frame_timer<=0;
      end else begin
        launch<=0;clear<=0;render_start<=0;stream_start<=0;
        frame_timer<=frame_tick ? 0 : frame_timer+1'b1;
        if(command_valid) begin
          if(command>=8'h10 && command<=8'h15) material<=command[2:0];
          if(command[7:2]==6'h08) pattern<=command[1:0];
          if(command==8'h01) launch<=1;
          if(command==8'h02) clear<=1;
        end
        if(!render_inflight && !back_ready && (!front_valid || frame_tick)) begin
          render_bank<=front_valid ? !front_bank : 1'b0;
          render_start<=1;render_inflight<=1;
        end
        if(render_done && render_inflight) begin
          render_inflight<=0;
          if(!front_valid) begin front_bank<=render_bank;front_valid<=1;end
          else back_ready<=1;
        end
        // stream_start is also a guard: stream_busy rises one edge after it.
        if(back_ready && !stream_busy && !stream_start && !request) begin
          front_bank<=render_bank;front_sequence<=front_sequence+1'b1;back_ready<=0;
        end
        if(request && front_valid && !stream_busy && !stream_start) stream_start<=1;
      end
    end
endmodule
