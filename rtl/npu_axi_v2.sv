`timescale 1ns/1ps
module npu_axi_v2 (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXI, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    input wire s_axi_aclk,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    input wire s_axi_aresetn,
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 17" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input wire [16:0] s_axi_awaddr,
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
    output reg [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output reg s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [16:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output reg [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output reg [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output reg s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire s_axi_rready,
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT" *)
    output wire irq,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    output wire [31:0] m_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)
    output wire [7:0] m_axi_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)
    output wire [2:0] m_axi_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *)
    output wire [1:0] m_axi_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
    output wire m_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
    input wire m_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
    input wire [31:0] m_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
    input wire [1:0] m_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)
    input wire m_axi_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
    input wire m_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
    output wire m_axi_rready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)
    output wire [31:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)
    output wire [7:0] m_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)
    output wire [2:0] m_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *)
    output wire [1:0] m_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output wire m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input wire m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output wire [31:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output wire [3:0] m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)
    output wire m_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output wire m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input wire m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input wire [1:0] m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input wire m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output wire m_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARCACHE" *)
    output wire [3:0] m_axi_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *)
    output wire [3:0] m_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)
    output wire [2:0] m_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
    output wire [2:0] m_axi_awprot
);
    localparam MEM_WORDS=16384, MEM_AW=14, QUEUE_DEPTH=8;
    (* ram_style="block" *) reg [31:0] memory [0:MEM_WORDS-1];
    reg [31:0] staging [0:15];
    reg [31:0] queue [0:127];
    wire [31:0] descriptor [0:15];
    reg [2:0] rdptr, wrptr;
    reg [3:0] queued;
    reg [31:0] control, completed, last_tag, last_error, last_cycles, errors;
    reg irq_pending;
    wire core_busy, core_done;
    wire [31:0] core_error, core_tag, core_cycles;
    wire mem_en, mem_we;
    wire [MEM_AW-1:0] mem_addr;
    wire [31:0] mem_wdata;
    wire compute_busy, compute_done, dma_busy, dma_done;
    wire [31:0] compute_error, compute_tag, compute_cycles;
    wire [31:0] dma_error, dma_words, dma_cycles;
    reg [31:0] dma_tag;
    wire compute_mem_en, compute_mem_we, dma_mem_en, dma_mem_we;
    wire [MEM_AW-1:0] compute_mem_addr, dma_mem_addr;
    wire [31:0] compute_mem_wdata, dma_mem_wdata;
    wire dma_command=descriptor[0][7:0]==8'h10 || descriptor[0][7:0]==8'h11;
    reg bad_dma_descriptor;
    integer reserved_word;
    always @* begin
        bad_dma_descriptor=(descriptor[0]&32'hfffffe00)!=0 || descriptor[2]>=MEM_WORDS ||
                           descriptor[3]==0 || descriptor[3]>MEM_WORDS || descriptor[15]!=0;
        for(reserved_word=4;reserved_word<14;reserved_word=reserved_word+1)
            if(descriptor[reserved_word]!=0) bad_dma_descriptor=1;
    end
    assign core_busy=compute_busy || dma_busy;
    assign core_done=compute_done || dma_done;
    assign core_error=dma_done ? dma_error : compute_error;
    assign core_tag=dma_done ? dma_tag : compute_tag;
    assign core_cycles=dma_done ? dma_cycles : compute_cycles;
    assign mem_en=compute_mem_en || dma_mem_en;
    assign mem_we=dma_mem_en ? dma_mem_we : compute_mem_we;
    assign mem_addr=dma_mem_en ? dma_mem_addr : compute_mem_addr;
    assign mem_wdata=dma_mem_en ? dma_mem_wdata : compute_mem_wdata;
    assign m_axi_arcache=4'b0011; assign m_axi_awcache=4'b0011;
    assign m_axi_arprot=0; assign m_axi_awprot=0;
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) dma_tag<=0;
        else if(dispatch && dma_command) dma_tag<=descriptor[14];
    end





    reg [31:0] mem_rdata;
    reg read_pending;
    reg aw_pending, w_pending;
    reg [16:0] awaddr;
    reg [31:0] wdata;
    reg [3:0] wstrb;
    integer i, lane;
    wire write_fire=aw_pending && w_pending && !s_axi_bvalid;
    wire submit=write_fire && awaddr==17'h10 && wstrb==4'hf && wdata==1 && queued<QUEUE_DEPTH;
    wire dispatch=control[0] && queued!=0 && !core_busy && !core_done;
    wire memory_locked=core_busy || queued!=0 || submit;
    assign irq=control[1] && irq_pending;
    assign s_axi_awready=!aw_pending && !s_axi_bvalid;
    assign s_axi_wready=!w_pending && !s_axi_bvalid;
    // Serialize CPU RAM reads against writes on the shared synchronous RAM port.
    assign s_axi_arready=!s_axi_rvalid && !read_pending && !(write_fire && awaddr[16]);
    wire cpu_write=s_axi_aresetn && write_fire && awaddr[16] && awaddr[1:0]==0 && !memory_locked;
    wire cpu_read=s_axi_aresetn && s_axi_arvalid && s_axi_arready &&
                  s_axi_araddr[16] && s_axi_araddr[1:0]==0 && !memory_locked;
    wire ram_en=mem_en || cpu_write || cpu_read;
    wire [MEM_AW-1:0] ram_addr=mem_en ? mem_addr : cpu_write ? awaddr[15:2] : s_axi_araddr[15:2];
    wire [31:0] ram_wdata=mem_en ? mem_wdata : wdata;
    wire [3:0] ram_we=mem_en ? {4{mem_we}} : cpu_write ? wstrb : 4'b0;
    genvar g;
    generate for (g=0;g<16;g=g+1) begin : descriptor_mux
        assign descriptor[g]=queue[{rdptr,4'b0}+g];
    end endgenerate
    npu_compute #(.MEM_WORDS(MEM_WORDS),.MEM_AW(MEM_AW)) compute (
        .clk(s_axi_aclk),.rstn(s_axi_aresetn),.start(dispatch && !dma_command),.descriptor(descriptor),
        .busy(compute_busy),.done(compute_done),.error(compute_error),.tag(compute_tag),.cycles(compute_cycles),
        .mem_en(compute_mem_en),.mem_we(compute_mem_we),.mem_addr(compute_mem_addr),.mem_wdata(compute_mem_wdata),.mem_rdata(mem_rdata)
    );

    npu_dma #(.MEM_WORDS(MEM_WORDS),.MEM_AW(MEM_AW)) dma (
        .clk(s_axi_aclk),.rstn(s_axi_aresetn),.start(dispatch && dma_command),
        .direction(descriptor[0][0]),.packed_int8(descriptor[0][8]),
        .ddr_address(descriptor[1]),.scratch_base(descriptor[2][15:0]),
        .element_count(bad_dma_descriptor ? 16'd0 : descriptor[3][15:0]),
        .busy(dma_busy),.done(dma_done),.error(dma_error),.words_done(dma_words),.cycles(dma_cycles),
        .mem_en(dma_mem_en),.mem_we(dma_mem_we),.mem_addr(dma_mem_addr),
        .mem_wdata(dma_mem_wdata),.mem_rdata(mem_rdata),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
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
    // Single synchronous byte-write RAM port. Contents are deliberately not reset.
    // CPU access is excluded while work is queued/executing.
    always @(posedge s_axi_aclk) begin
        if (ram_en) begin
            mem_rdata<=memory[ram_addr];
            for (lane=0;lane<4;lane=lane+1)
                if (ram_we[lane]) memory[ram_addr][lane*8+:8]<=ram_wdata[lane*8+:8];
        end
    end
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            aw_pending<=0; w_pending<=0; awaddr<=0; wdata<=0; wstrb<=0;
            s_axi_bvalid<=0; s_axi_bresp<=0;
            s_axi_rvalid<=0; s_axi_rdata<=0; s_axi_rresp<=0;
            read_pending<=0;
            rdptr<=0; wrptr<=0; queued<=0; control<=0;
            completed<=0; last_tag<=0; last_error<=0; last_cycles<=0; errors<=0; irq_pending<=0;
            for (i=0;i<16;i=i+1) staging[i]<=0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin awaddr<=s_axi_awaddr; aw_pending<=1; end
            if (s_axi_wvalid && s_axi_wready) begin wdata<=s_axi_wdata; wstrb<=s_axi_wstrb; w_pending<=1; end
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
            if (s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
            if (read_pending) begin
                read_pending<=0; s_axi_rvalid<=1; s_axi_rdata<=mem_rdata;
            end
            case ({submit,dispatch})
                2'b10: queued<=queued+1;
                2'b01: queued<=queued-1;
                default: begin end
            endcase
            if (dispatch) rdptr<=rdptr+1;
            if (submit) begin
                for (i=0;i<16;i=i+1) queue[{wrptr,4'b0}+i]<=staging[i];
                wrptr<=wrptr+1;
            end
            if (write_fire) begin
                aw_pending<=0; w_pending<=0; s_axi_bvalid<=1; s_axi_bresp<=0;
                if (awaddr[1:0]!=0) s_axi_bresp<=2;
                else if (awaddr[16]) begin
                    if (memory_locked) s_axi_bresp<=2;
                end else if (awaddr>=17'h100 && awaddr<17'h140) begin
                    for (i=0;i<4;i=i+1)
                        if (wstrb[i]) staging[awaddr[5:2]][i*8+:8]<=wdata[i*8+:8];
                end else if (awaddr==4 && wstrb==4'hf && (wdata & 32'hfffffffc)==0) control<=wdata;
                else if (awaddr==17'h10) begin
                    if (!submit) s_axi_bresp<=2;
                end else if (awaddr==17'h28 && wstrb==4'hf && wdata==1) irq_pending<=0;
                else s_axi_bresp<=2;
            end
            if (core_done) begin
                completed<=completed+1; last_tag<=core_tag; last_error<=core_error;
                last_cycles<=core_cycles; irq_pending<=1;
                if (core_error!=0) errors<=errors+1;
            end
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid<=1; s_axi_rresp<=0; s_axi_rdata<=0;
                if (s_axi_araddr[1:0]!=0) s_axi_rresp<=2;
                else if (s_axi_araddr[16]) begin
                    if (memory_locked) s_axi_rresp<=2;
                    else begin read_pending<=1; s_axi_rvalid<=0; end
                end else if (s_axi_araddr>=17'h100 && s_axi_araddr<17'h140)
                    s_axi_rdata<=staging[s_axi_araddr[5:2]];
                else case (s_axi_araddr)
                    0: s_axi_rdata<=32'h4e505532;
                    4: s_axi_rdata<=control;
                    8: s_axi_rdata<={27'd0,irq_pending,(queued==0),(last_error!=0),(queued==QUEUE_DEPTH),core_busy};
                    12: s_axi_rdata<=completed;
                    20: s_axi_rdata<=last_tag;
                    24: s_axi_rdata<=last_error;
                    28: s_axi_rdata<=last_cycles;
                    32: s_axi_rdata<=errors;
                    36: s_axi_rdata<={28'd0,queued};
                    40: s_axi_rdata<={31'd0,irq_pending};
                    44: s_axi_rdata<=MEM_WORDS;
                    48: s_axi_rdata<=100000000;
                    default: s_axi_rresp<=2;
                endcase
            end
        end
    end
endmodule

