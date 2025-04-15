import bridge_utils::*;

module AXI2APB_TOP #(
    parameter ADDR_WIDTH            = 32,
    parameter DATA_WIDTH            = 32
)(
    input  logic clk,
    input  logic rst_n,

    output apb_cmd_t apb_cmd,
    input apb_info_t apb_info,

    wr_cmd_t wr_cmd,
    wr_info_t wr_info,

    rd_cmd_t rd_cmd,
    rd_info_t rd_info,

    logic arvalid,
    logic awvalid
);
    //1. Arbitrate on wither read or write
    typedef enum {IDLE,READ,WRITE} state_t;
    typedef enum {AXI_RECEIVE_ADDR, APB_RECEIVE_DATA, AXI_SEND_DATA} read_state_t;
    typedef enum {AXI_RECEIVE_ADDR_DATA, APB_SEND_DATA, AXI_SEND_RESP} write_state_t;
    
    state_t state_cur, state_nxt;
    read_state_t read_state_cur, read_state_nxt;
    write_state_t write_state_cur, write_state_nxt;
    access_type_t access_type_cur, access_type_nxt;

    always_comb begin
        state_nxt = state_cur;
        read_state_nxt = read_state_cur;
        write_state_nxt = write_state_cur;

        wr_cmd = W_DISABLE;
        rd_cmd = R_DISABLE;
        apb_cmd = APB_DISABLE;

        case(state_cur)
            //---IDLE (and arbitration)---//
            IDLE: begin
                if (arvalid || awvalid) begin
                    if (arvalid) begin
                        wr_cmd = W_GET_DATA;
                        state_nxt = READ;
                    end else if (awvalid) begin
                        rd_cmd = R_GET_ADDR_DATA;
                        state_nxt = WRITE;
                    end
                end
            end

            //---READ ENGINE---//
            READ: begin
                case(read_state_cur)
                    AXI_RECEIVE_ADDR: begin
                        if (wr_info == W_SWITCH) begin
                            apb_cmd = APB_READ;
                            read_state_nxt = APB_RECEIVE_DATA;
                        end
                    end

                    APB_RECEIVE_DATA: begin
                        if (apb_info == APB_SWITCH) begin
                            wr_cmd = W_GET_DATA;
                            read_state_nxt = AXI_SEND_DATA;
                        end
                    end

                    AXI_SEND_DATA: begin
                        if(wr_info == W_IDLE) begin
                            state_nxt = IDLE;
                            read_state_nxt = AXI_RECEIVE_ADDR;
                        end
                    end
                endcase
            end
            
            //---WRITE ENGINE---//
            WRITE: begin
                case(write_state_cur)
                    AXI_RECEIVE_ADDR_DATA: begin
                        if (rd_info == R_SWITCH) begin
                            apb_cmd = APB_WRITE;
                            write_state_nxt = APB_SEND_DATA;
                        end
                    end

                    APB_SEND_DATA: begin
                        if (apb_info == APB_SWITCH) begin
                            rd_cmd = R_GET_RESP;
                            write_state_nxt = AXI_SEND_RESP;
                        end
                    end

                    AXI_SEND_RESP: begin
                        if(rd_info == R_IDLE) begin
                            state_nxt = IDLE;
                            write_state_nxt = AXI_RECEIVE_ADDR_DATA;
                        end
                    end
                endcase
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_cur <= IDLE;
            read_state_cur <= AXI_RECEIVE_ADDR;
            write_state_cur <= AXI_RECEIVE_ADDR_DATA;
        end else begin
            state_cur <= state_nxt;
            read_state_cur <= read_state_nxt;
            write_state_cur <= write_state_nxt;
        end
    end
endmodule

/*
Possible performance improvements:
- Let the APB start before the AXI finishes
- Let a potential writer still be able to write to the FIFO while the APB is reading from the other one
*/
