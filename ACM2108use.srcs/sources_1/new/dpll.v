`timescale 1ns / 1ps

module dpll_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [31:0] nominal_step,
    input  wire [7:0]  kp,
    input  wire [7:0]  ki,
    input  wire [7:0]  threshold,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] phase_acc,
    output reg  [31:0] freq_word,
    output reg  [31:0] status
);

    reg prev_below;
    reg signed [31:0] integ;
    wire fire = s_axis_tvalid && s_axis_tready;
    wire [7:0] ch0 = s_axis_tdata[7:0];
    wire rise = prev_below && (ch0 >= threshold);
    wire signed [15:0] phase_error = phase_acc[31:16];
    wire signed [31:0] p_term = $signed({1'b0, kp}) * $signed(phase_error);
    wire signed [31:0] i_term = $signed({1'b0, ki}) * $signed(phase_error);
    wire signed [31:0] correction = (p_term >>> 4) + (integ >>> 8);

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            phase_acc <= 32'd0;
            freq_word <= 32'd0;
            status <= 32'd0;
            prev_below <= 1'b1;
            integ <= 32'sd0;
        end else if (!enable) begin
            phase_acc <= 32'd0;
            freq_word <= nominal_step;
            prev_below <= 1'b1;
        end else if (fire) begin
            phase_acc <= phase_acc + freq_word;
            if (ch0 < threshold) begin
                prev_below <= 1'b1;
            end else begin
                prev_below <= 1'b0;
            end
            if (rise) begin
                integ <= integ - i_term;
                freq_word <= nominal_step - correction;
                phase_acc <= 32'd0;
                status <= {phase_error, freq_word[15:0]};
            end
        end
    end

endmodule
