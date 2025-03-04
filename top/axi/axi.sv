package axi_utils;
    parameter int addr_width = 32;
    parameter int data_width = 32;
    parameter int axi_data_buffer_size = 16;

    typedef enum {AW,AR,DW,DR,B} ch_state;

    typedef enum {AR_READY,AR_READ} ar_state;
    typedef enum {DR_READY,DR_READ} dr_state;
    typedef enum {DW_VALID,DW_WRITE} dw_state;
    typedef enum {B_READY,B_READ} br_state;
    typedef enum {B_VALID,B_WRITE} bw_state;

    typedef enum logic [2:0] {
        OKAY       = 3'b000, // Non-exclusive write: The transaction was successful.
        EXOKAY     = 3'b001, // Exclusive write succeeded.
        SLVERR     = 3'b010, // The request has reached an end point but has not completed successfully.
        DECERR     = 3'b011, // The request has not reached a point where data can be written.
        DEFER      = 3'b100, // Write was unsuccessful because it cannot be serviced at this time.
        TRANSFAULT = 3'b101, // Write was terminated because of a translation fault.
        RESERVED1  = 3'b110, // Reserved
        RESERVED2  = 3'b111  // Reserved
    } write_error_code;

    typedef struct {
        logic [3:0] ID;
        logic [addr_width-1:0] ADDR;
        logic [3:0] LEN;
        logic [2:0] SIZE;
        logic [1:0] BURST;
        logic [1:0] LOCK;
        logic [3:0] CACHE;
        logic [2:0] PROT;
        logic [data_width-1:0] DATA;
        logic [1:0] RESP;
    } addr_msg;
    typedef struct {
        logic [3:0] ID;
        logic [data_width-1:0] DATA;
        logic [3:0] STRB;
    } data_msg;
    typedef struct {
        logic [3:0] ID;
        logic [2:0] RESP;
    } resp_msg;
endpackage

interface ch_ar;
    import axi_utils::*;
    logic [3:0] ARID;
    logic [addr_width-1:0] ARADDR;
    logic [3:0] ARLEN;
    logic [2:0] ARSIZE;
    logic [1:0] ARBURST;
    logic [1:0] ARLOCK;
    logic [3:0] ARCACHE;
    logic [2:0] ARPROT;
    logic ARVALID;
    logic ARREADY;
    modport addr_reader(output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARVALID, input ARREADY);
    modport addr_writer(input ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARVALID, output ARREADY);

endinterface

interface ch_dr;
    import axi_utils::*;
    logic [3:0] RID;
    logic [data_width-1:0] RDATA;
    logic [3:0] STRB;
    logic RLAST;
    logic RVALID;
    logic RREADY;
    modport data_reader(input RID, RDATA, STRB, RLAST, RVALID, output RREADY);
endinterface

interface ch_aw;
    import axi_utils::*;
    logic [3:0] AWID;
    logic [addr_width-1:0] AWADDR;
    logic [3:0] AWLEN;
    logic [2:0] AWSIZE;
    logic [1:0] AWBURST;
    logic [1:0] AWLOCK;
    logic [3:0] AWCACHE;
    logic [2:0] AWPROT;
    logic AWVALID;
    logic AWREADY;
    modport addr_writer(output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWVALID, input AWREADY);
endinterface

interface ch_dw;
    import axi_utils::*;
    logic [3:0] ID;
    logic [data_width-1:0] DATA;
    logic [3:0] STRB;
    logic LAST;
    logic VALID;
    logic READY;
    modport data_writer(output ID, DATA, STRB, LAST, VALID, input READY);
endinterface

interface ch_b;
    import axi_utils::*;
    logic [3:0] ID;
    logic [1:0] RESP;
    logic VALID;
    logic READY;
    modport b_writer(output ID, RESP, VALID, input READY);
    modport b_reader(input ID, RESP, VALID, output READY);
endinterface

interface ch_global;
    logic clk;
    logic rst;
endinterface


interface axi4;
    import axi_utils::*;
    axi4_ch_read_addr ch_read_addr();
    axi4_ch_read_data ch_read_data();
    axi4_ch_write_addr ch_write_addr();
    axi4_ch_write_data ch_write_data();
    axi4_ch_write_resp ch_write_resp();
    axi4_ch_global ch_global();
endinterface

