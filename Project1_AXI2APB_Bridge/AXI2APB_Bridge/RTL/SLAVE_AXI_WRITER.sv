/*
Module SALVE_AXI_WRITE
This module implements the AXI slave read channels, which it writes to and has an axi interface to the outside.
*/
module slave_axi_writer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
)(
    input logic clk,
    input logic rst_n,

    // AXI interface
    // AXI Read Address Channel
    input  logic                     arid,
    input  logic [ADDR_WIDTH-1:0]    araddr,
    input  logic [3:0]               arlen,
    input  logic [2:0]               arsize,
    input  logic [1:0]               arburst,
    input  logic                     arvalid,
    output logic                     arready,

    // AXI Read Data Channel
    output logic                     rid,
    output logic [DATA_WIDTH-1:0]    rdata,
    output logic [1:0]               rresp,
    output logic                     rlast,
    output logic                     rvalid,
    input  logic                     rready,

    // Internal interface to engine
    axi_writer_inf.writer i_inf
);
    import bridge_utils::*;
    typedef enum {IDLE,AR,WAIT_W,W} w_state;

    //Internal registers
    w_state state_cur, state_nxt;

    logic [4:0] beats, beats_nxt; //NB! Null indexed or not?


    always_comb begin
        i_inf.addr_info_valid = 1'b0;

        arready = 1'b0;

        
        beats_nxt = 5'd0;

        case(state)
            IDLE: begin
                i_inf.wr_info = W_IDLE;
                if(i_inf.wr_cmd == W_GET_ADDR) begin
                    next_state = AR;
                end else begin
                    next_state = IDLE;
                end
            end

            AR: begin
                arready = 1'b1;
                i_inf.wr_info = W_BUSY;
                if(arvalid) begin
                    i_inf.addr_info_valid = 1'b1;
                    beats_nxt = arlen;
                    next_state = WAIT_W;
                end else begin
                    next_state = AR;
                end
            end

            WAIT_W: begin
                i_inf.wr_info = W_SWITCH;
                if(i_inf.wr_cmd == W_GET_DATA) begin
                    next_state = W;
                end else begin
                    next_state = WAIT_RESP;
                end
            end

            W: begin
                rvalid = 1'b1;
                i_inf.rdata_ready = 1'b1;
                i_inf.wr_info = R_BUSY;
                if(wready) begin
                    //Go for INCR always here, just with a counter (might be single anyways)
                    //NB null indexing!
                end else begin
                    next_state = R;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end


    //Continous assignment for driving internal interface
    assign i_inf.addr_info.id = arid;
    assign i_inf.addr_info.addr = araddr;
    assign i_inf.addr_info.len = arlen;
    assign i_inf.addr_info.burst = arburst;
    assign i_inf.addr_info.size = arsize;
    //Continous assignment for driving the external interface

endmodule
