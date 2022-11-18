module cbi980_core(
	input wire clk,
	input wire rst,
	output wire interrupt,

	output wire i2s_rstn,
	output wire i2s_mclk,
	output wire i2s_lrclk,
	output wire i2s_sclk,
	output wire i2s_sdin,
	input wire  i2s_sdout,

	input wire [2:0] wr_addr,
	input wire [31:0] wr_data,
	input wire wr_en,
	output wire wr_err,

	input wire [2:0] rd_addr,
	output reg [31:0] rd_data,
	input wire rd_valid_in,
	output reg rd_valid_out
);

// Register addresses
localparam CVR=3'd0, SR=3'd1, CR=3'd2, LCFR=3'd3, DOUT1R=3'd4, DOUT0R=3'd5, DIN1R=3'd6, DIN0R=3'd7;

// SR & CR flags
wire init;
reg  [1:0] rx_ovf, tx_unf;
wire [1:0] rxne, rxf, txnf, txe;
wire [11:0] flags={rx_ovf[1], tx_unf[1], rx_ovf[0], tx_unf[0], rxne[1], rxf[1], txnf[1], txe[1], rxne[0], rxf[0], txnf[0], txe[0]};
reg [11:0] ie;
reg rxen, txen;

assign interrupt=|(flags&ie);

// LCFR flags
reg [2:0] mclk_rate=3'b0;
wire[2:0] sclk_rate=3'd2;
reg [2:0] octet_cnt=3'b1;
reg       rjust    =1'b0;
reg       lsb_first=1'b0;

// FIFOs
// RX FIFOs
reg [31:0] r1fifo [15:0];
reg [31:0] r0fifo [15:0];
reg [3:0]  r1head, r1tail;
reg [3:0]  r0head, r0tail;

// TX FIFOs
reg [31:0] t1fifo [15:0];
reg [31:0] t0fifo [15:0];
reg [3:0]  t1head, t1tail;
reg [3:0]  t0head, t0tail;

// Reset flags
reg irq_rst, soft_rst;

// Read regs
always @(posedge clk)
	case(rd_addr)
		CVR:     rd_data <= 32'hcb199800;
		SR:      rd_data <= {init, 7'b0, 4'b0, flags, 8'b0};
		CR:      rd_data <= {8'b0, 4'b0, ie, rxen, txen, interrupt, 1'b0};
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
		irq_rst <= 1'b0;
		soft_rst <= 1'b0;
		t1head <= 'b0;
		t0head <= 'b0;
	end else if(wr_en) case(wr_addr)
		CR: begin
			ie <= wr_data[15:4];
			rxen <= wr_data[3];
			txen <= wr_data[2];
			irq_rst <= wr_data[1];
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

// I2S i/f
wire [1:0] aud_dout_vld, aud_din_ack;
wire [23:0] aud_dout, aud_din0, aud_din1;

always @(posedge clk)
	if(rst) begin
		rx_ovf[0] <= 1'b0;
		//tx_unf[0] <= 1'b0;
		r0head <= 'b0;
	end else if(aud_dout_vld) begin
		r0fifo[r0head] <= aud_dout;
		r0head <= r0head + 1;
	end

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
	.aud_dout(aud_dout),
	.aud_din_ack(aud_din_ack),
	.aud_din0(aud_din0),
	.aud_din1(aud_din1)
);

endmodule
