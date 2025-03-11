// Copyright (c) 2021 Sungkyunkwan University
//
// Authors:
// - Jungrae Kim <dale40@skku.edu>

package DMAC_CFG_UTILS;
    `define ADDR_WIDTH 12
    `define DATA_WIDTH 32

    `define DMA_BASE `ADDR_WIDTH'h000 //For now, as we have no higher module to put the base address in yet

    `define DMA_VER_OFFSET `ADDR_WIDTH'h000
    `define DMA_SRC_OFFSET `ADDR_WIDTH'h100
    `define DMA_DST_OFFSET `ADDR_WIDTH'h104
    `define DMA_LEN_OFFSET `ADDR_WIDTH'h108
    `define DMA_CMD_OFFSET `ADDR_WIDTH'h10C
    `define DMA_STATUS_OFFSET `ADDR_WIDTH'h110

    `define DMA_START_BIT 0
    `define DMA_DONE_BIT 0

    typedef struct packed{
        logic [`DATA_WIDTH-1:0] dma_ver;
        logic [`DATA_WIDTH-1:0] dma_src;
        logic [`DATA_WIDTH-1:0] dma_dst;
        logic [`DATA_WIDTH-1:0] dma_len;
        logic [`DATA_WIDTH-1:0] dma_cmd;            
        logic [`DATA_WIDTH-1:0] dma_status; 
    } cfg_reg_t;

endpackage
    

module DMAC_CFG
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // AMBA APB interface
    input   wire                            psel_i,
    input   wire                            penable_i,
    input   wire    [11:0]                  paddr_i,
    input   wire                            pwrite_i,
    input   wire    [`DATA_WIDTH-1:0]       pwdata_i,
    output  reg                             pready_o,
    output  reg     [`DATA_WIDTH-1:0]       prdata_o,
    output  reg                             pslverr_o,

    // configuration registers
    output  reg     [31:0]      src_addr_o,
    output  reg     [31:0]      dst_addr_o,
    output  reg     [15:0]      byte_len_o,
    output  wire                start_o,
    input   wire                done_i
);
    import DMAC_CFG_UTILS::*;
    cfg_reg_t cfg;
    logic error;
    

    //----------------------------------------------------------
    // INIT
    //----------------------------------------------------------
    //Flush and initial conditions in the DMAC registers (set the version here?)
    always @(negedge rst_n) begin
        cfg.dma_ver = `DATA_WIDTH'h00012025;
        cfg.dma_src = 0;
        cfg.dma_dst = 0;
        cfg.dma_len = 0;
        cfg.dma_cmd = 0;
        cfg.dma_status = `DATA_WIDTH'h1;
    end
    
    //----------------------------------------------------------
    // Write
    //----------------------------------------------------------
    // an APB write occurs when PSEL & PENABLE & PWRITE
    // clk     : __--__--__--__--__--__--__--__--__--__--
    // psel    : ___--------_____________________________
    // penable : _______----_____________________________
    // pwrite  : ___--------_____________________________
    // wren    : _______----_____________________________
    //
    // DMA start command must be asserted when APB writes 1 to the DMA_CMD
    // register
    // clk     : __--__--__--__--__--__--__--__--__--__--
    // psel    : ___--------_____________________________
    // penable : _______----_____________________________
    // pwrite  : ___--------_____________________________
    // paddr   :    |DMA_CMD|
    // pwdata  :    |   1   |
    // start   : _______----_____________________________

    // Intermediate signal to indiacate when a write (2. phase) can occur (Our condition for having a write)
    wire wren;
    assign wren = psel_i && penable_i && pwrite_i;
    always @(posedge clk) begin
        //If our condition for write is true, clock in pwdata_i into the correct memory location (remember the offset)
        if(wren) begin
            case(paddr_i)
                `DMA_BASE+`DMA_VER_OFFSET: cfg.dma_ver = pwdata_i; //Write restricted?
                `DMA_BASE+`DMA_SRC_OFFSET: cfg.dma_src = pwdata_i;
                `DMA_BASE+`DMA_DST_OFFSET: cfg.dma_dst = pwdata_i;
                `DMA_BASE+`DMA_LEN_OFFSET: cfg.dma_len = pwdata_i;
                `DMA_BASE+`DMA_CMD_OFFSET: cfg.dma_cmd = pwdata_i;
                default: error = 1;
            endcase
        end
    end

    wire start;
    assign start = (paddr_i && `DMA_BASE+`DMA_CMD_OFFSET) && (pwdata_i & 1) && penable_i;

    
    //----------------------------------------------------------
    // READ
    //----------------------------------------------------------
    // an APB read occurs when PSEL & PENABLE & !PWRITE
    // To make read data a direct output from register,
    // this code shall buffer the muxed read data into a register
    // in the SETUP cycle (PSEL & !PENABLE)
    // clk        : __--__--__--__--__--__--__--__--__--__--
    // psel       : ___--------_____________________________
    // penable    : _______----_____________________________
    // pwrite     : ________________________________________
    // reg update : ___----_________________________________ (the reg after the mux)
    

    //Only setup the buffer value in the setup period (whenever we have psel_i and not penable)
    logic [`DATA_WIDTH-1:0] rdata;
    wire rden;
    assign rden = psel_i && !penable_i && !pwrite_i;
    always @(posedge clk) begin
        if(rden) begin
            case(paddr_i)
                `DMA_BASE+`DMA_VER_OFFSET: rdata = cfg.dma_ver;
                `DMA_BASE+`DMA_SRC_OFFSET: rdata = cfg.dma_src;
                `DMA_BASE+`DMA_DST_OFFSET: rdata = cfg.dma_dst;
                `DMA_BASE+`DMA_LEN_OFFSET: rdata = cfg.dma_len;
                `DMA_BASE+`DMA_CMD_OFFSET: rdata = cfg.dma_cmd;
                `DMA_BASE+`DMA_STATUS_OFFSET: rdata = cfg.dma_status;
                default: error = 1;
            endcase
        end
    end

    //----------------------------------------------------------
    // ERROR HANFLING
    //----------------------------------------------------------
    //Alignemnt, reserved region writes, checking, etc


    assign  pready_o            = 1'b1;
    assign  prdata_o            = rdata;
    assign  pslverr_o           = error;

    assign  src_addr_o          = cfg.dma_src;
    assign  dst_addr_o          = cfg.dma_dst;
    assign  byte_len_o          = cfg.dma_len;
    assign  start_o             = start;

endmodule
