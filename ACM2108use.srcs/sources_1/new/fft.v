`timescale 1ns / 1ps

module fft_axis #(
    parameter integer BIN_COUNT = 16
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [1:0]  window_mode,
    input  wire [31:0] frame_len,

    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    output reg  [31:0] status,
    output reg  [31:0] peak_status,
    output reg  [31:0] thd_status,
    output reg  [31:0] snr_status
);

    localparam integer PHASE_BITS = 6;
    reg [31:0] sample_count;
    reg [1:0]  calc_state;
    reg signed [47:0] acc_re [0:BIN_COUNT-1];
    reg signed [47:0] acc_im [0:BIN_COUNT-1];
    reg [31:0] mag [0:BIN_COUNT-1];
    reg [31:0] total_mag;
    reg [31:0] harmonic_mag;
    reg [31:0] noise_mag;
    reg [7:0]  peak_bin;
    reg [31:0] peak_mag;
    reg [31:0] mag_calc;
    reg [31:0] harm_calc;
    reg [31:0] noise_calc;
    reg [7:0]  calc_bin;
    reg [31:0] scan_total;
    reg [31:0] scan_peak;
    reg [7:0]  scan_peak_bin;
    reg [7:0]  h2_idx;
    reg [7:0]  h3_idx;

    integer i;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire [31:0] frame_safe = (frame_len == 32'd0) ? 32'd64 : frame_len;
    wire frame_last = fire && ((sample_count == frame_safe - 32'd1) || s_axis_tlast);

    wire signed [8:0] centered_sample = $signed({1'b0, s_axis_tdata[7:0]}) - $signed(9'd128);
    wire [7:0] window_weight = make_window(sample_count[5:0], window_mode);
    wire signed [17:0] windowed_sample = centered_sample * $signed({1'b0, window_weight});
    wire signed [15:0] sample_win = windowed_sample >>> 7;

    assign s_axis_tready = m_axis_tready && (calc_state == 2'd0);
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid && (calc_state == 2'd0);
    assign m_axis_tlast  = s_axis_tlast;

    function signed [7:0] sin16;
        input [3:0] phase;
        begin
            case (phase)
                4'd0:  sin16 = 8'sd0;
                4'd1:  sin16 = 8'sd49;
                4'd2:  sin16 = 8'sd90;
                4'd3:  sin16 = 8'sd118;
                4'd4:  sin16 = 8'sd127;
                4'd5:  sin16 = 8'sd118;
                4'd6:  sin16 = 8'sd90;
                4'd7:  sin16 = 8'sd49;
                4'd8:  sin16 = 8'sd0;
                4'd9:  sin16 = -8'sd49;
                4'd10: sin16 = -8'sd90;
                4'd11: sin16 = -8'sd118;
                4'd12: sin16 = -8'sd127;
                4'd13: sin16 = -8'sd118;
                4'd14: sin16 = -8'sd90;
                default: sin16 = -8'sd49;
            endcase
        end
    endfunction

    function signed [7:0] cos16;
        input [3:0] phase;
        begin
            cos16 = sin16(phase + 4'd4);
        end
    endfunction

    function [7:0] make_window;
        input [5:0] idx;
        input [1:0] mode;
        reg [6:0] tri_weight;
        begin
            tri_weight = idx[5] ? {1'b0, (6'd63 - idx)} : {1'b0, idx};
            case (mode)
                2'd1: make_window = {1'b0, tri_weight} << 1;
                2'd2: make_window = 8'd64 + ({1'b0, tri_weight} << 1);
                default: make_window = 8'd127;
            endcase
        end
    endfunction

    function [3:0] bin_phase16;
        input [5:0] sample_idx;
        input integer bin_idx;
        reg [5:0] phase;
        begin
            phase = sample_idx * bin_idx;
            bin_phase16 = phase[5:2];
        end
    endfunction

    function [31:0] abs_sat48;
        input signed [47:0] value;
        reg [47:0] abs_value;
        begin
            abs_value = value[47] ? -value : value;
            if (abs_value[47:32] != 16'd0) begin
                abs_sat48 = 32'hffff_ffff;
            end else begin
                abs_sat48 = abs_value[31:0];
            end
        end
    endfunction

    function [31:0] add_sat32;
        input [31:0] a;
        input [31:0] b;
        reg [32:0] sum;
        begin
            sum = {1'b0, a} + {1'b0, b};
            add_sat32 = sum[32] ? 32'hffff_ffff : sum[31:0];
        end
    endfunction

    always @(posedge aclk) begin
        if (!aresetn) begin
            sample_count <= 32'd0;
            calc_state   <= 2'd0;
            total_mag    <= 32'd0;
            harmonic_mag <= 32'd0;
            noise_mag    <= 32'd0;
            peak_bin     <= 8'd0;
            peak_mag     <= 32'd0;
            calc_bin     <= 8'd0;
            scan_total   <= 32'd0;
            scan_peak    <= 32'd0;
            scan_peak_bin <= 8'd0;
            status       <= 32'd0;
            peak_status  <= 32'd0;
            thd_status   <= 32'd0;
            snr_status   <= 32'd0;
            for (i = 0; i < BIN_COUNT; i = i + 1) begin
                acc_re[i] <= 48'sd0;
                acc_im[i] <= 48'sd0;
                mag[i]    <= 32'd0;
            end
        end else begin
            if (fire && enable) begin
                for (i = 0; i < BIN_COUNT; i = i + 1) begin
                    acc_re[i] <= acc_re[i] + sample_win * cos16(bin_phase16(sample_count[5:0], i));
                    acc_im[i] <= acc_im[i] - sample_win * sin16(bin_phase16(sample_count[5:0], i));
                end

                if (frame_last) begin
                    sample_count <= 32'd0;
                    calc_state <= 2'd1;
                    calc_bin <= 8'd0;
                    scan_total <= 32'd0;
                    scan_peak <= 32'd0;
                    scan_peak_bin <= 8'd0;
                end else begin
                    sample_count <= sample_count + 32'd1;
                end
            end else if (!enable) begin
                sample_count <= 32'd0;
                calc_state <= 2'd0;
                calc_bin <= 8'd0;
                scan_total <= 32'd0;
                scan_peak <= 32'd0;
                scan_peak_bin <= 8'd0;
                for (i = 0; i < BIN_COUNT; i = i + 1) begin
                    acc_re[i] <= 48'sd0;
                    acc_im[i] <= 48'sd0;
                end
            end

            if (calc_state == 2'd1) begin
                mag_calc = add_sat32(abs_sat48(acc_re[calc_bin]), abs_sat48(acc_im[calc_bin]));
                mag[calc_bin] <= mag_calc;
                scan_total <= add_sat32(scan_total, mag_calc);
                if (mag_calc > scan_peak) begin
                    scan_peak <= mag_calc;
                    scan_peak_bin <= calc_bin;
                end
                if (calc_bin == BIN_COUNT - 1) begin
                    total_mag <= add_sat32(scan_total, mag_calc);
                    peak_mag <= (mag_calc > scan_peak) ? mag_calc : scan_peak;
                    peak_bin <= (mag_calc > scan_peak) ? calc_bin : scan_peak_bin;
                    calc_state <= 2'd2;
                end else begin
                    calc_bin <= calc_bin + 8'd1;
                end
            end else if (calc_state == 2'd2) begin
                harm_calc = 32'd0;
                h2_idx = peak_bin << 1;
                h3_idx = (peak_bin << 1) + peak_bin;
                if (h2_idx < BIN_COUNT) begin
                    harm_calc = add_sat32(harm_calc, mag[h2_idx]);
                end
                if (h3_idx < BIN_COUNT) begin
                    harm_calc = add_sat32(harm_calc, mag[h3_idx]);
                end
                noise_calc = (total_mag > add_sat32(peak_mag, harm_calc)) ? (total_mag - peak_mag - harm_calc) : 32'd0;
                harmonic_mag <= harm_calc;
                noise_mag <= noise_calc;
                status <= {peak_mag[15:0], peak_bin, 7'd0, 1'b1};
                peak_status <= peak_mag;
                thd_status <= harm_calc;
                snr_status <= noise_calc;
                for (i = 0; i < BIN_COUNT; i = i + 1) begin
                    acc_re[i] <= 48'sd0;
                    acc_im[i] <= 48'sd0;
                end
                calc_state <= 2'd0;
            end
        end
    end

endmodule
