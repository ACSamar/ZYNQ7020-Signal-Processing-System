`timescale 1ns / 1ps

module calibrate_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire signed [15:0] ch0_offset,
    input  wire signed [15:0] ch1_offset,
    input  wire signed [15:0] ch0_gain,
    input  wire signed [15:0] ch1_gain,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    wire signed [15:0] x0 = $signed({1'b0, s_axis_tdata[7:0]}) - 16'sd128 + ch0_offset;
    wire signed [15:0] x1 = $signed({1'b0, s_axis_tdata[23:16]}) - 16'sd128 + ch1_offset;
    wire signed [31:0] y0 = ($signed(x0) * $signed(ch0_gain)) >>> 8;
    wire signed [31:0] y1 = ($signed(x1) * $signed(ch1_gain)) >>> 8;

    function [7:0] sat_offset;
        input signed [31:0] value;
        reg signed [32:0] shifted;
        begin
            shifted = value + 33'sd128;
            if (shifted < 0) begin
                sat_offset = 8'd0;
            end else if (shifted > 33'sd255) begin
                sat_offset = 8'hff;
            end else begin
                sat_offset = shifted[7:0];
            end
        end
    endfunction

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;
    assign m_axis_tdata  = enable ? {8'd0, sat_offset(y1), 8'd0, sat_offset(y0)} : s_axis_tdata;

endmodule
