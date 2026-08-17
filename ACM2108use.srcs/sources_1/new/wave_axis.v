`timescale 1ns / 1ps

module wave_axis (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF m_axis_dac, ASSOCIATED_RESET aresetn" *)
    input  wire        aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire        aresetn,

    input  wire        enable,
    input  wire [3:0]  mode,
    input  wire [31:0] phase_inc,
    input  wire [31:0] amp_offset,
    input  wire [31:0] frame_len,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_dac TDATA" *)
    output wire [31:0] m_axis_dac_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_dac TVALID" *)
    output wire        m_axis_dac_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_dac TREADY" *)
    input  wire        m_axis_dac_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_dac TLAST" *)
    output wire        m_axis_dac_tlast
);

    wire [7:0] sample;
    wire axis_fire = m_axis_dac_tvalid && m_axis_dac_tready;
    wire [31:0] frame_len_safe = (frame_len == 32'd0) ? 32'd1 : frame_len;
    reg [31:0] frame_count;

    assign m_axis_dac_tvalid = enable;
    assign m_axis_dac_tdata  = {24'd0, sample};
    assign m_axis_dac_tlast  = (frame_count == frame_len_safe - 32'd1);

    wave u_wave (
        .clk        (aclk),
        .rst        (!aresetn),
        .enable     (axis_fire),
        .phase_load (!enable),
        .mode       (mode),
        .phase_inc  (phase_inc),
        .phase_offset(32'd0),
        .amp_offset (amp_offset),
        .sample     (sample)
    );

    always @(posedge aclk) begin
        if (!aresetn || !enable) begin
            frame_count <= 32'd0;
        end else if (axis_fire) begin
            if (m_axis_dac_tlast) begin
                frame_count <= 32'd0;
            end else begin
                frame_count <= frame_count + 32'd1;
            end
        end
    end

endmodule

module wavegen_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [3:0]  mode,
    input  wire [31:0] phase_inc,
    input  wire [31:0] amp_offset,
    input  wire [31:0] frame_len,
    output wire [31:0] m_axis_dac_tdata,
    output wire        m_axis_dac_tvalid,
    input  wire        m_axis_dac_tready,
    output wire        m_axis_dac_tlast
);

    wave_axis u_wave_axis (
        .aclk              (aclk),
        .aresetn           (aresetn),
        .enable            (enable),
        .mode              (mode),
        .phase_inc         (phase_inc),
        .amp_offset        (amp_offset),
        .frame_len         (frame_len),
        .m_axis_dac_tdata  (m_axis_dac_tdata),
        .m_axis_dac_tvalid (m_axis_dac_tvalid),
        .m_axis_dac_tready (m_axis_dac_tready),
        .m_axis_dac_tlast  (m_axis_dac_tlast)
    );

endmodule
