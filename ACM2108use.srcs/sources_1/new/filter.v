`timescale 1ns / 1ps

module filter #(
    parameter integer TAPS = 16
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_en,
    input  wire [1:0]  mode,
    input  wire        coeff_we,
    input  wire [3:0]  coeff_addr,
    input  wire [15:0] coeff_data,
    input  wire [7:0]  iir_alpha,
    input  wire [7:0]  ch0_in,
    input  wire [7:0]  ch1_in,
    output reg  [7:0]  ch0_out,
    output reg  [7:0]  ch1_out
);

    reg signed [8:0] delay0 [0:TAPS-1];
    reg signed [8:0] delay1 [0:TAPS-1];
    reg signed [15:0] coeff [0:TAPS-1];
    reg signed [15:0] iir0;
    reg signed [15:0] iir1;

    integer i;
    reg signed [35:0] acc0;
    reg signed [35:0] acc1;
    reg signed [15:0] x0_ext;
    reg signed [15:0] x1_ext;
    reg signed [15:0] lp0;
    reg signed [15:0] lp1;
    reg signed [15:0] hp0;
    reg signed [15:0] hp1;

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

    wire signed [8:0] x0 = $signed({1'b0, ch0_in}) - 9'sd128;
    wire signed [8:0] x1 = $signed({1'b0, ch1_in}) - 9'sd128;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < TAPS; i = i + 1) begin
                delay0[i] <= 9'sd0;
                delay1[i] <= 9'sd0;
                coeff[i] <= (i == 0) ? 16'sd32767 : 16'sd0;
            end
            iir0 <= 16'sd0;
            iir1 <= 16'sd0;
            ch0_out <= 8'h80;
            ch1_out <= 8'h80;
        end else begin
            if (coeff_we) begin
                coeff[coeff_addr] <= coeff_data;
            end

            if (sample_en) begin
                for (i = TAPS - 1; i > 0; i = i - 1) begin
                    delay0[i] <= delay0[i - 1];
                    delay1[i] <= delay1[i - 1];
                end
                delay0[0] <= x0;
                delay1[0] <= x1;

                acc0 = 36'sd0;
                acc1 = 36'sd0;
                for (i = 0; i < TAPS; i = i + 1) begin
                    acc0 = acc0 + $signed(delay0[i]) * $signed(coeff[i]);
                    acc1 = acc1 + $signed(delay1[i]) * $signed(coeff[i]);
                end

                x0_ext = {{7{x0[8]}}, x0};
                x1_ext = {{7{x1[8]}}, x1};
                iir0 <= iir0 + (($signed({1'b0, iir_alpha}) * (x0_ext - iir0)) >>> 8);
                iir1 <= iir1 + (($signed({1'b0, iir_alpha}) * (x1_ext - iir1)) >>> 8);
                lp0 = iir0;
                lp1 = iir1;
                hp0 = x0_ext - iir0;
                hp1 = x1_ext - iir1;

                case (mode)
                2'd1: begin
                    ch0_out <= sat_offset(acc0[30:15]);
                    ch1_out <= sat_offset(acc1[30:15]);
                end
                2'd2: begin
                    ch0_out <= sat_offset(lp0);
                    ch1_out <= sat_offset(lp1);
                end
                2'd3: begin
                    ch0_out <= sat_offset(hp0);
                    ch1_out <= sat_offset(hp1);
                end
                default: begin
                    ch0_out <= ch0_in;
                    ch1_out <= ch1_in;
                end
                endcase
            end
        end
    end

endmodule

module filter_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [1:0]  mode,
    input  wire        coeff_we,
    input  wire [3:0]  coeff_addr,
    input  wire [15:0] coeff_data,
    input  wire [7:0]  iir_alpha,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    reg        out_valid;
    reg [31:0] out_data;
    reg        out_last;
    reg        pending_valid;
    reg        pending_last;
    wire       output_ready = !out_valid || m_axis_tready;
    wire       accept_sample = enable && s_axis_tvalid && s_axis_tready;
    wire [7:0] ch0_out;
    wire [7:0] ch1_out;

    assign s_axis_tready = enable ? (output_ready && !pending_valid) : m_axis_tready;
    assign m_axis_tvalid = enable ? out_valid : s_axis_tvalid;
    assign m_axis_tdata  = enable ? out_data  : s_axis_tdata;
    assign m_axis_tlast  = enable ? out_last  : s_axis_tlast;

    filter u_filter (
        .clk        (aclk),
        .rst        (!aresetn),
        .sample_en  (accept_sample),
        .mode       (mode),
        .coeff_we   (coeff_we),
        .coeff_addr (coeff_addr),
        .coeff_data (coeff_data),
        .iir_alpha  (iir_alpha),
        .ch0_in     (s_axis_tdata[7:0]),
        .ch1_in     (s_axis_tdata[23:16]),
        .ch0_out    (ch0_out),
        .ch1_out    (ch1_out)
    );

    always @(posedge aclk) begin
        if (!aresetn) begin
            out_valid     <= 1'b0;
            out_data      <= 32'd0;
            out_last      <= 1'b0;
            pending_valid <= 1'b0;
            pending_last  <= 1'b0;
        end else begin
            if (out_valid && m_axis_tready) begin
                out_valid <= 1'b0;
            end
            if (accept_sample) begin
                pending_valid <= 1'b1;
                pending_last  <= s_axis_tlast;
            end
            if (pending_valid && output_ready) begin
                out_valid     <= 1'b1;
                out_data      <= {8'd0, ch1_out, 8'd0, ch0_out};
                out_last      <= pending_last;
                pending_valid <= 1'b0;
            end
        end
    end

endmodule
