`timescale 1ns / 1ps

module codec_if
(
   input             clk,
   input             rst,

   output            init_done,
   input       [3:0] mclk_rate,
   input       [3:0] sclk_rate,

   output            codec_rstn,
   output            codec_mclk,
   output            codec_lrclk,
   output            codec_sclk,
   output            codec_sdin,
   input             codec_sdout,

   output reg [ 1:0] aud_dout_vld,
   output     [23:0] aud_dout,

   output reg [ 1:0] aud_din_ack,
   input      [23:0] aud_din0,
   input      [23:0] aud_din1
);


// Configuration pins
// stand-alone slave mode, left justified, 256x mclk
/*
assign codec_m0      = 1'b1;
assign codec_m1      = 1'b1;
assign codec_i2s     = 1'b0;
assign codec_mdiv1   = 1'b1;
assign codec_mdiv2   = 1'b1;
*/

// free-running counter, resettable
// - clock generation
// - reset generation & wait for at least 1045 sampling periods
reg [19:0] div_cntr;
always @ (posedge clk)
if(rst) begin
  div_cntr <= 'b0;
end else div_cntr <= div_cntr + 'b1;

assign codec_lrclk  = div_cntr[8];      // /512
assign codec_sclk   = div_cntr[sclk_rate];
assign codec_mclk   = div_cntr[mclk_rate];

wire sclk_fall;
wire sclk_rise;
assign sclk_fall    = div_cntr[2:0]==3'b111;
assign sclk_rise    = div_cntr[2:0]==3'b011;

// "virtual" bit counter, 5-bit part of div_cntr
wire [ 4:0] bit_cntr;
assign bit_cntr     = div_cntr[7:3];

// active low reset for the codec
// ~8 sampling periods long after system reset
reg rst_ff;
always @ (posedge clk)
if(rst) rst_ff <= 1'b0;
else if(div_cntr[12]) rst_ff <= 1'b1;

// assign codec reset to output port
assign codec_rstn = rst_ff;

// init done:
// wait at least 1045 sampling periods after codec reset is released,
// then set init done
reg init_done_ff;
always @ (posedge clk)
if(rst) init_done_ff <= 1'b0;
else if(&div_cntr[19:9]) init_done_ff <= 1'b1;

// input shift register
// sample input data when the generated sclk has a rising edge
reg  [23:0] shr_rx;
always @ (posedge clk)
if(sclk_rise) shr_rx={shr_rx[22:0], codec_sdout};

// ADC parallel data valid for channel 0
// should be 0 when init_done is 0 
always @ (posedge clk)
if(sclk_rise&&init_done_ff&&codec_lrclk&&bit_cntr==5'd23)
  aud_dout_vld[0]<=1'b1;
else
  aud_dout_vld[0]<=1'b0;

// ADC parallel data valid for channel 1
// should be 0 when init_done is 0
always @ (posedge clk)
if(sclk_rise&&init_done_ff&&!codec_lrclk&&bit_cntr==5'd23)
  aud_dout_vld[1]<=1'b1;
else
  aud_dout_vld[1]<=1'b0;

// ADC parallel data output: the receive shift register
assign aud_dout = shr_rx;



// transmit shift register, which should
// - load channel 0 or channel 1 parallel data
// - or shift when the generated sclk has a falling edge 
reg  [23:0] shr_tx;
always @ (posedge clk)
if(sclk_fall) begin
  if(init_done_ff&&bit_cntr==5'd31)
    if(codec_lrclk) shr_tx<=aud_din0;
    else shr_tx<=aud_din1;
  else
    shr_tx<={shr_tx[22:0], 1'b0};
end

// serial input of the CODEC
assign codec_sdin = shr_tx[23];


// ACK output for channel 0 parallel data input
always @ (posedge clk)
if(sclk_fall&&init_done_ff&&bit_cntr==5'd24&&codec_lrclk)
  aud_din_ack[0]<=1'b1;
else aud_din_ack[0]<=1'b0;

// ACK output for channel 1 parallel data input   
always @ (posedge clk)
if(sclk_fall&&init_done_ff&&bit_cntr==5'd24&&!codec_lrclk)
  aud_din_ack[1]<=1'b1;
else aud_din_ack[1]<=1'b0;
 
assign init_done=init_done_ff;

endmodule
