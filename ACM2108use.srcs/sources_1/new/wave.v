`timescale 1ns / 1ps

module wave (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire        phase_load,
    input  wire [3:0]  mode,
    input  wire [31:0] phase_inc,
    input  wire [31:0] phase_offset,
    input  wire [31:0] amp_offset,
    output reg  [7:0]  sample
);

    // 257 quarter-wave entries yield 1024 phase points per period.
    function [7:0] sine_quarter_1024;
        input [8:0] index;
        begin
            case (index)
            9'd0: sine_quarter_1024 = 8'd0;             9'd1: sine_quarter_1024 = 8'd1;             9'd2: sine_quarter_1024 = 8'd2;             9'd3: sine_quarter_1024 = 8'd2;
            9'd4: sine_quarter_1024 = 8'd3;             9'd5: sine_quarter_1024 = 8'd4;             9'd6: sine_quarter_1024 = 8'd5;             9'd7: sine_quarter_1024 = 8'd5;
            9'd8: sine_quarter_1024 = 8'd6;             9'd9: sine_quarter_1024 = 8'd7;             9'd10: sine_quarter_1024 = 8'd8;             9'd11: sine_quarter_1024 = 8'd9;
            9'd12: sine_quarter_1024 = 8'd9;             9'd13: sine_quarter_1024 = 8'd10;             9'd14: sine_quarter_1024 = 8'd11;             9'd15: sine_quarter_1024 = 8'd12;
            9'd16: sine_quarter_1024 = 8'd12;             9'd17: sine_quarter_1024 = 8'd13;             9'd18: sine_quarter_1024 = 8'd14;             9'd19: sine_quarter_1024 = 8'd15;
            9'd20: sine_quarter_1024 = 8'd16;             9'd21: sine_quarter_1024 = 8'd16;             9'd22: sine_quarter_1024 = 8'd17;             9'd23: sine_quarter_1024 = 8'd18;
            9'd24: sine_quarter_1024 = 8'd19;             9'd25: sine_quarter_1024 = 8'd19;             9'd26: sine_quarter_1024 = 8'd20;             9'd27: sine_quarter_1024 = 8'd21;
            9'd28: sine_quarter_1024 = 8'd22;             9'd29: sine_quarter_1024 = 8'd22;             9'd30: sine_quarter_1024 = 8'd23;             9'd31: sine_quarter_1024 = 8'd24;
            9'd32: sine_quarter_1024 = 8'd25;             9'd33: sine_quarter_1024 = 8'd26;             9'd34: sine_quarter_1024 = 8'd26;             9'd35: sine_quarter_1024 = 8'd27;
            9'd36: sine_quarter_1024 = 8'd28;             9'd37: sine_quarter_1024 = 8'd29;             9'd38: sine_quarter_1024 = 8'd29;             9'd39: sine_quarter_1024 = 8'd30;
            9'd40: sine_quarter_1024 = 8'd31;             9'd41: sine_quarter_1024 = 8'd32;             9'd42: sine_quarter_1024 = 8'd32;             9'd43: sine_quarter_1024 = 8'd33;
            9'd44: sine_quarter_1024 = 8'd34;             9'd45: sine_quarter_1024 = 8'd35;             9'd46: sine_quarter_1024 = 8'd35;             9'd47: sine_quarter_1024 = 8'd36;
            9'd48: sine_quarter_1024 = 8'd37;             9'd49: sine_quarter_1024 = 8'd38;             9'd50: sine_quarter_1024 = 8'd38;             9'd51: sine_quarter_1024 = 8'd39;
            9'd52: sine_quarter_1024 = 8'd40;             9'd53: sine_quarter_1024 = 8'd41;             9'd54: sine_quarter_1024 = 8'd41;             9'd55: sine_quarter_1024 = 8'd42;
            9'd56: sine_quarter_1024 = 8'd43;             9'd57: sine_quarter_1024 = 8'd44;             9'd58: sine_quarter_1024 = 8'd44;             9'd59: sine_quarter_1024 = 8'd45;
            9'd60: sine_quarter_1024 = 8'd46;             9'd61: sine_quarter_1024 = 8'd46;             9'd62: sine_quarter_1024 = 8'd47;             9'd63: sine_quarter_1024 = 8'd48;
            9'd64: sine_quarter_1024 = 8'd49;             9'd65: sine_quarter_1024 = 8'd49;             9'd66: sine_quarter_1024 = 8'd50;             9'd67: sine_quarter_1024 = 8'd51;
            9'd68: sine_quarter_1024 = 8'd51;             9'd69: sine_quarter_1024 = 8'd52;             9'd70: sine_quarter_1024 = 8'd53;             9'd71: sine_quarter_1024 = 8'd54;
            9'd72: sine_quarter_1024 = 8'd54;             9'd73: sine_quarter_1024 = 8'd55;             9'd74: sine_quarter_1024 = 8'd56;             9'd75: sine_quarter_1024 = 8'd56;
            9'd76: sine_quarter_1024 = 8'd57;             9'd77: sine_quarter_1024 = 8'd58;             9'd78: sine_quarter_1024 = 8'd58;             9'd79: sine_quarter_1024 = 8'd59;
            9'd80: sine_quarter_1024 = 8'd60;             9'd81: sine_quarter_1024 = 8'd61;             9'd82: sine_quarter_1024 = 8'd61;             9'd83: sine_quarter_1024 = 8'd62;
            9'd84: sine_quarter_1024 = 8'd63;             9'd85: sine_quarter_1024 = 8'd63;             9'd86: sine_quarter_1024 = 8'd64;             9'd87: sine_quarter_1024 = 8'd65;
            9'd88: sine_quarter_1024 = 8'd65;             9'd89: sine_quarter_1024 = 8'd66;             9'd90: sine_quarter_1024 = 8'd67;             9'd91: sine_quarter_1024 = 8'd67;
            9'd92: sine_quarter_1024 = 8'd68;             9'd93: sine_quarter_1024 = 8'd69;             9'd94: sine_quarter_1024 = 8'd69;             9'd95: sine_quarter_1024 = 8'd70;
            9'd96: sine_quarter_1024 = 8'd71;             9'd97: sine_quarter_1024 = 8'd71;             9'd98: sine_quarter_1024 = 8'd72;             9'd99: sine_quarter_1024 = 8'd72;
            9'd100: sine_quarter_1024 = 8'd73;             9'd101: sine_quarter_1024 = 8'd74;             9'd102: sine_quarter_1024 = 8'd74;             9'd103: sine_quarter_1024 = 8'd75;
            9'd104: sine_quarter_1024 = 8'd76;             9'd105: sine_quarter_1024 = 8'd76;             9'd106: sine_quarter_1024 = 8'd77;             9'd107: sine_quarter_1024 = 8'd78;
            9'd108: sine_quarter_1024 = 8'd78;             9'd109: sine_quarter_1024 = 8'd79;             9'd110: sine_quarter_1024 = 8'd79;             9'd111: sine_quarter_1024 = 8'd80;
            9'd112: sine_quarter_1024 = 8'd81;             9'd113: sine_quarter_1024 = 8'd81;             9'd114: sine_quarter_1024 = 8'd82;             9'd115: sine_quarter_1024 = 8'd82;
            9'd116: sine_quarter_1024 = 8'd83;             9'd117: sine_quarter_1024 = 8'd84;             9'd118: sine_quarter_1024 = 8'd84;             9'd119: sine_quarter_1024 = 8'd85;
            9'd120: sine_quarter_1024 = 8'd85;             9'd121: sine_quarter_1024 = 8'd86;             9'd122: sine_quarter_1024 = 8'd86;             9'd123: sine_quarter_1024 = 8'd87;
            9'd124: sine_quarter_1024 = 8'd88;             9'd125: sine_quarter_1024 = 8'd88;             9'd126: sine_quarter_1024 = 8'd89;             9'd127: sine_quarter_1024 = 8'd89;
            9'd128: sine_quarter_1024 = 8'd90;             9'd129: sine_quarter_1024 = 8'd90;             9'd130: sine_quarter_1024 = 8'd91;             9'd131: sine_quarter_1024 = 8'd91;
            9'd132: sine_quarter_1024 = 8'd92;             9'd133: sine_quarter_1024 = 8'd93;             9'd134: sine_quarter_1024 = 8'd93;             9'd135: sine_quarter_1024 = 8'd94;
            9'd136: sine_quarter_1024 = 8'd94;             9'd137: sine_quarter_1024 = 8'd95;             9'd138: sine_quarter_1024 = 8'd95;             9'd139: sine_quarter_1024 = 8'd96;
            9'd140: sine_quarter_1024 = 8'd96;             9'd141: sine_quarter_1024 = 8'd97;             9'd142: sine_quarter_1024 = 8'd97;             9'd143: sine_quarter_1024 = 8'd98;
            9'd144: sine_quarter_1024 = 8'd98;             9'd145: sine_quarter_1024 = 8'd99;             9'd146: sine_quarter_1024 = 8'd99;             9'd147: sine_quarter_1024 = 8'd100;
            9'd148: sine_quarter_1024 = 8'd100;             9'd149: sine_quarter_1024 = 8'd101;             9'd150: sine_quarter_1024 = 8'd101;             9'd151: sine_quarter_1024 = 8'd102;
            9'd152: sine_quarter_1024 = 8'd102;             9'd153: sine_quarter_1024 = 8'd102;             9'd154: sine_quarter_1024 = 8'd103;             9'd155: sine_quarter_1024 = 8'd103;
            9'd156: sine_quarter_1024 = 8'd104;             9'd157: sine_quarter_1024 = 8'd104;             9'd158: sine_quarter_1024 = 8'd105;             9'd159: sine_quarter_1024 = 8'd105;
            9'd160: sine_quarter_1024 = 8'd106;             9'd161: sine_quarter_1024 = 8'd106;             9'd162: sine_quarter_1024 = 8'd106;             9'd163: sine_quarter_1024 = 8'd107;
            9'd164: sine_quarter_1024 = 8'd107;             9'd165: sine_quarter_1024 = 8'd108;             9'd166: sine_quarter_1024 = 8'd108;             9'd167: sine_quarter_1024 = 8'd109;
            9'd168: sine_quarter_1024 = 8'd109;             9'd169: sine_quarter_1024 = 8'd109;             9'd170: sine_quarter_1024 = 8'd110;             9'd171: sine_quarter_1024 = 8'd110;
            9'd172: sine_quarter_1024 = 8'd111;             9'd173: sine_quarter_1024 = 8'd111;             9'd174: sine_quarter_1024 = 8'd111;             9'd175: sine_quarter_1024 = 8'd112;
            9'd176: sine_quarter_1024 = 8'd112;             9'd177: sine_quarter_1024 = 8'd112;             9'd178: sine_quarter_1024 = 8'd113;             9'd179: sine_quarter_1024 = 8'd113;
            9'd180: sine_quarter_1024 = 8'd113;             9'd181: sine_quarter_1024 = 8'd114;             9'd182: sine_quarter_1024 = 8'd114;             9'd183: sine_quarter_1024 = 8'd114;
            9'd184: sine_quarter_1024 = 8'd115;             9'd185: sine_quarter_1024 = 8'd115;             9'd186: sine_quarter_1024 = 8'd115;             9'd187: sine_quarter_1024 = 8'd116;
            9'd188: sine_quarter_1024 = 8'd116;             9'd189: sine_quarter_1024 = 8'd116;             9'd190: sine_quarter_1024 = 8'd117;             9'd191: sine_quarter_1024 = 8'd117;
            9'd192: sine_quarter_1024 = 8'd117;             9'd193: sine_quarter_1024 = 8'd118;             9'd194: sine_quarter_1024 = 8'd118;             9'd195: sine_quarter_1024 = 8'd118;
            9'd196: sine_quarter_1024 = 8'd118;             9'd197: sine_quarter_1024 = 8'd119;             9'd198: sine_quarter_1024 = 8'd119;             9'd199: sine_quarter_1024 = 8'd119;
            9'd200: sine_quarter_1024 = 8'd120;             9'd201: sine_quarter_1024 = 8'd120;             9'd202: sine_quarter_1024 = 8'd120;             9'd203: sine_quarter_1024 = 8'd120;
            9'd204: sine_quarter_1024 = 8'd121;             9'd205: sine_quarter_1024 = 8'd121;             9'd206: sine_quarter_1024 = 8'd121;             9'd207: sine_quarter_1024 = 8'd121;
            9'd208: sine_quarter_1024 = 8'd122;             9'd209: sine_quarter_1024 = 8'd122;             9'd210: sine_quarter_1024 = 8'd122;             9'd211: sine_quarter_1024 = 8'd122;
            9'd212: sine_quarter_1024 = 8'd122;             9'd213: sine_quarter_1024 = 8'd123;             9'd214: sine_quarter_1024 = 8'd123;             9'd215: sine_quarter_1024 = 8'd123;
            9'd216: sine_quarter_1024 = 8'd123;             9'd217: sine_quarter_1024 = 8'd123;             9'd218: sine_quarter_1024 = 8'd124;             9'd219: sine_quarter_1024 = 8'd124;
            9'd220: sine_quarter_1024 = 8'd124;             9'd221: sine_quarter_1024 = 8'd124;             9'd222: sine_quarter_1024 = 8'd124;             9'd223: sine_quarter_1024 = 8'd124;
            9'd224: sine_quarter_1024 = 8'd125;             9'd225: sine_quarter_1024 = 8'd125;             9'd226: sine_quarter_1024 = 8'd125;             9'd227: sine_quarter_1024 = 8'd125;
            9'd228: sine_quarter_1024 = 8'd125;             9'd229: sine_quarter_1024 = 8'd125;             9'd230: sine_quarter_1024 = 8'd125;             9'd231: sine_quarter_1024 = 8'd126;
            9'd232: sine_quarter_1024 = 8'd126;             9'd233: sine_quarter_1024 = 8'd126;             9'd234: sine_quarter_1024 = 8'd126;             9'd235: sine_quarter_1024 = 8'd126;
            9'd236: sine_quarter_1024 = 8'd126;             9'd237: sine_quarter_1024 = 8'd126;             9'd238: sine_quarter_1024 = 8'd126;             9'd239: sine_quarter_1024 = 8'd126;
            9'd240: sine_quarter_1024 = 8'd126;             9'd241: sine_quarter_1024 = 8'd126;             9'd242: sine_quarter_1024 = 8'd127;             9'd243: sine_quarter_1024 = 8'd127;
            9'd244: sine_quarter_1024 = 8'd127;             9'd245: sine_quarter_1024 = 8'd127;             9'd246: sine_quarter_1024 = 8'd127;             9'd247: sine_quarter_1024 = 8'd127;
            9'd248: sine_quarter_1024 = 8'd127;             9'd249: sine_quarter_1024 = 8'd127;             9'd250: sine_quarter_1024 = 8'd127;             9'd251: sine_quarter_1024 = 8'd127;
            9'd252: sine_quarter_1024 = 8'd127;             9'd253: sine_quarter_1024 = 8'd127;             9'd254: sine_quarter_1024 = 8'd127;             9'd255: sine_quarter_1024 = 8'd127;
            9'd256: sine_quarter_1024 = 8'd127;
            default: sine_quarter_1024 = 8'd127;
            endcase
        end
    endfunction


    function signed [8:0] wave_lookup;
        input [31:0] phase;
        input [3:0]  mode_i;
        reg [7:0] ramp;
        reg [7:0] index;
        begin
            ramp = phase[31:24];
            index = phase[29:22];
            case (mode_i[1:0])
            2'd1: wave_lookup = phase[31] ? -9'sd128 : 9'sd127;
            2'd2: wave_lookup = phase[31] ? 9'sd127 - $signed({1'b0, phase[30:23]}) :
                                           $signed({1'b0, phase[30:23]}) - 9'sd127;
            2'd3: wave_lookup = $signed({1'b0, ramp}) - 9'sd128;
            default: begin
                if (phase[31:30] == 2'b00) begin
                    wave_lookup = $signed({1'b0, sine_quarter_1024({1'b0, index})});
                end else if (phase[31:30] == 2'b01) begin
                    wave_lookup = $signed({1'b0, sine_quarter_1024(9'd256 - {1'b0, index})});
                end else if (phase[31:30] == 2'b10) begin
                    wave_lookup = -$signed({1'b0, sine_quarter_1024({1'b0, index})});
                end else begin
                    wave_lookup = -$signed({1'b0, sine_quarter_1024(9'd256 - {1'b0, index})});
                end
            end
            endcase
        end
    endfunction

    reg [31:0] phase_acc;
    reg [31:0] phase_lookup;
    reg [3:0] mode_lookup;
    reg signed [8:0] wave_raw;
    reg [7:0] wave_amp;
    reg [7:0] wave_offset;
    reg signed [17:0] wave_product;
    reg [7:0] wave_offset_d;
    reg signed [18:0] wave_scaled;

    always @(posedge clk) begin
        if (rst) begin
            phase_acc     <= 32'd0;
            phase_lookup  <= 32'd0;
            mode_lookup   <= 4'd0;
            wave_raw      <= 9'sd0;
            wave_amp      <= 8'h00;
            wave_offset   <= 8'h80;
            wave_product  <= 18'sd0;
            wave_offset_d <= 8'h80;
            wave_scaled   <= 19'sd128;
            sample        <= 8'h80;
        end else begin
            // Register the phase sum before the waveform lookup. This keeps
            // the 32-bit accumulator adder and the lookup mux in separate
            // 125 MHz timing stages while preserving the phase sequence.
            phase_lookup  <= phase_acc + phase_offset;
            mode_lookup   <= mode;
            wave_raw      <= wave_lookup(phase_lookup, mode_lookup);
            wave_amp      <= amp_offset[7:0];
            wave_offset   <= amp_offset[15:8];
            wave_product  <= $signed(wave_raw) * $signed({1'b0, wave_amp});
            wave_offset_d <= wave_offset;
            wave_scaled   <= $signed({1'b0, wave_offset_d}) + ($signed(wave_product) >>> 7);

            if (wave_scaled < 0) begin
                sample <= 8'd0;
            end else if (wave_scaled > 19'sd255) begin
                sample <= 8'hff;
            end else begin
                sample <= wave_scaled[7:0];
            end

            if (phase_load) begin
                phase_acc <= 32'd0;
            end else if (enable) begin
                phase_acc <= phase_acc + phase_inc;
            end
        end
    end

endmodule

module wavegen_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire        phase_load,
    input  wire [3:0]  mode,
    input  wire [31:0] phase_inc,
    input  wire [31:0] phase_offset,
    input  wire [31:0] amp_offset,
    output wire [7:0]  sample
);

    wave u_wave (
        .clk           (clk),
        .rst           (rst),
        .enable        (enable),
        .phase_load    (phase_load),
        .mode          (mode),
        .phase_inc     (phase_inc),
        .phase_offset  (phase_offset),
        .amp_offset    (amp_offset),
        .sample        (sample)
    );

endmodule
