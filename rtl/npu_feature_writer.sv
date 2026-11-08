`timescale 1ns/1ps
// Publish an entire normalized 8x8 image to a private two-slot DDR mailbox.
// Sequence becomes visible to software only after the AXI B response succeeds.
module npu_feature_writer #(
 parameter [31:0] DDR_ADDRESS=32'h04000000
)(
 input wire clk,rstn,input wire [31:0] source_sequence,source_cycles,
 output reg [31:0] published_sequence,published_cycles,errors,
 output wire [6:0] feature_address,input wire [7:0] feature_data,
 output wire [31:0] m_axi_awaddr,output wire [7:0] m_axi_awlen,
 output wire [2:0] m_axi_awsize,output wire [1:0] m_axi_awburst,
 output wire m_axi_awvalid,input wire m_axi_awready,
 output wire [31:0] m_axi_wdata,output wire [3:0] m_axi_wstrb,
 output wire m_axi_wlast,m_axi_wvalid,input wire m_axi_wready,
 input wire [1:0] m_axi_bresp,input wire m_axi_bvalid,output wire m_axi_bready
);
 localparam IDLE=0,ADDR=1,FETCH=2,CAPTURE=3,SEND=4,RESPONSE=5;
 reg [2:0] state;
 reg [31:0] seen,job_sequence,job_cycles,elapsed,buffer;
 reg job_bank;
 reg [5:0] index;
 reg [1:0] lane;
 assign feature_address={job_bank,index};
 assign m_axi_awaddr=DDR_ADDRESS+{25'd0,job_bank,6'd0};
 assign m_axi_awlen=15; assign m_axi_awsize=2; assign m_axi_awburst=1;
 assign m_axi_awvalid=state==ADDR;
 assign m_axi_wdata=buffer; assign m_axi_wstrb=15;
 assign m_axi_wvalid=state==SEND; assign m_axi_wlast=index==63;
 assign m_axi_bready=state==RESPONSE;
 always @(posedge clk) begin
  if(!rstn) begin
   state<=IDLE; seen<=0; job_sequence<=0; job_cycles<=0; elapsed<=0; buffer<=0;
   job_bank<=0; index<=0; lane<=0; published_sequence<=0; published_cycles<=0; errors<=0;
  end else begin
   if(state!=IDLE) elapsed<=elapsed+1;
   case(state)
    IDLE: if(source_sequence!=seen) begin
     job_sequence<=source_sequence; job_cycles<=source_cycles; seen<=source_sequence;
     job_bank<=~source_sequence[0]; index<=0; lane<=0; buffer<=0; elapsed<=1; state<=ADDR;
    end
    ADDR: if(m_axi_awready) state<=FETCH;
    FETCH: state<=CAPTURE;
    CAPTURE: begin
     buffer[lane*8+:8]<=feature_data;
     if(lane==3) state<=SEND;
     else begin index<=index+1'b1; lane<=lane+1'b1; state<=FETCH; end
    end
    SEND: if(m_axi_wready) begin
     if(index==63) state<=RESPONSE;
     else begin index<=index+1'b1; lane<=0; buffer<=0; state<=FETCH; end
    end
    RESPONSE: if(m_axi_bvalid) begin
     if(m_axi_bresp!=0 || source_sequence!=job_sequence) errors<=errors+1;
     else begin published_sequence<=job_sequence; published_cycles<=job_cycles+elapsed+1; end
     state<=IDLE;
    end
    default: begin errors<=errors+1; state<=IDLE; end
   endcase
  end
 end
endmodule
