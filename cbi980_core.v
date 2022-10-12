module cbi980_core(
	input wire clk,
	input wire rst,

	input wire [31:0] wr_addr,
	input wire [31:0] wr_data,
	input wire wr_en,

	input wire [31:0] rd_addr,
	output reg [31:0] rd_data,
	input wire rd_valid_in,
	output wire rd_valid_out
);

endmodule
