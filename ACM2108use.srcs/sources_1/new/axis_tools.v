`timescale 1ns / 1ps

module axis_reg_slice #(
    parameter integer DATA_WIDTH = 32
) (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axis:m_axis, ASSOCIATED_RESET aresetn" *)
    input  wire                  aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                  aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input  wire                  s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output wire                  s_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TLAST" *)
    input  wire                  s_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output wire                  m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input  wire                  m_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TLAST" *)
    output wire                  m_axis_tlast
);

    reg [DATA_WIDTH-1:0] data_r;
    reg                  valid_r;
    reg                  last_r;

    assign s_axis_tready = !valid_r || m_axis_tready;
    assign m_axis_tdata  = data_r;
    assign m_axis_tvalid = valid_r;
    assign m_axis_tlast  = last_r;

    always @(posedge aclk) begin
        if (!aresetn) begin
            data_r  <= {DATA_WIDTH{1'b0}};
            valid_r <= 1'b0;
            last_r  <= 1'b0;
        end else if (s_axis_tready) begin
            data_r  <= s_axis_tdata;
            valid_r <= s_axis_tvalid;
            last_r  <= s_axis_tlast;
        end
    end

endmodule

module axis_broadcast2 #(
    parameter integer DATA_WIDTH = 32
) (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axis:m0_axis:m1_axis, ASSOCIATED_RESET aresetn" *)
    input  wire                  aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                  aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input  wire                  s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output wire                  s_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TLAST" *)
    input  wire                  s_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m0_axis TDATA" *)
    output wire [DATA_WIDTH-1:0] m0_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m0_axis TVALID" *)
    output wire                  m0_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m0_axis TREADY" *)
    input  wire                  m0_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m0_axis TLAST" *)
    output wire                  m0_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m1_axis TDATA" *)
    output wire [DATA_WIDTH-1:0] m1_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m1_axis TVALID" *)
    output wire                  m1_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m1_axis TREADY" *)
    input  wire                  m1_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m1_axis TLAST" *)
    output wire                  m1_axis_tlast
);

    wire both_ready = m0_axis_tready && m1_axis_tready;

    assign s_axis_tready  = both_ready;
    assign m0_axis_tdata  = s_axis_tdata;
    assign m1_axis_tdata  = s_axis_tdata;
    assign m0_axis_tvalid = s_axis_tvalid && m1_axis_tready;
    assign m1_axis_tvalid = s_axis_tvalid && m0_axis_tready;
    assign m0_axis_tlast  = s_axis_tlast;
    assign m1_axis_tlast  = s_axis_tlast;

    wire unused_clk = aclk;
    wire unused_rst = aresetn;

endmodule

module axis_mux2 #(
    parameter integer DATA_WIDTH = 32
) (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s0_axis:s1_axis:m_axis, ASSOCIATED_RESET aresetn" *)
    input  wire                  aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                  aresetn,
    input  wire                  sel,
    input  wire                  sel_load,
    input  wire                  sel_on_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TDATA" *)
    input  wire [DATA_WIDTH-1:0] s0_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TVALID" *)
    input  wire                  s0_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TREADY" *)
    output wire                  s0_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TLAST" *)
    input  wire                  s0_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TDATA" *)
    input  wire [DATA_WIDTH-1:0] s1_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TVALID" *)
    input  wire                  s1_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TREADY" *)
    output wire                  s1_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TLAST" *)
    input  wire                  s1_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output wire                  m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input  wire                  m_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TLAST" *)
    output wire                  m_axis_tlast,
    output wire                  active_sel
);

    reg sel_r;
    reg pending_sel;
    reg pending_valid;

    wire active_last = sel_r ? s1_axis_tlast : s0_axis_tlast;
    wire active_valid = sel_r ? s1_axis_tvalid : s0_axis_tvalid;
    wire fire = active_valid && m_axis_tready;
    wire safe_point = !sel_on_tlast || (fire && active_last);

    assign active_sel = sel_r;
    assign s0_axis_tready = (!sel_r) ? m_axis_tready : 1'b0;
    assign s1_axis_tready = sel_r ? m_axis_tready : 1'b0;
    assign m_axis_tdata   = sel_r ? s1_axis_tdata : s0_axis_tdata;
    assign m_axis_tvalid  = active_valid;
    assign m_axis_tlast   = active_last;

    always @(posedge aclk) begin
        if (!aresetn) begin
            sel_r          <= 1'b0;
            pending_sel    <= 1'b0;
            pending_valid  <= 1'b0;
        end else begin
            if (sel_load) begin
                pending_sel   <= sel;
                pending_valid  <= 1'b1;
            end

            if (pending_valid && safe_point) begin
                sel_r         <= pending_sel;
                pending_valid <= sel_load;
            end
        end
    end

endmodule

module axis_switch2 #(
    parameter integer DATA_WIDTH = 32
) (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s0_axis:s1_axis:m_axis, ASSOCIATED_RESET aresetn" *)
    input  wire                  aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                  aresetn,
    input  wire                  sel,
    input  wire                  sel_load,
    input  wire                  sel_on_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TDATA" *)
    input  wire [DATA_WIDTH-1:0] s0_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TVALID" *)
    input  wire                  s0_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TREADY" *)
    output wire                  s0_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s0_axis TLAST" *)
    input  wire                  s0_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TDATA" *)
    input  wire [DATA_WIDTH-1:0] s1_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TVALID" *)
    input  wire                  s1_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TREADY" *)
    output wire                  s1_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s1_axis TLAST" *)
    input  wire                  s1_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output wire                  m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input  wire                  m_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TLAST" *)
    output wire                  m_axis_tlast,
    output wire                  active_sel
);

    axis_mux2 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_axis_mux2 (
        .aclk(aclk),
        .aresetn(aresetn),
        .sel(sel),
        .sel_load(sel_load),
        .sel_on_tlast(sel_on_tlast),
        .s0_axis_tdata(s0_axis_tdata),
        .s0_axis_tvalid(s0_axis_tvalid),
        .s0_axis_tready(s0_axis_tready),
        .s0_axis_tlast(s0_axis_tlast),
        .s1_axis_tdata(s1_axis_tdata),
        .s1_axis_tvalid(s1_axis_tvalid),
        .s1_axis_tready(s1_axis_tready),
        .s1_axis_tlast(s1_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .active_sel(active_sel)
    );

endmodule
