// Read one immutable front buffer and send a CRC-protected protocol-v1 frame.
// Eight 3-bit indices form one little-endian 24-bit payload group.
module frame_streamer (
    input clk, input rst, input start,
    input frame_bank, input [15:0] frame_seq,
    input [2:0] mem_data,
    output reg mem_bank, output reg [11:0] mem_addr,
    input tx_busy, output reg tx_start, output reg [7:0] tx_data,
    output reg busy
);
    localparam IDLE=0, HEADER=1, READ_ADDR=2, READ_CAPTURE=3,
               PAYLOAD=4, CRC=5, WAIT_HIGH=6, WAIT_LOW=7, FINISH=8;
    reg [3:0] state, after_tx;
    reg [3:0] header_index;
    reg [2:0] pixel_index;
    reg [1:0] byte_index;
    reg [23:0] pixels;
    reg [15:0] seq;
    reg [7:0] crc;
    reg [7:0] header_byte;
    function [7:0] crc_next;
        input [7:0] c, d;
        reg [7:0] v;
        integer i;
        begin
            v=c^d;
            for(i=0;i<8;i=i+1) v=v[7] ? (v<<1)^8'h07 : v<<1;
            crc_next=v;
        end
    endfunction
    always @* begin
        case(header_index)
            0:header_byte=8'h50; 1:header_byte=8'h59;
            2:header_byte=8'h01; 3:header_byte=8'h46;
            4:header_byte=seq[7:0]; 5:header_byte=seq[15:8];
            6:header_byte=8'h00; default:header_byte=8'h06;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE; after_tx<=IDLE; busy<=0; tx_start<=0;tx_data<=0;
            mem_bank<=0;mem_addr<=0;header_index<=0;pixel_index<=0;
            byte_index<=0;pixels<=0;seq<=0;crc<=0;
        end else begin
            tx_start<=0;
            case(state)
                IDLE: if(start) begin
                    busy<=1;mem_bank<=frame_bank;seq<=frame_seq;mem_addr<=0;
                    header_index<=0;pixel_index<=0;byte_index<=0;pixels<=0;
                    crc<=0;state<=HEADER;
                end
                HEADER: if(!tx_busy) begin
                    tx_data<=header_byte;tx_start<=1;
                    if(header_index>=2) crc<=crc_next(crc,header_byte);
                    after_tx<=header_index==7 ? READ_ADDR : HEADER;
                    header_index<=header_index+1'b1;state<=WAIT_HIGH;
                end
                READ_ADDR: state<=READ_CAPTURE;
                READ_CAPTURE: begin
                    pixels<={mem_data,pixels[23:3]};
                    if(mem_addr!=12'd4095) mem_addr<=mem_addr+1'b1;
                    if(pixel_index==7) begin pixel_index<=0;byte_index<=0;state<=PAYLOAD;end
                    else begin pixel_index<=pixel_index+1'b1;state<=READ_ADDR;end
                end
                PAYLOAD: if(!tx_busy) begin
                    tx_data<=pixels[7:0];tx_start<=1;crc<=crc_next(crc,pixels[7:0]);
                    pixels<={8'd0,pixels[23:8]};
                    if(byte_index==2) after_tx<=mem_addr==4095 ? CRC : READ_ADDR;
                    else after_tx<=PAYLOAD;
                    byte_index<=byte_index+1'b1;state<=WAIT_HIGH;
                end
                CRC: if(!tx_busy) begin
                    tx_data<=crc;tx_start<=1;after_tx<=FINISH;state<=WAIT_HIGH;
                end
                WAIT_HIGH: if(tx_busy) state<=WAIT_LOW;
                WAIT_LOW: if(!tx_busy) state<=after_tx;
                FINISH: begin busy<=0;state<=IDLE;end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
