/*
Module SALVE_AXI_READ
This module implements the AXI slave write channels, which it reads from and has an axi interface to the outside.
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
    axi_reader_inf.reader r_internal_inf
)
    import bridge_utils::*;
    typedef enum {IDLE,AW,W,WAIT_B,B} r_state;
    
    //Internal registers
    r_state state_cur, state_nxt = IDLE;

    always_comb begin
        r_internal_inf.addr_info_valid = 1'b0;
        r_internal_inf.data_valid = 1'b0;


        awready = 1'b0;
        wready = 1'b0;
        bvalid = 1'b0;

        
        case(state)
            IDLE: begin
                r_internal_inf.axi_r_out_state = R_IDLE;
                if(axi_r_in_state == W_GET_ADDR_DATA) begin
                    next_state = AR;
                end else begin
                    next_state = IDLE;
                end
            end

            AR: begin
                awready = 1'b1;
                r_internal_inf.axi_r_out_state = R_BUSY;
                if(awvalid) begin
                    r_internal_inf.addr_info_valid = 1'b1;
                    next_state = R;
                end else begin
                    next_state = AR;
                end
            end

            R: begin
                wready = 1'b1;
                r_internal_inf.axi_r_out_state = R_BUSY;
                if(wvalid) begin
                    r_internal_inf.data_valid = 1'b1;
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
                r_internal_inf.axi_r_out_state = R_SWITCH;
                if(r_internal_inf.axi_r_in_state == R_GET_RESP) begin
                    next_state = B;
                end else begin
                    next_state = WAIT_RESP;
                end
            end
            B: begin
                bvalid = 1'b1;
                r_internal_inf.axi_r_out_state = R_BUSY;
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
    assign r_internal_inf.addr_info.id = awid;
    assign r_internal_inf.addr_info.addr = awaddr;
    assign r_internal_inf.addr_info.len = awlen;
    assign r_internal_inf.addr_info.size = awsize;
    assign r_internal_inf.data = wdata;

    //Continous assignment for driving the external interface
    assign bid = r_internal_inf.resp_info.id;
    assign bresp = r_internal_inf.resp_info.resp;

endmodule