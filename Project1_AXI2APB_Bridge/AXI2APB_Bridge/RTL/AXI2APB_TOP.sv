import bridge_utils::*;

module AXI2APB_TOP #(
    parameter ADDR_WIDTH            = 32,
    parameter DATA_WIDTH            = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // AXI Write Address Channel
    input  wire                     awid_i,
    input  wire [ADDR_WIDTH-1:0]    awaddr_i,
    input  wire [3:0]               awlen_i,
    input  wire [2:0]               awsize_i,
    input  wire [1:0]               awburst_i,
    input  wire                     awvalid_i,
    output wire                     awready_o,

    // AXI Write Data Channel
    input  wire                     wid_i,
    input  wire [DATA_WIDTH-1:0]    wdata_i,
    input  wire [3:0]               wstrb_i,
    input  wire                     wlast_i,
    input  wire                     wvalid_i,
    output wire                     wready_o,

    // AXI Write Response Channel
    output wire                     bid_o,
    output wire [1:0]               bresp_o,
    output wire                     bvalid_o,
    input  wire                     bready_i,

    // AXI Read Address Channel
    input  wire                     arid_i,
    input  wire [ADDR_WIDTH-1:0]    araddr_i,
    input  wire [3:0]               arlen_i,
    input  wire [2:0]               arsize_i,
    input  wire [1:0]               arburst_i,
    input  wire                     arvalid_i,
    output wire                     arready_o,

    // AXI Read Data Channel
    output wire                     rid_o,
    output wire [DATA_WIDTH-1:0]    rdata_o,
    output wire [1:0]               rresp_o,
    output wire                     rlast_o,
    output wire                     rvalid_o,
    input  wire                     rready_i,

    // APB Master Interface
    output wire [ADDR_WIDTH-1:0]    paddr_o,
    output wire [DATA_WIDTH-1:0]    pwdata_o,
    output wire                     pwrite_o,
    output wire                     penable_o,
    output wire [1:0]               psel_o,
    input  wire [DATA_WIDTH-1:0]    prdata_i,
    input  wire                     pready_i,
    input  wire                     pslverr_i
);

    // Internal signals
    //Commands and information to/from the 3 different submodules
    wr_cmd_t wr_cmd;
    wr_info_t wr_info;
    rd_cmd_t rd_cmd;
    rd_info_t rd_info;
    apb_cmd_t apb_cmd;
    apb_info_t apb_info;

    // FIFO signals
    // Write FIFO signals
    logic write_fifo_rden;
    logic write_fifo_wren;
    logic [DATA_WIDTH-1:0] write_fifo_wdata;
    logic [DATA_WIDTH-1:0] write_fifo_rdata;
    
    // Read FIFO signals
    logic read_fifo_rden;
    logic read_fifo_wren;
    logic [DATA_WIDTH-1:0] read_fifo_wdata;
    logic [DATA_WIDTH-1:0] read_fifo_rdata;

    // Address information from the AXI reader and writer
    addr_info_t addr_info_wr;
    addr_info_t addr_info_rd;

    // Engine that drives all 3 different modules based off its commands
    bridge_engine #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bridge_engine_inst (
        .clk(clk),
        .rst_n(rst_n),
        .apb_cmd(apb_cmd),
        .apb_info(apb_info),
        .wr_cmd(wr_cmd),
        .wr_info(wr_info),
        .rd_cmd(rd_cmd),
        .rd_info(rd_info),
        .arvalid(arvalid_i),    // For arbitration
        .awvalid(awvalid_i)     // For arbitration
    );

    // An AXI writer takes place in a READ operation, thus uses the read FIFO
    slave_axi_writer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_writer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .arid(arid_i),
        .araddr(araddr_i),
        .arlen(arlen_i),
        .arsize(arsize_i),
        .arburst(arburst_i),
        .arvalid(arvalid_i),
        .arready(arready_o),
        .rid(rid_o),
        .rdata(rdata_o),
        .rresp(rresp_o),
        .rlast(rlast_o),
        .rvalid(rvalid_o),
        .rready(rready_i),
        .wr_cmd(wr_cmd),
        .wr_info(wr_info),
        .addr_info(addr_info_wr),
        .fifo_read(read_fifo_rden),
        .data(read_fifo_rdata)
    );

    // An AXI reader takes place in a WRITE operation, thus uses the write FIFO
    slave_axi_reader #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_reader_inst (
        .clk(clk),
        .rst_n(rst_n),
        .awid(awid_i),
        .awaddr(awaddr_i),
        .awlen(awlen_i),
        .awsize(awsize_i),
        .awburst(awburst_i),
        .awvalid(awvalid_i),
        .awready(awready_o),
        .wid(wid_i),
        .wdata(wdata_i),
        .wstrb(wstrb_i),
        .wlast(wlast_i),
        .wvalid(wvalid_i),
        .wready(wready_o),
        .bid(bid_o),
        .bresp(bresp_o),
        .bvalid(bvalid_o),
        .bready(bready_i),
        .rd_cmd(rd_cmd),
        .rd_info(rd_info),
        .addr_info(addr_info_rd),
        .fifo_write(write_fifo_wren),
        .data(write_fifo_wdata)
    );

    // An APB master takes the data from both FIFOs and sends it to the APB bus
    master_apb #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) apb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr_o),
        .pwdata(pwdata_o),
        .pwrite(pwrite_o),
        .penable(penable_o),
        .psel(psel_o),
        .prdata(prdata_i),
        .pready(pready_i),
        .pslverr(pslverr_i),
        .apb_cmd(apb_cmd),
        .apb_info(apb_info),
        .addr_info_wr(addr_info_wr),
        .addr_info_rd(addr_info_rd),
        .fifo_read(write_fifo_rden),
        .data_in(write_fifo_rdata),
        .fifo_write(read_fifo_wren),
        .data_out(read_fifo_wdata)
    );

    // Write FIFO instantiation
    BRIDGE_FIFO #(
        .DEPTH_LG2(FIFO_DEPTH_LG2),
        .DATA_WIDTH(DATA_WIDTH)
    ) write_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wren_i(write_fifo_wren),
        .wdata_i(write_fifo_wdata),
        .full_o(),
        .rden_i(write_fifo_rden),
        .rdata_o(write_fifo_rdata),
        .empty_o()
    );

    // Read FIFO instantiation
    BRIDGE_FIFO #(
        .DEPTH_LG2(FIFO_DEPTH_LG2),
        .DATA_WIDTH(DATA_WIDTH)
    ) read_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .wren_i(read_fifo_wren),
        .wdata_i(read_fifo_wdata),
        .full_o(),
        .rden_i(read_fifo_rden),
        .rdata_o(read_fifo_rdata),
        .empty_o()
    );
    
endmodule