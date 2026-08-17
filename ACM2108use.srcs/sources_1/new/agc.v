`timescale 1ns / 1ps

module agc_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [7:0]  target_amp,
    input  wire [7:0]  decay,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] status
);

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire signed [8:0] x0 = $signed({1'b0, s_axis_tdata[7:0]}) - 9'sd128;
    wire signed [8:0] x1 = $signed({1'b0, s_axis_tdata[23:16]}) - 9'sd128;
    wire [8:0] abs0 = x0[8] ? (~x0 + 9'd1) : x0;
    wire [8:0] abs1 = x1[8] ? (~x1 + 9'd1) : x1;
    reg [8:0] peak0;
    reg [8:0] peak1;
    wire [15:0] gain0 = (peak0 == 9'd0) ? 16'd128 : (({8'd0, target_amp} << 7) / peak0);
    wire [15:0] gain1 = (peak1 == 9'd0) ? 16'd128 : (({8'd0, target_amp} << 7) / peak1);
    wire signed [24:0] y0_full = $signed(x0) * $signed({1'b0, gain0});
    wire signed [24:0] y1_full = $signed(x1) * $signed({1'b0, gain1});
    wire signed [15:0] y0 = y0_full >>> 7;
    wire signed [15:0] y1 = y1_full >>> 7;

    function [7:0] sat_offset;
        input signed [15:0] value;
        reg signed [16:0] shifted;
        begin
            shifted = value + 17'sd128;
            if (shifted < 0) begin
                sat_offset = 8'd0;
            end else if (shifted > 17'sd255) begin
                sat_offset = 8'hff;
            end else begin
                sat_offset = shifted[7:0];
            end
        end
    endfunction

    assign m_axis_tdata = enable ? {8'd0, sat_offset(y1), 8'd0, sat_offset(y0)} : s_axis_tdata;

    always @(posedge aclk) begin
        if (!aresetn) begin
            peak0 <= 9'd1;
            peak1 <= 9'd1;
            status <= 32'd0;
        end else if (fire && enable) begin
            if (abs0 > peak0) begin
                peak0 <= abs0;
            end else if (peak0 > {1'b0, decay}) begin
                peak0 <= peak0 - {1'b0, decay};
            end

            if (abs1 > peak1) begin
                peak1 <= abs1;
            end else if (peak1 > {1'b0, decay}) begin
                peak1 <= peak1 - {1'b0, decay};
            end

            status <= {7'd0, peak1, 7'd0, peak0};
        end
    end

endmodule
