`timescale 1ns / 1ps

module acm2108 (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aclk, FREQ_HZ 50000000, ASSOCIATED_BUSIF s_axi:m_axis_adc:s_axis_dac0:s_axis_dac1, ASSOCIATED_RESET s_axi_aresetn" *)
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

    input  wire        clk_adc_i,
    input  wire        clk_dac_i,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TDATA" *)
    output wire [31:0] m_axis_adc_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TVALID" *)
    output wire        m_axis_adc_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TREADY" *)
    input  wire        m_axis_adc_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TLAST" *)
    output wire        m_axis_adc_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac0 TDATA" *)
    input  wire [31:0] s_axis_dac0_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac0 TVALID" *)
    input  wire        s_axis_dac0_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac0 TREADY" *)
    output wire        s_axis_dac0_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac0 TLAST" *)
    input  wire        s_axis_dac0_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac1 TDATA" *)
    input  wire [31:0] s_axis_dac1_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac1 TVALID" *)
    input  wire        s_axis_dac1_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac1 TREADY" *)
    output wire        s_axis_dac1_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_dac1 TLAST" *)
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
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq_out INTERRUPT" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME irq_out, SENSITIVITY LEVEL_HIGH" *)
    output wire        irq_out
);

    platform u_platform (
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
        .clk_adc_i           (clk_adc_i),
        .clk_dac_i           (clk_dac_i),
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
        .clk_adj1_out        (clk_adj1_out),
        .clk_adj2_out        (clk_adj2_out),
        .clk_adj3_out        (clk_adj3_out),
        .gain_level_out      (gain_level_out),
        .irq_out             (irq_out)
    );

endmodule
