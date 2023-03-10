module cbi980_core(
	input wire clk,
	input wire ext_rst,
	output wire interrupt,

	output wire i2s_rstn,
	output wire i2s_mclk,
	(* mark_debug = "true" *)
	output wire i2s_lrclk,
	output wire i2s_sclk,
	output wire i2s_sdin,
	input wire  i2s_sdout,

	(* mark_debug = "true" *)
	input wire [2:0] wr_addr,
	input wire [31:0] wr_data,
	(* mark_debug = "true" *)
	input wire wr_en,
	output wire wr_err,

	input wire [2:0] rd_addr,
	output reg [31:0] rd_data,
	input wire rd_valid_in,
	output reg rd_valid_out
);

parameter FIFO_SIZE=4;

// Register addresses
localparam CVR=3'd0, SR=3'd1, CR=3'd2, LCFR=3'd3, DOUT1R=3'd4, DOUT0R=3'd5, DIN1R=3'd6, DIN0R=3'd7;

// SR & CR flags
wire init;
reg  [1:0] rx_ovf, tx_unf;
wire [1:0] rxne, rxf, txnf, txe;
wire [11:0] flags={rx_ovf[1], tx_unf[1], rx_ovf[0], tx_unf[0], rxne[1], rxf[1], txnf[1], txe[1], rxne[0], rxf[0], txnf[0], txe[0]};
reg [11:0] ie;
reg [1:0] rxen, txen;

assign interrupt=|(flags&ie);

// LCFR flags
reg [2:0] mclk_rate=3'b0;
wire[2:0] sclk_rate=3'd2;
reg [2:0] octet_cnt=3'd2;
reg       rjust    =1'b0;
reg       lsb_first=1'b0;

// FIFOs
// RX FIFOs
reg [31:0] r1fifo [2**FIFO_SIZE-1:0];
reg [31:0] r0fifo [2**FIFO_SIZE-1:0];
(* mark_debug = "true" *)
reg [FIFO_SIZE-1:0]  r1head, r1tail;
(* mark_debug = "true" *)
reg [FIFO_SIZE-1:0]  r0head, r0tail;

// TX FIFOs
reg [31:0] t1fifo [2**FIFO_SIZE-1:0];
reg [31:0] t0fifo [2**FIFO_SIZE-1:0];
(* mark_debug = "true" *)
reg [FIFO_SIZE-1:0]  t1head, t1tail;
(* mark_debug = "true" *)
reg [FIFO_SIZE-1:0]  t0head, t0tail;

// Reset flags
reg irq_rst, soft_rst;
wire rst = ext_rst | soft_rst;

// FIFO status
wire [FIFO_SIZE-1:0] r1head_next = r1head+'b1;
wire [FIFO_SIZE-1:0] t1head_next = t1head+'b1;
wire [FIFO_SIZE-1:0] r0head_next = r0head+'b1;
wire [FIFO_SIZE-1:0] t0head_next = t0head+'b1;

assign rxne[1]=r1head!=r1tail;
assign rxf [1]=r1head_next==r1tail;
assign txnf[1]=t1head_next!=t1tail;
assign txe [1]=t1head==t1tail;
assign rxne[0]=r0head!=r0tail;
assign rxf [0]=r0head_next==r0tail;
assign txnf[0]=t0head_next!=t0tail;
assign txe [0]=t0head==t0tail;

// Read regs
always @(posedge clk)
	case(rd_addr)
		CVR:     rd_data <= 32'hcb199800;
		SR:      rd_data <= {init, 7'b0, 4'b0, flags, 8'b0};
		CR:      rd_data <= {8'b0, 4'b0, ie, 2'b0, rxen, txen, interrupt, 1'b0};
		LCFR:    rd_data <= {5'b0, mclk_rate, 5'b0, sclk_rate, 5'b0, octet_cnt, 6'b0, rjust, lsb_first};
		DIN1R:   rd_data <= r1fifo[r1tail];
		DIN0R:   rd_data <= r0fifo[r0tail];
		default: rd_data <= 32'b0;
	endcase

always @(posedge clk)
	if(rst) begin
		r1tail <= 'b0;
		r0tail <= 'b0;
	end else if(rd_valid_in) case(rd_addr)
		DIN1R:   r1tail <= r1tail + 1;
		DIN0R:   r0tail <= r0tail + 1;
	endcase

always @(posedge clk)
	rd_valid_out <= rd_valid_in;

// Write regs
assign wr_err=wr_en&((wr_addr<CR)|(wr_addr>DOUT0R));

always @(posedge clk)
	if(rst) begin
		ie <= 12'b0;
		rxen <= 1'b0;
		txen <= 1'b0;
		soft_rst <= 1'b0;
		t1head <= 'b0;
		t0head <= 'b0;
	end else if(wr_en) case(wr_addr)
		CR: begin
			ie <= wr_data[19:8];
			rxen <= wr_data[5:4];
			txen <= wr_data[3:2];
			soft_rst <= wr_data[0];
		end
		DOUT1R: begin
			t1fifo[t1head] <= wr_data;
			t1head <= t1head + 1;
		end
		DOUT0R: begin
			t0fifo[t0head] <= wr_data;
			t0head <= t0head + 1;
		end
	endcase

always @(posedge clk)
	if(~rst & wr_en & (wr_addr == CR))
		irq_rst <= wr_data[1];
	else
		irq_rst <= 1'b0;

// I2S i/f
(* mark_debug = "true" *)
wire [1:0]  aud_dout_vld, aud_din_ack;
(* mark_debug = "true" *)
wire [31:0] aud_dout, aud_din0, aud_din1;

always @(posedge clk)
	if(rst)
		r1head <= 'b0;
	else if(aud_dout_vld[1] & rxen[1]) begin
		r1fifo[r1head] <= aud_dout;
		r1head <= r1head + 1;
	end

always @(posedge clk)
	if(rst)
		t1tail <= 'b0;
	else if(aud_din_ack[1] & txen[1])
		t1tail <= t1tail + 1;

assign aud_din1 = t1fifo[t1tail];

always @(posedge clk)
	if(rst)
		r0head <= 'b0;
	else if(aud_dout_vld[0] & rxen[0]) begin
		r0fifo[r0head] <= aud_dout;
		r0head <= r0head + 1;
	end

always @(posedge clk)
	if(rst)
		t0tail <= 'b0;
	else if(aud_din_ack[0] & txen[0])
		t0tail <= t0tail + 1;

assign aud_din0 = t0fifo[t0tail];

wire [1:0] txfeed={2{wr_en}}&{wr_addr==DOUT1R, wr_addr==DOUT0R};
wire [1:0] rxsink={2{rd_valid_in}}&{rd_addr==DIN1R, rd_addr==DIN0R};

genvar i;
generate for(i=0; i<2; i=i+1) begin
always @(posedge clk)
	if(rst)
		rx_ovf[i] <= 1'b0;
	else if(aud_dout_vld[i] & rxen[i] & rxf[i] & ~ rxsink[i])
		rx_ovf[i] <= 1'b1;
	else if(irq_rst)
		rx_ovf[i] <= 1'b0;

always @(posedge clk)
	if(rst)
		tx_unf[i] <= 1'b0;
	else if(aud_din_ack[i] & txen[i] & txe[i] & ~txfeed[i])
		tx_unf[i] <= 1'b1;
	else if(irq_rst)
		tx_unf[i] <= 1'b0;
end
endgenerate

codec_if i2s_if(
	.clk(clk),
	.rst(rst),
	.init_done(init),
	.mclk_rate(mclk_rate),
	.sclk_rate(sclk_rate),
	
	.codec_rstn(i2s_rstn),
	.codec_mclk(i2s_mclk),
	.codec_lrclk(i2s_lrclk),
	.codec_sclk(i2s_sclk),
	.codec_sdin(i2s_sdin),
	.codec_sdout(i2s_sdout),
	
	.aud_dout_vld(aud_dout_vld),
	.aud_dout(aud_dout[31:8]),
	.aud_din_ack(aud_din_ack),
	.aud_din0(aud_din0[31:8]),
	.aud_din1(aud_din1[31:8])
);
assign aud_dout[7:0] = 8'b0;

endmodule
