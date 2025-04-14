module AXI2APB_TOP #(
    parameter ADDR_WIDTH            = 32,
    parameter DATA_WIDTH            = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

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

    // fill your code.

    
endmodule