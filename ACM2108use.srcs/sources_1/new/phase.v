`timescale 1ns / 1ps

module phase #(
    parameter integer DATA_WIDTH = 33,
    parameter integer ADDR_WIDTH = 12
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire [ADDR_WIDTH:0]          delay_request,
    input  wire                         delay_load,
    input  wire                         safe_update,
    input  wire                         immediate_update,
    output reg  [ADDR_WIDTH-1:0]        active_delay,
    output reg  [ADDR_WIDTH-1:0]        pending_delay,
    output reg                          pending_valid,

    input  wire [DATA_WIDTH-1:0]        s_data,
    input  wire                         s_valid,
    output wire                         s_ready,

    output reg  [DATA_WIDTH-1:0]        m_data,
    output reg                          m_valid,
    input  wire                         m_ready
);

    localparam integer DEPTH = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] delay_mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;

    function [ADDR_WIDTH-1:0] clamp_delay;
        input [ADDR_WIDTH:0] value;
        begin
            if (value[ADDR_WIDTH]) begin
                clamp_delay = {ADDR_WIDTH{1'b1}};
            end else begin
                clamp_delay = value[ADDR_WIDTH-1:0];
            end
        end
    endfunction

    wire can_accept = !m_valid || m_ready;
    wire in_fire = s_valid && can_accept;
    wire apply_update = pending_valid && (immediate_update || safe_update);
    wire [ADDR_WIDTH-1:0] next_delay = apply_update ? pending_delay : active_delay;
    wire [ADDR_WIDTH-1:0] rd_ptr = wr_ptr - next_delay;
    wire [DATA_WIDTH-1:0] delayed_data =
        (next_delay == {ADDR_WIDTH{1'b0}}) ? s_data : delay_mem[rd_ptr];

    assign s_ready = can_accept;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr        <= {ADDR_WIDTH{1'b0}};
            active_delay  <= {ADDR_WIDTH{1'b0}};
            pending_delay <= {ADDR_WIDTH{1'b0}};
            pending_valid <= 1'b0;
            m_data        <= {DATA_WIDTH{1'b0}};
            m_valid       <= 1'b0;
        end else begin
            if (delay_load) begin
                pending_delay <= clamp_delay(delay_request);
                pending_valid <= 1'b1;
            end

            if (m_valid && m_ready) begin
                m_valid <= 1'b0;
            end

            if (in_fire) begin
                delay_mem[wr_ptr] <= s_data;
                m_data            <= delayed_data;
                m_valid           <= 1'b1;
                wr_ptr            <= wr_ptr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};

                if (apply_update) begin
                    active_delay <= pending_delay;
                    if (!delay_load) begin
                        pending_valid <= 1'b0;
                    end
                end
            end else if (apply_update && immediate_update) begin
                active_delay <= pending_delay;
                if (!delay_load) begin
                    pending_valid <= 1'b0;
                end
            end
        end
    end

endmodule

module phase_delay_core #(
    parameter integer DATA_WIDTH = 33,
    parameter integer ADDR_WIDTH = 12
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire [ADDR_WIDTH:0]          delay_request,
    input  wire                         delay_load,
    input  wire                         safe_update,
    input  wire                         immediate_update,
    output wire [ADDR_WIDTH-1:0]        active_delay,
    output wire [ADDR_WIDTH-1:0]        pending_delay,
    output wire                         pending_valid,
    input  wire [DATA_WIDTH-1:0]        s_data,
    input  wire                         s_valid,
    output wire                         s_ready,
    output wire [DATA_WIDTH-1:0]        m_data,
    output wire                         m_valid,
    input  wire                         m_ready
);

    phase #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_phase (
        .clk              (clk),
        .rst              (rst),
        .delay_request    (delay_request),
        .delay_load       (delay_load),
        .safe_update      (safe_update),
        .immediate_update (immediate_update),
        .active_delay     (active_delay),
        .pending_delay    (pending_delay),
        .pending_valid    (pending_valid),
        .s_data           (s_data),
        .s_valid          (s_valid),
        .s_ready          (s_ready),
        .m_data           (m_data),
        .m_valid          (m_valid),
        .m_ready          (m_ready)
    );

endmodule
