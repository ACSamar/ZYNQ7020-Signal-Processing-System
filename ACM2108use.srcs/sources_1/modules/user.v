`timescale 1ns / 1ps

// Replace the logic inside this module when adding a new stream algorithm.
// Keep the module name and ports unchanged so the Block Design stays reusable.
module user #(
    parameter integer DATA_WIDTH = 32
) (
    input  wire                  aclk,
    input  wire                  resetn,

    input  wire [31:0]           cfg0,
    input  wire [31:0]           cfg1,
    input  wire [31:0]           cfg2,
    input  wire [31:0]           cfg3,
    input  wire [31:0]           cfg4,
    input  wire [31:0]           cfg5,
    input  wire [31:0]           cfg6,
    input  wire [31:0]           cfg7,
    output wire [31:0]           status,

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast
);

    // Safe default implementation: lossless AXI Stream pass-through.
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    // "USER" identifies the default module through the shell status register.
    assign status = 32'h5553_4552;

endmodule
