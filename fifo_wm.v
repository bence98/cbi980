module fifo_wm(
	input wire clk,
	input wire rst,

	input wire [WORD_WIDTH-1:0] data_in,
	input wire enqueue,

	output wire [WORD_WIDTH-1:0] data_out,
	input wire dequeue,

	output wire full,
	output wire empty,

	input wire [WMARK_SIZE-1:0] wmark,
	output wire almost_full,
	output wire almost_empty,

	input wire irq_rst,
	output reg unf,
	output reg ovf
);
parameter FIFO_SIZE=4;
parameter WORD_WIDTH=32;
parameter WMARK_SIZE=2;

reg  [WORD_WIDTH-1:0] fifo [2**FIFO_SIZE-1:0];
reg  [FIFO_SIZE-1:0]  head, tail;
wire [FIFO_SIZE-1:0]  head_next = head+'b1;

wire full_wm  [FIFO_SIZE-1:0];
wire empty_wm [FIFO_SIZE-1:0];

genvar i;
generate for(i=0; i<FIFO_SIZE; i=i+1) begin
	assign full_wm [i]=head_next[FIFO_SIZE-1:i]==tail[FIFO_SIZE-1:i];
	assign empty_wm[i]=head     [FIFO_SIZE-1:i]==tail[FIFO_SIZE-1:i];
end
endgenerate

assign full=full_wm[0];
assign empty=empty_wm[0];

assign almost_full=full_wm[wmark];
assign almost_empty=empty_wm[wmark];

always @(posedge clk)
	if(rst)
		tail <= 'b0;
	else if(dequeue)
		tail <= tail + 'b1;

assign data_out = fifo[tail];

always @(posedge clk)
	if(rst)
		head <= 'b0;
	else if(enqueue) begin
		fifo[head] <= data_in;
		head <= head_next;
	end

always @(posedge clk)
	if(rst)
		ovf <= 1'b0;
	else if(enqueue & full & ~dequeue)
		ovf <= 1'b1;
	else if(irq_rst)
		ovf <= 1'b0;

always @(posedge clk)
	if(rst)
		unf <= 1'b0;
	else if(dequeue & empty & ~enqueue)
		unf <= 1'b1;
	else if(irq_rst)
		unf <= 1'b0;

endmodule
