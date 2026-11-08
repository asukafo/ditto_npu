`timescale 1ns/1ps
module tb_dma;
reg clk=0; always #5 clk=~clk;
reg rstn=0,start=0,dir=0,packed_mode=0;
reg [31:0] ddr_address=0; reg [15:0] scratch_base=0,count=0;
wire busy,done; wire [31:0] error,words_done,cycles;
wire men,mwe; wire [13:0] ma; wire [31:0] mw; reg [31:0] mr;
wire [31:0] araddr,awaddr,wd; wire [7:0] arlen,awlen; wire [2:0] arsize,awsize;
wire [1:0] arburst,awburst; wire arv,awv,rr,wv,wl,br;
wire [3:0] ws;
reg arr=0,awr=0,wr=0,rv=0,rl=0,bv=0;
reg [31:0] rd=0; reg [1:0] rresp=0,bresp=0;
reg [31:0] scratch[0:16383]; reg [7:0] ddr[0:16383];
integer tick=0,seed=716,read_left=0,write_left=0,read_addr=0,write_addr=0;
integer bursts=0,read_pos=0,write_pos=0,inject_r=-1,inject_b=0,early_last=-1;
integer i,j,k,timeout,expected,base;
reg ractive=0,wactive=0,bpending=0;
reg stalled_ar=0,stalled_aw=0,stalled_w=0;
reg [39:0] held_ar,held_aw; reg [36:0] held_w;
npu_dma dut(.clk(clk),.rstn(rstn),.start(start),.direction(dir),.packed_int8(packed_mode),.ddr_address(ddr_address),.scratch_base(scratch_base),.element_count(count),.busy(busy),.done(done),.error(error),.words_done(words_done),.cycles(cycles),.mem_en(men),.mem_we(mwe),.mem_addr(ma),.mem_wdata(mw),.mem_rdata(mr),.m_axi_araddr(araddr),.m_axi_arlen(arlen),.m_axi_arsize(arsize),.m_axi_arburst(arburst),.m_axi_arvalid(arv),.m_axi_arready(arr),.m_axi_rdata(rd),.m_axi_rresp(rresp),.m_axi_rlast(rl),.m_axi_rvalid(rv),.m_axi_rready(rr),.m_axi_awaddr(awaddr),.m_axi_awlen(awlen),.m_axi_awsize(awsize),.m_axi_awburst(awburst),.m_axi_awvalid(awv),.m_axi_awready(awr),.m_axi_wdata(wd),.m_axi_wstrb(ws),.m_axi_wlast(wl),.m_axi_wvalid(wv),.m_axi_wready(wr),.m_axi_bresp(bresp),.m_axi_bvalid(bv),.m_axi_bready(br));
always @(posedge clk) begin
 if(men) begin mr<=scratch[ma]; if(mwe) scratch[ma]<=mw; end
 tick<=tick+1;
 // Pseudorandom but deterministic channel stalls; R/B responses stay stable until accepted.
 arr<=tick%5!=0; awr<=tick%4!=1; wr<=tick%7!=2;
 if(rstn) begin
  if(stalled_ar && (!arv || {araddr,arlen}!==held_ar)) $fatal(1,"AR unstable under stall");
  if(stalled_aw && (!awv || {awaddr,awlen}!==held_aw)) $fatal(1,"AW unstable under stall");
  if(stalled_w && (!wv || {wd,ws,wl}!==held_w)) $fatal(1,"W unstable under stall");
  stalled_ar<=arv&&!arr; held_ar<={araddr,arlen};
  stalled_aw<=awv&&!awr; held_aw<={awaddr,awlen};
  stalled_w<=wv&&!wr; held_w<={wd,ws,wl};
 end
 if(arv && arr) begin
  if(ractive || arsize!=2 || arburst!=1 || arlen>15 || araddr[1:0]!=0 || araddr[11:0]+4*(arlen+1)>4096) $fatal(1,"invalid AR burst");
  ractive<=1; read_left<=arlen+1; read_addr<=araddr-32'h100000; read_pos<=0; bursts<=bursts+1;
 end
 if(ractive && !rv && tick%3!=0) begin
  rd<={ddr[read_addr+3],ddr[read_addr+2],ddr[read_addr+1],ddr[read_addr]};
  rresp<=read_pos==inject_r ? 2 : 0; rl<=read_left==1 || read_pos==early_last; rv<=1;
 end
 if(rv && rr) begin
  rv<=0; read_left<=read_left-1; read_addr<=read_addr+4; read_pos<=read_pos+1;
  if(rl) ractive<=0;
 end
 if(awv && awr) begin
  if(wactive || awsize!=2 || awburst!=1 || awlen>15 || awaddr[1:0]!=0 || awaddr[11:0]+4*(awlen+1)>4096) $fatal(1,"invalid AW burst");
  wactive<=1; write_left<=awlen+1; write_addr<=awaddr-32'h100000; write_pos<=0; bursts<=bursts+1;
 end
 if(wv && wr) begin
  if(!wactive || wl!=(write_left==1)) $fatal(1,"WLAST or outstanding write invalid");
  for(k=0;k<4;k=k+1) if(ws[k]) ddr[write_addr+k]<=wd[k*8+:8];
  write_addr<=write_addr+4; write_left<=write_left-1; write_pos<=write_pos+1;
  if(wl) begin wactive<=0; bpending<=1; end
 end
 if(bpending && !bv && tick%4!=0) begin bv<=1; bresp<=inject_b ? 2 : 0; bpending<=0; end
 if(bv && br) bv<=0;
end
task run(input integer want_error);
begin
 @(negedge clk); start=1; @(negedge clk); start=0;
 timeout=0; while(!done && timeout<200000) begin @(negedge clk); timeout=timeout+1; end
 if(!done || error!==want_error) $fatal(1,"DMA error=%d expected=%d timeout=%d",error,want_error,timeout);
 if(ractive || wactive || rv || bv || bpending) $fatal(1,"done with outstanding AXI transaction");
 if(want_error==0 && words_done!==count) $fatal(1,"word count %d expected %d",words_done,count);
 repeat(2) @(negedge clk);
end endtask
initial begin
 for(i=0;i<16384;i=i+1) begin scratch[i]=32'hdeadbeef; ddr[i]=(i*37+19)%256; end
 repeat(5) @(negedge clk); rstn=1;
 // Raw reads cross 4 KiB and 16-beat boundaries; arbitrary lengths and scratch offsets.
 for(j=0;j<4;j=j+1) begin
  dir=0; packed_mode=0; base=4088+j*4; ddr_address=32'h100000+base; scratch_base=123; count=67+j;
  run(0);
  for(i=0;i<count;i=i+1) begin
   expected={ddr[base+i*4+3],ddr[base+i*4+2],ddr[base+i*4+1],ddr[base+i*4]};
   if(scratch[123+i]!==expected) $fatal(1,"raw read mismatch %d",i);
  end
 end
 // Packed read sign extension and packed write tails (1..4 bytes), plus raw writes.
 for(j=1;j<=7;j=j+1) begin
  dir=0; packed_mode=1; base=4092; ddr_address=32'h100000+base; scratch_base=400; count=64+j; run(0);
  for(i=0;i<count;i=i+1) if($signed(scratch[400+i])!==$signed(ddr[base+i])) $fatal(1,"packed read %d",i);
  dir=1; base=8188; ddr_address=32'h100000+base;
  for(i=0;i<count+4;i=i+1) ddr[base+i]=8'ha5;
  run(0);
  for(i=0;i<count;i=i+1) if(ddr[base+i]!==scratch[400+i][7:0]) $fatal(1,"packed write %d",i);
  for(i=count;i<count+4;i=i+1) if(ddr[base+i]!==8'ha5) $fatal(1,"tail byte overwritten");
 end
 dir=1; packed_mode=0; count=79; scratch_base=10; ddr_address=32'h103ff0-512; base=ddr_address-32'h100000;
 for(i=0;i<count;i=i+1) scratch[10+i]=32'habcd0000+i;
 run(0);
 for(i=0;i<count;i=i+1) if({ddr[base+i*4+3],ddr[base+i*4+2],ddr[base+i*4+1],ddr[base+i*4]}!==scratch[10+i]) $fatal(1,"raw write");
 // Parameter rejection must issue no burst.
 base=bursts; count=0; run(1); count=1; ddr_address=32'h100001; run(1);
 ddr_address=32'h0; run(1); ddr_address=32'h1ffffffc; count=2; run(1);
 ddr_address=32'h100000; count=2; scratch_base=16383; run(1);
 if(bursts!=base) $fatal(1,"invalid job issued AXI");
 // RRESP failure in mid-burst must drain remaining responses; next job still works.
 dir=0; packed_mode=0; scratch_base=1000; count=16; inject_r=3; run(2); inject_r=-1; run(0);
 dir=1; inject_b=1; run(4); inject_b=0; run(0);
 dir=0; early_last=2; run(8); early_last=-1; run(0);
 $display("NPU_DMA: PASS raw/packed bidirectional, tails, 4KiB splits, channel stalls, bounds, RRESP/BRESP/RLAST recovery"); $finish;
end
initial begin #20000000; $fatal(1,"watchdog"); end
endmodule
