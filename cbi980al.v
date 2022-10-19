// CBI980 I2S controller with AXI4-Lite interface
// @author Csókás Bence
module cbi980al(
	// AXI4-Lite
	input wire aclk,
	input wire arstn,

	input wire [31:0] awaddr,
	input wire [3:0] awcache,
	input wire [2:0] awprot,
	input wire awvalid,
	output wire awready,

	input wire [31:0] wdata,
	input wire [3:0] wstrb,
	input wire wvalid,
	output wire wready,

	output wire [1:0] bresp,
	output wire bvalid,
	input wire bready,

	input wire [31:0] araddr,
	input wire [3:0] arcache,
	input wire [2:0] arprot,
	input wire arvalid,
	output wire arready,

	output reg  [31:0] rdata,
	output wire [1:0] rresp,
	output wire rvalid,
	input wire rready
);

// Async nRST -> sync RST
reg rst;
always @(posedge clk, negedge arstn)
	if(arstn) rst <= 1'b0;
	else      rst <= 1'b1;

wire write_en, write_err, write_inval=~&wstrb;
reg  [31:0] write_data;
reg  [31:0] write_addr;

wire read_en, read_vld;
wire [31:0] read_data;
reg  [31:0] read_addr;
// TODO: read_vld from inner module
// read_addr, read_en to inner module
// read_data from inner

// Write FSM
localparam WR_WAIT = 2'd0;
localparam WR_SENT = 2'd1;
localparam WR_DONE = 2'b2;
localparam WR_DERR = 2'd3;

reg [1:0] wr_state;
always @(posedge aclk)
        if(rst) wr_state <= WR_WAIT;
	else case(wr_state)
		WR_WAIT: if(awvalid & wvalid) wr_state <= WR_DONE;
		WR_SENT: if(write_err|write_inval) wr_state <= WR_DERR;
		         else       wr_state <= WR_DONE;
		WR_DONE: if(bready) wr_state <= WR_WAIT;
	endcase
assign awready  = wr_state == WR_SENT;
assign wready   = wr_state == WR_SENT;
assign write_en = wr_state == WR_SENT & ~write_inval;
assign bvalid   = wr_state == WR_DONE || wr_state == WR_DERR;

always @(posedge aclk) begin
	if(awvalid) write_addr <= awaddr;
	if(wvalid)  write_data <= wdata;
end

// Read FSM
localparam RD_WAIT = 2'd0;
localparam RD_SENT = 2'd1;
localparam RD_DONE = 2'd2;

reg [1:0] rd_state;

always @(posedge aclk)
	if(rst) rd_state <= RD_WAIT;
	else case(rd_state)
		RD_WAIT: if(arvalid)  rd_state <= RD_SENT;
		RD_SENT: if(read_vld) rd_state <= RD_DONE;
		RD_DONE: if(rready)   rd_state <= RD_WAIT;
	endcase
assign arready = rd_state == RD_WAIT;
assign rd_en   = rd_state == RD_SENT;
assign rvalid  = rd_state == RD_DONE;
assign rresp   = 2'b00; // OKAY

always @(posedge aclk) begin
	if(read_vld) rdata <= read_data;
	if(arvalid)  read_addr <= araddr;
end

endmodule
