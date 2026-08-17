`timescale 1ns / 1ps

module adc_dsp_axis (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axis_adc:m_axis_adc, ASSOCIATED_RESET aresetn" *)
    input  wire        aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire        aresetn,

    input  wire [1:0]  mode,
    input  wire [7:0]  lms_mu,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_adc TDATA" *)
    input  wire [31:0] s_axis_adc_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_adc TVALID" *)
    input  wire        s_axis_adc_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_adc TREADY" *)
    output wire        s_axis_adc_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_adc TLAST" *)
    input  wire        s_axis_adc_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TDATA" *)
    output wire [31:0] m_axis_adc_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TVALID" *)
    output wire        m_axis_adc_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TREADY" *)
    input  wire        m_axis_adc_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_adc TLAST" *)
    output wire        m_axis_adc_tlast
);

    reg        out_valid;
    reg [31:0] out_data;
    reg        out_last;
    reg        pending_valid;
    reg        pending_last;
    wire       bypass = (mode == 2'd0);
    wire       output_ready = !out_valid || m_axis_adc_tready;
    wire       accept_sample = !bypass && s_axis_adc_tvalid && s_axis_adc_tready;
    wire [7:0] dsp0_sample;
    wire [7:0] dsp1_sample;

    assign s_axis_adc_tready = bypass ? m_axis_adc_tready : (output_ready && !pending_valid);
    assign m_axis_adc_tvalid = bypass ? s_axis_adc_tvalid : out_valid;
    assign m_axis_adc_tdata  = bypass ? s_axis_adc_tdata  : out_data;
    assign m_axis_adc_tlast  = bypass ? s_axis_adc_tlast  : out_last;

    adc_dsp_core u_adc_inline_dsp (
        .clk         (aclk),
        .rst         (!aresetn),
        .sample_en   (accept_sample),
        .mode        (mode),
        .lms_mu      (lms_mu),
        .adc0_sample (s_axis_adc_tdata[7:0]),
        .adc1_sample (s_axis_adc_tdata[23:16]),
        .dsp0_sample (dsp0_sample),
        .dsp1_sample (dsp1_sample)
    );

    always @(posedge aclk) begin
        if (!aresetn) begin
            out_valid     <= 1'b0;
            out_data      <= 32'd0;
            out_last      <= 1'b0;
            pending_valid <= 1'b0;
            pending_last  <= 1'b0;
        end else begin
            if (out_valid && m_axis_adc_tready) begin
                out_valid <= 1'b0;
            end

            if (accept_sample) begin
                pending_valid <= 1'b1;
                pending_last  <= s_axis_adc_tlast;
            end

            if (pending_valid && output_ready) begin
                out_valid     <= 1'b1;
                out_data      <= {8'd0, dsp1_sample, 8'd0, dsp0_sample};
                out_last      <= pending_last;
                pending_valid <= 1'b0;
            end
        end
    end

endmodule
