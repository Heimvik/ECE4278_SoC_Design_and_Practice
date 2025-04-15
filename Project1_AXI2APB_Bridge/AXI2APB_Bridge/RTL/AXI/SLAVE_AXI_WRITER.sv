/*
Module SALVE_AXI_WRITE
This module implements the AXI slave read channels, which it writes to and has an axi interface to the outside.
*/
import bridge_utils::*;

module slave_axi_writer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,

    // AXI interface
    // AXI Read Address Channel
    input  logic [ID_WIDTH-1:0]      arid,
    input  logic [ADDR_WIDTH-1:0]    araddr,
    input  logic [3:0]               arlen,
    input  logic [2:0]               arsize,
    input  logic [1:0]               arburst,
    input  logic                     arvalid,
    output logic                     arready,

    // AXI Read Data Channel
    output logic [ID_WIDTH-1:0]      rid,
    output logic [DATA_WIDTH-1:0]    rdata,
    output logic [1:0]               rresp,
    output logic                     rlast,
    output logic                     rvalid,
    input  logic                     rready,

    // Internal interface to engine
    axi_writer_inf.slave_axi_wr axi_wr_inf
);
    typedef enum {IDLE,AR,WAIT_W,W} w_state;

    //Internal registers
    w_state state_cur, state_nxt;
    logic [3:0] beats_cur, beats_nxt;           //Current beats NB! Null indexed!
    logic [ID_WIDTH-1:0] id_cur, id_nxt;
    addr_info_t addr_info_cur, addr_info_nxt;   //Holds target beats in len
    data_info_t data_info_cur, data_info_nxt;

    always_comb begin
        axi_wr_inf.fifo_read = 1'b0;
        id_nxt = id_cur;
        beats_nxt = beats_cur;

        addr_info_nxt = addr_info_cur;
        data_info_nxt = data_info_cur;

        arready = 1'b0;
        rvalid = 1'b0;
        rlast = 1'b0;

        axi_wr_inf.wr_info = W_IDLE;

        case(state_cur)
            IDLE: begin
                axi_wr_inf.wr_info = W_IDLE;
                if(axi_wr_inf.wr_cmd == W_GET_ADDR) begin
                    state_nxt = AR;
                end else begin
                    state_nxt = IDLE;
                end
            end

            AR: begin
                arready = 1'b1;
                axi_wr_inf.wr_info = W_BUSY;
                if(arvalid) begin
                    id_nxt = arid;
                    addr_info_nxt = '{addr: araddr, len: arlen, size: arsize, burst: arburst};
                    state_nxt = WAIT_W;
                end else begin
                    state_nxt = AR;
                end
            end

            WAIT_W: begin
                axi_wr_inf.wr_info = W_SWITCH;
                if(axi_wr_inf.wr_cmd == W_GET_DATA) begin
                    data_info_nxt = '{strb: 4'b1111, resp: 2'b0}; //Add actual response here?
                    state_nxt = W;
                end else begin
                    state_nxt = WAIT_W;
                end
            end

            W: begin
                rvalid = 1'b1;
                axi_wr_inf.wr_info = W_BUSY;
                if(rready) begin
                    axi_wr_inf.fifo_read = 1'b1;
                    rlast = (beats_cur == addr_info_cur.len);
                    if(rlast) begin
                        beats_nxt = 4'b0;
                        state_nxt = IDLE;
                    end else begin
                        beats_nxt = beats_cur + 1'b1;
                        state_nxt = W;
                    end
                end else begin
                    state_nxt = W;
                end
            end

            default: state_nxt = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state_cur <= IDLE;
            beats_cur <= 4'b0;
            id_cur <= {ID_WIDTH{1'b0}};
            addr_info_cur <= '{addr: {ADDR_WIDTH{1'b0}}, len: 4'b0, size: 3'b0, burst: 2'b0};
            data_info_cur <= '{strb: 4'b0, resp: 2'b0};
        end else begin
            state_cur <= state_nxt;
            beats_cur <= beats_nxt;
            id_cur <= id_nxt;
            addr_info_cur <= addr_info_nxt;
            data_info_cur <= data_info_nxt;
        end
    end


    //Continous assignment for driving internal interface
    assign axi_wr_inf.addr_info.addr = addr_info_cur.addr;
    assign axi_wr_inf.addr_info.len = addr_info_cur.len;
    assign axi_wr_inf.addr_info.burst = addr_info_cur.burst;
    assign axi_wr_inf.addr_info.size = addr_info_cur.size;

    //Continous assignment for driving the external interface
    assign rid = id_cur;
    assign rdata = axi_wr_inf.data;
    assign rresp = data_info_cur.resp;

endmodule
