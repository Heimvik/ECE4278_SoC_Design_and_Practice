`include "../TB/AXI_TYPEDEF.svh"

interface AXI_AW_CH
#(
    parameter   ADDR_WIDTH      = `AXI_ADDR_WIDTH,
    parameter   ID_WIDTH        = `AXI_ID_WIDTH
 )
(
    input                       clk
);
    logic                       awvalid;
    logic                       awready;
    logic   [ID_WIDTH-1:0]      awid;
    logic   [ADDR_WIDTH-1:0]    awaddr;
    logic   [3:0]               awlen;
    logic   [2:0]               awsize;
    logic   [1:0]               awburst;

    task init();
        awvalid = 0;
        awid    = 0;
        awaddr  = 0;
        awlen   = 0;
        awsize  = 0;
        awburst = 0;
    endtask

endinterface

interface AXI_W_CH
#(
    parameter   DATA_WIDTH      = `AXI_DATA_WIDTH,
    parameter   ID_WIDTH        = `AXI_ID_WIDTH
 )
(
    input                       clk
);
    logic                       wvalid;
    logic                       wready;
    logic   [ID_WIDTH-1:0]      wid;
    logic   [DATA_WIDTH-1:0]    wdata;
    logic   [DATA_WIDTH/8-1:0]  wstrb;
    logic                       wlast;

    task init();
        wvalid  = 0;
        wid     = 0;
        wdata   = 0;
        wstrb   = 0;
        wlast   = 0;
    endtask

endinterface

interface AXI_B_CH
#(
    parameter   ID_WIDTH        = `AXI_ID_WIDTH
 )
(
    input                       clk
);
    logic                       bvalid;
    logic                       bready;
    logic   [ID_WIDTH-1:0]      bid;
    logic   [1:0]               bresp;

    task init();
        bready = 0;
    endtask

endinterface

interface AXI_AR_CH
#(
    parameter   ADDR_WIDTH      = `AXI_ADDR_WIDTH,
    parameter   ID_WIDTH        = `AXI_ID_WIDTH
 )
(
    input                       clk
);
    logic                       arvalid;
    logic                       arready;
    logic   [ID_WIDTH-1:0]      arid;
    logic   [ADDR_WIDTH-1:0]    araddr;
    logic   [3:0]               arlen;
    logic   [2:0]               arsize;
    logic   [1:0]               arburst;

    task init();
        arvalid = 0;
        arid    = 0;
        araddr  = 0;
        arlen   = 0;
        arsize  = 0;
        arburst = 0;
    endtask

endinterface

interface AXI_R_CH
#(
    parameter   DATA_WIDTH      = `AXI_DATA_WIDTH,
    parameter   ID_WIDTH        = `AXI_ID_WIDTH
 )
(
    input                       clk
);
    logic                       rvalid;
    logic                       rready;
    logic   [ID_WIDTH-1:0]      rid;
    logic   [DATA_WIDTH-1:0]    rdata;
    logic   [1:0]               rresp;
    logic                       rlast;


    task init();
        rready = 0;
    endtask

endinterface

interface APB(
    input                       clk
);
    logic   [1:0]               psel;
    logic                       penable;
    logic   [31:0]              paddr;
    logic                       pwrite;
    logic   [31:0]              pwdata;
    logic                       pready;
    logic   [31:0]              prdata;
    logic                       pslverr;

    // a semaphore to allow only one access at a time
    semaphore                   sema;
    initial begin
        sema                        = new(1);
    end

    modport slave (
        input   clk,
        input   psel, penable, paddr, pwrite, pwdata,
        output  pready, prdata, pslverr
    );

    task init();
        pready                  = 1'b0;
        prdata                  = 32'b0;
        pslverr                 = 1'd0;
    endtask

    // Optional: task for test
    task automatic respond_write();
        @(posedge clk);
        wait (psel && penable && pwrite);
        // write request
        $display("[APB_SLAVE] Write to addr 0x%08x with data 0x%08x", paddr, pwdata);
    endtask

    task automatic respond_read(input logic [31:0] read_data);
        @(posedge clk);
        wait (psel && penable && !pwrite);
        // read request
        prdata = read_data;
        $display("[APB_SLAVE] Read from addr 0x%08x → send data 0x%08x", paddr, read_data);
    endtask

endinterface