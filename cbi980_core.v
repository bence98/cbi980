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
wire [1:0] rx_ovf, tx_unf;
wire [1:0] rxne, rxf, txnf, txe;
wire [11:0] flags={rx_ovf[1], tx_unf[1], rx_ovf[0], tx_unf[0], rxne[1], rxf[1], txnf[1], txe[1], rxne[0], rxf[0], txnf[0], txe[0]};
reg  [11:0] ie;
reg  [1:0] rxen, txen;

assign interrupt=|(flags&ie);

// LCFR flags
reg [2:0] mclk_rate=3'b0;
wire[2:0] sclk_rate=3'd2;
reg [2:0] octet_cnt=3'd2;
reg       rjust    =1'b0;
reg       lsb_first=1'b0;

// FIFOs
// RX FIFOs
wire [31:0] rxfifo_out [1:0];
// TX FIFOs
wire [31:0] txfifo_out [1:0];

// Reset flags
reg irq_rst, soft_rst;
wire rst = ext_rst | soft_rst;

// FIFO status
wire [1:0] rxe, txf;
assign rxne = ~rxe;
assign txnf = ~txf;

// Read regs
always @(posedge clk)
	case(rd_addr)
		CVR:     rd_data <= 32'hcb199800;
		SR:      rd_data <= {init, 7'b0, 4'b0, flags, 8'b0};
		CR:      rd_data <= {8'b0, 4'b0, ie, 2'b0, rxen, txen, interrupt, 1'b0};
		LCFR:    rd_data <= {5'b0, mclk_rate, 5'b0, sclk_rate, 5'b0, octet_cnt, 6'b0, rjust, lsb_first};
		DIN1R:   rd_data <= rxfifo_out[1];
		DIN0R:   rd_data <= rxfifo_out[0];
		default: rd_data <= 32'b0;
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
	end else if(wr_en) case(wr_addr)
		CR: begin
			ie <= wr_data[19:8];
			rxen <= wr_data[5:4];
			txen <= wr_data[3:2];
			soft_rst <= wr_data[0];
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
wire [31:0] aud_dout, aud_din [1:0];

wire [1:0] txfeed={2{wr_en}}&{wr_addr==DOUT1R, wr_addr==DOUT0R};
wire [1:0] rxsink={2{rd_valid_in}}&{rd_addr==DIN1R, rd_addr==DIN0R};

genvar i;
generate for(i=0; i<2; i=i+1) begin
	fifo_wm rxfifo(
		.clk(clk),
		.rst(rst),
		.data_in(aud_dout),
		.enqueue(aud_dout_vld[i] & rxen[i]),
		.data_out(rxfifo_out[i]),
		.dequeue(rxsink[i]),
		.full(rxf[i]),
		.empty(rxe[i]),
		.wmark(2'b0),
		.almost_full(),
		.almost_empty(),
		.irq_rst(irq_rst),
		.unf(),
		.ovf(rx_ovf[i])
	);

	fifo_wm txfifo(
		.clk(clk),
		.rst(rst),
		.data_in(wr_data),
		.enqueue(txfeed[i]),
		.data_out(aud_din[i]),
		.dequeue(aud_din_ack[i] & txen[i]),
		.full(txf[i]),
		.empty(txe[i]),
		.wmark(2'b0),
		.almost_full(),
		.almost_empty(),
		.irq_rst(irq_rst),
		.unf(tx_unf[i]),
		.ovf()
	);
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
	.aud_din0(aud_din[0][31:8]),
	.aud_din1(aud_din[1][31:8])
);
assign aud_dout[7:0] = 8'b0;

endmodule
