/*
Module to write a spesific adress on the axi bus.
Inputs: addr_msg specifying the adress to write to
        data_msg array specifying the data to write
Outputs: Error code, valid message id

Once the id appears on the valid msg id output, the message is written to the salve which responed with the given error code.
*/
module axi_master_writer(
    interface inf,
    input axi_utils::addr_msg addr_msg,
    input axi_utils::data_msg data_msg_buffer[axi_utils::axi_data_buffer_size],
    output axi_utils::resp_msg resp_msg_buffer_cur,
    output int unsigned valid_msg_id_cur
);
    import axi_utils::*;

    ch_state state_cur, state_nxt = AW;
    dw_state dr_state_cur, dr_state_nxt = DW_VALID;
    br_state b_state_cur, b_state_nxt = B_READY;

    `define aw_inf inf.ch_aw.addr_writer;
    `define dw_inf inf.ch_w.data_writer;
    `define b_inf inf.ch_b.b_reader;

    int unsigned target_beats_cur, target_beats_nxt = 0;
    int unsigned beats_cur, beats_nxt = 0;

    int unsigned valid_msg_id_nxt;

    resp_msg resp_msg_buffer_nxt;

    always_comb begin
        state_nxt = state_cur;
        aw_inf.AWVALID = 0;
        aw_inf.AWID = '0;
        aw_inf.AWADDR = '0;
        aw_inf.AWLEN = '0;
        aw_inf.AWSIZE = '0;
        aw_inf.AWBURST = '0;
        aw_inf.AWLOCK = '0;
        aw_inf.AWCACHE = '0;
        aw_inf.AWPROT = '0;

        dw_inf.WVALID = 0;
        dw_inf.WID = '0;
        dw_inf.WDATA = '0;
        dw_inf.WSTRB = '0;
        dw_inf.WLAST = 0;

        state_nxt = state_cur;
        dr_state_nxt = dr_state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;
        resp_msg_buffer_nxt = resp_msg_buffer_cur;

        case (state_cur)
            AW: begin
                aw_inf.AWVALID = 1;
                aw_inf.AWID = addr_msg.ID;
                aw_inf.AWADDR = addr_msg.ADDR;
                aw_inf.AWLEN = addr_msg.LEN;
                aw_inf.AWSIZE = addr_msg.SIZE;
                aw_inf.AWBURST = addr_msg.BURST;
                aw_inf.AWLOCK = addr_msg.LOCK;
                aw_inf.AWCACHE = addr_msg.CACHE;
                aw_inf.AWPROT = addr_msg.PROT;
                target_beats_nxt = addr_msg.LEN;
                if (aw_inf.AWREADY) begin
                    state_nxt = DW;
                end else begin
                    state_nxt = AW;
                end
            end
            DW: begin
                aw_inf.AWVALID = 0;
                dw_inf.WVALID = 1;
                dw_inf.WID = addr_msg.ID;
                dw_inf.WDATA = data_msg_buffer[beats_cur].DATA;
                dw_inf.WSTRB = data_msg_buffer[beats_cur].STRB;
                dw_inf.WLAST = (beats_cur == target_beats_cur-1);
            end
            B: begin
                case(b_state_cur)
                    B_READY: begin
                        b_inf.RREADY = 1;
                        if(b_inf.VALID) begin
                            b_state_nxt = B_READ;
                        end else begin
                            b_state_nxt = B_READY;
                        end
                    end
                    B_READ: begin
                        b_inf.RREADY = 0;
                        resp_msg_buffer_nxt = '{b_inf.RRESP, b_inf.RID};
                        valid_msg_id_nxt = data_msg_cur.ID;
                        b_state_nxt = B_READY;
                        state_nxt = AW;
                    end
                endcase
            end
        endcase
    end

    always_ff @(posedge inf.ch_global.clk) begin
        if(!inf.ch_global.rst) begin
            state_cur <= AW;
            dr_state_cur <= DW_VALID;
        end else begin
            unique if(dw_inf.WREADY && dw_inf.WVALID) begin
                beats_cur <= beats_cur + 1;
            end else if(!dw_inf.WLAST && !(dw_inf.WREADY && dw_inf.WVALID)) begin
                beats_cur <= beats_cur;
            end else begin
                beats_cur <= 0;
            end
            state_cur <= state_nxt;
            dr_state_cur <= dr_state_nxt;
            target_beats_cur <= target_beats_nxt;
            valid_msg_id_cur <= valid_msg_id_nxt;
            resp_msg_buffer_cur <= resp_msg_buffer_nxt;
        end
    end
endmodule