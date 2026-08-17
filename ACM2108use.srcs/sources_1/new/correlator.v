`timescale 1ns / 1ps

(* use_dsp = "no" *)
module correlator_axis #(
    parameter integer TAPS = 16
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire        coeff_we,
    input  wire [3:0]  coeff_addr,
    input  wire [15:0] coeff_data,
    input  wire [31:0] threshold,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] corr_value,
    output reg  [31:0] corr_peak,
    output reg  [31:0] status
);

    reg signed [8:0] delay [0:TAPS-1];
    reg signed [15:0] coeff [0:TAPS-1];
    (* use_dsp = "no" *) reg signed [39:0] acc;
    integer i;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire signed [8:0] x0 = $signed({1'b0, s_axis_tdata[7:0]}) - 9'sd128;
    wire [31:0] abs_corr = corr_value[31] ? (~corr_value + 32'd1) : corr_value;

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            for (i = 0; i < TAPS; i = i + 1) begin
                delay[i] <= 9'sd0;
                coeff[i] <= 16'sd0;
            end
            corr_value <= 32'd0;
            corr_peak <= 32'd0;
            status <= 32'd0;
        end else begin
            if (coeff_we) begin
                coeff[coeff_addr] <= coeff_data;
            end
            if (fire && enable) begin
                for (i = TAPS - 1; i > 0; i = i - 1) begin
                    delay[i] <= delay[i - 1];
                end
                delay[0] <= x0;
                acc = 40'sd0;
                for (i = 0; i < TAPS; i = i + 1) begin
                    acc = acc + $signed(delay[i]) * $signed(coeff[i]);
                end
                corr_value <= acc[39:8];
                if (abs_corr > corr_peak) begin
                    corr_peak <= abs_corr;
                end
                status[0] <= (abs_corr >= threshold);
                if (abs_corr >= threshold) begin
                    status[1] <= ~status[1];
                end
            end
        end
    end

endmodule
