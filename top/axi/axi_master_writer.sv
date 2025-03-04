/*
Module to write a spesific adress on the axi bus.
Inputs: addr_msg specifying the adress to write to
        data_msg array specifying the data to write
Outputs: Error code, valid message id

Once the id appears on the valid msg id output, the message is written to the salve which responed with the given error code.
*/
module axi_master_writer(
    axi4 inf,
    input axi_utils::addr_msg addr_msg,
    input axi_utils::data_msg data_msg_buffer[axi_utils::axi_data_buffer_size],
    output axi_utils::resp_msg resp_msg_buffer_cur,
    output int unsigned valid_msg_id_cur
);
    import axi_utils::*;

    ch_state state_cur, state_nxt = AW;
    dw_state dw_state_cur, dw_state_nxt = DW_VALID;
    br_state b_state_cur, b_state_nxt = B_READY;

    //`define aw_inf inf.ch_addr_write.tx;
    //`define dw_inf inf.ch_data_write.tx;
    //`define b_inf inf.ch_resp.rx;

    int unsigned target_beats_cur, target_beats_nxt = 0;
    int unsigned beats_cur, beats_nxt = 0;

    int unsigned valid_msg_id_nxt;

    resp_msg resp_msg_buffer_nxt;

    always_comb begin
        state_nxt = state_cur;
        inf.ch_addr_write.tx.VALID = 0;
        inf.ch_addr_write.tx.ID = '0;
        inf.ch_addr_write.tx.ADDR = '0;
        inf.ch_addr_write.tx.LEN = '0;
        inf.ch_addr_write.tx.SIZE = '0;
        inf.ch_addr_write.tx.BURST = '0;
        inf.ch_addr_write.tx.LOCK = '0;
        inf.ch_addr_write.tx.CACHE = '0;
        inf.ch_addr_write.tx.PROT = '0;

        inf.ch_data_write.tx.VALID = 0;
        inf.ch_data_write.tx.ID = '0;
        inf.ch_data_write.tx.DATA = '0;
        inf.ch_data_write.tx.STRB = '0;
        inf.ch_data_write.tx.LAST = 0;

        state_nxt = state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;
        resp_msg_buffer_nxt = resp_msg_buffer_cur;

        case (state_cur)
            AW: begin
                inf.ch_addr_write.tx.VALID = 1;

                inf.ch_addr_write.tx.ID = addr_msg.ID;
                inf.ch_addr_write.tx.ADDR = addr_msg.ADDR;
                inf.ch_addr_write.tx.LEN = addr_msg.LEN;
                inf.ch_addr_write.tx.SIZE = addr_msg.SIZE;
                inf.ch_addr_write.tx.BURST = addr_msg.BURST;
                inf.ch_addr_write.tx.LOCK = addr_msg.LOCK;
                inf.ch_addr_write.tx.CACHE = addr_msg.CACHE;
                inf.ch_addr_write.tx.PROT = addr_msg.PROT;
                target_beats_nxt = addr_msg.LEN;
                if (inf.ch_addr_write.tx.READY && inf.ch_addr_write.tx.VALID) begin
                    state_nxt = DW;
                end else begin
                    state_nxt = AW;
                end
            end
            DW: begin
                inf.ch_addr_write.tx.VALID = 0;

                inf.ch_data_write.tx.VALID = 1;
                inf.ch_data_write.tx.ID = addr_msg.ID;
                inf.ch_data_write.tx.DATA = data_msg_buffer[beats_cur].DATA;
                inf.ch_data_write.tx.STRB = data_msg_buffer[beats_cur].STRB;
                inf.ch_data_write.tx.LAST = (beats_cur == target_beats_cur-1);
                
                if(inf.ch_data_write.tx.LAST && inf.ch_data_write.tx.READY && inf.ch_data_write.tx.VALID) begin
                    state_nxt = B;
                end else begin
                    state_nxt = DW;
                end
            end
            B: begin
                inf.ch_resp.rx.READY = 1;
                resp_msg_buffer_nxt = '{inf.ch_resp.rx.RESP, inf.ch_resp.rx.ID};
                valid_msg_id_nxt = inf.ch_resp.rx.ID;
                if(inf.ch_resp.rx.VALID) begin
                    state_nxt = AW;
                end else begin
                    state_nxt = B;
                end
            end
            default: begin
                $display("Invalid main state in axi_master_writer!");
            end

        endcase
    end

    always_ff @(posedge inf.ch_global.clk) begin
        if(!inf.ch_global.rst) begin
            state_cur <= AW;
        end else begin
            unique if(!inf.ch_data_write.tx.LAST && inf.ch_data_write.tx.READY && inf.ch_data_write.tx.VALID) begin
                beats_cur <= beats_cur + 1;
            end else if(!inf.ch_data_write.tx.LAST && !(inf.ch_data_write.tx.READY && inf.ch_data_write.tx.VALID)) begin
                beats_cur <= beats_cur;
            end else begin
                beats_cur <= 0;
            end
            state_cur <= state_nxt;
            target_beats_cur <= target_beats_nxt;
            valid_msg_id_cur <= valid_msg_id_nxt;
            resp_msg_buffer_cur <= resp_msg_buffer_nxt;
        end
    end
endmodule