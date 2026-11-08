`timescale 1ns/1ps
module tb_video_ddr;
reg clk=0; always #5 clk=~clk;
reg rstn=0; reg [23:0] pixel=0; reg valid=0,ready=0,sof=0,eol=0;
wire [31:0] published=dut.frame_sequence,published_cycles=dut.frame_cycles,errors=dut.frame_errors;

reg [7:0] ddr[0:127];
wire [31:0] awaddr,wdata; wire [7:0] awlen; wire [2:0] awsize;
wire [1:0] awburst; wire awvalid,wvalid,wlast,bready; wire [3:0] wstrb;
reg awready=0,wready=0,bvalid=0; reg [1:0] bresp=0;
integer tick=0,active=0,remaining=0,address=0,i,k,timeout;
reg bpending=0,inject=0;
npu_video_ddr dut(.s_axi_aclk(clk),.s_axi_aresetn(rstn),
.s_axi_awaddr(12'd0),.s_axi_awprot(3'd0),.s_axi_awvalid(1'b0),
.s_axi_wdata(32'd0),.s_axi_wstrb(4'd0),.s_axi_wvalid(1'b0),.s_axi_bready(1'b1),
.s_axi_araddr(12'd0),.s_axi_arprot(3'd0),.s_axi_arvalid(1'b0),.s_axi_rready(1'b1),
.pixel_data(pixel),.pixel_valid(valid),.pixel_ready(ready),.pixel_sof(sof),.pixel_eol(eol),
.m_axi_awaddr(awaddr),.m_axi_awlen(awlen),.m_axi_awsize(awsize),.m_axi_awburst(awburst),
.m_axi_awvalid(awvalid),.m_axi_awready(awready),.m_axi_wdata(wdata),.m_axi_wstrb(wstrb),
.m_axi_wlast(wlast),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
.m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready));
always @(posedge clk) begin
 tick<=tick+1;
 awready<=tick%7!=0; wready<=tick%4!=0;
 if(awvalid && awready) begin
  if(active || awlen!=15 || awsize!=2 || awburst!=1 || awaddr<32'h04000000 || awaddr>32'h04000040) $fatal(1,"invalid mailbox burst");
  active<=1; remaining<=16; address<=awaddr-32'h04000000;
 end
 if(wvalid && wready) begin
  if(!active || wlast!=(remaining==1) || wstrb!=15) $fatal(1,"invalid W transaction");
  for(k=0;k<4;k=k+1) ddr[address+k]<=wdata[k*8+:8];
  address<=address+4; remaining<=remaining-1;
  if(wlast) begin active<=0; bpending<=1; end
 end
 if(bpending && !bvalid && tick%5!=0) begin bvalid<=1; bresp<=inject ? 2 : 0; bpending<=0; end
 if(bvalid && bready) bvalid<=0;
end
task wait_publish(input integer want);
begin
 timeout=0; while(published!=want && timeout<5000) begin @(negedge clk); timeout++; end
 if(published!=want || published_cycles<=1234) $fatal(1,"publication/latency failed");
end endtask
integer x,y,f,intensity,expected;
initial begin
 for(i=0;i<128;i=i+1) ddr[i]=8'ha5;
 repeat(5) @(negedge clk); rstn=1;
 for(f=0;f<2;f=f+1) begin
  for(y=0;y<720;y=y+1) for(x=0;x<1280;x=x+1) begin
   @(negedge clk); valid=1; ready=1; sof=x==0 && y==0; eol=x==1279;
   intensity=f==0 ? ((y/90)*8+x/160)*4 : 255; pixel={3{intensity[7:0]}};
  end
  @(negedge clk); valid=0; ready=0; sof=0; eol=0;
  wait_publish(f+1);
  for(i=0;i<64;i=i+1) begin
   expected=f==0 ? ((255-i*4)*112+127)/255 : 0;
   if(ddr[f*64+i]!==expected) $fatal(1,"full-frame DDR feature %d = %d expected %d",i,ddr[f*64+i],expected);
  end
 end
 if(errors!=0 || dut.last_pixels!=921600 || dut.frames_started!=2) $fatal(1,"frame integrity");
 $display("NPU_VIDEO_DDR: PASS two full 1280x720 frames -> exact packed DDR features, inversion, double buffers and publication ordering"); $finish;
end
initial begin #30000000; $fatal(1,"watchdog"); end
endmodule
