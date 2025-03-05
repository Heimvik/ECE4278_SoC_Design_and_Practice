/*
Module to write a spesific adress on the axi bus.
Inputs: addr_msg specifying the adress to write to
        data_msg array specifying the data to write
Outputs: Error code, valid message id

Once the id appears on the valid msg id output, the message is written to the salve which responed with the given error code.
*/
module axi_master_writer(
    ch_aw.tx inf_aw,
    ch_dw.tx inf_dw,
    ch_b.rx inf_b,
    input axi_utils::addr_msg addr_msg,
    input axi_utils::data_msg data_msg_buffer[axi_utils::axi_data_buffer_size],
    output axi_utils::resp_msg resp_msg_buffer_cur,
    output int unsigned valid_msg_id_cur
);
    import axi_utils::*;

    ch_state state_cur, state_nxt = AW;

    int unsigned target_beats_cur, target_beats_nxt;
    int unsigned beats_cur;

    int unsigned valid_msg_id_nxt;

    resp_msg resp_msg_buffer_nxt;

    always_comb begin
        /*
        state_nxt = state_cur;
        inf_aw.VALID = 0;
        inf_aw.ID = '0;
        inf_aw.ADDR = '0;
        inf_aw.LEN = '0;
        inf_aw.SIZE = '0;
        inf_aw.BURST = '0;
        inf_aw.LOCK = '0;
        inf_aw.CACHE = '0;
        inf_aw.PROT = '0;

        inf_dw.VALID = 0;
        inf_dw.ID = '0;
        inf_dw.DATA = '0;
        inf_dw.STRB = '0;
        inf_dw.LAST = 0;

        inf_b.READY = 0;

        state_nxt = state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;
        resp_msg_buffer_nxt = resp_msg_buffer_cur;
        */

        case (state_cur)
            AW: begin
                $display("Master: STATE AW %0d at %0t", AW,$time);
                inf_aw.VALID = 1;

                inf_aw.ID = addr_msg.ID;
                inf_aw.ADDR = addr_msg.ADDR;
                inf_aw.LEN = addr_msg.LEN;
                inf_aw.SIZE = addr_msg.SIZE;
                inf_aw.BURST = addr_msg.BURST;
                inf_aw.LOCK = addr_msg.LOCK;
                inf_aw.CACHE = addr_msg.CACHE;
                inf_aw.PROT = addr_msg.PROT;
                target_beats_nxt = addr_msg.LEN;
                if (inf_aw.READY && inf_aw.VALID) begin
                    state_nxt = DW;
                end else begin
                    state_nxt = AW;
                end
            end
            DW: begin
                $display("Master: STATE DW %0d at %0t", DW,$time);
                inf_aw.VALID = 0;

                inf_dw.VALID = 1;
                inf_dw.ID = addr_msg.ID;
                inf_dw.DATA = data_msg_buffer[beats_cur].DATA;
                inf_dw.STRB = data_msg_buffer[beats_cur].STRB;
                inf_dw.LAST = (beats_cur == target_beats_cur);
                if(inf_dw.LAST && inf_dw.READY && inf_dw.VALID) begin
                    state_nxt = B;
                end else begin
                    state_nxt = DW;
                end
            end
            B: begin
                inf_dw.VALID = 0;
                inf_dw.LAST = 0;

                inf_b.READY = 1;
                resp_msg_buffer_nxt = '{inf_b.RESP, inf_b.ID};
                valid_msg_id_nxt = inf_b.ID;
                if(inf_b.VALID) begin
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
            unique if(!inf_dw.LAST && inf_dw.READY && inf_dw.VALID) begin
                beats_cur <= beats_cur + 1;
            end else if(!inf_dw.LAST && !(inf_dw.READY && inf_dw.VALID)) begin
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