/*
The AXI slave reader slould respond to a master's read request if you are the one being adressed, and if you are, send the data
by sending the data back to the master following the AXI protocol.
Inputs: The interface
Outputs: The data, valid message id
*/

module axi_slave_writer(
    ch_aw.rx inf_aw,
    ch_dw.rx inf_dw,
    ch_b.tx inf_b,
    output axi_utils::data_msg data_msg_frontbuffer_cur[axi_utils::axi_data_buffer_size],
    output int unsigned valid_msg_id_cur
);
    import axi_utils::*;

    ch_state slave_state_cur = AR;
    ch_state slave_state_nxt = AR;

    int unsigned target_beats_cur, target_beats_nxt = 0;
    int unsigned beats_cur, beats_nxt = 0;

    int unsigned valid_msg_id_nxt;

    addr_msg addr_msg_cur, addr_msg_nxt;
    data_msg data_msg_frontbuffer_nxt[axi_data_buffer_size];
    data_msg data_msg_backbuffer_cur[axi_data_buffer_size];
    data_msg data_msg_backbuffer_nxt[axi_data_buffer_size];

    always_comb begin
        /*
        inf_b.ID = '0;
        inf_b.RESP = '0;
        inf_b.VALID = 0;

        inf_aw.READY = 0;
        inf_dw.READY = 0;

        addr_msg_nxt = addr_msg_cur;

        slave_state_nxt = slave_state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;
        */
        case(slave_state_cur)
            AR: begin
                $display("Slave: STATE AR %0d at %0t", AR,$time);
                inf_aw.READY = 1;
                if(inf_aw.ADDR == dmac_utils::dmac_addr) begin
                    //We are being adressed, save it in the adress object
                    addr_msg_nxt.ID = inf_aw.ID;
                    addr_msg_nxt.ADDR = inf_aw.ADDR;
                    addr_msg_nxt.LEN = inf_aw.LEN;
                    addr_msg_nxt.SIZE = inf_aw.SIZE;
                    addr_msg_nxt.BURST = inf_aw.BURST;
                    addr_msg_nxt.LOCK = inf_aw.LOCK;
                    addr_msg_nxt.CACHE = inf_aw.CACHE;
                    addr_msg_nxt.PROT = inf_aw.PROT;

                    target_beats_nxt = inf_aw.LEN;
                    valid_msg_id_nxt = inf_aw.ID;
                    slave_state_nxt = DR;
                end
                if(inf_aw.READY && inf_aw.VALID) begin
                    slave_state_nxt = DR;
                end else begin
                    slave_state_nxt = AR;
                end                
            end
            DR: begin
                $display("Slave: STATE DR %0d at %0t", DR,$time);
                inf_aw.READY = 0;

                inf_dw.READY = 1;
                data_msg_backbuffer_nxt[beats_cur] = '{ID: inf_dw.ID, DATA: inf_dw.DATA, STRB: inf_dw.STRB};
                
                if(inf_dw.LAST && inf_dw.READY && inf_dw.VALID) begin
                    slave_state_nxt = B;
                end else begin
                    slave_state_nxt = DR;
                end
            end
            B: begin
                inf_dw.READY = 0;

                inf_b.VALID = 1;
                inf_b.ID = valid_msg_id_cur;
                inf_b.RESP = '0; //Change accordingly'
                data_msg_frontbuffer_nxt = data_msg_backbuffer_cur;
                
                if(inf_b.READY) begin
                    slave_state_nxt = AR;
                end else begin
                    slave_state_nxt = B;
                end
            end
            default: begin
                $display("Invalid main state in axi_slave_writer, being %0d, and not %0d", slave_state_cur, AR);
            end
        endcase
    end

    always_ff @(posedge inf.ch_global.clk or posedge inf.ch_global.rst) begin
        if (inf.ch_global.rst) begin
            slave_state_cur <= AR;
        end else begin
            unique if(!inf_dw.LAST && inf_dw.READY && inf_dw.VALID) begin
                beats_cur <= beats_cur + 1;
            end else if(!inf_dw.LAST && !(inf_dw.READY && inf_dw.VALID)) begin
                beats_cur <= beats_cur;
            end else begin
                beats_cur <= 0;
                //assert (beats_nxt == target_beats_cur) else $fatal("AXI read: beats_nxt != beat_trgt_cur on last beat");
            end
            slave_state_cur <= slave_state_nxt;
            target_beats_cur <= target_beats_nxt;
            valid_msg_id_cur <= valid_msg_id_nxt;
            data_msg_backbuffer_cur = data_msg_backbuffer_nxt;
            data_msg_frontbuffer_cur = data_msg_frontbuffer_nxt;
        end
        $display("beats: %0d, target_beats: %0d", beats_cur, target_beats_cur);
    end
endmodule

                
                





