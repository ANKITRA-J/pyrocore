// UART receiver module
// 115200 baud, 8N1 format, with 2-FF synchronizer and framing error detection

module uart_rx #(
  parameter CLKS_PER_BIT = 434  // 50MHz / 115200 = 434
)(
  input clk,
  input rst,
  input rx_serial,
  output reg [7:0] rx_data,
  output reg rx_valid,
  output reg rx_error,
  output reg busy
);

  // 2-FF synchronizer for metastability protection
  reg rx_sync1, rx_sync2;
  
  // State machine
  localparam IDLE = 3'd0;
  localparam START = 3'd1;
  localparam DATA = 3'd2;
  localparam STOP = 3'd3;
  
  reg [2:0] state;
  localparam COUNTER_BITS = $clog2(CLKS_PER_BIT);
  reg [COUNTER_BITS-1:0] clk_count;
  reg [2:0] bit_index;
  reg [7:0] rx_shift;
  
  always @(posedge clk) begin
    if (rst) begin
      rx_sync1 <= 1'b1;
      rx_sync2 <= 1'b1;
      state <= IDLE;
      clk_count <= 0;
      bit_index <= 3'd0;
      rx_shift <= 8'd0;
      rx_data <= 8'd0;
      rx_valid <= 1'b0;
      rx_error <= 1'b0;
      busy <= 1'b0;
    end else begin
      // Synchronizer
      rx_sync1 <= rx_serial;
      rx_sync2 <= rx_sync1;
      
      // Clear pulse outputs
      rx_valid <= 1'b0;
      rx_error <= 1'b0;
      
      case (state)
        IDLE: begin
          busy <= 1'b0;
          clk_count <= 0;
          bit_index <= 3'd0;
          // Detect start bit (idle-to-low transition)
          if (rx_sync2 == 1'b0) begin
            state <= START;
            busy <= 1'b1;
          end
        end
        
        START: begin
          if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
            // Sample at bit center
            if (rx_sync2 == 1'b0) begin
              // Valid start bit
              clk_count <= 0;
              state <= DATA;
            end else begin
              // False start bit (glitch)
              state <= IDLE;
            end
          end else begin
            clk_count <= clk_count + 1;
          end
        end
        
        DATA: begin
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            // Sample data bit (LSB first)
            rx_shift[bit_index] <= rx_sync2;
            
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
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            // Check stop bit
            if (rx_sync2 == 1'b1) begin
              // Valid stop bit
              rx_data <= rx_shift;
              rx_valid <= 1'b1;
            end else begin
              // Framing error
              rx_error <= 1'b1;
            end
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
