`timescale 1ns / 1ps

module axi_test();
reg s_axi_aclk=0;
reg s_axi_arstn=0;

always #50 s_axi_aclk=~s_axi_aclk;
initial #100 s_axi_arstn=1;

reg [31:0] s_axi_awaddr;
reg [2:0] s_axi_awprot;
reg s_axi_awvalid;
wire s_axi_awready;
reg [31:0] s_axi_wdata;
reg [3:0] s_axi_wstrb;
reg s_axi_wvalid;
wire s_axi_wready;
reg s_axi_bready;
wire s_axi_bvalid;
wire [1:0] s_axi_bresp;
reg [31:0] s_axi_araddr;
reg [2:0] s_axi_arprot;
reg s_axi_arvalid;
wire s_axi_arready;
wire [31:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
reg s_axi_rready;
wire s_axi_rvalid;

task axi_write32;
	input [31:0] address;
	input [31:0] data;
	begin
		address = address & 32'hfffffffc;
		@(posedge s_axi_aclk);
		$display("%t: AXI write - address=0x%h, data=0x%h", $time, address, data);
		fork
			//Írási cím csatorna.
			begin
				#1 s_axi_awaddr = address;
				s_axi_awprot = 3'b000;
				s_axi_awvalid = 1'b1;
				wait (s_axi_awready == 1'b1);
				@(posedge s_axi_aclk);
				#1 s_axi_awvalid = 1'b0;
			end
			//Írási adat csatorna.
			begin
				#1 s_axi_wdata = data;
				s_axi_wstrb = 4'b1111;
				s_axi_wvalid = 1'b1;
				wait (s_axi_wready == 1'b1);
				@(posedge s_axi_aclk);
				#1 s_axi_wvalid = 1'b0;
			end
			//Írási válasz csatorna.
			begin
				#1 s_axi_bready = 1'b1;
				wait (s_axi_bvalid == 1'b1);
				$display("%t: AXI write - resp=0x%h", $time, s_axi_bresp);
				@(posedge s_axi_aclk);
				#1 s_axi_bready = 1'b0;
			end
		join
	end
endtask

task axi_read32;
	input [31:0] address;
	begin
		address = address & 32'hfffffffc;
		@(posedge s_axi_aclk);
		$display("%t: AXI read - address=0x%h", $time, address);
		fork
			//olvasási cím csatorna.
			begin
				#1 s_axi_araddr = address;
				s_axi_arprot = 3'b000;
				s_axi_arvalid = 1'b1;
				wait (s_axi_arready == 1'b1);
				@(posedge s_axi_aclk);
				#1 s_axi_arvalid = 1'b0;
			end
			//olvasási válasz csatorna.
			begin
				#1 s_axi_rready = 1'b1;
				wait (s_axi_rvalid == 1'b1);
				$display("%t: AXI read - resp=0x%h, data=0x%h", $time, s_axi_rresp, s_axi_rdata);
				@(posedge s_axi_aclk);
				#1 s_axi_rready = 1'b0;
			end
		join
	end
endtask

initial begin
    #150 axi_read32(.address(32'b1000));
    #150 axi_write32(.address(32'b1000), .data(32'b11111));
    #150 axi_write32(.address(32'b0000), .data(32'b11111));
    #150 axi_read32(.address(32'b0000));
    #150 axi_read32(.address(32'b1000));
end

cbi980al uut(
    .aclk(s_axi_aclk),
    .arstn(s_axi_arstn),
    .awaddr(s_axi_awaddr),
    .awcache(4'b0),
    .awprot(s_axi_awprot),
    .awvalid(s_axi_awvalid),
    .awready(s_axi_awready),
    .wdata(s_axi_wdata),
    .wstrb(s_axi_wstrb),
    .wvalid(s_axi_wvalid),
    .wready(s_axi_wready),
    .bresp(s_axi_bresp),
    .bvalid(s_axi_bvalid),
    .bready(s_axi_bready),
    .araddr(s_axi_araddr),
    .arcache(4'b0),
    .arprot(s_axi_arprot),
    .arvalid(s_axi_arvalid),
    .arready(s_axi_arready),
    .rdata(s_axi_rdata),
    .rresp(s_axi_rresp),
    .rvalid(s_axi_rvalid),
    .rready(s_axi_rready),
    .irq()
);

endmodule
