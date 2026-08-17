`timescale 1ns / 1ps

module nco_bank #(
    parameter integer CHANNELS = 3
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [CHANNELS-1:0]          enable,
    input  wire [CHANNELS-1:0]          load,
    input  wire [(CHANNELS*32)-1:0]     step_flat,
    output wire [CHANNELS-1:0]          clk_out,
    output wire [31:0]                  status
);

    reg [31:0] step_reg [0:CHANNELS-1];
    reg [31:0] phase_acc [0:CHANNELS-1];
    reg [CHANNELS-1:0] clk_out_r;
    reg [CHANNELS-1:0] active_r;

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < CHANNELS; i = i + 1) begin
                step_reg[i]  <= 32'd0;
                phase_acc[i] <= 32'd0;
                clk_out_r[i] <= 1'b0;
            end
        end else begin
            for (i = 0; i < CHANNELS; i = i + 1) begin
                if (load[i]) begin
                    step_reg[i] <= step_flat[(i*32) +: 32];
                end

                if (enable[i]) begin
                    phase_acc[i] <= phase_acc[i] + step_reg[i];
                    clk_out_r[i] <= phase_acc[i][31];
                end else begin
                    phase_acc[i] <= 32'd0;
                    clk_out_r[i] <= 1'b0;
                end
            end
        end
    end

    always @* begin
        for (i = 0; i < CHANNELS; i = i + 1) begin
            active_r[i] = enable[i] && (step_reg[i] != 32'd0);
        end
    end

    assign clk_out = clk_out_r;
    assign status = {{(32-CHANNELS){1'b0}}, active_r};

endmodule
