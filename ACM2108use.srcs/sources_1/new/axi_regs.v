`timescale 1ns / 1ps

module axi_regs (
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

    output reg  [31:0] ctrl_reg,
    output reg  [31:0] clk_ctrl_reg,
    output reg  [31:0] clk_step_ch1_reg,
    output reg  [31:0] clk_step_ch2_reg,
    output reg  [31:0] clk_step_ch3_reg,
    output reg  [2:0]  clk_load_pulse,
    output reg  [31:0] dac_src_reg,
    output reg  [31:0] dma_frame_len_reg,
    output reg  [31:0] adc_ctrl_reg,
    output reg  [31:0] dac0_phase_inc_reg,
    output reg  [31:0] dac0_amp_offset_reg,
    output reg  [31:0] dac1_phase_inc_reg,
    output reg  [31:0] dac1_amp_offset_reg,
    output reg  [31:0] dac0_phase_offset_reg,
    output reg  [31:0] dac1_phase_offset_reg,
    output reg         dac_phase_load_toggle,
    output wire        adc_fifo_reset,
    output reg  [31:0] meas_window_reg,
    output reg  [31:0] irq_enable_reg,
    input  wire [31:0] io_status,
    input  wire [31:0] clk_status,
    input  wire [31:0] meas_ch0_minmax,
    input  wire [31:0] meas_ch1_minmax,
    input  wire [31:0] meas_ch0_sum,
    input  wire [31:0] meas_ch1_sum,
    input  wire [31:0] meas_freq_count,
    input  wire [31:0] irq_event_flags,
    output wire        irq_out
);

    localparam [13:0] A_ID            = 14'h000;
    localparam [13:0] A_CTRL          = 14'h001;
    localparam [13:0] A_STATUS        = 14'h002;
    localparam [13:0] A_CLK_CTRL      = 14'h004;
    localparam [13:0] A_CLK_STEP_CH1  = 14'h005;
    localparam [13:0] A_CLK_STEP_CH2  = 14'h006;
    localparam [13:0] A_CLK_STEP_CH3  = 14'h007;
    localparam [13:0] A_CLK_LOAD      = 14'h008;
    localparam [13:0] A_CLK_STATUS    = 14'h009;
    localparam [13:0] A_DAC_SRC       = 14'h00c;
    localparam [13:0] A_DMA_FRAME_LEN = 14'h00d;
    localparam [13:0] A_ADC_CTRL      = 14'h00e;
    localparam [13:0] A_DAC0_PHASE    = 14'h010;
    localparam [13:0] A_DAC0_AMP_OFF  = 14'h011;
    localparam [13:0] A_DAC1_PHASE    = 14'h012;
    localparam [13:0] A_DAC1_AMP_OFF  = 14'h013;
    localparam [13:0] A_MEAS_WINDOW   = 14'h014;
    localparam [13:0] A_MEAS0_MINMAX  = 14'h015;
    localparam [13:0] A_MEAS1_MINMAX  = 14'h016;
    localparam [13:0] A_MEAS0_SUM     = 14'h017;
    localparam [13:0] A_MEAS1_SUM     = 14'h018;
    localparam [13:0] A_MEAS_FREQ     = 14'h019;
    localparam [13:0] A_IRQ_STATUS        = 14'h01a;
    localparam [13:0] A_IRQ_ENABLE        = 14'h01b;
    localparam [13:0] A_DAC0_PHASE_OFFSET = 14'h01c;
    localparam [13:0] A_DAC1_PHASE_OFFSET = 14'h01d;
    localparam [13:0] A_FIFO_CTRL        = 14'h01e;
    localparam [13:0] A_DAC_PHASE_LOAD   = 14'h01f;

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  wstrb;
        begin
            apply_wstrb = old_value;
            if (wstrb[0]) apply_wstrb[7:0]   = new_value[7:0];
            if (wstrb[1]) apply_wstrb[15:8]  = new_value[15:8];
            if (wstrb[2]) apply_wstrb[23:16] = new_value[23:16];
            if (wstrb[3]) apply_wstrb[31:24] = new_value[31:24];
        end
    endfunction

    reg        awready_r;
    reg        wready_r;
    reg        bvalid_r;
    reg        aw_seen;
    reg        w_seen;
    reg [31:0] awaddr_latched;
    reg [31:0] wdata_latched;
    reg [3:0]  wstrb_latched;
    reg [31:0] irq_status_reg;
    reg [4:0]  adc_fifo_reset_count;

    assign adc_fifo_reset = |adc_fifo_reset_count;

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = bvalid_r;
    assign irq_out        = |(irq_status_reg & irq_enable_reg);

    wire [13:0] wr_addr = awaddr_latched[15:2];

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            awready_r        <= 1'b0;
            wready_r         <= 1'b0;
            bvalid_r         <= 1'b0;
            aw_seen          <= 1'b0;
            w_seen           <= 1'b0;
            awaddr_latched   <= 32'd0;
            wdata_latched    <= 32'd0;
            wstrb_latched    <= 4'd0;
            ctrl_reg         <= 32'h0000_0000;
            clk_ctrl_reg     <= 32'h0000_0007;
            clk_step_ch1_reg <= 32'd0;
            clk_step_ch2_reg <= 32'd0;
            clk_step_ch3_reg <= 32'd0;
            clk_load_pulse   <= 3'b111;
            dac_src_reg      <= 32'd0;
            dma_frame_len_reg <= 32'd4096;
            adc_ctrl_reg      <= 32'd0;
            dac0_phase_inc_reg <= 32'h0100_0000;
            dac0_amp_offset_reg <= 32'h0000_4080;
            dac1_phase_inc_reg <= 32'h0100_0000;
            dac1_amp_offset_reg <= 32'h0000_4080;
            dac0_phase_offset_reg <= 32'd0;
            dac1_phase_offset_reg <= 32'd0;
            dac_phase_load_toggle <= 1'b0;
            meas_window_reg   <= 32'd4096;
            irq_enable_reg    <= 32'd0;
            irq_status_reg    <= 32'd0;
            adc_fifo_reset_count <= 5'd0;
        end else begin
            awready_r      <= 1'b0;
            wready_r       <= 1'b0;
            clk_load_pulse <= 3'b000;
            irq_status_reg <= irq_status_reg | irq_event_flags;
            if (adc_fifo_reset_count != 5'd0) begin
                adc_fifo_reset_count <= adc_fifo_reset_count - 5'd1;
            end

            if (!aw_seen && !bvalid_r) begin
                awready_r <= 1'b1;
                if (s_axi_awvalid) begin
                    aw_seen        <= 1'b1;
                    awaddr_latched <= s_axi_awaddr;
                end
            end

            if (!w_seen && !bvalid_r) begin
                wready_r <= 1'b1;
                if (s_axi_wvalid) begin
                    w_seen        <= 1'b1;
                    wdata_latched <= s_axi_wdata;
                    wstrb_latched <= s_axi_wstrb;
                end
            end

            if (aw_seen && w_seen && !bvalid_r) begin
                case (wr_addr)
                A_CTRL: begin
                    ctrl_reg <= apply_wstrb(ctrl_reg, wdata_latched, wstrb_latched);
                end
                A_CLK_CTRL: begin
                    clk_ctrl_reg <= apply_wstrb(clk_ctrl_reg, wdata_latched, wstrb_latched);
                end
                A_CLK_STEP_CH1: begin
                    clk_step_ch1_reg <= apply_wstrb(clk_step_ch1_reg, wdata_latched, wstrb_latched);
                end
                A_CLK_STEP_CH2: begin
                    clk_step_ch2_reg <= apply_wstrb(clk_step_ch2_reg, wdata_latched, wstrb_latched);
                end
                A_CLK_STEP_CH3: begin
                    clk_step_ch3_reg <= apply_wstrb(clk_step_ch3_reg, wdata_latched, wstrb_latched);
                end
                A_CLK_LOAD: begin
                    if (wstrb_latched[0]) begin
                        clk_load_pulse <= wdata_latched[2:0];
                    end
                end
                A_DAC_SRC: begin
                    dac_src_reg <= apply_wstrb(dac_src_reg, wdata_latched, wstrb_latched);
                end
                A_DMA_FRAME_LEN: begin
                    dma_frame_len_reg <= apply_wstrb(dma_frame_len_reg, wdata_latched, wstrb_latched);
                end
                A_ADC_CTRL: begin
                    adc_ctrl_reg <= apply_wstrb(adc_ctrl_reg, wdata_latched, wstrb_latched);
                end
                A_DAC0_PHASE: begin
                    dac0_phase_inc_reg <= apply_wstrb(dac0_phase_inc_reg, wdata_latched, wstrb_latched);
                end
                A_DAC0_AMP_OFF: begin
                    dac0_amp_offset_reg <= apply_wstrb(dac0_amp_offset_reg, wdata_latched, wstrb_latched);
                end
                A_DAC1_PHASE: begin
                    dac1_phase_inc_reg <= apply_wstrb(dac1_phase_inc_reg, wdata_latched, wstrb_latched);
                end
                A_DAC1_AMP_OFF: begin
                    dac1_amp_offset_reg <= apply_wstrb(dac1_amp_offset_reg, wdata_latched, wstrb_latched);
                end
                A_MEAS_WINDOW: begin
                    meas_window_reg <= apply_wstrb(meas_window_reg, wdata_latched, wstrb_latched);
                end
                A_IRQ_STATUS: begin
                    irq_status_reg <= (irq_status_reg | irq_event_flags) & ~apply_wstrb(32'd0, wdata_latched, wstrb_latched);
                end
                A_IRQ_ENABLE: begin
                    irq_enable_reg <= apply_wstrb(irq_enable_reg, wdata_latched, wstrb_latched);
                end
                A_DAC0_PHASE_OFFSET: begin
                    dac0_phase_offset_reg <= apply_wstrb(dac0_phase_offset_reg, wdata_latched, wstrb_latched);
                end
                A_DAC1_PHASE_OFFSET: begin
                    dac1_phase_offset_reg <= apply_wstrb(dac1_phase_offset_reg, wdata_latched, wstrb_latched);
                end
                A_FIFO_CTRL: begin
                    if (wstrb_latched[0] && wdata_latched[0]) begin
                        adc_fifo_reset_count <= 5'd16;
                    end
                end
                A_DAC_PHASE_LOAD: begin
                    if (wstrb_latched[0] && wdata_latched[0]) begin
                        dac_phase_load_toggle <= ~dac_phase_load_toggle;
                    end
                end
                default: begin
                end
                endcase

                aw_seen  <= 1'b0;
                w_seen   <= 1'b0;
                bvalid_r <= 1'b1;
            end else if (bvalid_r && s_axi_bready) begin
                bvalid_r <= 1'b0;
            end
        end
    end

    reg        arready_r;
    reg        rvalid_r;
    reg [31:0] rdata_r;

    assign s_axi_arready = arready_r;
    assign s_axi_rvalid  = rvalid_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;

    wire [13:0] rd_addr = s_axi_araddr[15:2];

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            arready_r <= 1'b0;
            rvalid_r  <= 1'b0;
            rdata_r   <= 32'd0;
        end else begin
            arready_r <= 1'b0;

            if (!rvalid_r && s_axi_arvalid) begin
                arready_r <= 1'b1;
                rvalid_r  <= 1'b1;
                case (rd_addr)
                A_ID:            rdata_r <= 32'h2108_0003;
                A_CTRL:          rdata_r <= ctrl_reg;
                A_STATUS:        rdata_r <= io_status;
                A_CLK_CTRL:      rdata_r <= clk_ctrl_reg;
                A_CLK_STEP_CH1:  rdata_r <= clk_step_ch1_reg;
                A_CLK_STEP_CH2:  rdata_r <= clk_step_ch2_reg;
                A_CLK_STEP_CH3:  rdata_r <= clk_step_ch3_reg;
                A_CLK_LOAD:      rdata_r <= 32'd0;
                A_CLK_STATUS:    rdata_r <= clk_status;
                A_DAC_SRC:       rdata_r <= dac_src_reg;
                A_DMA_FRAME_LEN: rdata_r <= dma_frame_len_reg;
                A_ADC_CTRL:      rdata_r <= adc_ctrl_reg;
                A_DAC0_PHASE:    rdata_r <= dac0_phase_inc_reg;
                A_DAC0_AMP_OFF:  rdata_r <= dac0_amp_offset_reg;
                A_DAC1_PHASE:    rdata_r <= dac1_phase_inc_reg;
                A_DAC1_AMP_OFF:  rdata_r <= dac1_amp_offset_reg;
                A_MEAS_WINDOW:   rdata_r <= meas_window_reg;
                A_MEAS0_MINMAX:  rdata_r <= meas_ch0_minmax;
                A_MEAS1_MINMAX:  rdata_r <= meas_ch1_minmax;
                A_MEAS0_SUM:     rdata_r <= meas_ch0_sum;
                A_MEAS1_SUM:     rdata_r <= meas_ch1_sum;
                A_MEAS_FREQ:     rdata_r <= meas_freq_count;
                A_IRQ_STATUS:    rdata_r <= irq_status_reg;
                A_IRQ_ENABLE:         rdata_r <= irq_enable_reg;
                A_DAC0_PHASE_OFFSET:  rdata_r <= dac0_phase_offset_reg;
                A_DAC1_PHASE_OFFSET:  rdata_r <= dac1_phase_offset_reg;
                A_FIFO_CTRL:          rdata_r <= {31'd0, adc_fifo_reset};
                A_DAC_PHASE_LOAD:     rdata_r <= 32'd0;
                default:              rdata_r <= 32'd0;
                endcase
            end else if (rvalid_r && s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

endmodule
