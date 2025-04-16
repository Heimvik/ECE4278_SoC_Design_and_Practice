/*
Module SALVE_AXI_READ
This module interfaces the AXI slave write channels, which it reads from and has an axi interface to the outside.
*/
import bridge_utils::*;

module slave_axi_reader #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,

    // AXI interface
    // Write Address Channel
    input logic [ID_WIDTH-1:0] awid,
    input logic [ADDR_WIDTH-1:0] awaddr,
    input logic [3:0] awlen,
    input logic [2:0] awsize,
    input logic [1:0] awburst,
    input logic awvalid,
    output logic awready,

    // Write Data Channel
    input logic [3:0] wid,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [3:0] wstrb,
    input logic wlast,
    input logic wvalid,
    output logic wready,

    // Write Response Channel
    output logic [3:0] bid,
    output logic [1:0] bresp,
    output logic bvalid,
    input logic bready,

    // Internal interface to engine
    // Control signals
    input rd_cmd_t rd_cmd,
    output rd_info_t rd_info,
    
    // Address information
    output addr_info_t addr_info,
    
    // Data signals
    output logic fifo_write,
    output logic [DATA_WIDTH-1:0] data
);
    typedef enum {IDLE,AR,R,WAIT_RESP,B} r_state;
    
    //Internal registers
    r_state state_cur, state_nxt;

    //Metadata of the current transfer
    logic [ID_WIDTH-1:0] id_cur, id_nxt;
    addr_info_t addr_info_cur, addr_info_nxt; 
    data_info_t data_info_cur, data_info_nxt;
    resp_info_t resp_info_cur, resp_info_nxt;

    always_comb begin
        fifo_write = 1'b0;
        id_nxt = id_cur;

        addr_info_nxt = addr_info_cur;
        data_info_nxt = data_info_cur;
        resp_info_nxt = resp_info_cur;

        awready = 1'b0;
        wready = 1'b0;
        bvalid = 1'b0;

        rd_info = R_IDLE;

        case(state_cur)
            IDLE: begin
                rd_info = R_IDLE;
                if(rd_cmd == R_GET_ADDR_DATA) begin
                    state_nxt = AR;
                end else begin
                    state_nxt = IDLE;
                end
            end

            AR: begin
                awready = 1'b1;
                rd_info = R_BUSY;
                if(awvalid) begin
                    id_nxt = awid;
                    addr_info_nxt = '{addr: awaddr, len: awlen, size: awsize, burst: awburst};
                    state_nxt = R;
                end else begin
                    state_nxt = AR;
                end
            end

            R: begin
                wready = 1'b1;
                rd_info = R_BUSY;
                if(wvalid) begin
                    data_info_nxt = '{strb: wstrb, resp: 0};
                    fifo_write = 1'b1;
                    if(wlast) begin
                        state_nxt = WAIT_RESP;
                    end else begin
                        state_nxt = R;
                    end
                end else begin
                    state_nxt = R;
                end
            end

            WAIT_RESP: begin
                rd_info = R_SWITCH;
                if(rd_cmd == R_GET_RESP) begin
                    resp_info_nxt = '{resp: 0}; //Add actual response here?
                    state_nxt = B;
                end else begin
                    state_nxt = WAIT_RESP;
                end
            end
            B: begin
                bvalid = 1'b1;
                rd_info = R_BUSY;
                if(bready) begin
                    state_nxt = IDLE;
                end else begin
                    state_nxt = B;
                end
            end

            default: state_nxt = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state_cur <= IDLE;
            id_cur <= {ID_WIDTH{1'b0}};
            addr_info_cur <= '{addr: {ADDR_WIDTH{1'b0}}, len: 4'b0, size: 3'b0, burst: 2'b0};
            data_info_cur <= '{strb: 4'b0, resp: 2'b0};
            resp_info_cur <= '{resp: 2'b0};
        end else begin
            state_cur <= state_nxt;
            id_cur <= id_nxt;
            addr_info_cur <= addr_info_nxt;
            data_info_cur <= data_info_nxt;
            resp_info_cur <= resp_info_nxt;
        end
    end

    //Continous assignment for driving internal interface
    assign addr_info.addr = addr_info_cur.addr;
    assign addr_info.len = addr_info_cur.len;
    assign addr_info.burst = addr_info_cur.burst;
    assign addr_info.size = addr_info_cur.size;

    assign data = wdata;

    //Continous assignment for driving the external interface
    assign bid = id_cur;
    assign bresp = resp_info_cur.resp;

endmodule