/*
This module should (as the other ones) respond to its commands from the engine.
It should also when invoking switch, and the engine responds with disable, put it in idle
*/
import bridge_utils::*;

module slave_axi_writer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,

    // APB interface
    output logic [ADDR_WIDTH-1:0]    paddr,
    output logic [DATA_WIDTH-1:0]    pwdata,
    output logic                     pwrite,
    output logic                     penable,
    output logic [1:0]               psel,
    input  logic [DATA_WIDTH-1:0]    prdata,
    input  logic                     pready,
    input  logic                     pslverr,

    apb_inf.master_apb apb_rw_inf

);
    typedef enum {IDLE, READ_WRITE, DONE} p_state_t;
    typedef enum {SETUP, ACCESS} p_phase_t;

    logic [ADDR_WIDTH-1:0] data;

    //Internal registers'
    access_type_t access_cur, access_nxt;
    p_state_t state_cur, state_nxt;
    p_phase_t phase_cur, phase_nxt;
    logic [3:0] beats_cur, beats_nxt;  //Current beats NB! Null indexed!

    addr_info_t addr_info_cur, addr_info_nxt;   //Holds selected target

    always_comb begin
        apb_rw_inf.fifo_read = 1'b0;
        apb_rw_inf.fifo_write = 1'b0;

        access_nxt = access_cur;
        beats_nxt = beats_cur;
        addr_info_nxt = addr_info_cur;
        state_nxt = state_cur;
        phase_nxt = phase_cur;

        pwrite = 1'b0;
        penable = 1'b0;
        psel = 2'b00;

        case(state_cur)
            IDLE: begin
                apb_rw_inf.apb_info = APB_IDLE;
                if(apb_rw_inf.apb_cmd == APB_READ) begin
                    access_nxt = READ;
                    addr_info_nxt = apb_rw_inf.addr_info_rd;
                    state_nxt = READ_WRITE;
                end else if(apb_rw_inf.apb_cmd == APB_WRITE) begin
                    access_nxt = WRITE;
                    addr_info_nxt = apb_rw_inf.addr_info_wr;
                    state_nxt = READ_WRITE;
                end else begin
                    state_nxt = IDLE;
                end
            end
            
            READ_WRITE: begin
                apb_rw_inf.apb_info = APB_BUSY;

                pwrite = (access_cur == WRITE) ? 1'b1 : 1'b0;
                //Select signal done with address decoding
                //psel[0] = (addr_info_cur.addr >= 32'h0001_F000) && (addr_info_cur.addr <= 32'h0001_FFFF);
                psel[0] = (addr_info_cur.addr >= 32'h0002_F000) && (addr_info_cur.addr <= 32'h0002_FFFF);

                case(phase_cur)
                    SETUP: begin
                        penable = 1'b0;
                        phase_nxt = ACCESS;
                    end

                    ACCESS: begin
                        penable = 1'b1;
                        if(pready) begin
                            apb_rw_inf.fifo_write = (access_cur == READ) ? 1'b1 : 1'b0; //Under a read operation from the AXI, we need to write to the FIFO
                            apb_rw_inf.fifo_read = (access_cur == WRITE) ? 1'b1 : 1'b0; //Under a write operation from the AXI, we need to read from the FIFO
                            if(beats_cur == addr_info_cur.len) begin
                                beats_nxt = 4'b0;
                                state_nxt = DONE;
                                phase_nxt = SETUP;
                            end else begin
                                beats_nxt = beats_cur + 1'b1;
                                addr_info_nxt.addr = addr_info_cur.addr + (addr_info_cur.size * 8);
                                phase_nxt = SETUP;
                            end
                        end else begin
                            phase_nxt = ACCESS;
                        end
                    end
                endcase
            end

            //NBNB! Note that the APB wont go out of done before you give it disable
            DONE: begin
                apb_rw_inf.apb_info = APB_SWITCH;
                if(apb_rw_inf.apb_cmd == APB_DISABLE) begin
                    state_nxt = IDLE;
                end else begin
                    state_nxt = DONE;
                end
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state_cur <= IDLE;
            access_cur <= READ;
            phase_cur <= SETUP;
            beats_cur <= 4'b0;
            addr_info_cur <= '{addr: {ADDR_WIDTH{1'b0}}, len: 4'b0, size: 3'b0, burst: 2'b0};
        end else begin
            state_cur <= state_nxt;
            access_cur <= access_nxt;
            phase_cur <= phase_nxt;
            beats_cur <= beats_nxt;
            addr_info_cur <= addr_info_nxt;
        end
    end

    assign paddr = addr_info_cur.addr;
    assign pwdata = apb_rw_inf.data_in;
    assign apb_rw_inf.data_out = prdata;

endmodule

