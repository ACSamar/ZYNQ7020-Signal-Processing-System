`timescale 1ns / 1ps

module wave_ram #(
    parameter integer ADDR_WIDTH = 12
) (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    localparam integer DEPTH = (1 << ADDR_WIDTH);
    localparam [15:0] A_CTRL   = 16'h0000;
    localparam [15:0] A_LEN    = 16'h0001;
    localparam [15:0] A_START  = 16'h0002;
    localparam [15:0] A_STATUS = 16'h0003;
    localparam [15:0] A_RAM    = 16'h0400;

    reg [7:0] ram [0:DEPTH-1];
    reg [31:0] ctrl_r;
    reg [31:0] length_r;
    reg [ADDR_WIDTH-1:0] start_r;
    reg [ADDR_WIDTH-1:0] rd_addr;
    reg done_r;

    reg awready_r;
    reg wready_r;
    reg bvalid_r;
    reg aw_seen;
    reg w_seen;
    reg [31:0] awaddr_latched;
    reg [31:0] wdata_latched;
    reg [3:0]  wstrb_latched;
    reg arready_r;
    reg rvalid_r;
    reg [31:0] rdata_r;

    wire [15:0] wr_word = awaddr_latched[17:2];
    wire [15:0] rd_word = s_axi_araddr[17:2];
    wire [ADDR_WIDTH-1:0] wr_mem_addr = wr_word[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_mem_addr = rd_word[ADDR_WIDTH-1:0];
    wire [31:0] length_safe = (length_r == 32'd0) ? 32'd1 : length_r;
    wire axis_fire = m_axis_tvalid && m_axis_tready;

    integer i;

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_arready = arready_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rvalid  = rvalid_r;

    assign m_axis_tvalid = ctrl_r[0] && !done_r;
    assign m_axis_tdata  = {24'd0, ram[rd_addr]};
    assign m_axis_tlast  = (rd_addr - start_r == length_safe[ADDR_WIDTH-1:0] - {{(ADDR_WIDTH-1){1'b0}}, 1'b1});

    always @(posedge aclk) begin
        if (!aresetn) begin
            ctrl_r <= 32'd0;
            length_r <= 32'd1024;
            start_r <= {ADDR_WIDTH{1'b0}};
            rd_addr <= {ADDR_WIDTH{1'b0}};
            done_r <= 1'b0;
            awready_r <= 1'b0;
            wready_r <= 1'b0;
            bvalid_r <= 1'b0;
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            awaddr_latched <= 32'd0;
            wdata_latched <= 32'd0;
            wstrb_latched <= 4'd0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                ram[i] <= 8'h80;
            end
        end else begin
            awready_r <= 1'b0;
            wready_r <= 1'b0;

            if (!ctrl_r[0]) begin
                rd_addr <= start_r;
                done_r <= 1'b0;
            end else if (axis_fire) begin
                if (m_axis_tlast) begin
                    if (ctrl_r[1]) begin
                        rd_addr <= start_r;
                    end else begin
                        done_r <= 1'b1;
                    end
                end else begin
                    rd_addr <= rd_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                end
            end

            if (!aw_seen && !bvalid_r) begin
                awready_r <= 1'b1;
                if (s_axi_awvalid) begin
                    aw_seen <= 1'b1;
                    awaddr_latched <= s_axi_awaddr;
                end
            end
            if (!w_seen && !bvalid_r) begin
                wready_r <= 1'b1;
                if (s_axi_wvalid) begin
                    w_seen <= 1'b1;
                    wdata_latched <= s_axi_wdata;
                    wstrb_latched <= s_axi_wstrb;
                end
            end
            if (aw_seen && w_seen && !bvalid_r) begin
                case (wr_word)
                A_CTRL: begin
                    if (wstrb_latched[0]) ctrl_r[7:0] <= wdata_latched[7:0];
                    if (wstrb_latched[1]) ctrl_r[15:8] <= wdata_latched[15:8];
                    if (wstrb_latched[2]) ctrl_r[23:16] <= wdata_latched[23:16];
                    if (wstrb_latched[3]) ctrl_r[31:24] <= wdata_latched[31:24];
                end
                A_LEN: begin
                    length_r <= wdata_latched;
                end
                A_START: begin
                    start_r <= wdata_latched[ADDR_WIDTH-1:0];
                    rd_addr <= wdata_latched[ADDR_WIDTH-1:0];
                end
                default: begin
                    if ((wr_word >= A_RAM) && (wr_word < A_RAM + DEPTH)) begin
                        if (wstrb_latched[0]) ram[wr_mem_addr] <= wdata_latched[7:0];
                    end
                end
                endcase
                aw_seen <= 1'b0;
                w_seen <= 1'b0;
                bvalid_r <= 1'b1;
            end else if (bvalid_r && s_axi_bready) begin
                bvalid_r <= 1'b0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            arready_r <= 1'b0;
            rvalid_r <= 1'b0;
            rdata_r <= 32'd0;
        end else begin
            arready_r <= 1'b0;
            if (!rvalid_r && s_axi_arvalid) begin
                arready_r <= 1'b1;
                rvalid_r <= 1'b1;
                case (rd_word)
                A_CTRL:   rdata_r <= ctrl_r;
                A_LEN:    rdata_r <= length_r;
                A_START:  rdata_r <= {{(32-ADDR_WIDTH){1'b0}}, start_r};
                A_STATUS: rdata_r <= {30'd0, done_r, ctrl_r[0]};
                default: begin
                    if ((rd_word >= A_RAM) && (rd_word < A_RAM + DEPTH)) begin
                        rdata_r <= {24'd0, ram[rd_mem_addr]};
                    end else begin
                        rdata_r <= 32'd0;
                    end
                end
                endcase
            end else if (rvalid_r && s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

endmodule
