`timescale 1ns/1ps
// Exclusive scratchpad owner; reads are synchronous with one-cycle latency.
// AXI4 INCR, aligned 32-bit transfers, <=16 beats, no 4 KiB crossing.
module npu_dma #(
 parameter integer MEM_WORDS=16384, MEM_AW=14,
 parameter [31:0] DDR_BASE=32'h00100000, DDR_LIMIT=32'h20000000
)(
 input wire clk,rstn,start,input wire direction,packed_int8,
 input wire [31:0] ddr_address,input wire [15:0] scratch_base,element_count,
 output reg busy,done,output reg [31:0] error,words_done,cycles,
 output reg mem_en,mem_we,output reg [MEM_AW-1:0] mem_addr,
 output reg [31:0] mem_wdata,input wire [31:0] mem_rdata,
 output wire [31:0] m_axi_araddr,output wire [7:0] m_axi_arlen,
 output wire [2:0] m_axi_arsize,output wire [1:0] m_axi_arburst,
 output wire m_axi_arvalid,input wire m_axi_arready,
 input wire [31:0] m_axi_rdata,input wire [1:0] m_axi_rresp,
 input wire m_axi_rlast,m_axi_rvalid,output wire m_axi_rready,
 output wire [31:0] m_axi_awaddr,output wire [7:0] m_axi_awlen,
 output wire [2:0] m_axi_awsize,output wire [1:0] m_axi_awburst,
 output wire m_axi_awvalid,input wire m_axi_awready,
 output wire [31:0] m_axi_wdata,output wire [3:0] m_axi_wstrb,
 output wire m_axi_wlast,m_axi_wvalid,input wire m_axi_wready,
 input wire [1:0] m_axi_bresp,input wire m_axi_bvalid,output wire m_axi_bready
);
 localparam IDLE=0,CHECK=1,BURST=2,RADDR=3,RWAIT=4,RSTORE=5,
            RDRAIN=6,WADDR=7,WFETCH=8,WCAPTURE=9,WSEND=10,BWAIT=11,FINISH=12;
 reg [3:0] state;
 reg dir,packed_mode;
 reg [31:0] address,buffer;
 reg [15:0] left;
 reg [16:0] cursor;
 reg [4:0] beats,beat;
 reg [2:0] lane,beat_elements;
 integer remaining_beats,boundary_beats,next_beats;
 // Validate the atomically captured request, avoiding a queue mux plus address
 // bounds arithmetic in the same cycle. No AXI request precedes CHECK.
 wire [32:0] requested_bytes=packed_mode ? (({17'd0,left}+3)>>2)<<2 : {15'd0,left,2'b0};
 wire [32:0] end_address={1'b0,address}+requested_bytes;
 wire invalid_cfg=left==0 || cursor+{1'b0,left}>MEM_WORDS ||
                  address[1:0]!=0 || address<DDR_BASE || end_address>{1'b0,DDR_LIMIT};
 assign m_axi_araddr=address; assign m_axi_awaddr=address;
 assign m_axi_arlen=beats-1'b1; assign m_axi_awlen=beats-1'b1;
 assign m_axi_arsize=3'd2; assign m_axi_awsize=3'd2;
 assign m_axi_arburst=2'b01; assign m_axi_awburst=2'b01;
 assign m_axi_arvalid=state==RADDR; assign m_axi_awvalid=state==WADDR;
 assign m_axi_rready=state==RWAIT || state==RDRAIN;
 assign m_axi_wvalid=state==WSEND; assign m_axi_wdata=buffer;
 assign m_axi_wstrb=packed_mode ? (4'b1111>>(4-beat_elements)) : 4'b1111;
 assign m_axi_wlast=beat==beats-1'b1; assign m_axi_bready=state==BWAIT;
 always @* begin
  remaining_beats=packed_mode ? (({16'd0,left}+3)>>2) : left;
  boundary_beats=(4096-{20'd0,address[11:0]})>>2;
  next_beats=remaining_beats;
  if(next_beats>16) next_beats=16;
  if(next_beats>boundary_beats) next_beats=boundary_beats;
  mem_en=0; mem_we=0; mem_addr=cursor[MEM_AW-1:0]; mem_wdata=0;
  if(state==RSTORE) begin
   mem_en=1; mem_we=1;
   mem_wdata=packed_mode ? {{24{buffer[lane*8+7]}},buffer[lane*8+:8]} : buffer;
  end
  if(state==WFETCH) mem_en=1;
 end
 always @(posedge clk) begin
  if(!rstn) begin
   state<=IDLE; busy<=0; done<=0; error<=0; words_done<=0; cycles<=0;
   dir<=0; packed_mode<=0; address<=0; buffer<=0; left<=0; cursor<=0;
   beats<=1; beat<=0; lane<=0; beat_elements<=0;
  end else begin
   done<=0;
   if(busy) cycles<=cycles+1;
   case(state)
    IDLE: if(start) begin
     busy<=1; error<=0; words_done<=0; cycles<=0;
     dir<=direction; packed_mode<=packed_int8; address<=ddr_address;
     left<=element_count; cursor<={1'b0,scratch_base};
     // Configuration is sampled atomically with start.
     state<=CHECK;
    end
    CHECK: if(invalid_cfg) begin error<=1; state<=FINISH; end else state<=BURST;
    BURST: begin beats<=next_beats; beat<=0; state<=dir ? WADDR : RADDR; end
    RADDR: if(m_axi_arready) state<=RWAIT;
    RWAIT: if(m_axi_rvalid) begin
     if(m_axi_rresp!=0 || m_axi_rlast!=(beat==beats-1'b1)) begin
      error<=(m_axi_rresp!=0 ? 2 : 0) | (m_axi_rlast!=(beat==beats-1'b1) ? 8 : 0);
      // Drain an accepted outstanding burst before making the engine idle.
      state<=m_axi_rlast ? FINISH : RDRAIN;
     end else begin buffer<=m_axi_rdata; lane<=0; state<=RSTORE; end
    end
    RDRAIN: if(m_axi_rvalid && m_axi_rlast) state<=FINISH;
    RSTORE: begin
     cursor<=cursor+1; left<=left-1'b1; words_done<=words_done+1;
     if(packed_mode && lane<3 && left>1) lane<=lane+1'b1;
     else if(beat==beats-1'b1) begin
      address<=address+{25'd0,beats,2'b0}; state<=left==1 ? FINISH : BURST;
     end else begin beat<=beat+1'b1; state<=RWAIT; end
    end
    WADDR: if(m_axi_awready) begin buffer<=0; lane<=0; beat_elements<=0; state<=WFETCH; end
    WFETCH: state<=WCAPTURE;
    WCAPTURE: begin
     if(packed_mode) buffer[lane*8+:8]<=mem_rdata[7:0]; else buffer<=mem_rdata;
     cursor<=cursor+1; left<=left-1'b1; beat_elements<=beat_elements+1'b1;
     if(packed_mode && lane<3 && left>1) begin lane<=lane+1'b1; state<=WFETCH; end
     else state<=WSEND;
    end
    WSEND: if(m_axi_wready) begin
     words_done<=words_done+beat_elements;
     if(beat==beats-1'b1) state<=BWAIT;
     else begin beat<=beat+1'b1; lane<=0; beat_elements<=0; buffer<=0; state<=WFETCH; end
    end
    BWAIT: if(m_axi_bvalid) begin
     if(m_axi_bresp!=0) begin error<=4; state<=FINISH; end
     else begin address<=address+{25'd0,beats,2'b0}; state<=left==0 ? FINISH : BURST; end
    end
    FINISH: begin busy<=0; done<=1; state<=IDLE; end
    default: begin error<=16; state<=FINISH; end
   endcase
  end
 end
endmodule
