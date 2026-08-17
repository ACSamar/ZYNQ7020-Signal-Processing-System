`timescale 1ns / 1ps

module selftest_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire        generator_mode,
    input  wire [31:0] frame_len,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] error_count,
    output reg  [31:0] sample_count
);

    reg [7:0] pattern;
    wire [31:0] frame_safe = (frame_len == 32'd0) ? 32'd1 : frame_len;
    wire gen_fire = generator_mode && m_axis_tvalid && m_axis_tready;
    wire chk_fire = !generator_mode && s_axis_tvalid && s_axis_tready;
    wire [31:0] expected = {8'd0, pattern + 8'd1, 8'd0, pattern};

    assign s_axis_tready = generator_mode ? 1'b0 : m_axis_tready;
    assign m_axis_tvalid = generator_mode ? enable : s_axis_tvalid;
    assign m_axis_tdata  = generator_mode ? expected : s_axis_tdata;
    assign m_axis_tlast  = generator_mode ? (sample_count == frame_safe - 32'd1) : s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn || !enable) begin
            pattern <= 8'd0;
            error_count <= 32'd0;
            sample_count <= 32'd0;
        end else if (gen_fire) begin
            pattern <= pattern + 8'd2;
            if (m_axis_tlast) begin
                sample_count <= 32'd0;
            end else begin
                sample_count <= sample_count + 32'd1;
            end
        end else if (chk_fire) begin
            if (s_axis_tdata[7:0] != pattern) begin
                error_count <= error_count + 32'd1;
            end
            pattern <= pattern + 8'd1;
            sample_count <= sample_count + 32'd1;
        end
    end

endmodule
