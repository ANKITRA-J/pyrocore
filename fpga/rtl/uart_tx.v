// UART transmitter module
// 115200 baud, 8N1 format

module uart_tx #(
  parameter CLKS_PER_BIT = 434  // 50MHz / 115200 = 434
)(
  input clk,
  input rst,
  input tx_start,
  input [7:0] tx_data,
  output reg tx_serial,
  output reg busy
);

  // State machine
  localparam IDLE = 3'd0;
  localparam START = 3'd1;
  localparam DATA = 3'd2;
  localparam STOP = 3'd3;
  
  reg [2:0] state;
  localparam COUNTER_BITS = $clog2(CLKS_PER_BIT);
  reg [COUNTER_BITS-1:0] clk_count;
  reg [2:0] bit_index;
  reg [7:0] tx_shift;
  
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      clk_count <= 0;
      bit_index <= 3'd0;
      tx_shift <= 8'd0;
      tx_serial <= 1'b1;
      busy <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          tx_serial <= 1'b1;
          busy <= 1'b0;
          clk_count <= 0;
          bit_index <= 3'd0;
          
          if (tx_start) begin
            tx_shift <= tx_data;
            busy <= 1'b1;
            state <= START;
          end
        end
        
        START: begin
          tx_serial <= 1'b0;  // Start bit
          
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            state <= DATA;
          end else begin
            clk_count <= clk_count + 1;
          end
        end
        
        DATA: begin
          tx_serial <= tx_shift[bit_index];  // LSB first
          
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            
            if (bit_index == 3'd7) begin
              bit_index <= 3'd0;
              state <= STOP;
            end else begin
              bit_index <= bit_index + 1;
            end
          end else begin
            clk_count <= clk_count + 1;
          end
        end
        
        STOP: begin
          tx_serial <= 1'b1;  // Stop bit
          
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            state <= IDLE;
          end else begin
            clk_count <= clk_count + 1;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule
