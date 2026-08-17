`timescale 1ns / 1ps

module phase_detect_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [7:0]  threshold,
    input  wire [7:0]  hysteresis,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] phase_samples,
    output reg  [31:0] period_samples,
    output reg  [31:0] status
);

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire [7:0] ch0 = s_axis_tdata[7:0];
    wire [7:0] ch1 = s_axis_tdata[23:16];
    wire [8:0] low_thr_ext = ({1'b0, threshold} > {1'b0, hysteresis}) ?
                             ({1'b0, threshold} - {1'b0, hysteresis}) : 9'd0;
    wire [8:0] high_thr_ext = ({1'b0, threshold} + {1'b0, hysteresis} > 9'd255) ?
                              9'd255 : ({1'b0, threshold} + {1'b0, hysteresis});
    wire [7:0] low_thr = low_thr_ext[7:0];
    wire [7:0] high_thr = high_thr_ext[7:0];

    reg below0;
    reg below1;
    reg [31:0] sample_time;
    reg [31:0] last_ch0_rise;
    reg [31:0] prev_ch0_rise;

    wire rise0 = below0 && (ch0 >= high_thr);
    wire rise1 = below1 && (ch1 >= high_thr);

    always @(posedge aclk) begin
        if (!aresetn) begin
            phase_samples  <= 32'd0;
            period_samples <= 32'd0;
            status         <= 32'd0;
            below0         <= 1'b1;
            below1         <= 1'b1;
            sample_time    <= 32'd0;
            last_ch0_rise  <= 32'd0;
            prev_ch0_rise  <= 32'd0;
        end else if (!enable) begin
            status[0] <= 1'b0;
        end else if (fire) begin
            sample_time <= sample_time + 32'd1;

            if (ch0 < low_thr) below0 <= 1'b1;
            if (ch0 >= high_thr) below0 <= 1'b0;
            if (ch1 < low_thr) below1 <= 1'b1;
            if (ch1 >= high_thr) below1 <= 1'b0;

            if (rise0) begin
                prev_ch0_rise <= last_ch0_rise;
                last_ch0_rise <= sample_time;
                period_samples <= sample_time - prev_ch0_rise;
                status[1] <= 1'b1;
            end

            if (rise1) begin
                phase_samples <= sample_time - last_ch0_rise;
                status[0] <= ~status[0];
            end
        end
    end

endmodule
