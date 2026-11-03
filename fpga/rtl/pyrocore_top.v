// Dedicated BRAM ports for SLG47910V Rev BB.
(* top *) module pyrocore_top (
  (* iopad_external_pin, clkbuf_inhibit *) input OSC_CLK,
  (* iopad_external_pin, clkbuf_inhibit *) input core_clk,
  (* iopad_external_pin *) output core_clk_out,
  (* iopad_external_pin *) output core_clk_en,
  (* iopad_external_pin *) output OSC_EN,
  (* iopad_external_pin *) output led_out,
  (* iopad_external_pin *) output led_oe,
  (* iopad_external_pin *) output [7:0] BRAM0_WDATA,
  (* iopad_external_pin *) output [8:0] BRAM0_WADDR,
  (* iopad_external_pin *) output [8:0] BRAM0_RADDR,
  (* iopad_external_pin *) output [1:0] BRAM0_RATIO,
  (* iopad_external_pin *) input BRAM0_RDATA,
  (* iopad_external_pin *) output BRAM0_nWEN,
  (* iopad_external_pin *) output BRAM0_nREN,
  (* iopad_external_pin *) output BRAM0_nWCLKEN,
  (* iopad_external_pin *) output BRAM0_nRCLKEN,
  (* iopad_external_pin *) output BRAM0_WCLKINV,
  (* iopad_external_pin *) output BRAM0_RCLKINV,
  (* iopad_external_pin *) output [7:0] BRAM1_WDATA,
  (* iopad_external_pin *) output [8:0] BRAM1_WADDR,
  (* iopad_external_pin *) output [8:0] BRAM1_RADDR,
  (* iopad_external_pin *) output [1:0] BRAM1_RATIO,
  (* iopad_external_pin *) input BRAM1_RDATA,
  (* iopad_external_pin *) output BRAM1_nWEN,
  (* iopad_external_pin *) output BRAM1_nREN,
  (* iopad_external_pin *) output BRAM1_nWCLKEN,
  (* iopad_external_pin *) output BRAM1_nRCLKEN,
  (* iopad_external_pin *) output BRAM1_WCLKINV,
  (* iopad_external_pin *) output BRAM1_RCLKINV,
  (* iopad_external_pin *) output [7:0] BRAM2_WDATA,
  (* iopad_external_pin *) output [8:0] BRAM2_WADDR,
  (* iopad_external_pin *) output [8:0] BRAM2_RADDR,
  (* iopad_external_pin *) output [1:0] BRAM2_RATIO,
  (* iopad_external_pin *) input BRAM2_RDATA,
  (* iopad_external_pin *) output BRAM2_nWEN,
  (* iopad_external_pin *) output BRAM2_nREN,
  (* iopad_external_pin *) output BRAM2_nWCLKEN,
  (* iopad_external_pin *) output BRAM2_nRCLKEN,
  (* iopad_external_pin *) output BRAM2_WCLKINV,
  (* iopad_external_pin *) output BRAM2_RCLKINV,
  (* iopad_external_pin *) output [7:0] BRAM4_WDATA,
  (* iopad_external_pin *) output [8:0] BRAM4_WADDR,
  (* iopad_external_pin *) output [8:0] BRAM4_RADDR,
  (* iopad_external_pin *) output [1:0] BRAM4_RATIO,
  (* iopad_external_pin *) input BRAM4_RDATA,
  (* iopad_external_pin *) output BRAM4_nWEN,
  (* iopad_external_pin *) output BRAM4_nREN,
  (* iopad_external_pin *) output BRAM4_nWCLKEN,
  (* iopad_external_pin *) output BRAM4_nRCLKEN,
  (* iopad_external_pin *) output BRAM4_WCLKINV,
  (* iopad_external_pin *) output BRAM4_RCLKINV,
  (* iopad_external_pin *) output [7:0] BRAM5_WDATA,
  (* iopad_external_pin *) output [8:0] BRAM5_WADDR,
  (* iopad_external_pin *) output [8:0] BRAM5_RADDR,
  (* iopad_external_pin *) output [1:0] BRAM5_RATIO,
  (* iopad_external_pin *) input BRAM5_RDATA,
  (* iopad_external_pin *) output BRAM5_nWEN,
  (* iopad_external_pin *) output BRAM5_nREN,
  (* iopad_external_pin *) output BRAM5_nWCLKEN,
  (* iopad_external_pin *) output BRAM5_nRCLKEN,
  (* iopad_external_pin *) output BRAM5_WCLKINV,
  (* iopad_external_pin *) output BRAM5_RCLKINV,
  (* iopad_external_pin *) output [7:0] BRAM6_WDATA,
  (* iopad_external_pin *) output [8:0] BRAM6_WADDR,
  (* iopad_external_pin *) output [8:0] BRAM6_RADDR,
  (* iopad_external_pin *) output [1:0] BRAM6_RATIO,
  (* iopad_external_pin *) input BRAM6_RDATA,
  (* iopad_external_pin *) output BRAM6_nWEN,
  (* iopad_external_pin *) output BRAM6_nREN,
  (* iopad_external_pin *) output BRAM6_nWCLKEN,
  (* iopad_external_pin *) output BRAM6_nRCLKEN,
  (* iopad_external_pin *) output BRAM6_WCLKINV,
  (* iopad_external_pin *) output BRAM6_RCLKINV
,
  (* iopad_external_pin *) input uart_rx_pin,
  (* iopad_external_pin *) output uart_tx_pin,
  (* iopad_external_pin *) output uart_tx_oe
);
  reg [3:0] clock_div=0;
  always @(posedge OSC_CLK) clock_div<=clock_div+4'd1;
  assign core_clk_out=clock_div[3];
  assign core_clk_en=1'b1;
  assign OSC_EN=1'b1;
  reg [7:0] startup=0;
  always @(posedge core_clk) if(!(&startup)) startup<=startup+1'b1;
  wire rst=!(&startup);
  wire mem_we,mem_wbank,mem_re,mem_rbank;
  wire [11:0] mem_waddr,mem_raddr;
  wire [2:0] mem_wdata,mem_rdata;
  wire [2:0] bank0_q,bank1_q;
  assign mem_rdata=mem_rbank ? bank1_q : bank0_q;
  assign led_oe=1'b1;
  assign uart_tx_oe=1'b1;
  pyrocore_core engine(.clk(core_clk),.rst(rst),.uart_rx_pin(uart_rx_pin),
    .uart_tx_pin(uart_tx_pin),.mem_we(mem_we),.mem_wbank(mem_wbank),
    .mem_waddr(mem_waddr),.mem_wdata(mem_wdata),.mem_re(mem_re),
    .mem_rbank(mem_rbank),.mem_raddr(mem_raddr),.mem_rdata(mem_rdata),.led(led_out));
  // Slice0: bank0, colour bit0,4096x1; extension pins hold address LSBs.
  assign BRAM0_WADDR=mem_waddr[11:3];
  assign BRAM0_RADDR=mem_raddr[11:3];
  assign BRAM0_WDATA={mem_waddr[2:0],mem_raddr[2:0],1'b0,mem_wdata[0]};
  assign BRAM0_RATIO=2'b11;
  assign BRAM0_nWEN=!(mem_we && mem_wbank==1'b0);
  assign BRAM0_nREN=!(mem_re && mem_rbank==1'b0);
  assign BRAM0_nWCLKEN=1'b0;
  assign BRAM0_nRCLKEN=1'b0;
  assign BRAM0_WCLKINV=1'b0;
  assign BRAM0_RCLKINV=1'b0;
  assign bank0_q[0]=BRAM0_RDATA;
  // Slice1: bank0, colour bit1,4096x1; extension pins hold address LSBs.
  assign BRAM1_WADDR=mem_waddr[11:3];
  assign BRAM1_RADDR=mem_raddr[11:3];
  assign BRAM1_WDATA={mem_waddr[2:0],mem_raddr[2:0],1'b0,mem_wdata[1]};
  assign BRAM1_RATIO=2'b11;
  assign BRAM1_nWEN=!(mem_we && mem_wbank==1'b0);
  assign BRAM1_nREN=!(mem_re && mem_rbank==1'b0);
  assign BRAM1_nWCLKEN=1'b0;
  assign BRAM1_nRCLKEN=1'b0;
  assign BRAM1_WCLKINV=1'b0;
  assign BRAM1_RCLKINV=1'b0;
  assign bank0_q[1]=BRAM1_RDATA;
  // Slice2: bank0, colour bit2,4096x1; extension pins hold address LSBs.
  assign BRAM2_WADDR=mem_waddr[11:3];
  assign BRAM2_RADDR=mem_raddr[11:3];
  assign BRAM2_WDATA={mem_waddr[2:0],mem_raddr[2:0],1'b0,mem_wdata[2]};
  assign BRAM2_RATIO=2'b11;
  assign BRAM2_nWEN=!(mem_we && mem_wbank==1'b0);
  assign BRAM2_nREN=!(mem_re && mem_rbank==1'b0);
  assign BRAM2_nWCLKEN=1'b0;
  assign BRAM2_nRCLKEN=1'b0;
  assign BRAM2_WCLKINV=1'b0;
  assign BRAM2_RCLKINV=1'b0;
  assign bank0_q[2]=BRAM2_RDATA;
  // Slice4: bank1, colour bit0,4096x1; extension pins hold address LSBs.
  assign BRAM4_WADDR=mem_waddr[11:3];
  assign BRAM4_RADDR=mem_raddr[11:3];
  assign BRAM4_WDATA={mem_waddr[2:0],mem_raddr[2:0],1'b0,mem_wdata[0]};
  assign BRAM4_RATIO=2'b11;
  assign BRAM4_nWEN=!(mem_we && mem_wbank==1'b1);
  assign BRAM4_nREN=!(mem_re && mem_rbank==1'b1);
  assign BRAM4_nWCLKEN=1'b0;
  assign BRAM4_nRCLKEN=1'b0;
  assign BRAM4_WCLKINV=1'b0;
  assign BRAM4_RCLKINV=1'b0;
  assign bank1_q[0]=BRAM4_RDATA;
  // Slice5: bank1, colour bit1,4096x1; extension pins hold address LSBs.
  assign BRAM5_WADDR=mem_waddr[11:3];
  assign BRAM5_RADDR=mem_raddr[11:3];
  assign BRAM5_WDATA={mem_waddr[2:0],mem_raddr[2:0],1'b0,mem_wdata[1]};
  assign BRAM5_RATIO=2'b11;
  assign BRAM5_nWEN=!(mem_we && mem_wbank==1'b1);
  assign BRAM5_nREN=!(mem_re && mem_rbank==1'b1);
  assign BRAM5_nWCLKEN=1'b0;
  assign BRAM5_nRCLKEN=1'b0;
  assign BRAM5_WCLKINV=1'b0;
  assign BRAM5_RCLKINV=1'b0;
  assign bank1_q[1]=BRAM5_RDATA;
  // Slice6: bank1, colour bit2,4096x1; extension pins hold address LSBs.
  assign BRAM6_WADDR=mem_waddr[11:3];
  assign BRAM6_RADDR=mem_raddr[11:3];
  assign BRAM6_WDATA={mem_waddr[2:0],mem_raddr[2:0],1'b0,mem_wdata[2]};
  assign BRAM6_RATIO=2'b11;
  assign BRAM6_nWEN=!(mem_we && mem_wbank==1'b1);
  assign BRAM6_nREN=!(mem_re && mem_rbank==1'b1);
  assign BRAM6_nWCLKEN=1'b0;
  assign BRAM6_nRCLKEN=1'b0;
  assign BRAM6_WCLKINV=1'b0;
  assign BRAM6_RCLKINV=1'b0;
  assign bank1_q[2]=BRAM6_RDATA;
endmodule
