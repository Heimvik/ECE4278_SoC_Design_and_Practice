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
    `define DMA_CMD_OFFSET `ADDR_WIDTH'h10C
    `define DMA_STATUS_OFFSET `ADDR_WIDTH'h110

    `define DMA_START_BIT 0
    `define DMA_DONE_BIT 0

    //Memory map all registers and reserved areas for easier and better access (in my opinion)
    typedef struct packed{
        logic [`data_width-1:0] dma_ver;
        logic [8*(`DMA_SRC_OFFSET-`DMA_VER_OFFSET-4):0] reserved;
        logic [`data_width-1:0] dma_src;
        logic [`data_width-1:0] dma_dst;
        logic [`data_width-1:0] dma_len;
        logic [`data_width-1:0] dma_cmd;            
        logic [`data_width-1:0] dma_status; 
    } cfg_reg_t;
    typedef union packed{
        cfg_reg_t reg;
        byte unsigned mem [`DMA_STATUS_OFFSET-`DMA_VER_OFFSET];
    } cfg_mem_t;

endpackage
    

module DMAC_CFG
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // AMBA APB interface
    input   wire                psel_i,
    input   wire                penable_i,
    input   wire    [11:0]      paddr_i,
    input   wire                pwrite_i,
    input   wire    [31:0]      pwdata_i,
    output  reg                 pready_o,
    output  reg     [31:0]      prdata_o,
    output  reg                 pslverr_o,

    // configuration registers
    output  reg     [31:0]      src_addr_o,
    output  reg     [31:0]      dst_addr_o,
    output  reg     [15:0]      byte_len_o,
    output  wire                start_o,
    input   wire                done_i
);
    import DMAC_CFG_UTILS::*;
    // Configuration register to read/write           
    cfg_mem_t cfg = '{default: '0};

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
            cfg.mem[paddr_i-`DMA_BASE] = pw_data_i;            
        end
    end

    wire start;
    assign start = (paddr_i && `DMA_BASE+`DMA_CMD_OFFSET) && (pw_data_i & 1) && penable_i;

    // Read
    logic [data_width-1:0] rdata;

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
    //
    wire rden;
    //Only setup the buffer value in the setup period (whenever we have psel_i and not penable)
    assign rden = psel_i && !penable && !pwrite_i;
    always @(posedge clk) begin
        if(rden) begin
            rdata = cfg.mem[paddr_o-`DMA_BASE];
        end
    end

    // output assignments
    assign  pready_o            = 1'b1;
    assign  prdata_o            = rdata;
    assign  pslverr_o           = 1'b0;

    assign  src_addr_o          = src_addr;
    assign  dst_addr_o          = dst_addr;
    assign  byte_len_o          = byte_len;
    assign  start_o             = start;

endmodule
