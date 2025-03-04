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
    logic [3:0] ID;
    logic [addr_width-1:0] ADDR;
    logic [3:0] LEN;
    logic [2:0] SIZE;
    logic [1:0] BURST;
    logic [1:0] LOCK;
    logic [3:0] CACHE;
    logic [2:0] PROT;
    logic VALID;
    logic READY;
    modport tx(output ID, ADDR, LEN, SIZE, BURST, LOCK, CACHE, PROT, VALID, input READY);
    modport rx(input ID, ADDR, LEN, SIZE, BURST, LOCK, CACHE, PROT, VALID, output READY);
endinterface

interface ch_dr;
    import axi_utils::*;
    logic [3:0] ID;
    logic [data_width-1:0] DATA;
    logic [3:0] STRB;
    logic LAST;
    logic VALID;
    logic READY;
    modport tx(output ID, DATA, STRB, LAST, VALID, input READY);
    modport rx(input ID, DATA, STRB, LAST, VALID, output READY);
endinterface

interface ch_aw;
    import axi_utils::*;
    logic [3:0] ID;
    logic [addr_width-1:0] ADDR;
    logic [3:0] LEN;
    logic [2:0] SIZE;
    logic [1:0] BURST;
    logic [1:0] LOCK;
    logic [3:0] CACHE;
    logic [2:0] PROT;
    logic VALID;
    logic READY;
    modport tx(output ID, ADDR, LEN, SIZE, BURST, LOCK, CACHE, PROT, VALID, input READY);
    modport rx(input ID, ADDR, LEN, SIZE, BURST, LOCK, CACHE, PROT, VALID, output READY);
endinterface

interface ch_dw;
    import axi_utils::*;
    logic [3:0] ID;
    logic [data_width-1:0] DATA;
    logic [3:0] STRB;
    logic LAST;
    logic VALID;
    logic READY;
    modport tx(output ID, DATA, STRB, LAST, VALID, input READY);
    modport rx(input ID, DATA, STRB, LAST, VALID, output READY);
endinterface

interface ch_b;
    import axi_utils::*;
    logic [3:0] ID;
    logic [1:0] RESP;
    logic VALID;
    logic READY;
    modport tx(output ID, RESP, VALID, input READY);
    modport rx(input ID, RESP, VALID, output READY);
endinterface

interface ch_g;
    logic clk;
    logic rst;
endinterface


interface axi4;
    import axi_utils::*;
    ch_ar ch_addr_read();
    ch_aw ch_addr_write();
    ch_dr ch_data_read();
    ch_dw ch_data_write();
    ch_b ch_resp();
    ch_g ch_global();
endinterface

