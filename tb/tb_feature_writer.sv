`timescale 1ns/1ps
module tb_feature_writer;
reg clk=0; always #5 clk=~clk;
reg rstn=0; reg [31:0] source=0,source_cycles=1234;
wire [31:0] published,published_cycles,errors;
wire [6:0] feature_addr; reg [7:0] feature_data;
reg [7:0] features[0:127],ddr[0:127];
wire [31:0] awaddr,wdata; wire [7:0] awlen; wire [2:0] awsize;
wire [1:0] awburst; wire awvalid,wvalid,wlast,bready; wire [3:0] wstrb;
reg awready=0,wready=0,bvalid=0; reg [1:0] bresp=0;
integer tick=0,active=0,remaining=0,address=0,i,k,timeout;
reg bpending=0,inject=0;
npu_feature_writer #(.DDR_ADDRESS(32'h100000)) dut(
 .clk(clk),.rstn(rstn),.source_sequence(source),.source_cycles(source_cycles),
 .published_sequence(published),.published_cycles(published_cycles),.errors(errors),
 .feature_address(feature_addr),.feature_data(feature_data),
 .m_axi_awaddr(awaddr),.m_axi_awlen(awlen),.m_axi_awsize(awsize),.m_axi_awburst(awburst),
 .m_axi_awvalid(awvalid),.m_axi_awready(awready),.m_axi_wdata(wdata),.m_axi_wstrb(wstrb),
 .m_axi_wlast(wlast),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
 .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready));
always @(posedge clk) begin
 feature_data<=features[feature_addr]; tick<=tick+1;
 awready<=tick%7!=0; wready<=tick%4!=0;
 if(awvalid && awready) begin
  if(active || awlen!=15 || awsize!=2 || awburst!=1 || awaddr<32'h100000 || awaddr>32'h100040) $fatal(1,"invalid mailbox burst");
  active<=1; remaining<=16; address<=awaddr-32'h100000;
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
initial begin
 for(i=0;i<128;i=i+1) begin features[i]=i; ddr[i]=8'ha5; end
 repeat(5) @(negedge clk); rstn=1;
 @(negedge clk); source=1; wait_publish(1);
 for(i=0;i<64;i=i+1) if(ddr[i]!==features[i]) $fatal(1,"slot0 mismatch");
 for(i=64;i<128;i=i+1) if(ddr[i]!==8'ha5) $fatal(1,"other slot corrupted");
 @(negedge clk); source=2; wait_publish(2);
 for(i=64;i<128;i=i+1) if(ddr[i]!==features[i]) $fatal(1,"slot1 mismatch");
 inject=1; @(negedge clk); source=3;
 repeat(500) @(negedge clk);
 if(published!=2 || errors!=1) $fatal(1,"failed BRESP was published");
 inject=0; @(negedge clk); source=4; wait_publish(4);
 if(errors!=1) $fatal(1,"recovery count");
 $display("NPU_FEATURE_WRITER: PASS exact DDR packing, ping-pong slots, stalls, response-error suppression/recovery, latency metadata"); $finish;
end
initial begin #1000000; $fatal(1,"watchdog"); end
endmodule
