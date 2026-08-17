`timescale 1ns / 1ps

module adc_dsp_core (
    input  wire       clk,
    input  wire       rst,
    input  wire       sample_en,
    input  wire [1:0] mode,
    input  wire [7:0] lms_mu,
    input  wire [7:0] adc0_sample,
    input  wire [7:0] adc1_sample,
    output reg  [7:0] dsp0_sample,
    output reg  [7:0] dsp1_sample
);

    function [7:0] offset_from_signed12;
        input signed [11:0] value;
        reg signed [12:0] shifted;
        begin
            shifted = value + 13'sd128;
            if (shifted < 0) begin
                offset_from_signed12 = 8'd0;
            end else if (shifted > 13'sd255) begin
                offset_from_signed12 = 8'hff;
            end else begin
                offset_from_signed12 = shifted[7:0];
            end
        end
    endfunction

    reg signed [8:0] fir0_d0;
    reg signed [8:0] fir0_d1;
    reg signed [8:0] fir0_d2;
    reg signed [8:0] fir1_d0;
    reg signed [8:0] fir1_d1;
    reg signed [8:0] fir1_d2;
    reg signed [15:0] lms_w;
    reg signed [8:0]  lms_ref_d;
    reg signed [8:0]  lms_err_d;
    reg signed [8:0]  lms_mu_adc;
    reg signed [15:0] lms_est_w_a;
    reg signed [8:0]  lms_est_ref_a;
    reg signed [24:0] lms_est_product_m;
    reg signed [24:0] lms_est_product;
    reg signed [8:0]  lms_delta_mu_a;
    reg signed [8:0]  lms_delta_err_a;
    reg signed [8:0]  lms_delta_ref_a;
    reg signed [17:0] lms_delta_ab_product;
    reg signed [8:0]  lms_delta_ref_b;
    reg signed [26:0] lms_delta_product_m;
    reg signed [26:0] lms_delta_product;

    wire signed [8:0] adc0_signed_adc = $signed({1'b0, adc0_sample}) - 9'sd128;
    wire signed [8:0] adc1_signed_adc = $signed({1'b0, adc1_sample}) - 9'sd128;
    wire signed [11:0] fir0_avg_adc = ($signed(adc0_signed_adc) + $signed(fir0_d0) + $signed(fir0_d1) + $signed(fir0_d2)) >>> 2;
    wire signed [11:0] fir1_avg_adc = ($signed(adc1_signed_adc) + $signed(fir1_d0) + $signed(fir1_d1) + $signed(fir1_d2)) >>> 2;
    wire signed [24:0] lms_est_adc = lms_est_product >>> 7;
    wire signed [11:0] lms_est_clip_adc =
        (lms_est_adc > 25'sd127)  ? 12'sd127 :
        (lms_est_adc < -25'sd128) ? -12'sd128 :
                                    lms_est_adc[11:0];
    wire signed [11:0] lms_err_adc = $signed({adc0_signed_adc[8], adc0_signed_adc}) - lms_est_clip_adc;
    wire signed [31:0] lms_delta_product_ext = {{5{lms_delta_product[26]}}, lms_delta_product};
    wire signed [31:0] lms_delta_adc = lms_delta_product_ext >>> 14;

    always @(posedge clk) begin
        if (rst) begin
            fir0_d0 <= 9'sd0;
            fir0_d1 <= 9'sd0;
            fir0_d2 <= 9'sd0;
            fir1_d0 <= 9'sd0;
            fir1_d1 <= 9'sd0;
            fir1_d2 <= 9'sd0;
            lms_w <= 16'sd64;
            lms_ref_d <= 9'sd0;
            lms_err_d <= 9'sd0;
            lms_mu_adc <= 9'sd0;
            lms_est_w_a <= 16'sd0;
            lms_est_ref_a <= 9'sd0;
            lms_est_product_m <= 25'sd0;
            lms_est_product <= 25'sd0;
            lms_delta_mu_a <= 9'sd0;
            lms_delta_err_a <= 9'sd0;
            lms_delta_ref_a <= 9'sd0;
            lms_delta_ab_product <= 18'sd0;
            lms_delta_ref_b <= 9'sd0;
            lms_delta_product_m <= 27'sd0;
            lms_delta_product <= 27'sd0;
            dsp0_sample <= 8'h80;
            dsp1_sample <= 8'h80;
        end else if (sample_en) begin
            fir0_d2 <= fir0_d1;
            fir0_d1 <= fir0_d0;
            fir0_d0 <= adc0_signed_adc;
            fir1_d2 <= fir1_d1;
            fir1_d1 <= fir1_d0;
            fir1_d0 <= adc1_signed_adc;

            lms_w <= lms_w + lms_delta_adc[15:0];
            lms_mu_adc <= $signed({1'b0, lms_mu});
            lms_ref_d <= adc1_signed_adc;
            lms_err_d <= lms_err_adc[8:0];
            lms_est_w_a <= lms_w;
            lms_est_ref_a <= adc1_signed_adc;
            lms_est_product_m <= $signed(lms_est_w_a) * $signed(lms_est_ref_a);
            lms_est_product <= lms_est_product_m;
            lms_delta_mu_a <= lms_mu_adc;
            lms_delta_err_a <= lms_err_d;
            lms_delta_ref_a <= lms_ref_d;
            lms_delta_ab_product <= $signed(lms_delta_mu_a) * $signed(lms_delta_err_a);
            lms_delta_ref_b <= lms_delta_ref_a;
            lms_delta_product_m <= $signed(lms_delta_ab_product) * $signed(lms_delta_ref_b);
            lms_delta_product <= lms_delta_product_m;

            case (mode)
            2'd1: begin
                dsp0_sample <= offset_from_signed12(fir0_avg_adc);
                dsp1_sample <= offset_from_signed12(fir1_avg_adc);
            end
            2'd2: begin
                dsp0_sample <= offset_from_signed12(lms_err_adc);
                dsp1_sample <= offset_from_signed12(lms_est_clip_adc);
            end
            default: begin
                dsp0_sample <= adc0_sample;
                dsp1_sample <= adc1_sample;
            end
            endcase
        end
    end

endmodule
