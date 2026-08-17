`timescale 1ns / 1ps

module slot #(
    parameter integer DATA_WIDTH = 32
) (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axis:m_axis, ASSOCIATED_RESET aresetn" *)
    input  wire                  aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                  aresetn,
    input  wire                  soft_reset,

    input  wire [31:0]           cfg0,
    input  wire [31:0]           cfg1,
    input  wire [31:0]           cfg2,
    input  wire [31:0]           cfg3,
    input  wire [31:0]           cfg4,
    input  wire [31:0]           cfg5,
    input  wire [31:0]           cfg6,
    input  wire [31:0]           cfg7,
    output wire [31:0]           status,

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

    wire resetn = aresetn && !soft_reset;

    user #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_user (
        .aclk          (aclk),
        .resetn        (resetn),
        .cfg0          (cfg0),
        .cfg1          (cfg1),
        .cfg2          (cfg2),
        .cfg3          (cfg3),
        .cfg4          (cfg4),
        .cfg5          (cfg5),
        .cfg6          (cfg6),
        .cfg7          (cfg7),
        .status        (status),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast)
    );

endmodule
