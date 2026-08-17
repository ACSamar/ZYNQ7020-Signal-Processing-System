`timescale 1ns / 1ps

module contest_ctrl (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aclk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn" *)
    input  wire        s_axi_aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aresetn, POLARITY ACTIVE_LOW" *)
    input  wire        s_axi_aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWADDR" *)
    input  wire [31:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWVALID" *)
    input  wire        s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWREADY" *)
    output wire        s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WDATA" *)
    input  wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WSTRB" *)
    input  wire [3:0]  s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WVALID" *)
    input  wire        s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WREADY" *)
    output wire        s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BRESP" *)
    output wire [1:0]  s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BVALID" *)
    output wire        s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BREADY" *)
    input  wire        s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARADDR" *)
    input  wire [31:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARVALID" *)
    input  wire        s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARREADY" *)
    output wire        s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RDATA" *)
    output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RRESP" *)
    output wire [1:0]  s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RVALID" *)
    output wire        s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RREADY" *)
    input  wire        s_axi_rready,

    output wire        dds_enable,
    output reg  [1:0]  dds_wave_mode,
    output reg  [2:0]  dds_mod_mode,
    output reg  [31:0] dds_carrier_step,
    output reg  [31:0] dds_phase_offset,
    output reg  [31:0] dds_amp_offset,
    output reg  [31:0] dds_sweep_step,
    output reg  [31:0] dds_sweep_min,
    output reg  [31:0] dds_sweep_max,
    output reg  [31:0] dds_fsk_step0,
    output reg  [31:0] dds_fsk_step1,
    output reg         dds_key,
    output reg  [7:0]  dds_mod_sample,
    output reg  [31:0] dds_frame_len,

    output wire        filter_enable,
    output reg  [1:0]  filter_mode,
    output reg         filter_coeff_we,
    output reg  [3:0]  filter_coeff_addr,
    output reg  [15:0] filter_coeff_data,
    output reg  [7:0]  filter_iir_alpha,

    output wire        fft_enable,
    output reg  [1:0]  fft_window_mode,
    output reg  [31:0] fft_frame_len,
    input  wire [31:0] fft_status,
    input  wire [31:0] fft_peak_status,
    input  wire [31:0] fft_thd_status,
    input  wire [31:0] fft_snr_status,

    output wire        measure_enable,
    output reg  [31:0] measure_window_len,
    output reg  [7:0]  measure_threshold,
    output reg  [7:0]  measure_hysteresis,
    input  wire [31:0] measure_status,
    input  wire [31:0] measure_ch0_minmax,
    input  wire [31:0] measure_ch1_minmax,
    input  wire [31:0] measure_ch0_sum,
    input  wire [31:0] measure_ch1_sum,
    input  wire [31:0] measure_ch0_sumsq,
    input  wire [31:0] measure_ch1_sumsq,
    input  wire [31:0] measure_zero_cross,
    input  wire [31:0] measure_phase_delta,

    output wire        trigger_enable,
    output reg  [1:0]  trigger_mode,
    output reg  [7:0]  trigger_level,
    output reg  [7:0]  trigger_level_high,
    output reg  [10:0] trigger_pre_count,
    output reg  [31:0] trigger_post_count,
    input  wire [31:0] trigger_status,

    output wire        agc_enable,
    output reg  [7:0]  agc_target_amp,
    output reg  [7:0]  agc_decay,
    input  wire [31:0] agc_status,

    output wire        phase_enable,
    output reg  [7:0]  phase_threshold,
    output reg  [7:0]  phase_hysteresis,
    input  wire [31:0] phase_samples,
    input  wire [31:0] phase_period_samples,
    input  wire [31:0] phase_status,

    output wire        cic_enable,
    output reg  [15:0] cic_decim_rate,
    output reg  [4:0]  cic_gain_shift,

    output wire        correlator_enable,
    output reg         correlator_coeff_we,
    output reg  [3:0]  correlator_coeff_addr,
    output reg  [15:0] correlator_coeff_data,
    output reg  [31:0] correlator_threshold,
    input  wire [31:0] correlator_value,
    input  wire [31:0] correlator_peak,
    input  wire [31:0] correlator_status,

    output wire        dpll_enable,
    output reg  [31:0] dpll_nominal_step,
    output reg  [7:0]  dpll_kp,
    output reg  [7:0]  dpll_ki,
    output reg  [7:0]  dpll_threshold,
    input  wire [31:0] dpll_phase_acc,
    input  wire [31:0] dpll_freq_word,
    input  wire [31:0] dpll_status,

    output wire        calibrate_enable,
    output reg  [15:0] calibrate_ch0_offset,
    output reg  [15:0] calibrate_ch1_offset,
    output reg  [15:0] calibrate_ch0_gain,
    output reg  [15:0] calibrate_ch1_gain,

    output wire        selftest_enable,
    output reg         selftest_generator_mode,
    output reg  [31:0] selftest_frame_len,
    input  wire [31:0] selftest_error_count,
    input  wire [31:0] selftest_sample_count,

    output wire        modem_enable,
    output reg  [7:0]  modem_threshold,
    output reg  [31:0] modem_window_len,
    input  wire [31:0] modem_status,

    output wire        dac0_mux_wave,
    output wire        dac1_mux_wave,
    output wire        dac0_alg_dds,
    output wire        dac1_alg_ram
);

    localparam [31:0] ID_VALUE = 32'hc071_2108;

    localparam [7:0] A_ID                = 8'h00;
    localparam [7:0] A_ENABLE            = 8'h01;
    localparam [7:0] A_DDS_CTRL          = 8'h02;
    localparam [7:0] A_DDS_CARRIER_STEP  = 8'h03;
    localparam [7:0] A_DDS_PHASE_OFFSET  = 8'h04;
    localparam [7:0] A_DDS_AMP_OFFSET    = 8'h05;
    localparam [7:0] A_DDS_SWEEP_STEP    = 8'h06;
    localparam [7:0] A_DDS_SWEEP_MIN     = 8'h07;
    localparam [7:0] A_DDS_SWEEP_MAX     = 8'h08;
    localparam [7:0] A_DDS_FSK_STEP0     = 8'h09;
    localparam [7:0] A_DDS_FSK_STEP1     = 8'h0a;
    localparam [7:0] A_DDS_FRAME_LEN     = 8'h0b;
    localparam [7:0] A_FILTER_CFG        = 8'h10;
    localparam [7:0] A_FILTER_COEFF      = 8'h11;
    localparam [7:0] A_FFT_CFG           = 8'h18;
    localparam [7:0] A_FFT_FRAME_LEN     = 8'h19;
    localparam [7:0] A_FFT_STATUS        = 8'h1a;
    localparam [7:0] A_FFT_PEAK          = 8'h1b;
    localparam [7:0] A_FFT_THD           = 8'h1c;
    localparam [7:0] A_FFT_SNR           = 8'h1d;
    localparam [7:0] A_MEAS_WINDOW       = 8'h20;
    localparam [7:0] A_MEAS_THRESH       = 8'h21;
    localparam [7:0] A_MEAS_STATUS       = 8'h22;
    localparam [7:0] A_MEAS_CH0_MINMAX   = 8'h23;
    localparam [7:0] A_MEAS_CH1_MINMAX   = 8'h24;
    localparam [7:0] A_MEAS_CH0_SUM      = 8'h25;
    localparam [7:0] A_MEAS_CH1_SUM      = 8'h26;
    localparam [7:0] A_MEAS_CH0_SUMSQ    = 8'h27;
    localparam [7:0] A_MEAS_CH1_SUMSQ    = 8'h28;
    localparam [7:0] A_MEAS_ZERO_CROSS   = 8'h29;
    localparam [7:0] A_MEAS_PHASE_DELTA  = 8'h2a;
    localparam [7:0] A_TRIG_CFG          = 8'h30;
    localparam [7:0] A_TRIG_COUNTS       = 8'h31;
    localparam [7:0] A_TRIG_STATUS       = 8'h32;
    localparam [7:0] A_AGC_CFG           = 8'h38;
    localparam [7:0] A_AGC_STATUS        = 8'h39;
    localparam [7:0] A_PHASE_CFG         = 8'h40;
    localparam [7:0] A_PHASE_SAMPLES     = 8'h41;
    localparam [7:0] A_PHASE_PERIOD      = 8'h42;
    localparam [7:0] A_PHASE_STATUS      = 8'h43;
    localparam [7:0] A_CIC_CFG           = 8'h48;
    localparam [7:0] A_CORR_THRESHOLD    = 8'h50;
    localparam [7:0] A_CORR_COEFF        = 8'h51;
    localparam [7:0] A_CORR_VALUE        = 8'h52;
    localparam [7:0] A_CORR_PEAK         = 8'h53;
    localparam [7:0] A_CORR_STATUS       = 8'h54;
    localparam [7:0] A_DPLL_STEP         = 8'h58;
    localparam [7:0] A_DPLL_CFG          = 8'h59;
    localparam [7:0] A_DPLL_PHASE        = 8'h5a;
    localparam [7:0] A_DPLL_FREQ         = 8'h5b;
    localparam [7:0] A_DPLL_STATUS       = 8'h5c;
    localparam [7:0] A_CAL_OFFSET        = 8'h60;
    localparam [7:0] A_CAL_GAIN          = 8'h61;
    localparam [7:0] A_SELFTEST_CFG      = 8'h68;
    localparam [7:0] A_SELFTEST_ERRORS   = 8'h69;
    localparam [7:0] A_SELFTEST_SAMPLES  = 8'h6a;
    localparam [7:0] A_MODEM_CFG         = 8'h70;
    localparam [7:0] A_MODEM_STATUS      = 8'h71;
    localparam [7:0] A_DAC_MUX           = 8'h78;

    reg [31:0] enable_mask;
    reg [3:0]  dac_mux_select;
    reg        awready_r;
    reg        wready_r;
    reg        bvalid_r;
    reg        aw_seen;
    reg        w_seen;
    reg [31:0] awaddr_latched;
    reg [31:0] wdata_latched;
    reg [3:0]  wstrb_latched;
    reg        arready_r;
    reg        rvalid_r;
    reg [31:0] rdata_r;

    wire [7:0] wr_word = awaddr_latched[9:2];
    wire [7:0] rd_word = s_axi_araddr[9:2];
    wire [31:0] filter_cfg_value = {16'd0, filter_iir_alpha, 6'd0, filter_mode};
    wire [31:0] filter_coeff_value = {12'd0, filter_coeff_addr, filter_coeff_data};
    wire [31:0] dds_ctrl_value = {dds_mod_sample, 7'd0, dds_key, 5'd0, dds_mod_mode, 6'd0, dds_wave_mode};
    wire [31:0] measure_thresh_value = {16'd0, measure_hysteresis, measure_threshold};
    wire [31:0] trigger_cfg_value = {8'd0, trigger_level_high, trigger_level, 6'd0, trigger_mode};
    wire [31:0] trigger_counts_value = {trigger_pre_count, trigger_post_count[20:0]};
    wire [31:0] agc_cfg_value = {16'd0, agc_decay, agc_target_amp};
    wire [31:0] phase_cfg_value = {16'd0, phase_hysteresis, phase_threshold};
    wire [31:0] cic_cfg_value = {11'd0, cic_gain_shift, cic_decim_rate};
    wire [31:0] corr_coeff_value = {12'd0, correlator_coeff_addr, correlator_coeff_data};
    wire [31:0] dpll_cfg_value = {8'd0, dpll_ki, dpll_kp, dpll_threshold};
    wire [31:0] cal_offset_value = {calibrate_ch1_offset, calibrate_ch0_offset};
    wire [31:0] cal_gain_value = {calibrate_ch1_gain, calibrate_ch0_gain};
    wire [31:0] selftest_cfg_value = {selftest_frame_len[30:0], selftest_generator_mode};
    wire [31:0] modem_cfg_value = {modem_window_len[23:0], modem_threshold};
    wire [31:0] dac_mux_value = {28'd0, dac_mux_select};

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_arready = arready_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rvalid  = rvalid_r;

    assign dds_enable        = enable_mask[0];
    assign filter_enable     = enable_mask[1];
    assign fft_enable        = enable_mask[2];
    assign measure_enable    = enable_mask[3];
    assign trigger_enable    = enable_mask[4];
    assign agc_enable        = enable_mask[5];
    assign phase_enable      = enable_mask[6];
    assign cic_enable        = enable_mask[7];
    assign correlator_enable = enable_mask[8];
    assign dpll_enable       = enable_mask[9];
    assign calibrate_enable  = enable_mask[10];
    assign selftest_enable   = enable_mask[11];
    assign modem_enable      = enable_mask[12];
    assign dac0_mux_wave     = dac_mux_select[0];
    assign dac1_mux_wave     = dac_mux_select[1];
    assign dac0_alg_dds      = dac_mux_select[2];
    assign dac1_alg_ram      = dac_mux_select[3];

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  strobe;
        begin
            apply_wstrb[7:0]   = strobe[0] ? new_value[7:0]   : old_value[7:0];
            apply_wstrb[15:8]  = strobe[1] ? new_value[15:8]  : old_value[15:8];
            apply_wstrb[23:16] = strobe[2] ? new_value[23:16] : old_value[23:16];
            apply_wstrb[31:24] = strobe[3] ? new_value[31:24] : old_value[31:24];
        end
    endfunction

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            enable_mask <= 32'd0;
            dac_mux_select <= 4'd0;
            dds_wave_mode <= 2'd0;
            dds_mod_mode <= 3'd0;
            dds_carrier_step <= 32'd0;
            dds_phase_offset <= 32'd0;
            dds_amp_offset <= 32'h0000_8060;
            dds_sweep_step <= 32'd0;
            dds_sweep_min <= 32'd0;
            dds_sweep_max <= 32'd0;
            dds_fsk_step0 <= 32'd0;
            dds_fsk_step1 <= 32'd0;
            dds_key <= 1'b0;
            dds_mod_sample <= 8'hff;
            dds_frame_len <= 32'd4096;
            filter_mode <= 2'd0;
            filter_coeff_we <= 1'b0;
            filter_coeff_addr <= 4'd0;
            filter_coeff_data <= 16'd0;
            filter_iir_alpha <= 8'd32;
            fft_window_mode <= 2'd0;
            fft_frame_len <= 32'd4096;
            measure_window_len <= 32'd4096;
            measure_threshold <= 8'd128;
            measure_hysteresis <= 8'd4;
            trigger_mode <= 2'd0;
            trigger_level <= 8'd128;
            trigger_level_high <= 8'd200;
            trigger_pre_count <= 11'd64;
            trigger_post_count <= 32'd1024;
            agc_target_amp <= 8'd96;
            agc_decay <= 8'd1;
            phase_threshold <= 8'd128;
            phase_hysteresis <= 8'd4;
            cic_decim_rate <= 16'd1;
            cic_gain_shift <= 5'd0;
            correlator_coeff_we <= 1'b0;
            correlator_coeff_addr <= 4'd0;
            correlator_coeff_data <= 16'd0;
            correlator_threshold <= 32'd1024;
            dpll_nominal_step <= 32'd0;
            dpll_kp <= 8'd8;
            dpll_ki <= 8'd1;
            dpll_threshold <= 8'd128;
            calibrate_ch0_offset <= 16'd0;
            calibrate_ch1_offset <= 16'd0;
            calibrate_ch0_gain <= 16'd256;
            calibrate_ch1_gain <= 16'd256;
            selftest_generator_mode <= 1'b0;
            selftest_frame_len <= 32'd4096;
            modem_threshold <= 8'd128;
            modem_window_len <= 32'd4096;
            awready_r <= 1'b0;
            wready_r <= 1'b0;
            bvalid_r <= 1'b0;
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            awaddr_latched <= 32'd0;
            wdata_latched <= 32'd0;
            wstrb_latched <= 4'd0;
        end else begin
            awready_r <= 1'b0;
            wready_r <= 1'b0;
            filter_coeff_we <= 1'b0;
            correlator_coeff_we <= 1'b0;

            if (!aw_seen && !bvalid_r) begin
                awready_r <= 1'b1;
                if (s_axi_awvalid) begin
                    aw_seen <= 1'b1;
                    awaddr_latched <= s_axi_awaddr;
                end
            end

            if (!w_seen && !bvalid_r) begin
                wready_r <= 1'b1;
                if (s_axi_wvalid) begin
                    w_seen <= 1'b1;
                    wdata_latched <= s_axi_wdata;
                    wstrb_latched <= s_axi_wstrb;
                end
            end

            if (aw_seen && w_seen && !bvalid_r) begin
                case (wr_word)
                A_ENABLE: begin
                    enable_mask <= apply_wstrb(enable_mask, wdata_latched, wstrb_latched);
                end
                A_DDS_CTRL: begin
                    dds_wave_mode <= wdata_latched[1:0];
                    dds_mod_mode <= wdata_latched[10:8];
                    dds_key <= wdata_latched[16];
                    dds_mod_sample <= wdata_latched[31:24];
                end
                A_DDS_CARRIER_STEP: dds_carrier_step <= apply_wstrb(dds_carrier_step, wdata_latched, wstrb_latched);
                A_DDS_PHASE_OFFSET: dds_phase_offset <= apply_wstrb(dds_phase_offset, wdata_latched, wstrb_latched);
                A_DDS_AMP_OFFSET: dds_amp_offset <= apply_wstrb(dds_amp_offset, wdata_latched, wstrb_latched);
                A_DDS_SWEEP_STEP: dds_sweep_step <= apply_wstrb(dds_sweep_step, wdata_latched, wstrb_latched);
                A_DDS_SWEEP_MIN: dds_sweep_min <= apply_wstrb(dds_sweep_min, wdata_latched, wstrb_latched);
                A_DDS_SWEEP_MAX: dds_sweep_max <= apply_wstrb(dds_sweep_max, wdata_latched, wstrb_latched);
                A_DDS_FSK_STEP0: dds_fsk_step0 <= apply_wstrb(dds_fsk_step0, wdata_latched, wstrb_latched);
                A_DDS_FSK_STEP1: dds_fsk_step1 <= apply_wstrb(dds_fsk_step1, wdata_latched, wstrb_latched);
                A_DDS_FRAME_LEN: dds_frame_len <= apply_wstrb(dds_frame_len, wdata_latched, wstrb_latched);
                A_FILTER_CFG: begin
                    filter_mode <= wdata_latched[1:0];
                    filter_iir_alpha <= wdata_latched[15:8];
                end
                A_FILTER_COEFF: begin
                    filter_coeff_data <= wdata_latched[15:0];
                    filter_coeff_addr <= wdata_latched[19:16];
                    filter_coeff_we <= 1'b1;
                end
                A_FFT_CFG: fft_window_mode <= wdata_latched[1:0];
                A_FFT_FRAME_LEN: fft_frame_len <= apply_wstrb(fft_frame_len, wdata_latched, wstrb_latched);
                A_MEAS_WINDOW: measure_window_len <= apply_wstrb(measure_window_len, wdata_latched, wstrb_latched);
                A_MEAS_THRESH: begin
                    measure_threshold <= wdata_latched[7:0];
                    measure_hysteresis <= wdata_latched[15:8];
                end
                A_TRIG_CFG: begin
                    trigger_mode <= wdata_latched[1:0];
                    trigger_level <= wdata_latched[15:8];
                    trigger_level_high <= wdata_latched[23:16];
                end
                A_TRIG_COUNTS: begin
                    trigger_post_count <= {11'd0, wdata_latched[20:0]};
                    trigger_pre_count <= wdata_latched[31:21];
                end
                A_AGC_CFG: begin
                    agc_target_amp <= wdata_latched[7:0];
                    agc_decay <= wdata_latched[15:8];
                end
                A_PHASE_CFG: begin
                    phase_threshold <= wdata_latched[7:0];
                    phase_hysteresis <= wdata_latched[15:8];
                end
                A_CIC_CFG: begin
                    cic_decim_rate <= (wdata_latched[15:0] == 16'd0) ? 16'd1 : wdata_latched[15:0];
                    cic_gain_shift <= wdata_latched[20:16];
                end
                A_CORR_THRESHOLD: correlator_threshold <= apply_wstrb(correlator_threshold, wdata_latched, wstrb_latched);
                A_CORR_COEFF: begin
                    correlator_coeff_data <= wdata_latched[15:0];
                    correlator_coeff_addr <= wdata_latched[19:16];
                    correlator_coeff_we <= 1'b1;
                end
                A_DPLL_STEP: dpll_nominal_step <= apply_wstrb(dpll_nominal_step, wdata_latched, wstrb_latched);
                A_DPLL_CFG: begin
                    dpll_threshold <= wdata_latched[7:0];
                    dpll_kp <= wdata_latched[15:8];
                    dpll_ki <= wdata_latched[23:16];
                end
                A_CAL_OFFSET: begin
                    calibrate_ch0_offset <= wdata_latched[15:0];
                    calibrate_ch1_offset <= wdata_latched[31:16];
                end
                A_CAL_GAIN: begin
                    calibrate_ch0_gain <= wdata_latched[15:0];
                    calibrate_ch1_gain <= wdata_latched[31:16];
                end
                A_SELFTEST_CFG: begin
                    selftest_generator_mode <= wdata_latched[0];
                    selftest_frame_len <= {1'b0, wdata_latched[31:1]};
                end
                A_MODEM_CFG: begin
                    modem_threshold <= wdata_latched[7:0];
                    modem_window_len <= {8'd0, wdata_latched[31:8]};
                end
                A_DAC_MUX: begin
                    dac_mux_select <= wdata_latched[3:0];
                end
                default: begin
                end
                endcase
                aw_seen <= 1'b0;
                w_seen <= 1'b0;
                bvalid_r <= 1'b1;
            end else if (bvalid_r && s_axi_bready) begin
                bvalid_r <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            arready_r <= 1'b0;
            rvalid_r <= 1'b0;
            rdata_r <= 32'd0;
        end else begin
            arready_r <= 1'b0;
            if (!rvalid_r && s_axi_arvalid) begin
                arready_r <= 1'b1;
                rvalid_r <= 1'b1;
                case (rd_word)
                A_ID:               rdata_r <= ID_VALUE;
                A_ENABLE:           rdata_r <= enable_mask;
                A_DDS_CTRL:         rdata_r <= dds_ctrl_value;
                A_DDS_CARRIER_STEP: rdata_r <= dds_carrier_step;
                A_DDS_PHASE_OFFSET: rdata_r <= dds_phase_offset;
                A_DDS_AMP_OFFSET:   rdata_r <= dds_amp_offset;
                A_DDS_SWEEP_STEP:   rdata_r <= dds_sweep_step;
                A_DDS_SWEEP_MIN:    rdata_r <= dds_sweep_min;
                A_DDS_SWEEP_MAX:    rdata_r <= dds_sweep_max;
                A_DDS_FSK_STEP0:    rdata_r <= dds_fsk_step0;
                A_DDS_FSK_STEP1:    rdata_r <= dds_fsk_step1;
                A_DDS_FRAME_LEN:    rdata_r <= dds_frame_len;
                A_FILTER_CFG:       rdata_r <= filter_cfg_value;
                A_FILTER_COEFF:     rdata_r <= filter_coeff_value;
                A_FFT_CFG:          rdata_r <= {30'd0, fft_window_mode};
                A_FFT_FRAME_LEN:    rdata_r <= fft_frame_len;
                A_FFT_STATUS:       rdata_r <= fft_status;
                A_FFT_PEAK:         rdata_r <= fft_peak_status;
                A_FFT_THD:          rdata_r <= fft_thd_status;
                A_FFT_SNR:          rdata_r <= fft_snr_status;
                A_MEAS_WINDOW:      rdata_r <= measure_window_len;
                A_MEAS_THRESH:      rdata_r <= measure_thresh_value;
                A_MEAS_STATUS:      rdata_r <= measure_status;
                A_MEAS_CH0_MINMAX:  rdata_r <= measure_ch0_minmax;
                A_MEAS_CH1_MINMAX:  rdata_r <= measure_ch1_minmax;
                A_MEAS_CH0_SUM:     rdata_r <= measure_ch0_sum;
                A_MEAS_CH1_SUM:     rdata_r <= measure_ch1_sum;
                A_MEAS_CH0_SUMSQ:   rdata_r <= measure_ch0_sumsq;
                A_MEAS_CH1_SUMSQ:   rdata_r <= measure_ch1_sumsq;
                A_MEAS_ZERO_CROSS:  rdata_r <= measure_zero_cross;
                A_MEAS_PHASE_DELTA: rdata_r <= measure_phase_delta;
                A_TRIG_CFG:         rdata_r <= trigger_cfg_value;
                A_TRIG_COUNTS:      rdata_r <= trigger_counts_value;
                A_TRIG_STATUS:      rdata_r <= trigger_status;
                A_AGC_CFG:          rdata_r <= agc_cfg_value;
                A_AGC_STATUS:       rdata_r <= agc_status;
                A_PHASE_CFG:        rdata_r <= phase_cfg_value;
                A_PHASE_SAMPLES:    rdata_r <= phase_samples;
                A_PHASE_PERIOD:     rdata_r <= phase_period_samples;
                A_PHASE_STATUS:     rdata_r <= phase_status;
                A_CIC_CFG:          rdata_r <= cic_cfg_value;
                A_CORR_THRESHOLD:   rdata_r <= correlator_threshold;
                A_CORR_COEFF:       rdata_r <= corr_coeff_value;
                A_CORR_VALUE:       rdata_r <= correlator_value;
                A_CORR_PEAK:        rdata_r <= correlator_peak;
                A_CORR_STATUS:      rdata_r <= correlator_status;
                A_DPLL_STEP:        rdata_r <= dpll_nominal_step;
                A_DPLL_CFG:         rdata_r <= dpll_cfg_value;
                A_DPLL_PHASE:       rdata_r <= dpll_phase_acc;
                A_DPLL_FREQ:        rdata_r <= dpll_freq_word;
                A_DPLL_STATUS:      rdata_r <= dpll_status;
                A_CAL_OFFSET:       rdata_r <= cal_offset_value;
                A_CAL_GAIN:         rdata_r <= cal_gain_value;
                A_SELFTEST_CFG:     rdata_r <= selftest_cfg_value;
                A_SELFTEST_ERRORS:  rdata_r <= selftest_error_count;
                A_SELFTEST_SAMPLES: rdata_r <= selftest_sample_count;
                A_MODEM_CFG:        rdata_r <= modem_cfg_value;
                A_MODEM_STATUS:     rdata_r <= modem_status;
                A_DAC_MUX:          rdata_r <= dac_mux_value;
                default:            rdata_r <= 32'd0;
                endcase
            end else if (rvalid_r && s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

endmodule
