`timescale 1ns / 1ps

module shell #(
    parameter integer DATA_WIDTH = 32
) (
    input  wire                  aclk,
    input  wire                  aresetn,

    input  wire [31:0]           s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [31:0]           s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,
    output wire [1:0]            s_axi_bresp,
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,
    input  wire [31:0]           s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    output wire [31:0]           s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready,

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,

    output wire [DATA_WIDTH-1:0] alg_s_axis_tdata,
    output wire                  alg_s_axis_tvalid,
    input  wire                  alg_s_axis_tready,
    output wire                  alg_s_axis_tlast,

    input  wire [DATA_WIDTH-1:0] alg_m_axis_tdata,
    input  wire                  alg_m_axis_tvalid,
    output wire                  alg_m_axis_tready,
    input  wire                  alg_m_axis_tlast,

    input  wire [31:0]           status_in,
    output wire [31:0]           cfg0,
    output wire [31:0]           cfg1,
    output wire [31:0]           cfg2,
    output wire [31:0]           cfg3,
    output wire [31:0]           cfg4,
    output wire [31:0]           cfg5,
    output wire [31:0]           cfg6,
    output wire [31:0]           cfg7,
    output wire                  alg_enable,
    output wire                  alg_bypass,
    output wire                  alg_soft_reset
);

    localparam [7:0] A_ID       = 8'h00;
    localparam [7:0] A_CTRL     = 8'h01;
    localparam [7:0] A_STATUS   = 8'h02;
    localparam [7:0] A_SAMPLES  = 8'h03;
    localparam [7:0] A_FRAMES   = 8'h04;
    localparam [7:0] A_CFG0     = 8'h10;
    localparam [7:0] A_CFG1     = 8'h11;
    localparam [7:0] A_CFG2     = 8'h12;
    localparam [7:0] A_CFG3     = 8'h13;
    localparam [7:0] A_CFG4     = 8'h14;
    localparam [7:0] A_CFG5     = 8'h15;
    localparam [7:0] A_CFG6     = 8'h16;
    localparam [7:0] A_CFG7     = 8'h17;

    reg [31:0] ctrl_r;
    reg [31:0] cfg_r [0:7];
    reg [31:0] sample_count;
    reg [31:0] frame_count;

    reg        awready_r;
    reg        wready_r;
    reg        bvalid_r;
    reg        aw_seen;
    reg        w_seen;
    reg [31:0] awaddr_latched;
    reg [31:0] wdata_latched;
    reg [3:0]  wstrb_latched;

    reg        arready_r;
    reg        rvalid_r;
    reg [31:0] rdata_r;

    integer i;

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  wstrb;
        begin
            apply_wstrb = old_value;
            if (wstrb[0]) apply_wstrb[7:0]   = new_value[7:0];
            if (wstrb[1]) apply_wstrb[15:8]  = new_value[15:8];
            if (wstrb[2]) apply_wstrb[23:16] = new_value[23:16];
            if (wstrb[3]) apply_wstrb[31:24] = new_value[31:24];
        end
    endfunction

    wire bypass = ctrl_r[1] || !ctrl_r[0];
    wire soft_reset = ctrl_r[2] || !aresetn;
    wire [7:0] wr_addr = awaddr_latched[9:2];
    wire [7:0] rd_addr = s_axi_araddr[9:2];
    wire m_fire = m_axis_tvalid && m_axis_tready;

    assign alg_enable     = ctrl_r[0];
    assign alg_bypass     = bypass;
    assign alg_soft_reset = soft_reset;
    assign cfg0 = cfg_r[0];
    assign cfg1 = cfg_r[1];
    assign cfg2 = cfg_r[2];
    assign cfg3 = cfg_r[3];
    assign cfg4 = cfg_r[4];
    assign cfg5 = cfg_r[5];
    assign cfg6 = cfg_r[6];
    assign cfg7 = cfg_r[7];

    assign s_axis_tready = bypass ? m_axis_tready : alg_s_axis_tready;
    assign m_axis_tdata  = bypass ? s_axis_tdata  : alg_m_axis_tdata;
    assign m_axis_tvalid = bypass ? s_axis_tvalid : alg_m_axis_tvalid;
    assign m_axis_tlast  = bypass ? s_axis_tlast  : alg_m_axis_tlast;

    assign alg_s_axis_tdata  = s_axis_tdata;
    assign alg_s_axis_tvalid = (!bypass) && s_axis_tvalid;
    assign alg_s_axis_tlast  = s_axis_tlast;
    assign alg_m_axis_tready = (!bypass) && m_axis_tready;

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_arready = arready_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rvalid  = rvalid_r;

    always @(posedge aclk) begin
        if (!aresetn) begin
            ctrl_r         <= 32'h0000_0003;
            sample_count   <= 32'd0;
            frame_count    <= 32'd0;
            awready_r      <= 1'b0;
            wready_r       <= 1'b0;
            bvalid_r       <= 1'b0;
            aw_seen        <= 1'b0;
            w_seen         <= 1'b0;
            awaddr_latched <= 32'd0;
            wdata_latched  <= 32'd0;
            wstrb_latched  <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                cfg_r[i] <= 32'd0;
            end
        end else begin
            awready_r <= 1'b0;
            wready_r  <= 1'b0;

            if (m_fire) begin
                sample_count <= sample_count + 32'd1;
                if (m_axis_tlast) begin
                    frame_count <= frame_count + 32'd1;
                end
            end

            if (!aw_seen && !bvalid_r) begin
                awready_r <= 1'b1;
                if (s_axi_awvalid) begin
                    aw_seen        <= 1'b1;
                    awaddr_latched <= s_axi_awaddr;
                end
            end

            if (!w_seen && !bvalid_r) begin
                wready_r <= 1'b1;
                if (s_axi_wvalid) begin
                    w_seen        <= 1'b1;
                    wdata_latched <= s_axi_wdata;
                    wstrb_latched <= s_axi_wstrb;
                end
            end

            if (aw_seen && w_seen && !bvalid_r) begin
                case (wr_addr)
                A_CTRL: ctrl_r <= apply_wstrb(ctrl_r, wdata_latched, wstrb_latched);
                A_CFG0: cfg_r[0] <= apply_wstrb(cfg_r[0], wdata_latched, wstrb_latched);
                A_CFG1: cfg_r[1] <= apply_wstrb(cfg_r[1], wdata_latched, wstrb_latched);
                A_CFG2: cfg_r[2] <= apply_wstrb(cfg_r[2], wdata_latched, wstrb_latched);
                A_CFG3: cfg_r[3] <= apply_wstrb(cfg_r[3], wdata_latched, wstrb_latched);
                A_CFG4: cfg_r[4] <= apply_wstrb(cfg_r[4], wdata_latched, wstrb_latched);
                A_CFG5: cfg_r[5] <= apply_wstrb(cfg_r[5], wdata_latched, wstrb_latched);
                A_CFG6: cfg_r[6] <= apply_wstrb(cfg_r[6], wdata_latched, wstrb_latched);
                A_CFG7: cfg_r[7] <= apply_wstrb(cfg_r[7], wdata_latched, wstrb_latched);
                default: begin
                end
                endcase

                aw_seen  <= 1'b0;
                w_seen   <= 1'b0;
                bvalid_r <= 1'b1;
            end else if (bvalid_r && s_axi_bready) begin
                bvalid_r <= 1'b0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            arready_r <= 1'b0;
            rvalid_r  <= 1'b0;
            rdata_r   <= 32'd0;
        end else begin
            arready_r <= 1'b0;
            if (!rvalid_r && s_axi_arvalid) begin
                arready_r <= 1'b1;
                rvalid_r  <= 1'b1;
                case (rd_addr)
                A_ID:      rdata_r <= 32'h5348_454c;
                A_CTRL:    rdata_r <= ctrl_r;
                A_STATUS:  rdata_r <= status_in;
                A_SAMPLES: rdata_r <= sample_count;
                A_FRAMES:  rdata_r <= frame_count;
                A_CFG0:    rdata_r <= cfg_r[0];
                A_CFG1:    rdata_r <= cfg_r[1];
                A_CFG2:    rdata_r <= cfg_r[2];
                A_CFG3:    rdata_r <= cfg_r[3];
                A_CFG4:    rdata_r <= cfg_r[4];
                A_CFG5:    rdata_r <= cfg_r[5];
                A_CFG6:    rdata_r <= cfg_r[6];
                A_CFG7:    rdata_r <= cfg_r[7];
                default:   rdata_r <= 32'd0;
                endcase
            end else if (rvalid_r && s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

endmodule
