`timescale 1ns / 1ps

module platform (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    input  wire        clk_adc_i,
    input  wire        clk_dac_i,

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
    output wire [7:0]  dac_data_0,
    output wire        dac_clk_1,
    output wire [7:0]  dac_data_1,

    output wire        clk_adj1_out,
    output wire        clk_adj2_out,
    output wire        clk_adj3_out,
    output wire        gain_level_out,
    output wire        irq_out
);

    wire [31:0] ctrl_reg;
    wire [31:0] clk_ctrl_reg;
    wire [31:0] clk_step_ch1_reg;
    wire [31:0] clk_step_ch2_reg;
    wire [31:0] clk_step_ch3_reg;
    wire [2:0]  clk_load_pulse;
    wire [31:0] dac_src_reg;
    wire [31:0] dma_frame_len_reg;
    wire [31:0] adc_ctrl_reg;
    wire [31:0] dac0_phase_inc_reg;
    wire [31:0] dac0_amp_offset_reg;
    wire [31:0] dac1_phase_inc_reg;
    wire [31:0] dac1_amp_offset_reg;
    wire [31:0] dac0_phase_offset_reg;
    wire [31:0] dac1_phase_offset_reg;
    wire [31:0] meas_window_reg;
    wire [31:0] irq_enable_reg;
    wire [31:0] io_status;
    wire [31:0] clk_status;
    wire [31:0] meas_ch0_minmax;
    wire [31:0] meas_ch1_minmax;
    wire [31:0] meas_ch0_sum;
    wire [31:0] meas_ch1_sum;
    wire [31:0] meas_freq_count;
    wire [31:0] irq_event_flags;
    wire        adc_fifo_reset;
    wire        dac_phase_load_toggle;

    assign gain_level_out = ctrl_reg[4];

    axi_regs u_regs (
        .s_axi_aclk          (s_axi_aclk),
        .s_axi_aresetn       (s_axi_aresetn),
        .s_axi_awaddr        (s_axi_awaddr),
        .s_axi_awvalid       (s_axi_awvalid),
        .s_axi_awready       (s_axi_awready),
        .s_axi_wdata         (s_axi_wdata),
        .s_axi_wstrb         (s_axi_wstrb),
        .s_axi_wvalid        (s_axi_wvalid),
        .s_axi_wready        (s_axi_wready),
        .s_axi_bresp         (s_axi_bresp),
        .s_axi_bvalid        (s_axi_bvalid),
        .s_axi_bready        (s_axi_bready),
        .s_axi_araddr        (s_axi_araddr),
        .s_axi_arvalid       (s_axi_arvalid),
        .s_axi_arready       (s_axi_arready),
        .s_axi_rdata         (s_axi_rdata),
        .s_axi_rresp         (s_axi_rresp),
        .s_axi_rvalid        (s_axi_rvalid),
        .s_axi_rready        (s_axi_rready),
        .ctrl_reg            (ctrl_reg),
        .clk_ctrl_reg        (clk_ctrl_reg),
        .clk_step_ch1_reg    (clk_step_ch1_reg),
        .clk_step_ch2_reg    (clk_step_ch2_reg),
        .clk_step_ch3_reg    (clk_step_ch3_reg),
        .clk_load_pulse      (clk_load_pulse),
        .dac_src_reg         (dac_src_reg),
        .dma_frame_len_reg   (dma_frame_len_reg),
        .adc_ctrl_reg        (adc_ctrl_reg),
        .dac0_phase_inc_reg   (dac0_phase_inc_reg),
        .dac0_amp_offset_reg  (dac0_amp_offset_reg),
        .dac1_phase_inc_reg   (dac1_phase_inc_reg),
        .dac1_amp_offset_reg  (dac1_amp_offset_reg),
        .dac0_phase_offset_reg(dac0_phase_offset_reg),
        .dac1_phase_offset_reg(dac1_phase_offset_reg),
        .dac_phase_load_toggle(dac_phase_load_toggle),
        .adc_fifo_reset      (adc_fifo_reset),
        .meas_window_reg     (meas_window_reg),
        .irq_enable_reg      (irq_enable_reg),
        .io_status           (io_status),
        .clk_status          (clk_status),
        .meas_ch0_minmax     (meas_ch0_minmax),
        .meas_ch1_minmax     (meas_ch1_minmax),
        .meas_ch0_sum        (meas_ch0_sum),
        .meas_ch1_sum        (meas_ch1_sum),
        .meas_freq_count     (meas_freq_count),
        .irq_event_flags     (irq_event_flags),
        .irq_out             (irq_out)
    );

    nco_bank #(
        .CHANNELS            (3)
    ) u_clock_bank (
        .clk                 (s_axi_aclk),
        .rst_n               (s_axi_aresetn),
        .enable              (clk_ctrl_reg[2:0]),
        .load                (clk_load_pulse),
        .step_flat           ({clk_step_ch3_reg, clk_step_ch2_reg, clk_step_ch1_reg}),
        .clk_out             ({clk_adj3_out, clk_adj2_out, clk_adj1_out}),
        .status              (clk_status)
    );

    io_stream u_io_stream (
        .s_axi_aclk          (s_axi_aclk),
        .s_axi_aresetn       (s_axi_aresetn),
        .clk_adc_i           (clk_adc_i),
        .clk_dac_i           (clk_dac_i),
        .adc_enable          (ctrl_reg[0]),
        .dac0_enable         (ctrl_reg[1]),
        .dac1_enable         (ctrl_reg[2]),
        .stream_enable       (ctrl_reg[3]),
        .dac_src_sel         (dac_src_reg[3:0]),
        .dma_frame_len       (dma_frame_len_reg),
        .adc_ctrl            (adc_ctrl_reg),
        .dac_wave_mode       ({dac_src_reg[11:8], dac_src_reg[7:4]}),
        .dac0_phase_inc      (dac0_phase_inc_reg),
        .dac0_amp_offset     (dac0_amp_offset_reg),
        .dac1_phase_inc      (dac1_phase_inc_reg),
        .dac1_amp_offset     (dac1_amp_offset_reg),
        .dac0_phase_offset   (dac0_phase_offset_reg),
        .dac1_phase_offset   (dac1_phase_offset_reg),
        .meas_window         (meas_window_reg),
        .adc_fifo_reset      (adc_fifo_reset),
        .dac_phase_load_toggle(dac_phase_load_toggle),
        .m_axis_adc_tdata    (m_axis_adc_tdata),
        .m_axis_adc_tvalid   (m_axis_adc_tvalid),
        .m_axis_adc_tready   (m_axis_adc_tready),
        .m_axis_adc_tlast    (m_axis_adc_tlast),
        .s_axis_dac0_tdata   (s_axis_dac0_tdata),
        .s_axis_dac0_tvalid  (s_axis_dac0_tvalid),
        .s_axis_dac0_tready  (s_axis_dac0_tready),
        .s_axis_dac0_tlast   (s_axis_dac0_tlast),
        .s_axis_dac1_tdata   (s_axis_dac1_tdata),
        .s_axis_dac1_tvalid  (s_axis_dac1_tvalid),
        .s_axis_dac1_tready  (s_axis_dac1_tready),
        .s_axis_dac1_tlast   (s_axis_dac1_tlast),
        .adc_clk_0           (adc_clk_0),
        .adc_data_0          (adc_data_0),
        .adc_clk_1           (adc_clk_1),
        .adc_data_1          (adc_data_1),
        .dac_clk_0           (dac_clk_0),
        .dac_data_0          (dac_data_0),
        .dac_clk_1           (dac_clk_1),
        .dac_data_1          (dac_data_1),
        .status              (io_status),
        .meas_ch0_minmax     (meas_ch0_minmax),
        .meas_ch1_minmax     (meas_ch1_minmax),
        .meas_ch0_sum        (meas_ch0_sum),
        .meas_ch1_sum        (meas_ch1_sum),
        .meas_freq_count     (meas_freq_count),
        .irq_event_flags     (irq_event_flags)
    );

endmodule
