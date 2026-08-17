`timescale 1ns / 1ps

module cic_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [15:0] decim_rate,
    input  wire [4:0]  gain_shift,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    reg signed [31:0] int0_0;
    reg signed [31:0] int0_1;
    reg signed [31:0] int0_2;
    reg signed [31:0] int1_0;
    reg signed [31:0] int1_1;
    reg signed [31:0] int1_2;
    reg signed [31:0] comb0_d0;
    reg signed [31:0] comb0_d1;
    reg signed [31:0] comb0_d2;
    reg signed [31:0] comb1_d0;
    reg signed [31:0] comb1_d1;
    reg signed [31:0] comb1_d2;
    reg [15:0] decim_count;
    reg [31:0] out_data;
    reg out_valid;
    reg out_last;

    wire output_ready = !out_valid || m_axis_tready;
    wire fire = s_axis_tvalid && s_axis_tready;
    wire [15:0] decim_safe = (decim_rate == 16'd0) ? 16'd1 : decim_rate;
    wire signed [8:0] x0 = $signed({1'b0, s_axis_tdata[7:0]}) - 9'sd128;
    wire signed [8:0] x1 = $signed({1'b0, s_axis_tdata[23:16]}) - 9'sd128;
    wire decim_last = (decim_count == decim_safe - 16'd1);

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

    assign s_axis_tready = enable ? output_ready : m_axis_tready;
    assign m_axis_tvalid = enable ? out_valid : s_axis_tvalid;
    assign m_axis_tdata  = enable ? out_data : s_axis_tdata;
    assign m_axis_tlast  = enable ? out_last : s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            int0_0 <= 32'sd0;
            int0_1 <= 32'sd0;
            int0_2 <= 32'sd0;
            int1_0 <= 32'sd0;
            int1_1 <= 32'sd0;
            int1_2 <= 32'sd0;
            comb0_d0 <= 32'sd0;
            comb0_d1 <= 32'sd0;
            comb0_d2 <= 32'sd0;
            comb1_d0 <= 32'sd0;
            comb1_d1 <= 32'sd0;
            comb1_d2 <= 32'sd0;
            decim_count <= 16'd0;
            out_data <= 32'd0;
            out_valid <= 1'b0;
            out_last <= 1'b0;
        end else begin
            if (out_valid && m_axis_tready) begin
                out_valid <= 1'b0;
            end

            if (fire && enable) begin
                int0_0 <= int0_0 + {{23{x0[8]}}, x0};
                int0_1 <= int0_1 + int0_0;
                int0_2 <= int0_2 + int0_1;
                int1_0 <= int1_0 + {{23{x1[8]}}, x1};
                int1_1 <= int1_1 + int1_0;
                int1_2 <= int1_2 + int1_1;

                if (decim_last) begin
                    comb0_d0 <= int0_2;
                    comb0_d1 <= int0_2 - comb0_d0;
                    comb0_d2 <= (int0_2 - comb0_d0) - comb0_d1;
                    comb1_d0 <= int1_2;
                    comb1_d1 <= int1_2 - comb1_d0;
                    comb1_d2 <= (int1_2 - comb1_d0) - comb1_d1;
                    out_data <= {
                        8'd0,
                        sat_offset(((int1_2 - comb1_d0) - comb1_d1 - comb1_d2) >>> gain_shift),
                        8'd0,
                        sat_offset(((int0_2 - comb0_d0) - comb0_d1 - comb0_d2) >>> gain_shift)
                    };
                    out_last <= s_axis_tlast;
                    out_valid <= 1'b1;
                    decim_count <= 16'd0;
                end else begin
                    decim_count <= decim_count + 16'd1;
                end
            end
        end
    end

endmodule
