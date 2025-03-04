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

    //`define aw_inf inf.ch_addr_write.tx;
    //`define dw_inf inf.ch_data_write.tx;
    //`define b_inf inf.ch_resp.rx;

    int unsigned target_beats_cur, target_beats_nxt;
    int unsigned beats_cur;

    int unsigned valid_msg_id_nxt;

    resp_msg resp_msg_buffer_nxt;

    always_comb begin
        /*
        state_nxt = state_cur;
        inf.ch_addr_write.VALID = 0;
        inf.ch_addr_write.ID = '0;
        inf.ch_addr_write.ADDR = '0;
        inf.ch_addr_write.LEN = '0;
        inf.ch_addr_write.SIZE = '0;
        inf.ch_addr_write.BURST = '0;
        inf.ch_addr_write.LOCK = '0;
        inf.ch_addr_write.CACHE = '0;
        inf.ch_addr_write.PROT = '0;

        inf.ch_data_write.VALID = 0;
        inf.ch_data_write.ID = '0;
        inf.ch_data_write.DATA = '0;
        inf.ch_data_write.STRB = '0;
        inf.ch_data_write.LAST = 0;

        inf.ch_resp.READY = 0;

        state_nxt = state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;
        resp_msg_buffer_nxt = resp_msg_buffer_cur;
        */

        case (state_cur)
            AW: begin
                $display("Master: STATE AW %0d at %0t", AW,$time);
                inf.ch_addr_write.VALID = 1;

                inf.ch_addr_write.ID = addr_msg.ID;
                inf.ch_addr_write.ADDR = addr_msg.ADDR;
                inf.ch_addr_write.LEN = addr_msg.LEN;
                inf.ch_addr_write.SIZE = addr_msg.SIZE;
                inf.ch_addr_write.BURST = addr_msg.BURST;
                inf.ch_addr_write.LOCK = addr_msg.LOCK;
                inf.ch_addr_write.CACHE = addr_msg.CACHE;
                inf.ch_addr_write.PROT = addr_msg.PROT;
                target_beats_nxt = addr_msg.LEN;
                if (inf.ch_addr_write.READY && inf.ch_addr_write.VALID) begin
                    state_nxt = DW;
                end else begin
                    state_nxt = AW;
                end
            end
            DW: begin
                $display("Master: STATE DW %0d at %0t", DW,$time);
                inf.ch_addr_write.VALID = 0;

                inf.ch_data_write.VALID = 1;
                inf.ch_data_write.ID = addr_msg.ID;
                inf.ch_data_write.DATA = data_msg_buffer[beats_cur].DATA;
                inf.ch_data_write.STRB = data_msg_buffer[beats_cur].STRB;
                inf.ch_data_write.LAST = (beats_cur == target_beats_cur);
                if(inf.ch_data_write.LAST && inf.ch_data_write.READY && inf.ch_data_write.VALID) begin
                    state_nxt = B;
                end else begin
                    state_nxt = DW;
                end
            end
            B: begin
                inf.ch_data_write.VALID = 0;
                inf.ch_data_write.LAST = 0;

                inf.ch_resp.READY = 1;
                resp_msg_buffer_nxt = '{inf.ch_resp.RESP, inf.ch_resp.ID};
                valid_msg_id_nxt = inf.ch_resp.ID;
                if(inf.ch_resp.VALID) begin
                    state_nxt = AW;
                end else begin
                    state_nxt = B;
                end
            end
            default: begin
                $display("Invalid main state in axi_master_writer, being %0d", state_cur);
            end

        endcase
    end

    always_ff @(posedge inf.ch_global.clk) begin
        if(inf.ch_global.rst) begin
            state_cur <= AW;
        end else begin
            $display("Master: beats_cur %0d target_beats_cur %0d", beats_cur, target_beats_cur);
            unique if(!inf.ch_data_write.LAST && inf.ch_data_write.READY && inf.ch_data_write.VALID) begin
                beats_cur <= beats_cur + 1;
            end else if(!inf.ch_data_write.LAST && !(inf.ch_data_write.READY && inf.ch_data_write.VALID)) begin
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