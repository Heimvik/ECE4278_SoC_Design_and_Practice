/*
Module SALVE_AXI_READ
This module interfaces the AXI slave write channels, which it reads from and has an axi interface to the outside.
*/
module slave_axi_reader #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
)(
    input logic clk,
    input logic rst_n,

    // AXI interface
    // Write Address Channel
    input logic [3:0] awid,
    input logic [ADDR_WIDTH:0] awaddr,
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
    axi_reader_inf.reader i_inf
)
    import bridge_utils::*;
    typedef enum {IDLE,AR,R,WAIT_B,B} r_state;
    
    //Internal registers
    r_state state_cur, state_nxt;

    always_comb begin
        i_inf.addr_info_valid = 1'b0;
        i_inf.data_valid = 1'b0;
        i_inf.data_info_valid = 1'b0;

        awready = 1'b0;
        wready = 1'b0;
        bvalid = 1'b0;

        case(state)
            IDLE: begin
                i_inf.rd_info = R_IDLE;
                if(i_inf.rd_cmd == W_GET_ADDR_DATA) begin
                    next_state = AR;
                end else begin
                    next_state = IDLE;
                end
            end

            AR: begin
                awready = 1'b1;
                i_inf.rd_info = R_BUSY;
                if(awvalid) begin
                    i_inf.addr_info_valid = 1'b1;
                    next_state = R;
                end else begin
                    next_state = AR;
                end
            end

            R: begin
                wready = 1'b1;
                i_inf.rd_info = R_BUSY;
                if(wvalid) begin
                    i_inf.data_valid = 1'b1;
                    i_inf.data_info_valid = 1'b1;
                    if(wlast) begin
                        next_state = WAIT_RESP;
                    end else begin
                        next_state = R;
                    end
                end else begin
                    next_state = R;
                end
            end

            WAIT_RESP: begin
                i_inf.rd_info = R_SWITCH;
                if(i_inf.rd_cmd == R_GET_RESP) begin
                    next_state = B;
                end else begin
                    next_state = WAIT_RESP;
                end
            end
            B: begin
                bvalid = 1'b1;
                i_inf.rd_info = R_BUSY;
                if(bready) begin
                    next_state = IDLE;
                end else begin
                    next_state = B;
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
    assign i_inf.addr_info.id = awid;
    assign i_inf.addr_info.addr = awaddr;
    assign i_inf.addr_info.len = awlen;
    assign i_inf.addr_info.burst = awburst;
    assign i_inf.addr_info.size = awsize;

    assign i_inf.data = wdata;
    assign i_inf.data_info.id = wid;

    //Continous assignment for driving the external interface
    assign bid = i_inf.resp_info.id;
    assign bresp = i_inf.resp_info.resp;

endmodule