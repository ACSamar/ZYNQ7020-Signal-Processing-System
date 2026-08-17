`timescale 1ns / 1ps

module modem_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [7:0]  threshold,
    input  wire [31:0] window_len,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] demod_status
);

    reg [31:0] count;
    reg [31:0] envelope_sum;
    reg [15:0] zero_cross;
    reg prev_below;
    reg [31:0] envelope_next;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire signed [8:0] x0 = $signed({1'b0, s_axis_tdata[7:0]}) - 9'sd128;
    wire [8:0] abs0 = x0[8] ? (~x0 + 9'd1) : x0;
    wire below = (s_axis_tdata[7:0] < threshold);
    wire rise = prev_below && !below;
    wire [31:0] window_safe = (window_len == 32'd0) ? 32'd1 : window_len;

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            count <= 32'd0;
            envelope_sum <= 32'd0;
            zero_cross <= 16'd0;
            prev_below <= 1'b1;
            demod_status <= 32'd0;
        end else if (!enable) begin
            count <= 32'd0;
            envelope_sum <= 32'd0;
            zero_cross <= 16'd0;
            prev_below <= 1'b1;
        end else if (fire) begin
            prev_below <= below;
            if (rise) begin
                zero_cross <= zero_cross + 16'd1;
            end
            if (count == window_safe - 32'd1) begin
                envelope_next = envelope_sum + {23'd0, abs0};
                demod_status <= {
                    zero_cross + (rise ? 16'd1 : 16'd0),
                    envelope_next[15:0]
                };
                count <= 32'd0;
                envelope_sum <= 32'd0;
                zero_cross <= 16'd0;
            end else begin
                count <= count + 32'd1;
                envelope_sum <= envelope_sum + {23'd0, abs0};
            end
        end
    end

endmodule
