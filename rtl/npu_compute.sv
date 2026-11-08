`timescale 1ns/1ps
// Scalar reference implementation. One shared signed MAC; geometry is runtime configurable.
// Memory reads return registered data one cycle after a request. No DDR master is implied.
module npu_compute #(
    parameter integer MEM_WORDS = 16384,
    parameter integer MEM_AW = 14
)(
    input wire clk, input wire rstn, input wire start,
    input wire [31:0] descriptor [0:15],
    output reg busy, output reg done, output reg [31:0] error,
    output reg [31:0] tag, output reg [31:0] cycles,
    output reg mem_en, output reg mem_we,
    output reg [MEM_AW-1:0] mem_addr,
    output reg [31:0] mem_wdata, input wire [31:0] mem_rdata
);
    localparam IDLE=0, CHECK=1, INIT=2, BREQ=3, BGET=4,
               XREQ=5, XGET=6, WREQ=7, WGET=8, MAC=9,
               KSTEP=10, STORE=11, NEXT=12, FINISH=13, GEO=14, ROW=15, ADDR=16, CNT1=17, CNT2=18, CNT3=19, SPAN=20;
    reg [4:0] state;
    reg [31:0] d [0:15];
    integer i;
    reg [8:0] ox, oy, oc, ic;
    reg [2:0] kx,ky;
    reg [8:0] out_w, out_h, out_c;
    reg [9:0] calc_w,calc_h,calc_c;
    integer src_count,dst_count,weight_count;
    reg signed [10:0] px,py;
    reg [MEM_AW-1:0] src_index,weight_index,dst_index;
    reg bad_shape, bad_range;
    reg [MEM_AW-1:0] src_row,weight_row,dst_row;
    reg [11:0] weight_kernel;
    reg [17:0] src_plane,dst_plane;
    reg [5:0] kernel_plane;
    reg [14:0] weight_channels;
    reg [26:0] src_span,dst_span,weight_span;
    reg signed [31:0] acc;
    reg signed [7:0] x, weight, peak;
    wire [7:0] opcode = d[0][7:0];
    wire is_conv = opcode == 1;
    wire is_relu = opcode == 2;
    wire is_pool = opcode == 3;
    wire has_bias = d[4] != 32'hffffffff;
    wire fused_relu = d[0][8];
    wire signed [15:0] product = x * $signed(mem_rdata[7:0]);
    reg signed [31:0] shifted;
    reg signed [7:0] result;

    function automatic valid_span(input [31:0] base, input integer count);
        valid_span = (count > 0) && (count <= MEM_WORDS) &&
                     (base < MEM_WORDS) && (base <= MEM_WORDS-count);
    endfunction
    function automatic overlap(input [31:0] a, input integer na,
                               input [31:0] b, input integer nb);
        overlap = (a < b+nb) && (b < a+na);
    endfunction
    always @* begin
        calc_w=0; calc_h=0; calc_c=0;
        src_count=0; dst_count=0; weight_count=0;
        bad_shape=0; bad_range=0;
        if (!(is_conv || is_relu || is_pool) || (d[0] & 32'hfffffefc) != 0 ||
            d[15] != 0 || d[5]<1 || d[5]>256 || d[6]<1 || d[6]>256 ||
            d[7]<1 || d[7]>256 || d[13]>31)
            bad_shape=1;
        if (is_relu) begin
            calc_w=d[5]; calc_h=d[6]; calc_c=d[7];
            if (d[13] != 0) bad_shape=1;
        end else begin
            if (d[9]<1 || d[9]>7 || d[10]<1 || d[10]>7 || d[12]>3 ||
                !(d[11]==1 || d[11]==2 || d[11]==4) ||
                d[5]+2*d[12]<d[9] || d[6]+2*d[12]<d[10]) bad_shape=1;
            calc_w=((d[5]+2*d[12]-d[9]) >> (d[11]==4 ? 2 : d[11]==2 ? 1 : 0))+1;
            calc_h=((d[6]+2*d[12]-d[10]) >> (d[11]==4 ? 2 : d[11]==2 ? 1 : 0))+1;
            calc_c=is_conv ? d[8] : d[7];
            if (is_conv && (d[8]<1 || d[8]>256)) bad_shape=1;
            if (is_pool && d[13] != 0) bad_shape=1;
        end
        // Products are bounded before use, including for malformed descriptors.
        if (!bad_shape) begin
            src_count=src_span;
            dst_count=dst_span;
            weight_count=weight_span;
            if (!valid_span(d[1],src_count) || !valid_span(d[2],dst_count) ||
                overlap(d[1],src_count,d[2],dst_count)) bad_range=1;
            if (is_conv && (!valid_span(d[3],weight_count) ||
                overlap(d[3],weight_count,d[2],dst_count))) bad_range=1;
            if (is_conv && has_bias && (!valid_span(d[4],d[8]) ||
                overlap(d[4],d[8],d[2],dst_count))) bad_range=1;
        end
    end
    always @* begin
        mem_en=0; mem_we=0; mem_addr=0; mem_wdata=0;
        shifted=acc >>> d[13][4:0];
        if (fused_relu && shifted<0) shifted=0;
        if (shifted>127) result=127;
        else if (shifted < -128) result=-128;
        else result=shifted[7:0];
        if (is_relu) result=x[7] ? 8'sd0 : x;
        if (is_pool) result=peak;
        case (state)
            BREQ: begin mem_en=1; mem_addr=d[4]+oc; end
            XREQ: begin
                if (is_relu || (px>=0 && px<d[5] && py>=0 && py<d[6])) begin
                    mem_en=1; mem_addr=src_index;
                end
            end
            XGET: if(is_conv) begin mem_en=1; mem_addr=weight_index; end
            WREQ: begin mem_en=1; mem_addr=weight_index; end
            STORE: begin
                mem_en=1; mem_we=1; mem_addr=dst_index;
                mem_wdata={{24{result[7]}},result};
            end
            default: begin end
        endcase
    end
    always @(posedge clk) begin
        if (!rstn) begin
            state<=IDLE; busy<=0; done<=0; error<=0; tag<=0; cycles<=0;
            ox<=0; oy<=0; oc<=0; kx<=0; ky<=0; ic<=0;
            out_w<=0; out_h<=0; out_c<=0; acc<=0; x<=0; weight<=0; peak<=-128;
            px<=0; py<=0; src_row<=0; weight_row<=0; dst_row<=0; weight_kernel<=0;
            src_index<=0; weight_index<=0; dst_index<=0; src_plane<=0; dst_plane<=0;
            kernel_plane<=0; weight_channels<=0; src_span<=0; dst_span<=0; weight_span<=0;
            for (i=0;i<16;i=i+1) d[i]<=0;
        end else begin
            done<=0;
            if (busy) cycles<=cycles+1;
            case (state)
                IDLE: if (start) begin
                    for (i=0;i<16;i=i+1) d[i]<=descriptor[i];
                    busy<=1; error<=0; cycles<=0; tag<=descriptor[14]; state<=CHECK;
                end
                CHECK: begin
                    if (bad_shape) begin
                        error<=1; state<=FINISH;
                    end else begin
                        out_w<=calc_w; out_h<=calc_h; out_c<=calc_c;
                        ox<=0; oy<=0; oc<=0; state<=CNT1;
                    end
                end
                CNT1: begin
                    src_plane<=d[5][8:0]*d[6][8:0]; dst_plane<=out_w*out_h;
                    kernel_plane<=d[9][2:0]*d[10][2:0]; state<=CNT2;
                end
                CNT2: begin
                    src_span<=src_plane*d[7][8:0]; dst_span<=dst_plane*out_c;
                    weight_channels<=kernel_plane*d[7][8:0]; state<=CNT3;
                end
                CNT3: begin weight_span<=weight_channels*d[8][8:0]; state<=SPAN; end
                SPAN: if(bad_range) begin error<=2; state<=FINISH; end else state<=INIT;
                GEO: begin
                    px<=(d[11]==4 ? (ox<<2) : d[11]==2 ? (ox<<1) : ox)+kx-d[12][1:0];
                    py<=(d[11]==4 ? (oy<<2) : d[11]==2 ? (oy<<1) : oy)+ky-d[12][1:0];
                    weight_kernel<=oc*d[10][2:0]+ky; state<=ROW;
                end
                ROW: begin
                    src_row<=py*d[5][8:0]+px; weight_row<=weight_kernel*d[9][2:0]+kx;
                    dst_row<=oy*out_w+ox; state<=ADDR;
                end
                ADDR: begin
                    src_index<=is_relu ? d[1]+dst_row*out_c+oc : d[1]+src_row*d[7][8:0]+(is_pool ? oc : ic);
                    weight_index<=d[3]+weight_row*d[7][8:0]+ic;
                    dst_index<=d[2]+dst_row*out_c+oc; state<=XREQ;
                end
                INIT: begin
                    acc<=0; peak<=-128; kx<=0; ky<=0; ic<=0;
                    state<=(is_conv && has_bias) ? BREQ : GEO;
                end
                BREQ: state<=BGET;
                BGET: begin acc<=$signed(mem_rdata); state<=GEO; end
                XREQ: begin
                    if (!is_relu && (px<0 || px>=d[5] || py<0 || py>=d[6])) state<=KSTEP;
                    else state<=XGET;
                end
                XGET: begin
                    x<=mem_rdata[7:0];
                    if (is_pool) begin
                        if ($signed(mem_rdata[7:0])>peak) peak<=$signed(mem_rdata[7:0]);
                        state<=KSTEP;
                    end else state<=is_relu ? STORE : WGET;
                end
                WREQ: state<=WGET;
                WGET: begin
                    acc<=acc+{{16{product[15]}},product};
                    if (is_conv && ic+1<d[7]) begin ic<=ic+1; state<=GEO; end
                    else begin
                        ic<=0;
                        if (kx+1<d[9]) begin kx<=kx+1; state<=GEO; end
                        else begin
                            kx<=0;
                            if (ky+1<d[10]) begin ky<=ky+1; state<=GEO; end
                            else state<=STORE;
                        end
                    end
                end
                MAC: begin acc<=acc+{{16{product[15]}},product}; state<=KSTEP; end
                KSTEP: begin
                    if (is_conv && ic+1<d[7]) begin ic<=ic+1; state<=GEO; end
                    else begin
                        ic<=0;
                        if (kx+1<d[9]) begin kx<=kx+1; state<=GEO; end
                        else begin
                            kx<=0;
                            if (ky+1<d[10]) begin ky<=ky+1; state<=GEO; end
                            else state<=STORE;
                        end
                    end
                end
                STORE: state<=NEXT;
                NEXT: begin
                    if (oc+1<out_c) begin oc<=oc+1; state<=INIT; end
                    else begin
                        oc<=0;
                        if (ox+1<out_w) begin ox<=ox+1; state<=INIT; end
                        else begin
                            ox<=0;
                            if (oy+1<out_h) begin oy<=oy+1; state<=INIT; end
                            else state<=FINISH;
                        end
                    end
                end
                FINISH: begin busy<=0; done<=1; state<=IDLE; end
                default: begin error<=3; state<=FINISH; end
            endcase
        end
    end
endmodule


