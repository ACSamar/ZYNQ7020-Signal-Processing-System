`timescale 1ns / 1ps

module io_stream (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire        clk_adc_i,
    input  wire        clk_dac_i,

    input  wire        adc_enable,
    input  wire        dac0_enable,
    input  wire        dac1_enable,
    input  wire        stream_enable,
    input  wire [3:0]  dac_src_sel,
    input  wire [31:0] dma_frame_len,
    input  wire [31:0] adc_ctrl,
    input  wire [7:0]  dac_wave_mode,
    input  wire [31:0] dac0_phase_inc,
    input  wire [31:0] dac0_amp_offset,
    input  wire [31:0] dac1_phase_inc,
    input  wire [31:0] dac1_amp_offset,
    input  wire [31:0] dac0_phase_offset,
    input  wire [31:0] dac1_phase_offset,
    input  wire        adc_fifo_reset,
    input  wire        dac_phase_load_toggle,
    input  wire [31:0] meas_window,

    output wire [31:0] m_axis_adc_tdata,
    output wire        m_axis_adc_tvalid,
    input  wire        m_axis_adc_tready,
    output wire        m_axis_adc_tlast,

    input  wire [31:0] s_axis_dac0_tdata,
    input  wire        s_axis_dac0_tvalid,
    output wire        s_axis_dac0_tready,
    input  wire        s_axis_dac0_tlast,

    input  wire [31:0] s_axis_dac1_tdata,
    input  wire        s_axis_dac1_tvalid,
    output wire        s_axis_dac1_tready,
    input  wire        s_axis_dac1_tlast,

    output wire        adc_clk_0,
    input  wire [7:0]  adc_data_0,
    output wire        adc_clk_1,
    input  wire [7:0]  adc_data_1,

    output wire        dac_clk_0,
    output reg  [7:0]  dac_data_0,
    output wire        dac_clk_1,
    output reg  [7:0]  dac_data_1,

    output wire [31:0] status
    ,
    output reg  [31:0] meas_ch0_minmax,
    output reg  [31:0] meas_ch1_minmax,
    output reg  [31:0] meas_ch0_sum,
    output reg  [31:0] meas_ch1_sum,
    output reg  [31:0] meas_freq_count,
    output wire [31:0] irq_event_flags
);

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("ASYNC")
    ) u_adc_clk0_oddr (
        .Q  (adc_clk_0),
        .C  (clk_adc_i),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("ASYNC")
    ) u_adc_clk1_oddr (
        .Q  (adc_clk_1),
        .C  (clk_adc_i),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("ASYNC")
    ) u_dac_clk0_oddr (
        .Q  (dac_clk_0),
        .C  (clk_dac_i),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("ASYNC")
    ) u_dac_clk1_oddr (
        .Q  (dac_clk_1),
        .C  (clk_dac_i),
        .CE (1'b1),
        .D1 (1'b0),
        .D2 (1'b1),
        .R  (1'b0),
        .S  (1'b0)
    );

    (* ASYNC_REG = "TRUE" *) reg [1:0] adc_reset_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dac_reset_sync = 2'b00;

    always @(posedge clk_adc_i) begin
        adc_reset_sync <= {adc_reset_sync[0], s_axi_aresetn};
    end

    always @(posedge clk_dac_i) begin
        dac_reset_sync <= {dac_reset_sync[0], s_axi_aresetn};
    end

    wire adc_reset = !adc_reset_sync[1];
    wire dac_reset = !dac_reset_sync[1];

    (* ASYNC_REG = "TRUE" *) reg [1:0] adc_enable_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] adc_fifo_reset_sync = 2'b00;

    always @(posedge clk_adc_i) begin
        if (adc_reset) begin
            adc_enable_sync <= 2'b00;
            adc_fifo_reset_sync <= 2'b00;
        end else begin
            adc_enable_sync <= {adc_enable_sync[0], adc_enable};
            adc_fifo_reset_sync <= {adc_fifo_reset_sync[0], adc_fifo_reset};
        end
    end

    wire adc_enable_adc = adc_enable_sync[1];
    wire adc_fifo_reset_adc = adc_fifo_reset_sync[1];

    (* ASYNC_REG = "TRUE" *) reg [1:0] adc_single_shot_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] meas_enable_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [31:0] adc_ctrl_adc_meta = 32'd0;
    (* ASYNC_REG = "TRUE" *) reg [31:0] adc_ctrl_adc = 32'd0;
    (* ASYNC_REG = "TRUE" *) reg [31:0] meas_window_adc_meta = 32'd4096;
    (* ASYNC_REG = "TRUE" *) reg [31:0] meas_window_adc = 32'd4096;

    always @(posedge clk_adc_i) begin
        if (adc_reset) begin
            adc_single_shot_sync <= 2'b00;
            meas_enable_sync     <= 2'b00;
            adc_ctrl_adc_meta    <= 32'd0;
            adc_ctrl_adc         <= 32'd0;
            meas_window_adc_meta <= 32'd4096;
            meas_window_adc      <= 32'd4096;
        end else begin
            adc_single_shot_sync <= {adc_single_shot_sync[0], adc_ctrl[0]};
            meas_enable_sync     <= {meas_enable_sync[0], adc_ctrl[1]};
            adc_ctrl_adc_meta    <= adc_ctrl;
            adc_ctrl_adc         <= adc_ctrl_adc_meta;
            meas_window_adc_meta <= meas_window;
            meas_window_adc      <= meas_window_adc_meta;
        end
    end

    wire adc_single_shot_adc = adc_single_shot_sync[1];
    wire meas_enable_adc = meas_enable_sync[1];

    wire [206:0] dac_cfg_current = {
        dac_phase_load_toggle,
        dac1_phase_offset,
        dac0_phase_offset,
        dac1_amp_offset,
        dac1_phase_inc,
        dac0_amp_offset,
        dac0_phase_inc,
        dac_wave_mode,
        dac_src_sel,
        dac1_enable,
        dac0_enable
    };
    reg  [206:0] dac_cfg_payload = 207'd0;
    reg  [206:0] dac_cfg_sent = 207'd0;
    reg          dac_cfg_send = 1'b0;
    reg          dac_cfg_busy = 1'b0;
    wire         dac_cfg_rcv;
    wire [206:0] dac_cfg_dac;
    wire         dac_cfg_req;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            dac_cfg_payload <= 207'd0;
            dac_cfg_sent    <= 207'd0;
            dac_cfg_send    <= 1'b0;
            dac_cfg_busy    <= 1'b0;
        end else begin
            dac_cfg_send <= 1'b0;
            if (dac_cfg_rcv) begin
                dac_cfg_busy <= 1'b0;
            end
            if (!dac_cfg_busy && (dac_cfg_current != dac_cfg_sent)) begin
                dac_cfg_payload <= dac_cfg_current;
                dac_cfg_sent    <= dac_cfg_current;
                dac_cfg_send    <= 1'b1;
                dac_cfg_busy    <= 1'b1;
            end
        end
    end

    xpm_cdc_handshake #(
        .DEST_EXT_HSK   (0),
        .DEST_SYNC_FF   (2),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_SYNC_FF    (2),
        .WIDTH          (207)
    ) u_dac_cfg_cdc (
        .src_clk  (s_axi_aclk),
        .src_in   (dac_cfg_payload),
        .src_send (dac_cfg_send),
        .src_rcv  (dac_cfg_rcv),
        .dest_clk (clk_dac_i),
        .dest_out (dac_cfg_dac),
        .dest_req (dac_cfg_req),
        .dest_ack (1'b0)
    );

    wire       dac0_enable_dac = dac_cfg_dac[0];
    wire       dac1_enable_dac = dac_cfg_dac[1];
    wire [1:0] dac0_src_sel_dac = dac_cfg_dac[3:2];
    wire [1:0] dac1_src_sel_dac = dac_cfg_dac[5:4];
    wire [7:0] dac_wave_mode_dac = dac_cfg_dac[13:6];
    wire [31:0] dac0_phase_inc_dac = dac_cfg_dac[45:14];
    wire [31:0] dac0_amp_offset_dac = dac_cfg_dac[77:46];
    wire [31:0] dac1_phase_inc_dac = dac_cfg_dac[109:78];
    wire [31:0] dac1_amp_offset_dac = dac_cfg_dac[141:110];
    wire [31:0] dac0_phase_offset_dac = dac_cfg_dac[173:142];
    wire [31:0] dac1_phase_offset_dac = dac_cfg_dac[205:174];
    reg dac_phase_load_d = 1'b0;

    always @(posedge clk_dac_i) begin
        if (dac_reset) begin
            dac_phase_load_d <= 1'b0;
        end else begin
            dac_phase_load_d <= dac_cfg_dac[206];
        end
    end

    wire dac_phase_load_pulse = dac_cfg_dac[206] ^ dac_phase_load_d;
    wire unused_dac_cfg_req = dac_cfg_req;

    wire        adc_fifo_full;
    wire        adc_fifo_empty;
    wire [15:0] adc_fifo_dout;
    wire        adc_fifo_rd_en;
    wire        adc_fifo_wr_en = adc_enable_adc && !adc_fifo_full;

    wire        dac0_fifo_full;
    wire        dac0_fifo_empty;
    wire [7:0]  dac0_fifo_dout;
    reg         dac0_fifo_rd_en;

    wire        dac1_fifo_full;
    wire        dac1_fifo_empty;
    wire [7:0]  dac1_fifo_dout;
    reg         dac1_fifo_rd_en;

    wire        dsp0_fifo_full;
    wire        dsp0_fifo_empty;
    wire [7:0]  dsp0_fifo_dout;
    reg         dsp0_fifo_rd_en;

    wire        dsp1_fifo_full;
    wire        dsp1_fifo_empty;
    wire [7:0]  dsp1_fifo_dout;
    reg         dsp1_fifo_rd_en;

    reg [31:0] meas_count_adc;
    reg [7:0]  meas0_min_adc;
    reg [7:0]  meas0_max_adc;
    reg [7:0]  meas1_min_adc;
    reg [7:0]  meas1_max_adc;
    reg [31:0] meas0_sum_adc;
    reg [31:0] meas1_sum_adc;
    reg [15:0] meas0_cross_adc;
    reg [15:0] meas1_cross_adc;
    reg [7:0]  meas0_prev_adc;
    reg [7:0]  meas1_prev_adc;
    reg [31:0] meas0_minmax_hold_adc;
    reg [31:0] meas1_minmax_hold_adc;
    reg [31:0] meas0_sum_hold_adc;
    reg [31:0] meas1_sum_hold_adc;
    reg [31:0] meas_freq_hold_adc;
    reg        meas_done_toggle_adc;

    (* ASYNC_REG = "TRUE" *) reg [1:0] adc_fifo_full_axi_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dac0_fifo_empty_axi_sync = 2'b11;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dac1_fifo_empty_axi_sync = 2'b11;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dsp0_fifo_full_axi_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dsp1_fifo_full_axi_sync = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [2:0] meas_done_toggle_axi_sync = 3'b000;

    wire meas_update_pulse = meas_done_toggle_axi_sync[2] ^ meas_done_toggle_axi_sync[1];

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            adc_fifo_full_axi_sync   <= 2'b00;
            dac0_fifo_empty_axi_sync <= 2'b11;
            dac1_fifo_empty_axi_sync <= 2'b11;
            dsp0_fifo_full_axi_sync  <= 2'b00;
            dsp1_fifo_full_axi_sync  <= 2'b00;
            meas_done_toggle_axi_sync <= 3'b000;
            meas_ch0_minmax <= 32'd0;
            meas_ch1_minmax <= 32'd0;
            meas_ch0_sum <= 32'd0;
            meas_ch1_sum <= 32'd0;
            meas_freq_count <= 32'd0;
        end else begin
            adc_fifo_full_axi_sync   <= {adc_fifo_full_axi_sync[0], adc_fifo_full};
            dac0_fifo_empty_axi_sync <= {dac0_fifo_empty_axi_sync[0], dac0_fifo_empty};
            dac1_fifo_empty_axi_sync <= {dac1_fifo_empty_axi_sync[0], dac1_fifo_empty};
            dsp0_fifo_full_axi_sync  <= {dsp0_fifo_full_axi_sync[0], dsp0_fifo_full};
            dsp1_fifo_full_axi_sync  <= {dsp1_fifo_full_axi_sync[0], dsp1_fifo_full};
            meas_done_toggle_axi_sync <= {meas_done_toggle_axi_sync[1:0], meas_done_toggle_adc};
            if (meas_update_pulse) begin
                meas_ch0_minmax <= meas0_minmax_hold_adc;
                meas_ch1_minmax <= meas1_minmax_hold_adc;
                meas_ch0_sum <= meas0_sum_hold_adc;
                meas_ch1_sum <= meas1_sum_hold_adc;
                meas_freq_count <= meas_freq_hold_adc;
            end
        end
    end

    reg [7:0] adc0_negedge;
    reg [7:0] adc1_negedge;
    reg [7:0] adc0_sample_adc;
    reg [7:0] adc1_sample_adc;

    always @(negedge clk_adc_i) begin
        adc0_negedge <= adc_data_0;
        adc1_negedge <= adc_data_1;
    end

    always @(posedge clk_adc_i) begin
        if (adc_reset) begin
            adc0_sample_adc <= 8'h80;
            adc1_sample_adc <= 8'h80;
        end else begin
            adc0_sample_adc <= adc0_negedge;
            adc1_sample_adc <= adc1_negedge;
        end
    end

    wire [1:0] dsp_mode_adc = adc_ctrl_adc[5:4];
    wire dsp_fifo_wr_en = adc_enable_adc && !dsp0_fifo_full && !dsp1_fifo_full;
    wire [7:0] dsp0_sample_adc;
    wire [7:0] dsp1_sample_adc;

    adc_dsp_core u_adc_inline_dsp (
        .clk         (clk_adc_i),
        .rst         (adc_reset),
        .sample_en   (dsp_fifo_wr_en),
        .mode        (dsp_mode_adc),
        .lms_mu      (adc_ctrl_adc[15:8]),
        .adc0_sample (adc0_sample_adc),
        .adc1_sample (adc1_sample_adc),
        .dsp0_sample (dsp0_sample_adc),
        .dsp1_sample (dsp1_sample_adc)
    );

    wire [31:0] meas_window_safe_adc = (meas_window_adc == 32'd0) ? 32'd1 : meas_window_adc;
    wire meas_sample_fire_adc = adc_enable_adc && meas_enable_adc;
    wire meas_window_last_adc = (meas_count_adc == meas_window_safe_adc - 32'd1);

    always @(posedge clk_adc_i) begin
        if (adc_reset || !meas_enable_adc) begin
            meas_count_adc       <= 32'd0;
            meas0_min_adc        <= 8'hff;
            meas0_max_adc        <= 8'h00;
            meas1_min_adc        <= 8'hff;
            meas1_max_adc        <= 8'h00;
            meas0_sum_adc        <= 32'd0;
            meas1_sum_adc        <= 32'd0;
            meas0_cross_adc      <= 16'd0;
            meas1_cross_adc      <= 16'd0;
            meas0_prev_adc       <= 8'h80;
            meas1_prev_adc       <= 8'h80;
            meas0_minmax_hold_adc <= 32'd0;
            meas1_minmax_hold_adc <= 32'd0;
            meas0_sum_hold_adc   <= 32'd0;
            meas1_sum_hold_adc   <= 32'd0;
            meas_freq_hold_adc   <= 32'd0;
            meas_done_toggle_adc <= 1'b0;
        end else if (meas_sample_fire_adc) begin
            if (meas_window_last_adc) begin
                meas0_minmax_hold_adc <= {
                    8'd0,
                    (adc0_sample_adc > meas0_max_adc) ? adc0_sample_adc : meas0_max_adc,
                    8'd0,
                    (adc0_sample_adc < meas0_min_adc) ? adc0_sample_adc : meas0_min_adc
                };
                meas1_minmax_hold_adc <= {
                    8'd0,
                    (adc1_sample_adc > meas1_max_adc) ? adc1_sample_adc : meas1_max_adc,
                    8'd0,
                    (adc1_sample_adc < meas1_min_adc) ? adc1_sample_adc : meas1_min_adc
                };
                meas0_sum_hold_adc <= meas0_sum_adc + {24'd0, adc0_sample_adc};
                meas1_sum_hold_adc <= meas1_sum_adc + {24'd0, adc1_sample_adc};
                meas_freq_hold_adc <= {
                    meas1_cross_adc + ((meas1_prev_adc < 8'h80 && adc1_sample_adc >= 8'h80) ? 16'd1 : 16'd0),
                    meas0_cross_adc + ((meas0_prev_adc < 8'h80 && adc0_sample_adc >= 8'h80) ? 16'd1 : 16'd0)
                };
                meas_done_toggle_adc <= ~meas_done_toggle_adc;
                meas_count_adc  <= 32'd0;
                meas0_min_adc   <= 8'hff;
                meas0_max_adc   <= 8'h00;
                meas1_min_adc   <= 8'hff;
                meas1_max_adc   <= 8'h00;
                meas0_sum_adc   <= 32'd0;
                meas1_sum_adc   <= 32'd0;
                meas0_cross_adc <= 16'd0;
                meas1_cross_adc <= 16'd0;
            end else begin
                meas_count_adc <= meas_count_adc + 32'd1;
                if (adc0_sample_adc < meas0_min_adc) meas0_min_adc <= adc0_sample_adc;
                if (adc0_sample_adc > meas0_max_adc) meas0_max_adc <= adc0_sample_adc;
                if (adc1_sample_adc < meas1_min_adc) meas1_min_adc <= adc1_sample_adc;
                if (adc1_sample_adc > meas1_max_adc) meas1_max_adc <= adc1_sample_adc;
                meas0_sum_adc <= meas0_sum_adc + {24'd0, adc0_sample_adc};
                meas1_sum_adc <= meas1_sum_adc + {24'd0, adc1_sample_adc};
                if (meas0_prev_adc < 8'h80 && adc0_sample_adc >= 8'h80) meas0_cross_adc <= meas0_cross_adc + 16'd1;
                if (meas1_prev_adc < 8'h80 && adc1_sample_adc >= 8'h80) meas1_cross_adc <= meas1_cross_adc + 16'd1;
            end
            meas0_prev_adc <= adc0_sample_adc;
            meas1_prev_adc <= adc1_sample_adc;
        end
    end

    xpm_fifo_async #(
        .CDC_SYNC_STAGES     (2),
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (2048),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (8),
        .PROG_FULL_THRESH    (2040),
        .RD_DATA_COUNT_WIDTH (12),
        .READ_DATA_WIDTH     (16),
        .READ_MODE           ("fwft"),
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0000"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (16),
        .WR_DATA_COUNT_WIDTH (12)
    ) u_adc_pair_fifo (
        .sleep          (1'b0),
        .rst            (adc_reset | adc_fifo_reset_adc),
        .wr_clk         (clk_adc_i),
        .wr_en          (adc_fifo_wr_en),
        .din            ({adc1_sample_adc, adc0_sample_adc}),
        .full           (adc_fifo_full),
        .wr_rst_busy    (),
        .rd_clk         (s_axi_aclk),
        .rd_en          (adc_fifo_rd_en),
        .dout           (adc_fifo_dout),
        .empty          (adc_fifo_empty),
        .rd_rst_busy    (),
        .almost_empty   (),
        .almost_full    (),
        .data_valid     (),
        .dbiterr        (),
        .overflow       (),
        .prog_empty     (),
        .prog_full      (),
        .rd_data_count  (),
        .sbiterr        (),
        .underflow      (),
        .wr_ack         (),
        .wr_data_count  (),
        .injectdbiterr  (1'b0),
        .injectsbiterr  (1'b0)
    );

    xpm_fifo_async #(
        .CDC_SYNC_STAGES     (2),
        .DOUT_RESET_VALUE    ("80"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (2048),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (8),
        .PROG_FULL_THRESH    (2040),
        .RD_DATA_COUNT_WIDTH (12),
        .READ_DATA_WIDTH     (8),
        .READ_MODE           ("fwft"),
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0000"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (8),
        .WR_DATA_COUNT_WIDTH (12)
    ) u_dsp0_fifo (
        .sleep          (1'b0),
        .rst            (adc_reset | adc_fifo_reset_adc),
        .wr_clk         (clk_adc_i),
        .wr_en          (dsp_fifo_wr_en),
        .din            (dsp0_sample_adc),
        .full           (dsp0_fifo_full),
        .wr_rst_busy    (),
        .rd_clk         (clk_dac_i),
        .rd_en          (dsp0_fifo_rd_en),
        .dout           (dsp0_fifo_dout),
        .empty          (dsp0_fifo_empty),
        .rd_rst_busy    (),
        .almost_empty   (),
        .almost_full    (),
        .data_valid     (),
        .dbiterr        (),
        .overflow       (),
        .prog_empty     (),
        .prog_full      (),
        .rd_data_count  (),
        .sbiterr        (),
        .underflow      (),
        .wr_ack         (),
        .wr_data_count  (),
        .injectdbiterr  (1'b0),
        .injectsbiterr  (1'b0)
    );

    xpm_fifo_async #(
        .CDC_SYNC_STAGES     (2),
        .DOUT_RESET_VALUE    ("80"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (2048),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (8),
        .PROG_FULL_THRESH    (2040),
        .RD_DATA_COUNT_WIDTH (12),
        .READ_DATA_WIDTH     (8),
        .READ_MODE           ("fwft"),
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0000"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (8),
        .WR_DATA_COUNT_WIDTH (12)
    ) u_dsp1_fifo (
        .sleep          (1'b0),
        .rst            (adc_reset | adc_fifo_reset_adc),
        .wr_clk         (clk_adc_i),
        .wr_en          (dsp_fifo_wr_en),
        .din            (dsp1_sample_adc),
        .full           (dsp1_fifo_full),
        .wr_rst_busy    (),
        .rd_clk         (clk_dac_i),
        .rd_en          (dsp1_fifo_rd_en),
        .dout           (dsp1_fifo_dout),
        .empty          (dsp1_fifo_empty),
        .rd_rst_busy    (),
        .almost_empty   (),
        .almost_full    (),
        .data_valid     (),
        .dbiterr        (),
        .overflow       (),
        .prog_empty     (),
        .prog_full      (),
        .rd_data_count  (),
        .sbiterr        (),
        .underflow      (),
        .wr_ack         (),
        .wr_data_count  (),
        .injectdbiterr  (1'b0),
        .injectsbiterr  (1'b0)
    );

    reg [31:0] frame_count;
    reg        stream_enable_d;
    reg        capture_active;
    reg        capture_done;
    reg        capture_done_pulse;
    wire [31:0] frame_len_safe = (dma_frame_len == 32'd0) ? 32'd1 : dma_frame_len;
    wire adc_single_shot = adc_ctrl[0];
    wire stream_start = stream_enable && !stream_enable_d;
    wire adc_capture_gate = !adc_single_shot || capture_active;
    wire adc_axis_fire = m_axis_adc_tvalid && m_axis_adc_tready;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn || adc_fifo_reset) begin
            frame_count        <= 32'd0;
            stream_enable_d    <= 1'b0;
            capture_active     <= 1'b0;
            capture_done       <= 1'b0;
            capture_done_pulse <= 1'b0;
        end else begin
            stream_enable_d    <= stream_enable;
            capture_done_pulse <= 1'b0;

            if (!stream_enable) begin
                frame_count    <= 32'd0;
                capture_active <= 1'b0;
                capture_done   <= 1'b0;
            end else if (stream_start || !adc_single_shot) begin
                capture_active <= 1'b1;
                if (stream_start) begin
                    frame_count  <= 32'd0;
                    capture_done <= 1'b0;
                end
            end

            if (adc_axis_fire) begin
                if (frame_count == frame_len_safe - 32'd1) begin
                    frame_count <= 32'd0;
                    if (adc_single_shot) begin
                        capture_active     <= 1'b0;
                        capture_done       <= 1'b1;
                        capture_done_pulse <= 1'b1;
                    end
                end else begin
                    frame_count <= frame_count + 32'd1;
                end
            end
        end
    end

    assign m_axis_adc_tvalid = stream_enable && adc_capture_gate && !adc_fifo_empty;
    assign m_axis_adc_tdata  = {8'd0, adc_fifo_dout[15:8], 8'd0, adc_fifo_dout[7:0]};
    assign m_axis_adc_tlast  = (frame_count == frame_len_safe - 32'd1);
    assign adc_fifo_rd_en    = adc_axis_fire;

    wire dac0_axis_mode = (dac_src_sel[1:0] == 2'd1);
    wire dac1_axis_mode = (dac_src_sel[3:2] == 2'd1);
    wire dac0_wave_mode = (dac_src_sel[1:0] == 2'd2);
    wire dac1_wave_mode = (dac_src_sel[3:2] == 2'd2);
    wire dac0_dsp_mode = (dac_src_sel[1:0] == 2'd3);
    wire dac1_dsp_mode = (dac_src_sel[3:2] == 2'd3);
    wire dac0_axis_mode_dac = (dac0_src_sel_dac == 2'd1);
    wire dac1_axis_mode_dac = (dac1_src_sel_dac == 2'd1);
    wire dac0_wave_mode_dac = (dac0_src_sel_dac == 2'd2);
    wire dac1_wave_mode_dac = (dac1_src_sel_dac == 2'd2);
    wire dac0_dsp_mode_dac = (dac0_src_sel_dac == 2'd3);
    wire dac1_dsp_mode_dac = (dac1_src_sel_dac == 2'd3);

    wire [7:0] dac0_wave_sample;
    wire [7:0] dac1_wave_sample;

    wave u_dac0_wave (
        .clk          (clk_dac_i),
        .rst          (dac_reset),
        .enable       (dac0_enable_dac && dac0_wave_mode_dac),
        .phase_load   (dac_phase_load_pulse),
        .mode         (dac_wave_mode_dac[3:0]),
        .phase_inc    (dac0_phase_inc_dac),
        .phase_offset (dac0_phase_offset_dac),
        .amp_offset   (dac0_amp_offset_dac),
        .sample       (dac0_wave_sample)
    );

    wave u_dac1_wave (
        .clk          (clk_dac_i),
        .rst          (dac_reset),
        .enable       (dac1_enable_dac && dac1_wave_mode_dac),
        .phase_load   (dac_phase_load_pulse),
        .mode         (dac_wave_mode_dac[7:4]),
        .phase_inc    (dac1_phase_inc_dac),
        .phase_offset (dac1_phase_offset_dac),
        .amp_offset   (dac1_amp_offset_dac),
        .sample       (dac1_wave_sample)
    );

    assign s_axis_dac0_tready = dac0_enable && dac0_axis_mode && !dac0_fifo_full;
    assign s_axis_dac1_tready = dac1_enable && dac1_axis_mode && !dac1_fifo_full;

    xpm_fifo_async #(
        .CDC_SYNC_STAGES     (2),
        .DOUT_RESET_VALUE    ("80"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (2048),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (8),
        .PROG_FULL_THRESH    (2040),
        .RD_DATA_COUNT_WIDTH (12),
        .READ_DATA_WIDTH     (8),
        .READ_MODE           ("fwft"),
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0000"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (8),
        .WR_DATA_COUNT_WIDTH (12)
    ) u_dac0_fifo (
        .sleep          (1'b0),
        .rst            (~s_axi_aresetn),
        .wr_clk         (s_axi_aclk),
        .wr_en          (s_axis_dac0_tvalid && s_axis_dac0_tready),
        .din            (s_axis_dac0_tdata[7:0]),
        .full           (dac0_fifo_full),
        .wr_rst_busy    (),
        .rd_clk         (clk_dac_i),
        .rd_en          (dac0_fifo_rd_en),
        .dout           (dac0_fifo_dout),
        .empty          (dac0_fifo_empty),
        .rd_rst_busy    (),
        .almost_empty   (),
        .almost_full    (),
        .data_valid     (),
        .dbiterr        (),
        .overflow       (),
        .prog_empty     (),
        .prog_full      (),
        .rd_data_count  (),
        .sbiterr        (),
        .underflow      (),
        .wr_ack         (),
        .wr_data_count  (),
        .injectdbiterr  (1'b0),
        .injectsbiterr  (1'b0)
    );

    xpm_fifo_async #(
        .CDC_SYNC_STAGES     (2),
        .DOUT_RESET_VALUE    ("80"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (2048),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (8),
        .PROG_FULL_THRESH    (2040),
        .RD_DATA_COUNT_WIDTH (12),
        .READ_DATA_WIDTH     (8),
        .READ_MODE           ("fwft"),
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0000"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (8),
        .WR_DATA_COUNT_WIDTH (12)
    ) u_dac1_fifo (
        .sleep          (1'b0),
        .rst            (~s_axi_aresetn),
        .wr_clk         (s_axi_aclk),
        .wr_en          (s_axis_dac1_tvalid && s_axis_dac1_tready),
        .din            (s_axis_dac1_tdata[7:0]),
        .full           (dac1_fifo_full),
        .wr_rst_busy    (),
        .rd_clk         (clk_dac_i),
        .rd_en          (dac1_fifo_rd_en),
        .dout           (dac1_fifo_dout),
        .empty          (dac1_fifo_empty),
        .rd_rst_busy    (),
        .almost_empty   (),
        .almost_full    (),
        .data_valid     (),
        .dbiterr        (),
        .overflow       (),
        .prog_empty     (),
        .prog_full      (),
        .rd_data_count  (),
        .sbiterr        (),
        .underflow      (),
        .wr_ack         (),
        .wr_data_count  (),
        .injectdbiterr  (1'b0),
        .injectsbiterr  (1'b0)
    );

    always @(posedge clk_dac_i) begin
        if (dac_reset) begin
            dac0_fifo_rd_en <= 1'b0;
            dac1_fifo_rd_en <= 1'b0;
            dsp0_fifo_rd_en  <= 1'b0;
            dsp1_fifo_rd_en  <= 1'b0;
            dac_data_0      <= 8'h80;
            dac_data_1      <= 8'h80;
        end else begin
            dac0_fifo_rd_en <= dac0_enable_dac && dac0_axis_mode_dac && !dac0_fifo_empty;
            dac1_fifo_rd_en <= dac1_enable_dac && dac1_axis_mode_dac && !dac1_fifo_empty;
            dsp0_fifo_rd_en  <= dac0_enable_dac && dac0_dsp_mode_dac && !dsp0_fifo_empty;
            dsp1_fifo_rd_en  <= dac1_enable_dac && dac1_dsp_mode_dac && !dsp1_fifo_empty;

            if (!dac0_enable_dac) begin
                dac_data_0 <= 8'h80;
            end else if (dac0_axis_mode_dac && !dac0_fifo_empty) begin
                dac_data_0 <= dac0_fifo_dout;
            end else if (dac0_wave_mode_dac) begin
                dac_data_0 <= dac0_wave_sample;
            end else if (dac0_dsp_mode_dac && !dsp0_fifo_empty) begin
                dac_data_0 <= dsp0_fifo_dout;
            end else if (!dac0_axis_mode_dac) begin
                dac_data_0 <= 8'h80;
            end

            if (!dac1_enable_dac) begin
                dac_data_1 <= 8'h80;
            end else if (dac1_axis_mode_dac && !dac1_fifo_empty) begin
                dac_data_1 <= dac1_fifo_dout;
            end else if (dac1_wave_mode_dac) begin
                dac_data_1 <= dac1_wave_sample;
            end else if (dac1_dsp_mode_dac && !dsp1_fifo_empty) begin
                dac_data_1 <= dsp1_fifo_dout;
            end else if (!dac1_axis_mode_dac) begin
                dac_data_1 <= 8'h80;
            end
        end
    end

    reg adc_fifo_full_axi_d;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            adc_fifo_full_axi_d <= 1'b0;
        end else begin
            adc_fifo_full_axi_d <= adc_fifo_full_axi_sync[1];
        end
    end

    wire adc_fifo_full_rise = adc_fifo_full_axi_sync[1] && !adc_fifo_full_axi_d;

    assign irq_event_flags = {
        29'd0,
        adc_fifo_full_rise,
        meas_update_pulse,
        capture_done_pulse
    };

    assign status = {
        12'd0,
        dsp1_fifo_full_axi_sync[1],
        dsp0_fifo_full_axi_sync[1],
        dac1_dsp_mode,
        dac0_dsp_mode,
        meas_update_pulse,
        capture_done,
        dac1_wave_mode,
        dac0_wave_mode,
        dac1_fifo_full,
        dac0_fifo_full,
        adc_fifo_full_axi_sync[1],
        dac1_fifo_empty_axi_sync[1],
        dac0_fifo_empty_axi_sync[1],
        adc_fifo_empty,
        dac1_axis_mode,
        dac0_axis_mode,
        stream_enable,
        dac1_enable,
        dac0_enable,
        adc_enable
    };

endmodule
