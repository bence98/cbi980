module cbi980_core(
	input wire clk,
	input wire rst,
	output wire interrupt,

	input wire [2:0] wr_addr,
	input wire [31:0] wr_data,
	input wire wr_en,
	output wire wr_err,

	input wire [2:0] rd_addr,
	output reg [31:0] rd_data,
	input wire rd_valid_in,
	output wire rd_valid_out
);

// Register addresses
localparam CVR=3'd0, SR=3'd1, CR=3'd2, LCFR=3'd3, DOUT1R=3'd4, DOUT0R=3'd5, DIN1R=3'd6, DIN0R=3'd7;

// SR & CR flags
wire init;
reg  [1:0] rx_ovf, tx_unf;
wire [1:0] rxne, rxf, txnf, txe;
wire [11:0] flags=rx_ovf[1], tx_unf[1], rx_ovf[0], tx_unf[0], rxne[1], rxf[1], txnf[1], txe[1], rxne[0], rxf[0], txnf[0], txe[0];
reg [11:0] ie;
reg rxen, txen;

assign interrupt=|(flags&ie);

// LCFR flags
reg [2:0] mclk_rate=3'b0;
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

// Read regs
always @(posedge clk)
	case(rd_addr)
		CVR:     rd_data <= 32'hcb199800;
		SR:      rd_data <= {init, 7'b0, 4'b0, flags, 8'b0};
		CR:      rd_data <= {8'b0, 4'b0, ie, rxen, txen, interrupt, 1'b0};
		LCFR:    rd_data <= {5'b0, mclk_rate, 3'd2, 5'b0, octet_cnt, 6'b0, rjust, lsb_first};
		DIN1R:   rd_data <= r1fifo[r1tail];
		DIN0R:   rd_data <= r0fifo[r0tail];
		default: rd_data <= 32'b0;
	endcase


always @(posedge clk)
	if(rd_valid_in) case(rd_addr)
		DIN1R:   r1tail <= r1tail + 1;
		DIN0R:   r0tail <= r0tail + 1;
	endcase

// Write regs
assign wr_err=wr_en&((wr_addr<CR)|(wr_addr>DOUT0R));

endmodule
