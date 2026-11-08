`timescale 1ns/1ps
module npu_video_ddr (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXI, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    input wire s_axi_aclk,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    input wire s_axi_aresetn,
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input wire [11:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input wire [2:0] s_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input wire s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input wire [3:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input wire s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [11:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire s_axi_rready,
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT" *)
    output wire irq,
    input wire [23:0] pixel_data,
    input wire pixel_valid,pixel_ready,pixel_sof,pixel_eol,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)
    output wire [31:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)
    output wire [7:0] m_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)
    output wire [2:0] m_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *)
    output wire [1:0] m_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output wire  m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input wire  m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output wire [31:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output wire [3:0] m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)
    output wire  m_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output wire  m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input wire  m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input wire [1:0] m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input wire  m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output wire  m_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *)
    output wire [3:0] m_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
    output wire [2:0] m_axi_awprot
);
    reg [31:0] control,ack_sequence,overruns,observed_sequence;
    
    wire [31:0] frame_sequence,frames_started,frame_errors,last_pixels,frame_cycles;
    wire [31:0] source_sequence,source_cycles,source_errors,writer_errors;
    wire [6:0] dma_feature_address; wire [7:0] dma_feature_data;
    assign frame_errors=source_errors+writer_errors;
    assign m_axi_awcache=4'b0011; assign m_axi_awprot=0;

    wire [6:0] feature_address=(s_axi_araddr-12'h100)>>2;
    wire [7:0] feature_data;
    reg aw_pending,w_pending,read_pending;
    reg [11:0] address;
    reg [31:0] write_data;
    reg [3:0] strobes;
    reg bvalid,rvalid;
    reg [1:0] bresp,rresp;
    reg [31:0] rdata;
    wire write_fire=aw_pending && w_pending && !bvalid;
    assign s_axi_awready=!aw_pending && !bvalid;
    assign s_axi_wready=!w_pending && !bvalid;
    assign s_axi_arready=!rvalid && !read_pending;
    assign s_axi_bvalid=bvalid; assign s_axi_bresp=bresp;
    assign s_axi_rvalid=rvalid; assign s_axi_rresp=rresp; assign s_axi_rdata=rdata;
    assign irq=0;
    npu_frame_preprocess preprocess (
        .clk(s_axi_aclk),.rstn(s_axi_aresetn),
        .pixel_data(pixel_data),.pixel_valid(pixel_valid),.pixel_ready(pixel_ready),
        .pixel_sof(pixel_sof),.pixel_eol(pixel_eol),.invert(control[0]),
        .frame_sequence(source_sequence),.frames_started(frames_started),
        .frame_errors(source_errors),.last_pixels(last_pixels),.frame_cycles(source_cycles),
        .feature_address(feature_address),.feature_data(feature_data),
        .dma_feature_address(dma_feature_address),.dma_feature_data(dma_feature_data)
    );

    npu_feature_writer writer (
        .clk(s_axi_aclk),.rstn(s_axi_aresetn),.source_sequence(source_sequence),.source_cycles(source_cycles),
        .published_sequence(frame_sequence),.published_cycles(frame_cycles),.errors(writer_errors),
        .feature_address(dma_feature_address),.feature_data(dma_feature_data),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready)
    );
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin
            control<=1; ack_sequence<=0; overruns<=0; observed_sequence<=0;
            aw_pending<=0; w_pending<=0; read_pending<=0;
            address<=0; write_data<=0; strobes<=0;
            bvalid<=0; bresp<=0; rvalid<=0; rresp<=0; rdata<=0;
        end else begin
            if(frame_sequence!=observed_sequence) begin
                observed_sequence<=frame_sequence;
                if(frame_sequence-ack_sequence>2) overruns<=overruns+1;
            end
            if(s_axi_awvalid && s_axi_awready) begin aw_pending<=1; address<=s_axi_awaddr; end
            if(s_axi_wvalid && s_axi_wready) begin w_pending<=1; write_data<=s_axi_wdata; strobes<=s_axi_wstrb; end
            if(bvalid && s_axi_bready) bvalid<=0;
            if(rvalid && s_axi_rready) rvalid<=0;
            if(write_fire) begin
                aw_pending<=0; w_pending<=0; bvalid<=1; bresp<=0;
                if(address==12'h14 && strobes==15 && (write_data&32'hfffffffe)==0) control<=write_data;
                else if(address==12'h18 && strobes==15 && frame_sequence-write_data<32'h80000000) ack_sequence<=write_data;
                else bresp<=2;
            end
            if(read_pending) begin read_pending<=0; rvalid<=1; rdata<={24'd0,feature_data}; end
            if(s_axi_arvalid && s_axi_arready) begin
                rvalid<=1; rresp<=0; rdata<=0;
                if(s_axi_araddr[1:0]!=0) rresp<=2;
                else if(s_axi_araddr>=12'h100 && s_axi_araddr<12'h300) begin
                    rvalid<=0; read_pending<=1;
                end else case(s_axi_araddr)
                    0: rdata<=32'h50524532;
                    4: rdata<=frame_sequence;
                    8: rdata<=last_pixels;
                    12: rdata<=frame_errors;
                    16: rdata<=frames_started;
                    20: rdata<=control;
                    24: rdata<=ack_sequence;
                    28: rdata<=overruns;
                    36: rdata<=frame_cycles;
                    40: rdata<=32'h04000000;
                    44: rdata<=writer_errors;
                    48: rdata<=source_sequence;
                    32: rdata<={31'd0,frame_sequence!=ack_sequence};
                    default: rresp<=2;
                endcase
            end
        end
    end
endmodule
