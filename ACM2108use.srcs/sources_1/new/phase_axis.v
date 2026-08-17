`timescale 1ns / 1ps

module phase_axis #(
    parameter integer ADDR_WIDTH = 12
) (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axis:m_axis, ASSOCIATED_RESET aresetn" *)
    input  wire                         aclk,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                         aresetn,

    input  wire [ADDR_WIDTH:0]          delay_samples,
    input  wire                         delay_load,
    input  wire [1:0]                   update_mode,
    output wire [ADDR_WIDTH-1:0]        active_delay,
    output wire [ADDR_WIDTH-1:0]        pending_delay,
    output wire                         pending_valid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input  wire [31:0]                  s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input  wire                         s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output wire                         s_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TLAST" *)
    input  wire                         s_axis_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output wire [31:0]                  m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output wire                         m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input  wire                         m_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TLAST" *)
    output wire                         m_axis_tlast
);

    localparam [1:0] UPDATE_IMMEDIATE = 2'd0;
    localparam [1:0] UPDATE_TLAST     = 2'd1;
    localparam [1:0] UPDATE_CH0_RISE  = 2'd2;
    localparam [1:0] UPDATE_CH1_RISE  = 2'd3;

    reg ch0_prev_below;
    reg ch1_prev_below;

    wire in_fire = s_axis_tvalid && s_axis_tready;
    wire ch0_below = (s_axis_tdata[7:0] < 8'h80);
    wire ch1_below = (s_axis_tdata[23:16] < 8'h80);
    wire ch0_rise = ch0_prev_below && !ch0_below;
    wire ch1_rise = ch1_prev_below && !ch1_below;
    wire safe_update =
        ((update_mode == UPDATE_TLAST)    && in_fire && s_axis_tlast) ||
        ((update_mode == UPDATE_CH0_RISE) && in_fire && ch0_rise) ||
        ((update_mode == UPDATE_CH1_RISE) && in_fire && ch1_rise);
    wire immediate_update = (update_mode == UPDATE_IMMEDIATE);
    wire [32:0] core_in = {s_axis_tlast, s_axis_tdata};
    wire [32:0] core_out;

    always @(posedge aclk) begin
        if (!aresetn) begin
            ch0_prev_below <= 1'b1;
            ch1_prev_below <= 1'b1;
        end else if (in_fire) begin
            ch0_prev_below <= ch0_below;
            ch1_prev_below <= ch1_below;
        end
    end

    phase #(
        .DATA_WIDTH (33),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_phase (
        .clk              (aclk),
        .rst              (!aresetn),
        .delay_request    (delay_samples),
        .delay_load       (delay_load),
        .safe_update      (safe_update),
        .immediate_update (immediate_update),
        .active_delay     (active_delay),
        .pending_delay    (pending_delay),
        .pending_valid    (pending_valid),
        .s_data           (core_in),
        .s_valid          (s_axis_tvalid),
        .s_ready          (s_axis_tready),
        .m_data           (core_out),
        .m_valid          (m_axis_tvalid),
        .m_ready          (m_axis_tready)
    );

    assign m_axis_tlast = core_out[32];
    assign m_axis_tdata = core_out[31:0];

endmodule

module phase_delay_axis #(
    parameter integer ADDR_WIDTH = 12
) (
    input  wire                         aclk,
    input  wire                         aresetn,
    input  wire [ADDR_WIDTH:0]          delay_samples,
    input  wire                         delay_load,
    input  wire [1:0]                   update_mode,
    output wire [ADDR_WIDTH-1:0]        active_delay,
    output wire [ADDR_WIDTH-1:0]        pending_delay,
    output wire                         pending_valid,
    input  wire [31:0]                  s_axis_tdata,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,
    output wire [31:0]                  m_axis_tdata,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast
);

    phase_axis #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_phase_axis (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .delay_samples (delay_samples),
        .delay_load    (delay_load),
        .update_mode   (update_mode),
        .active_delay  (active_delay),
        .pending_delay (pending_delay),
        .pending_valid (pending_valid),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast)
    );

endmodule
