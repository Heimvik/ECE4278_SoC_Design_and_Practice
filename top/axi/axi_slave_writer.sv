/*
The AXI slave reader slould respond to a master's read request if you are the one being adressed, and if you are, send the data
by sending the data back to the master following the AXI protocol.
Inputs: The interface
Outputs: The data, valid message id
*/

module axi_slave_writer(
    axi4 inf,
    output axi_utils::data_msg data_msg_frontbuffer_cur[axi_utils::axi_data_buffer_size],
    output int unsigned valid_msg_id_cur
);
    import axi_utils::*;

    ch_state state_cur, state_nxt = AR;

    //`define inf.ch_addr_write.rx inf.ch_addr_write.rx;
    //`define inf.ch_data_write.rx inf.ch_data_write.rx;
    //`define inf.ch_resp.tx inf.ch_resp.tx;

    int unsigned target_beats_cur, target_beats_nxt = 0;
    int unsigned beats_cur, beats_nxt = 0;

    int unsigned valid_msg_id_nxt;

    addr_msg addr_msg_cur, addr_msg_nxt;
    data_msg data_msg_frontbuffer_nxt[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_backbuffer_cur[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_backbuffer_nxt[axi_data_buffer_size] = '{default: '0};

    always_comb begin
        inf.ch_resp.tx.ID = '0;
        inf.ch_resp.tx.RESP = '0;
        inf.ch_resp.tx.VALID = 0;

        addr_msg_nxt = addr_msg_cur;

        state_nxt = state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;

        case(state_cur)
            AR: begin
                inf.ch_addr_write.rx.READY = 1;
                if(inf.ch_addr_write.rx.ADDR == dmac_utils::dmac_addr) begin
                    //We are being adressed, save it in the adress object
                    addr_msg_nxt.ID = inf.ch_addr_write.rx.ID;
                    addr_msg_nxt.ADDR = inf.ch_addr_write.rx.ADDR;
                    addr_msg_nxt.LEN = inf.ch_addr_write.rx.LEN;
                    addr_msg_nxt.SIZE = inf.ch_addr_write.rx.SIZE;
                    addr_msg_nxt.BURST = inf.ch_addr_write.rx.BURST;
                    addr_msg_nxt.LOCK = inf.ch_addr_write.rx.LOCK;
                    addr_msg_nxt.CACHE = inf.ch_addr_write.rx.CACHE;
                    addr_msg_nxt.PROT = inf.ch_addr_write.rx.PROT;
                    target_beats_nxt = inf.ch_addr_write.rx.LEN;
                    state_nxt = DR;
                end
                if(inf.ch_addr_write.rx.READY && inf.ch_addr_write.rx.VALID) begin
                    state_nxt = DR;
                end else begin
                    state_nxt = AR;
                end                
            end
            DR: begin
                inf.ch_addr_write.rx.READY = 0;

                inf.ch_data_write.rx.READY = 1;
                data_msg_backbuffer_nxt[beats_cur] = '{ID: inf.ch_data_write.rx.ID, DATA: inf.ch_data_write.rx.DATA, STRB: inf.ch_data_write.rx.STRB};
                
                if(inf.ch_data_write.rx.LAST && inf.ch_data_write.rx.READY && inf.ch_data_write.rx.VALID) begin
                    assert (beats_nxt == target_beats_cur) else $fatal("AXI read: beats_nxt != beat_trgt_cur on last beat");
                    state_nxt = B;
                end else begin
                    state_nxt = DW;
                end
            end
            B: begin
                inf.ch_resp.tx.VALID = 1;
                inf.ch_resp.tx.ID = valid_msg_id_cur;
                inf.ch_resp.tx.RESP = '0; //Change accordingly
                if(inf.ch_resp.tx.READY) begin
                    state_nxt = AR;
                end else begin
                    state_nxt = B;
                end
            end
            default: begin
                $display("Invalid main state in axi_slave_writer!");
            end
        endcase
    end

    always_ff @(posedge inf.ch_global.clk or posedge inf.ch_global.rst) begin
        if (!inf.ch_global.rst) begin
            state_cur <= AR;
        end else begin
            unique if(!inf.ch_data_write.rx.LAST && inf.ch_data_write.rx.READY && inf.ch_data_write.rx.VALID) begin
                beats_cur <= beats_cur + 1;
            end else if(!inf.ch_data_write.rx.LAST && !(inf.ch_data_write.rx.READY && inf.ch_data_write.rx.VALID)) begin
                beats_cur <= beats_cur;
            end else begin
                beats_cur <= 0;
            end
            state_cur <= state_nxt;
            target_beats_cur <= target_beats_nxt;
            valid_msg_id_cur <= valid_msg_id_nxt;
            data_msg_backbuffer_cur = data_msg_backbuffer_nxt;
            data_msg_frontbuffer_cur = data_msg_frontbuffer_nxt;
        end
    end
endmodule

                
                





