`timescale 1ns/1ps
module tb_preprocess_hd;
reg clk=0; always #5 clk=~clk;
reg rstn=0,valid=0,ready=0,sof=0,eol=0,invert=0;
reg [23:0] data=0; reg [6:0] address=0;
wire [7:0] feature; wire [31:0] seq,started,errors,pixels;
integer x,y,i,expected,timeout,frame;
reg [7:0] saved[0:63];
npu_frame_preprocess #(.WIDTH(1280),.HEIGHT(720)) dut(
 .clk(clk),.rstn(rstn),.pixel_data(data),.pixel_valid(valid),.pixel_ready(ready),
 .pixel_sof(sof),.pixel_eol(eol),.invert(invert),.frame_sequence(seq),
 .frames_started(started),.frame_errors(errors),.last_pixels(pixels),
 .feature_address(address),.feature_data(feature));
task send_frame(input integer mode,input integer malformed);
integer intensity;
begin
 for(y=0;y<720;y=y+1) for(x=0;x<1280;x=x+1) begin
  intensity=mode==0 ? ((y/90)*8+x/160)*4 : 255;
  @(negedge clk); valid=1; ready=1; sof=x==0 && y==0;
  eol=(x==1279) ^ (malformed && x==12 && y==3); data={3{intensity[7:0]}};
  // Stall the video path without accepting or changing the held pixel.
  if((x+y)%17==0) begin
   ready=0; repeat(2) @(negedge clk); ready=1;
  end
 end
 @(negedge clk); valid=0; ready=0; sof=0; eol=0;
 repeat(40) @(negedge clk);
end endtask
task check_features(input integer bank,input integer mode,input integer inv);
begin
 for(i=0;i<64;i=i+1) begin
  @(negedge clk); address=bank*64+i;
  repeat(2) @(negedge clk);
  if(mode==0) expected=((inv ? 255-i*4 : i*4)*112+127)/255;
  else expected=inv ? 0 : 112;
  if(feature!==expected) $fatal(1,"feature[%d] %d expected %d",i,feature,expected);
  if(bank==0) saved[i]=feature;
 end
end endtask
initial begin
 repeat(5) @(negedge clk); rstn=1;
 send_frame(0,0);
 if(seq!==1 || started!==1 || errors!==0 || pixels!==921600) $fatal(1,"frame counters");
 check_features(0,0,0);
 invert=1; send_frame(1,0);
 if(seq!==2 || errors!==0) $fatal(1,"second frame");
 check_features(1,1,1);
 for(i=0;i<64;i=i+1) begin
  @(negedge clk); address=i; repeat(2) @(negedge clk);
  if(feature!==saved[i]) $fatal(1,"double buffer overwritten");
 end
 send_frame(0,1);
 if(seq!==2 || errors!==1) $fatal(1,"malformed EOL frame was published");
 send_frame(0,0);
 if(seq!==3 || errors!==1 || started!==4) $fatal(1,"frame recovery");
 check_features(0,0,1);
 $display("NPU_PREPROCESS: PASS all-pixel area average, normalization/invert, stalls, double buffers, malformed-frame rejection/recovery"); $finish;
end
initial begin #60000000; $fatal(1,"watchdog"); end
endmodule

