// Copyright (c) 2021 Sungkyunkwan University
//
// Authors:
// - Jungrae Kim <dale40@skku.edu>

module DMAC_ENGINE
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // configuration registers
    input   wire    [31:0]      src_addr_i,
    input   wire    [31:0]      dst_addr_i,
    input   wire    [15:0]      byte_len_i,
    input   wire                start_i,
    output  wire                done_o,

    // AMBA AXI interface (AW channel)
    output  wire    [3:0]       awid_o,
    output  wire    [31:0]      awaddr_o,
    output  wire    [3:0]       awlen_o,
    output  wire    [2:0]       awsize_o,
    output  wire    [1:0]       awburst_o,
    output  wire                awvalid_o,
    input   wire                awready_i,

    // AMBA AXI interface (W channel)
    output  wire    [3:0]       wid_o,
    output  wire    [31:0]      wdata_o,
    output  wire    [3:0]       wstrb_o,
    output  wire                wlast_o,
    output  wire                wvalid_o,
    input   wire                wready_i,

    // AMBA AXI interface (B channel)
    input   wire    [3:0]       bid_i,
    input   wire    [1:0]       bresp_i,
    input   wire                bvalid_i,
    output  wire                bready_o,

    // AMBA AXI interface (AR channel)
    output  wire    [3:0]       arid_o,
    output  wire    [31:0]      araddr_o,
    output  wire    [3:0]       arlen_o,
    output  wire    [2:0]       arsize_o,
    output  wire    [1:0]       arburst_o,
    output  wire                arvalid_o,
    input   wire                arready_i,

    // AMBA AXI interface (R channel)
    input   wire    [3:0]       rid_i,
    input   wire    [31:0]      rdata_i,
    input   wire    [1:0]       rresp_i,
    input   wire                rlast_i,
    input   wire                rvalid_i,
    output  wire                rready_o
);

    // mnemonics for state values
    localparam                  S_IDLE  = 3'd0,
                                S_RREQ  = 3'd1,
                                S_RDATA = 3'd2,
                                S_WREQ  = 3'd3,
                                S_WDATA = 3'd4;

    reg     [2:0]               state,      state_n;

    reg     [31:0]              src_addr,   src_addr_n;
    reg     [31:0]              dst_addr,   dst_addr_n;
    reg     [15:0]              cnt,        cnt_n;
    reg     [3:0]               wcnt,       wcnt_n;

    reg                         arvalid,
                                rready,
                                awvalid,
                                wvalid,
                                wlast,
                                done;
    
    logic   [3:0]               beats, beats_n;

    wire                        fifo_full,
                                fifo_empty;
    reg                         fifo_wren,
                                fifo_rden;
    wire    [31:0]              fifo_rdata;


    // it's desirable to code registers in a simple way
    always_ff @(posedge clk)
        if (!rst_n) begin
            state               <= S_IDLE;

            src_addr            <= 32'd0;
            dst_addr            <= 32'd0;
            cnt                 <= 16'd0;

            wcnt                <= 4'd0;

            beats               <= 4'd0;
        end
        else begin
            state               <= state_n;

            src_addr            <= src_addr_n;
            dst_addr            <= dst_addr_n;
            cnt                 <= cnt_n;

            wcnt                <= wcnt_n;

            beats               <= beats_n;
        end
    

    // this block programs output values and next register values
    // based on states.
    always_comb begin
        //Default values (hinder inferred latches)
        state_n = state;
        src_addr_n = src_addr;
        dst_addr_n = dst_addr;
        cnt_n = cnt;
        wcnt_n = wcnt;
        
        arvalid = 0;
        rready = 0;
        awvalid = 0;
        wvalid = 0;
        wlast = 0;
        done = 0;

        fifo_wren = 0;
        fifo_rden = 0;

        beats_n = beats;

        case(state)
            S_IDLE: begin
                done = 1;
                if(start_i && byte_len_i != 0) begin
                    src_addr_n = src_addr_i;
                    dst_addr_n = dst_addr_i;
                    cnt_n = byte_len_i;
                    beats_n = (cnt >= 'd64) ? 4'hF: cnt[5:2]-4'h1;

                    state_n = S_RREQ;
                end
            end
            S_RREQ: begin
                arvalid = 1;
                if(arready_i) begin
                    //Here: Set the scene for next time by incrementing the scr_addr by the number of bytes ((beats+1)*4) we are sending the current fsm-run
                    src_addr_n = src_addr + (beats+1)*4;
                    state_n = S_RDATA;
                end
            end
            S_RDATA: begin
                rready = 1;
                if(rvalid_i) begin
                    fifo_wren = 1;
                    if(rlast_i) begin
                        state_n = S_WREQ;
                    end
                end
            end
            S_WREQ: begin
                awvalid = 1;
                if(awready_i) begin
                    //Same here: Set the scene for the next time by incrementing the destionation address the same number of times as we did with src
                    dst_addr_n = dst_addr + (beats+1)*4;
                    cnt_n = cnt - (beats+1)*4;
                    wcnt_n = beats; 
                    state_n = S_WDATA;
                end
            end
            S_WDATA: begin
                wvalid = 1;
                fifo_rden = 1;
                wlast = (wcnt == 0);
                if(wready_i) begin
                    if(!wlast) begin
                        wcnt_n = wcnt-1;
                    end else begin
                        if(cnt != 0) begin
                            //If we are not done yet, update how many beats the next bust will have
                            beats_n = (cnt >= 'd64) ? 4'hF: cnt[5:2]-4'h1;                            
                            state_n = S_RREQ;
                        end else begin
                            state_n = S_IDLE;
                        end
                    end
                end
            end
        endcase
    end

    DMAC_FIFO   u_fifo
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        .full_o                     (fifo_full),
        .wren_i                     (fifo_wren),
        .wdata_i                    (rdata_i),

        .empty_o                    (fifo_empty),
        .rden_i                     (fifo_rden),
        .rdata_o                    (fifo_rdata)
    );

    // Output assigments
    assign  done_o                  = done;

    assign  awid_o                  = 4'd0;
    assign  awaddr_o                = dst_addr;
    assign  awlen_o                 = beats;
    assign  awsize_o                = 3'b010;   // 4 bytes per transfer
    assign  awburst_o               = 2'b01;    // incremental
    assign  awvalid_o               = awvalid;

    assign  wid_o                   = 4'd0;
    assign  wdata_o                 = fifo_rdata;
    assign  wstrb_o                 = 4'b1111;  // all bytes within 4 byte are valid
    assign  wlast_o                 = wlast;
    assign  wvalid_o                = wvalid;

    assign  bready_o                = 1'b1;

    assign  arvalid_o               = arvalid;
    assign  araddr_o                = src_addr;
    assign  arid_o                  = 4'd0;
    assign  arlen_o                 = beats;
    assign  arsize_o                = 3'b010;   // 4 bytes per transfer
    assign  arburst_o               = 2'b01;    // incremental
    assign  arvalid_o               = arvalid;

    assign  rready_o                = rready & !fifo_full;

endmodule
