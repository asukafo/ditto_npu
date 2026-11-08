`timescale 1ns/1ps
module tb_v2;
reg clk=0; always #5 clk=~clk;
reg rstn=0;
reg [16:0] slave_awaddr=0,slave_araddr=0;
reg [31:0] wdata=0;
reg [3:0] wstrb=15;
reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
wire awready,wready,bvalid,arready,rvalid,irq;
wire [1:0] bresp,rresp; wire [31:0] rdata;
integer i,k; reg [31:0] v;

wire [31:0] araddr,awaddr,wd; wire [7:0] arlen,awlen;
wire [2:0] arsize,awsize; wire [1:0] arburst,awburst;
wire arv,awv,rr,wv,wl,br; wire [3:0] ws;
reg arr=0,awr=0,wr=0,rv=0,rl=0,bv=0;
reg [31:0] rd=0; reg [1:0] rresp_axi=0,bresp_axi=0;
reg [7:0] ddr[0:16383];
integer tick=0,seed=716,read_left=0,write_left=0,read_addr=0,write_addr=0;
integer bursts=0,read_pos=0,write_pos=0,inject_r=-1,inject_b=0,early_last=-1;
integer byte_lane,before_bursts;
reg ractive=0,wactive=0,bpending=0;
reg stalled_ar=0,stalled_aw=0,stalled_w=0;
reg [39:0] held_ar,held_aw; reg [36:0] held_w;
npu_axi_v2 dut(.s_axi_aclk(clk),.s_axi_aresetn(rstn),.s_axi_awaddr(slave_awaddr),.s_axi_awprot(3'd0),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(slave_araddr),.s_axi_arprot(3'd0),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.irq(irq),.m_axi_araddr(araddr),.m_axi_arlen(arlen),.m_axi_arsize(arsize),.m_axi_arburst(arburst),.m_axi_arvalid(arv),.m_axi_arready(arr),.m_axi_rdata(rd),.m_axi_rresp(rresp_axi),.m_axi_rlast(rl),.m_axi_rvalid(rv),.m_axi_rready(rr),.m_axi_awaddr(awaddr),.m_axi_awlen(awlen),.m_axi_awsize(awsize),.m_axi_awburst(awburst),.m_axi_awvalid(awv),.m_axi_awready(awr),.m_axi_wdata(wd),.m_axi_wstrb(ws),.m_axi_wlast(wl),.m_axi_wvalid(wv),.m_axi_wready(wr),.m_axi_bresp(bresp_axi),.m_axi_bvalid(bv),.m_axi_bready(br));
always @(posedge clk) begin
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
  rresp_axi<=read_pos==inject_r ? 2 : 0; rl<=read_left==1 || read_pos==early_last; rv<=1;
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
  for(byte_lane=0;byte_lane<4;byte_lane=byte_lane+1) if(ws[byte_lane]) ddr[write_addr+byte_lane]<=wd[byte_lane*8+:8];
  write_addr<=write_addr+4; write_left<=write_left-1; write_pos<=write_pos+1;
  if(wl) begin wactive<=0; bpending<=1; end
 end
 if(bpending && !bv && tick%4!=0) begin bv<=1; bresp_axi<=inject_b ? 2 : 0; bpending<=0; end
 if(bv && br) bv<=0;
end

task write_reg(input [16:0] a,input [31:0] data,input [3:0] st,input integer order,input [1:0] response);
begin
 @(negedge clk); slave_awaddr=a; wdata=data; wstrb=st;
 if(order==0) begin
 awvalid=1; do @(posedge clk); while(!awready);
 @(negedge clk); awvalid=0; repeat(3) @(negedge clk);
 wvalid=1; do @(posedge clk); while(!wready);
 @(negedge clk); wvalid=0;
 end else begin
 wvalid=1; do @(posedge clk); while(!wready);
 @(negedge clk); wvalid=0; repeat(2) @(negedge clk);
 awvalid=1; do @(posedge clk); while(!awready);
 @(negedge clk); awvalid=0;
 end
 while(!bvalid) @(negedge clk);
 if(bresp!==response) $fatal(1,"write %h response %d expected %d",a,bresp,response);
 repeat(3) begin @(negedge clk); if(!bvalid || bresp!==response) $fatal(1,"B stalled response unstable"); end
 bready=1; @(negedge clk); bready=0;
end endtask
task read_reg(input [16:0] a,input [1:0] response,output [31:0] data);
begin
 @(negedge clk); slave_araddr=a; arvalid=1;
 do @(posedge clk); while(!arready);
 @(negedge clk); arvalid=0;
 while(!rvalid) @(negedge clk);
 data=rdata;
 if(rresp!==response) $fatal(1,"read %h response %d expected %d",a,rresp,response);
 repeat(3) begin @(negedge clk); if(!rvalid || rdata!==data || rresp!==response) $fatal(1,"R stalled response unstable"); end
 rready=1; @(negedge clk); rready=0;
end endtask
initial begin
 repeat(5) @(negedge clk); rstn=1;
 read_reg(0,0,v); if(v!==32'h4e505532) $fatal(1,"ID");
 write_reg('h10000,32'h11223344,15,0,0);
 write_reg('h10000,32'haabbccdd,5,1,0);
 read_reg('h10000,0,v); if(v!==32'h11bb33dd) $fatal(1,"byte enables %h",v);
 write_reg('h10001,0,15,0,2); read_reg('h50,2,v);
 write_reg('h10000,-9,15,1,0);
 // ReLU: one input, one output, repeated descriptors queued while disabled.
 for(i=0;i<16;i=i+1) begin
 case(i)
 0:v=2; 1:v=0; 2:v=128; 4:v=32'hffffffff;
 5,6,7:v=1; 14:v=987; default:v=0;
 endcase
 write_reg('h100+i*4,v,15,i%2,0);
 end
 for(k=0;k<8;k=k+1) write_reg('h10,1,15,k%2,0);
 write_reg('h10,1,15,0,2);
 read_reg('h24,0,v); if(v!==8) $fatal(1,"queue depth %d",v);
 read_reg('h10000,2,v); write_reg('h10000,1,15,1,2);
 write_reg(4,3,15,0,0);
 v=0; while(v!=8) read_reg(12,0,v);
 read_reg('h10200,0,v); if(v!==0) $fatal(1,"relu output %h",v);
 read_reg('h14,0,v); if(v!==987 || !irq) $fatal(1,"tag/irq");
 write_reg('h28,1,15,1,0); if(irq) $fatal(1,"irq clear");

 // Queue a packed DDR load, compute, and packed DDR store before dispatch.
 for(i=0;i<16384;i=i+1) ddr[i]=8'ha5;
 for(i=0;i<9;i=i+1) ddr[4092+i]=i-4;
 write_reg(4,0,15,0,0);
 for(k=0;k<3;k=k+1) begin
  for(i=0;i<16;i=i+1) begin
   v=0;
   if(k==0) case(i)
    0:v='h110; 1:v='h100ffc; 2:v=0; 3:v=9; 14:v=1234;
   endcase
   if(k==1) case(i)
    0:v=2; 1:v=0; 2:v=128; 4:v=32'hffffffff; 5:v=3; 6:v=3; 7:v=1; 14:v=1235;
   endcase
   if(k==2) case(i)
    0:v='h111; 1:v='h102ffc; 2:v=128; 3:v=9; 14:v=1236;
   endcase
   write_reg('h100+i*4,v,15,i%2,0);
  end
  write_reg('h10,1,15,0,0);
 end
 write_reg(4,1,15,0,0);
 v=0; while(v!=11) read_reg(12,0,v);
 for(i=0;i<9;i=i+1) if(ddr[12284+i] !== (i<4 ? 8'd0 : i-4)) $fatal(1,"DMA-compute-store mismatch %d",i);
 if(ddr[12293]!==8'ha5) $fatal(1,"DMA store overwrote padding");
 read_reg('h18,0,v); if(v!==0) $fatal(1,"DMA chain error");
 read_reg('h14,0,v); if(v!==1236) $fatal(1,"DMA tag");
 before_bursts=bursts;
 for(i=0;i<16;i=i+1) begin
  v=0;
  case(i) 0:v='h10; 1:v='h100000; 3:v='h10009; 14:v=999; endcase
  write_reg('h100+i*4,v,15,0,0);
 end
 write_reg('h10,1,15,0,0);
 v=0; while(v!=12) read_reg(12,0,v);
 read_reg('h18,0,v); if(v!==1 || bursts!=before_bursts) $fatal(1,"high descriptor bits truncated instead of rejected");
 $display("NPU_V2: PASS AXI/queue/RAM plus packed DMA-load -> ReLU -> DMA-store, boundary/tail protection, descriptor validation"); $finish;

end
initial begin #5000000; $fatal(1,"watchdog"); end
endmodule
