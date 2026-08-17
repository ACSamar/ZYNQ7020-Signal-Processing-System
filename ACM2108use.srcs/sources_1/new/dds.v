`timescale 1ns / 1ps

module dds (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [1:0]  wave_mode,
    input  wire [2:0]  mod_mode,
    input  wire [31:0] carrier_step,
    input  wire [31:0] phase_offset,
    input  wire [31:0] amp_offset,
    input  wire [31:0] sweep_step,
    input  wire [31:0] sweep_min,
    input  wire [31:0] sweep_max,
    input  wire [31:0] fsk_step0,
    input  wire [31:0] fsk_step1,
    input  wire        key,
    input  wire [7:0]  mod_sample,
    output reg  [7:0]  sample
);

    localparam [2:0] MOD_OFF   = 3'd0;
    localparam [2:0] MOD_AM    = 3'd1;
    localparam [2:0] MOD_FSK   = 3'd2;
    localparam [2:0] MOD_PSK   = 3'd3;
    localparam [2:0] MOD_ASK   = 3'd4;
    localparam [2:0] MOD_SWEEP = 3'd5;

    function signed [9:0] wave_lookup;
        input [31:0] phase;
        input [1:0]  mode_i;
        reg [7:0] ramp;
        begin
            ramp = phase[31:24];
            case (mode_i)
            2'd1: wave_lookup = phase[31] ? -10'sd128 : 10'sd127;
            2'd2: wave_lookup = phase[31] ? $signed({1'b0, ~phase[30:23]}) - 10'sd128 :
                                           $signed({1'b0,  phase[30:23]}) - 10'sd128;
            2'd3: wave_lookup = $signed({1'b0, ramp}) - 10'sd128;
            default: begin
                if (phase[31:30] == 2'b00) begin
                    wave_lookup = $signed({1'b0, phase[29:22]});
                end else if (phase[31:30] == 2'b01) begin
                    wave_lookup = 10'sd127 - $signed({1'b0, phase[29:22]});
                end else if (phase[31:30] == 2'b10) begin
                    wave_lookup = -$signed({1'b0, phase[29:22]});
                end else begin
                    wave_lookup = $signed({1'b0, phase[29:22]}) - 10'sd127;
                end
            end
            endcase
        end
    endfunction

    reg [31:0] phase_acc;
    reg [31:0] step_r;
    reg        sweep_dir;
    reg signed [9:0] raw_r;
    reg signed [20:0] scaled_r;
    reg [7:0] amp_r;
    reg [7:0] offset_r;
    reg [31:0] phase_word;
    reg signed [20:0] out_signed;

    always @(posedge clk) begin
        if (rst) begin
            phase_acc  <= 32'd0;
            step_r     <= 32'd0;
            sweep_dir  <= 1'b0;
            raw_r      <= 10'sd0;
            scaled_r   <= 21'sd0;
            amp_r      <= 8'd0;
            offset_r   <= 8'h80;
            phase_word <= 32'd0;
            out_signed <= 21'sd128;
            sample     <= 8'h80;
        end else begin
            step_r <= carrier_step;
            if (mod_mode == MOD_FSK) begin
                step_r <= key ? fsk_step1 : fsk_step0;
            end else if (mod_mode == MOD_SWEEP) begin
                if (step_r < sweep_min) begin
                    step_r <= sweep_min;
                    sweep_dir <= 1'b0;
                end else if (step_r > sweep_max) begin
                    step_r <= sweep_max;
                    sweep_dir <= 1'b1;
                end else if (sweep_dir) begin
                    step_r <= step_r - sweep_step;
                    if (step_r <= sweep_min + sweep_step) sweep_dir <= 1'b0;
                end else begin
                    step_r <= step_r + sweep_step;
                    if (step_r >= sweep_max - sweep_step) sweep_dir <= 1'b1;
                end
            end

            amp_r <= amp_offset[7:0];
            if (mod_mode == MOD_AM) begin
                amp_r <= (({8'd0, amp_offset[7:0]} * {8'd0, mod_sample}) >> 8);
            end else if (mod_mode == MOD_ASK && !key) begin
                amp_r <= amp_offset[7:0] >> 2;
            end
            offset_r <= amp_offset[15:8];

            phase_word <= phase_acc + phase_offset + ((mod_mode == MOD_PSK && key) ? 32'h8000_0000 : 32'd0);
            raw_r <= wave_lookup(phase_word, wave_mode);
            scaled_r <= $signed(raw_r) * $signed({1'b0, amp_r});
            out_signed <= $signed({1'b0, offset_r}) + (scaled_r >>> 7);

            if (out_signed < 0) begin
                sample <= 8'd0;
            end else if (out_signed > 21'sd255) begin
                sample <= 8'hff;
            end else begin
                sample <= out_signed[7:0];
            end

            if (enable) begin
                phase_acc <= phase_acc + step_r;
            end
        end
    end

endmodule

module dds_axis (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        enable,
    input  wire [1:0]  wave_mode,
    input  wire [2:0]  mod_mode,
    input  wire [31:0] carrier_step,
    input  wire [31:0] phase_offset,
    input  wire [31:0] amp_offset,
    input  wire [31:0] sweep_step,
    input  wire [31:0] sweep_min,
    input  wire [31:0] sweep_max,
    input  wire [31:0] fsk_step0,
    input  wire [31:0] fsk_step1,
    input  wire        key,
    input  wire [7:0]  mod_sample,
    input  wire [31:0] frame_len,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    wire [7:0] sample;
    wire axis_fire = m_axis_tvalid && m_axis_tready;
    wire [31:0] frame_len_safe = (frame_len == 32'd0) ? 32'd1 : frame_len;
    reg [31:0] frame_count;

    assign m_axis_tvalid = enable;
    assign m_axis_tdata = {24'd0, sample};
    assign m_axis_tlast = (frame_count == frame_len_safe - 32'd1);

    dds u_dds (
        .clk          (aclk),
        .rst          (!aresetn),
        .enable       (axis_fire),
        .wave_mode    (wave_mode),
        .mod_mode     (mod_mode),
        .carrier_step (carrier_step),
        .phase_offset (phase_offset),
        .amp_offset   (amp_offset),
        .sweep_step   (sweep_step),
        .sweep_min    (sweep_min),
        .sweep_max    (sweep_max),
        .fsk_step0    (fsk_step0),
        .fsk_step1    (fsk_step1),
        .key          (key),
        .mod_sample   (mod_sample),
        .sample       (sample)
    );

    always @(posedge aclk) begin
        if (!aresetn || !enable) begin
            frame_count <= 32'd0;
        end else if (axis_fire) begin
            if (m_axis_tlast) begin
                frame_count <= 32'd0;
            end else begin
                frame_count <= frame_count + 32'd1;
            end
        end
    end

endmodule
