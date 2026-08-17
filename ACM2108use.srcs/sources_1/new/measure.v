`timescale 1ns / 1ps

module measure_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [31:0] window_len,
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
    output reg  [31:0] status,
    output reg  [31:0] ch0_minmax,
    output reg  [31:0] ch1_minmax,
    output reg  [31:0] ch0_sum,
    output reg  [31:0] ch1_sum,
    output reg  [31:0] ch0_sumsq,
    output reg  [31:0] ch1_sumsq,
    output reg  [31:0] zero_cross,
    output reg  [31:0] phase_delta
);

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tlast  = s_axis_tlast;

    wire fire = s_axis_tvalid && s_axis_tready;
    wire [7:0] ch0 = s_axis_tdata[7:0];
    wire [7:0] ch1 = s_axis_tdata[23:16];
    wire [31:0] window_safe = (window_len == 32'd0) ? 32'd1 : window_len;
    wire [8:0] low_thr_ext = ({1'b0, threshold} > {1'b0, hysteresis}) ?
                             ({1'b0, threshold} - {1'b0, hysteresis}) : 9'd0;
    wire [8:0] high_thr_ext = ({1'b0, threshold} + {1'b0, hysteresis} > 9'd255) ?
                              9'd255 : ({1'b0, threshold} + {1'b0, hysteresis});
    wire [7:0] low_thr = low_thr_ext[7:0];
    wire [7:0] high_thr = high_thr_ext[7:0];

    reg [31:0] count;
    reg [7:0] min0;
    reg [7:0] max0;
    reg [7:0] min1;
    reg [7:0] max1;
    reg [31:0] sum0;
    reg [31:0] sum1;
    reg [31:0] sumsq0;
    reg [31:0] sumsq1;
    reg [15:0] cross0;
    reg [15:0] cross1;
    reg below0;
    reg below1;
    reg [31:0] sample_time;
    reg [31:0] last_ch0_rise;

    wire rise0 = below0 && (ch0 >= high_thr);
    wire rise1 = below1 && (ch1 >= high_thr);
    wire window_last = (count == window_safe - 32'd1);

    always @(posedge aclk) begin
        if (!aresetn) begin
            status        <= 32'd0;
            ch0_minmax    <= 32'd0;
            ch1_minmax    <= 32'd0;
            ch0_sum       <= 32'd0;
            ch1_sum       <= 32'd0;
            ch0_sumsq     <= 32'd0;
            ch1_sumsq     <= 32'd0;
            zero_cross    <= 32'd0;
            phase_delta   <= 32'd0;
            count         <= 32'd0;
            min0          <= 8'hff;
            max0          <= 8'h00;
            min1          <= 8'hff;
            max1          <= 8'h00;
            sum0          <= 32'd0;
            sum1          <= 32'd0;
            sumsq0        <= 32'd0;
            sumsq1        <= 32'd0;
            cross0        <= 16'd0;
            cross1        <= 16'd0;
            below0        <= 1'b1;
            below1        <= 1'b1;
            sample_time   <= 32'd0;
            last_ch0_rise <= 32'd0;
        end else if (!enable) begin
            count <= 32'd0;
            status[0] <= 1'b0;
        end else if (fire) begin
            sample_time <= sample_time + 32'd1;
            if (rise0) begin
                last_ch0_rise <= sample_time;
            end
            if (rise1) begin
                phase_delta <= sample_time - last_ch0_rise;
            end

            if (ch0 < low_thr) below0 <= 1'b1;
            if (ch0 >= high_thr) below0 <= 1'b0;
            if (ch1 < low_thr) below1 <= 1'b1;
            if (ch1 >= high_thr) below1 <= 1'b0;

            if (window_last) begin
                ch0_minmax <= {8'd0, (ch0 > max0) ? ch0 : max0, 8'd0, (ch0 < min0) ? ch0 : min0};
                ch1_minmax <= {8'd0, (ch1 > max1) ? ch1 : max1, 8'd0, (ch1 < min1) ? ch1 : min1};
                ch0_sum    <= sum0 + {24'd0, ch0};
                ch1_sum    <= sum1 + {24'd0, ch1};
                ch0_sumsq  <= sumsq0 + ({24'd0, ch0} * {24'd0, ch0});
                ch1_sumsq  <= sumsq1 + ({24'd0, ch1} * {24'd0, ch1});
                zero_cross <= {
                    cross1 + (rise1 ? 16'd1 : 16'd0),
                    cross0 + (rise0 ? 16'd1 : 16'd0)
                };
                status[0] <= ~status[0];
                status[1] <= 1'b1;
                count <= 32'd0;
                min0 <= 8'hff;
                max0 <= 8'h00;
                min1 <= 8'hff;
                max1 <= 8'h00;
                sum0 <= 32'd0;
                sum1 <= 32'd0;
                sumsq0 <= 32'd0;
                sumsq1 <= 32'd0;
                cross0 <= 16'd0;
                cross1 <= 16'd0;
            end else begin
                count <= count + 32'd1;
                if (ch0 < min0) min0 <= ch0;
                if (ch0 > max0) max0 <= ch0;
                if (ch1 < min1) min1 <= ch1;
                if (ch1 > max1) max1 <= ch1;
                sum0 <= sum0 + {24'd0, ch0};
                sum1 <= sum1 + {24'd0, ch1};
                sumsq0 <= sumsq0 + ({24'd0, ch0} * {24'd0, ch0});
                sumsq1 <= sumsq1 + ({24'd0, ch1} * {24'd0, ch1});
                if (rise0) cross0 <= cross0 + 16'd1;
                if (rise1) cross1 <= cross1 + 16'd1;
            end
        end
    end

endmodule
