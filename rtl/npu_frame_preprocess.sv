`timescale 1ns/1ps
// Read-only video tap: accepts a pixel only when the existing video path handshakes.
// Every accepted pixel contributes to an 8x8 area-average image. Never drives TREADY.
module npu_frame_preprocess #(
 parameter integer WIDTH=1280, HEIGHT=720
)(
 input wire clk,rstn,
 input wire [23:0] pixel_data,input wire pixel_valid,pixel_ready,pixel_sof,pixel_eol,
 input wire invert,
 output reg [31:0] frame_sequence,frames_started,frame_errors,last_pixels,frame_cycles,
 input wire [6:0] feature_address,output reg [7:0] feature_data,
 input wire [6:0] dma_feature_address,output reg [7:0] dma_feature_data
);
 localparam integer TILE_W=WIDTH/8,TILE_H=HEIGHT/8;
 localparam integer DENOM=TILE_W*TILE_H*255;
 reg [23:0] sums[0:63];
 (* ram_style="distributed" *) reg [7:0] features[0:127];
 reg active,bad_frame,invert_frame,write_bank;
 integer x,y,bx,by;
 reg [2:0] tile_x,tile_y;
 reg [31:0] pixels;
 reg [31:0] clock_count,frame_start_clock,job_frame_cycles;
 wire accept=pixel_valid && pixel_ready;
 wire [9:0] weighted={2'b0,pixel_data[23:16]}+{1'b0,pixel_data[15:8],1'b0}+{2'b0,pixel_data[7:0]};
 wire [7:0] gray=weighted[9:2];
 wire [7:0] value=(pixel_sof ? invert : invert_frame) ? 8'd255-gray : gray;
 wire [5:0] tile={tile_y,tile_x};
 wire [24:0] accumulated={1'b0,sums[tile]}+value;
 reg dividing,commit_job,job_bank;
 reg [5:0] job_tile;
 reg [31:0] quotient;
 reg [32:0] remainder;
 reg [5:0] divide_left;
 wire [32:0] shifted_remainder={remainder[31:0],quotient[31]};
 integer i;
 always @(posedge clk) begin
  feature_data<=features[feature_address];
  dma_feature_data<=features[dma_feature_address];
  if(!rstn) begin
   frame_sequence<=0; frames_started<=0; frame_errors<=0; last_pixels<=0;
   clock_count<=0; frame_start_clock<=0; job_frame_cycles<=0; frame_cycles<=0;
   active<=0; bad_frame<=0; invert_frame<=0; write_bank<=0;
   x<=0; y<=0; bx<=0; by<=0; tile_x<=0; tile_y<=0; pixels<=0;
   dividing<=0; commit_job<=0; job_bank<=0; job_tile<=0;
   quotient<=0; remainder<=0; divide_left<=0;
   for(i=0;i<64;i=i+1) sums[i]<=0;
  end else begin
   clock_count<=clock_count+1;
   // Constant-divisor normalization is spread over 32 cycles, not put on the pixel path.
   if(dividing) begin
    if(shifted_remainder>=DENOM) begin
     remainder<=shifted_remainder-DENOM; quotient<={quotient[30:0],1'b1};
    end else begin remainder<=shifted_remainder; quotient<={quotient[30:0],1'b0}; end
    divide_left<=divide_left-1'b1;
    if(divide_left==1) begin
     features[{job_bank,job_tile}]<={quotient[6:0],shifted_remainder>=DENOM};
     dividing<=0;
     if(commit_job) begin
      frame_sequence<=frame_sequence+1; last_pixels<=WIDTH*HEIGHT;
      frame_cycles<=job_frame_cycles+32;
     end
    end
   end
   if(accept) begin
    if(pixel_sof) begin
     if(active) frame_errors<=frame_errors+1;
     frames_started<=frames_started+1;
     frame_start_clock<=clock_count;
     active<=1; bad_frame<=pixel_eol; invert_frame<=invert;
     x<=1; y<=0; bx<=1; by<=0; tile_x<=0; tile_y<=0; pixels<=1;
     for(i=0;i<64;i=i+1) sums[i]<=0;
     sums[0]<=value;
    end else if(active) begin
     pixels<=pixels+1;
     if(pixel_eol!=(x==WIDTH-1)) bad_frame<=1;
     if(bx==TILE_W-1 && by==TILE_H-1) begin
      sums[tile]<=0;
      if(dividing) bad_frame<=1;
      else begin
       dividing<=1; divide_left<=32; remainder<=0;
       quotient<=accumulated*112+DENOM/2;
       job_bank<=write_bank; job_tile<=tile;
       commit_job<=x==WIDTH-1 && y==HEIGHT-1 && !bad_frame && pixel_eol && pixels==WIDTH*HEIGHT-1;
       if(x==WIDTH-1 && y==HEIGHT-1) job_frame_cycles<=clock_count-frame_start_clock+1;
      end
     end else sums[tile]<=accumulated[23:0];
     if(x==WIDTH-1) begin
      x<=0; bx<=0; tile_x<=0;
      if(y==HEIGHT-1) begin
       active<=0;
       if(!bad_frame && pixel_eol && pixels==WIDTH*HEIGHT-1 && !dividing) write_bank<=~write_bank;
       else frame_errors<=frame_errors+1;
       y<=0; by<=0; tile_y<=0;
      end else begin
       y<=y+1;
       if(by==TILE_H-1) begin by<=0; tile_y<=tile_y+1'b1; end else by<=by+1;
      end
     end else begin
      x<=x+1;
      if(bx==TILE_W-1) begin bx<=0; tile_x<=tile_x+1'b1; end else bx<=bx+1;
     end
    end
   end
  end
 end
endmodule
