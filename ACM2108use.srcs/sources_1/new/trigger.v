`timescale 1ns / 1ps

module trigger_axis #(
    parameter integer ADDR_WIDTH = 10
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [1:0]  mode,
    input  wire [7:0]  level,
    input  wire [7:0]  level_high,
    input  wire [ADDR_WIDTH:0] pre_count,
    input  wire [31:0] post_count,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output reg  [31:0] status
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_PRE  = 2'd1;
    localparam [1:0] ST_LIVE = 2'd2;

    localparam [1:0] TRIG_RISE   = 2'd0;
    localparam [1:0] TRIG_FALL   = 2'd1;
    localparam [1:0] TRIG_WINDOW = 2'd2;

    localparam integer DEPTH = (1 << ADDR_WIDTH);

    reg [32:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0] pre_left;
    reg [31:0] post_left;
    reg [1:0] state;
    reg prev_above;
    reg [32:0] out_data;
    reg out_valid;
    reg out_last;

    wire [7:0] sample = s_axis_tdata[7:0];
    wire above = (sample >= level);
    wire trig_rise = !prev_above && above;
    wire trig_fall = prev_above && !above;
    wire trig_window = (sample >= level) && (sample <= level_high);
    wire trigger_hit =
        (mode == TRIG_RISE && trig_rise) ||
        (mode == TRIG_FALL && trig_fall) ||
        (mode == TRIG_WINDOW && trig_window);
    wire idle_ready = enable && (state == ST_IDLE);
    wire live_ready = enable && (state == ST_LIVE) && m_axis_tready;
    wire in_fire = s_axis_tvalid && s_axis_tready;
    wire pre_fire = out_valid && m_axis_tready && (state == ST_PRE);
    wire live_fire = s_axis_tvalid && m_axis_tready && (state == ST_LIVE);

    assign s_axis_tready = enable ? (idle_ready || live_ready) : m_axis_tready;
    assign m_axis_tdata  = enable ? ((state == ST_PRE) ? out_data[31:0] : s_axis_tdata) : s_axis_tdata;
    assign m_axis_tvalid = enable ? ((state == ST_PRE) ? out_valid : ((state == ST_LIVE) && s_axis_tvalid)) : s_axis_tvalid;
    assign m_axis_tlast  = enable ? ((state == ST_PRE) ? out_last : (post_left == 32'd1)) : s_axis_tlast;

    always @(posedge aclk) begin
        if (!aresetn) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            rd_ptr <= {ADDR_WIDTH{1'b0}};
            pre_left <= {ADDR_WIDTH+1{1'b0}};
            post_left <= 32'd0;
            state <= ST_IDLE;
            prev_above <= 1'b0;
            out_data <= 33'd0;
            out_valid <= 1'b0;
            out_last <= 1'b0;
            status <= 32'd0;
        end else if (!enable) begin
            state <= ST_IDLE;
            out_valid <= 1'b0;
            status[0] <= 1'b0;
        end else begin
            if (in_fire) begin
                mem[wr_ptr] <= {s_axis_tlast, s_axis_tdata};
                wr_ptr <= wr_ptr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                prev_above <= above;
            end

            case (state)
            ST_IDLE: begin
                if (in_fire && trigger_hit) begin
                    rd_ptr <= wr_ptr - pre_count[ADDR_WIDTH-1:0];
                    pre_left <= pre_count + {{ADDR_WIDTH{1'b0}}, 1'b1};
                    post_left <= post_count;
                    state <= ST_PRE;
                    out_valid <= 1'b0;
                    status[0] <= ~status[0];
                    status[1] <= 1'b1;
                end
            end
            ST_PRE: begin
                if (!out_valid || m_axis_tready) begin
                    out_data <= mem[rd_ptr];
                    out_valid <= (pre_left != {ADDR_WIDTH+1{1'b0}});
                    out_last <= (pre_left == {{ADDR_WIDTH{1'b0}}, 1'b1}) && (post_left == 32'd0);
                    if (pre_left != {ADDR_WIDTH+1{1'b0}}) begin
                        rd_ptr <= rd_ptr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                        pre_left <= pre_left - {{ADDR_WIDTH{1'b0}}, 1'b1};
                    end
                end
                if (pre_fire && (pre_left == {ADDR_WIDTH+1{1'b0}})) begin
                    out_valid <= 1'b0;
                    state <= (post_left == 32'd0) ? ST_IDLE : ST_LIVE;
                end
            end
            ST_LIVE: begin
                if (live_fire) begin
                    if (post_left <= 32'd1) begin
                        state <= ST_IDLE;
                        post_left <= 32'd0;
                    end else begin
                        post_left <= post_left - 32'd1;
                    end
                end
            end
            default: begin
                state <= ST_IDLE;
            end
            endcase

            status[9:8] <= state;
        end
    end

endmodule
