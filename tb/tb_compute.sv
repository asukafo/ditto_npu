`timescale 1ns/1ps
module tb_compute;
reg clk=0; always #5 clk=~clk;
reg rstn=0,start=0;
reg [31:0] d[0:15];
wire busy,done; wire [31:0] error,tag,cycles;
wire en,we; wire [13:0] addr; wire [31:0] wd; reg [31:0] rd;
reg [31:0] mem[0:16383];
integer i,t;
integer seed=12345, test_case;
npu_compute dut(clk,rstn,start,d,busy,done,error,tag,cycles,en,we,addr,wd,rd);
always @(posedge clk) if(en) begin rd<=mem[addr]; if(we) mem[addr]<=wd; end
task launch(input integer expected_error);
begin
 @(negedge clk); start=1; @(negedge clk); start=0;
 t=0; while(!done && t<100000) begin @(negedge clk); t=t+1; end
 if(!done || error!==expected_error || tag!==d[14]) $fatal(1,"completion error=%d expected=%d tag=%h cycles=%d",error,expected_error,tag,cycles);
 @(negedge clk);
end endtask
task expect_word(input integer a,input integer v);
begin if($signed(mem[a])!==v) $fatal(1,"memory[%d]=%d expected=%d",a,$signed(mem[a]),v); end
endtask
task reference_case;
integer ow,oh,xx,yy,cc,xxk,yyk,ci,px,py,a,w,b,sum,peak,out_channels,index;
integer expected[0:4095];
begin
 ow=(d[5]+2*d[12]-d[9])/d[11]+1;
 oh=(d[6]+2*d[12]-d[10])/d[11]+1;
 out_channels=d[0][7:0]==1 ? d[8] : d[7];
 for(yy=0;yy<oh;yy=yy+1) for(xx=0;xx<ow;xx=xx+1)
 for(cc=0;cc<out_channels;cc=cc+1) begin
  sum=d[4]==32'hffffffff ? 0 : $signed(mem[d[4]+cc]); peak=-128;
  for(yyk=0;yyk<d[10];yyk=yyk+1) for(xxk=0;xxk<d[9];xxk=xxk+1) begin
   px=xx*d[11]+xxk-d[12]; py=yy*d[11]+yyk-d[12];
   if(px>=0 && py>=0 && px<d[5] && py<d[6]) begin
    if(d[0][7:0]==3) begin
     a=$signed(mem[d[1]+(py*d[5]+px)*d[7]+cc][7:0]);
     if(a>peak) peak=a;
    end else for(ci=0;ci<d[7];ci=ci+1) begin
     a=$signed(mem[d[1]+(py*d[5]+px)*d[7]+ci][7:0]);
     w=$signed(mem[d[3]+((cc*d[10]+yyk)*d[9]+xxk)*d[7]+ci][7:0]);
     sum=sum+a*w;
    end
   end
  end
  if(d[0][7:0]==3) b=peak;
  else begin
   b=sum >>> d[13]; if(d[0][8] && b<0) b=0;
   if(b>127) b=127; if(b< -128) b=-128;
  end
  index=(yy*ow+xx)*out_channels+cc; expected[index]=b;
 end
 launch(0);
 for(index=0;index<ow*oh*out_channels;index=index+1) expect_word(d[2]+index,expected[index]);
end endtask
initial begin
 for(i=0;i<16;i=i+1) d[i]=0;
 d[1]=0; d[2]=128; d[3]=64; d[4]=32'hffffffff;
 d[5]=3; d[6]=3; d[7]=1; d[8]=1; d[9]=2; d[10]=2; d[11]=1; d[14]=123;
 for(i=0;i<9;i=i+1) mem[i]=i-4;
 for(i=64;i<68;i=i+1) mem[i]=1;
 repeat(5) @(negedge clk); rstn=1;
 d[0]=1; launch(0);
 expect_word(128,-8); expect_word(129,-4); expect_word(130,4); expect_word(131,8);
 d[0]=2; launch(0);
 for(i=0;i<9;i=i+1) expect_word(128+i,i<4 ? 0 : i-4);
 d[0]=3; launch(0);
 expect_word(128,0); expect_word(129,1); expect_word(130,3); expect_word(131,4);
 d[0]=1; d[4]=80; mem[80]=1000; launch(0); expect_word(128,127);
 mem[80]=-1000; launch(0); expect_word(128,-128);
 d[0]=257; launch(0); expect_word(128,0);
 d[0]=1; d[4]=32'hffffffff; d[13]=1; launch(0); expect_word(128,-4);
 d[0]=4; launch(1);
 d[0]=1; d[2]=0; launch(2);
 d[2]=128; d[11]=0; launch(1);
 d[1]=0; d[2]=1024; d[3]=256; d[4]=768;
 d[5]=4; d[6]=3; d[7]=3; d[8]=2; d[9]=3; d[10]=2;
 for(i=0;i<36;i=i+1) mem[i]=$random(seed)%128;
 for(i=256;i<292;i=i+1) mem[i]=$random(seed)%128;
 mem[768]=32'h7ffffff0; mem[769]=32'h80000010;
 for(test_case=0;test_case<6;test_case=test_case+1) begin
  d[0]=test_case%2 ? 257 : 1; d[11]=test_case<3 ? 1 : 2;
  d[12]=test_case%3; d[13]=test_case+1; reference_case;
 end
 d[0]=3; d[11]=4; d[12]=3; d[13]=0; reference_case;
 d[0]=1; d[1]=0; d[2]=4096; d[3]=512; d[4]=32'hffffffff;
 d[5]=256; d[6]=1; d[7]=1; d[8]=1; d[9]=1; d[10]=1; d[11]=1; d[12]=3; d[13]=0;
 for(i=0;i<256;i=i+1) mem[i]=i%31-15;
 mem[512]=2; reference_case;
 d[5]=1; d[6]=1; d[7]=256; d[12]=0;
 for(i=0;i<256;i=i+1) begin mem[i]=i%13-6; mem[512+i]=i%7-3; end
 reference_case;
 $display("NPU_COMPUTE: PASS conv/relu/pool/bias/saturation/fused/shift/invalid/multichannel/padding/stride/overflow"); $finish;
end
initial begin #2000000; $fatal(1,"watchdog"); end
endmodule

