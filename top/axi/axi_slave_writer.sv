/*
The AXI slave reader slould respond to a master's read request if you are the one being adressed, and if you are, send the data
by sending the data back to the master following the AXI protocol.
Inputs: The interface
Outputs: The data, valid message id
*/

module axi_slave_reader(
    interface inf,
    output axi_utils::data_msg data_msg_frontbuffer_cur[axi_utils::axi_data_buffer_size],
    output int unsigned valid_msg_id
);
    import axi_utils::*;

    ch_state state_cur, state_nxt = AR;
    ar_state ar_state_cur, ar_state_nxt = AR_READY;
    dr_state dr_state_cur, dr_state_nxt = DR_READY;
    bw_state b_state_cur, b_state_nxt = B_READY;

    `define aw_inf inf.ch_aw.addr_reader;
    `define dw_inf inf.ch_w.data_reader;
    `define b_inf inf.ch_b.b_writer;

    int unsigned target_beats_cur, target_beats_nxt = 0;
    int unsigned beats_cur, beats_nxt = 0;

    int unsigned valid_msg_id_nxt;

    addr_msg addr_msg_cur, addr_msg_nxt;
    data_msg data_msg_frontbuffer_nxt[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_backbuffer_cur[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_backbuffer_nxt[axi_data_buffer_size] = '{default: '0};

    always_comb begin
        b_ing.ID = '0;
        b_inf.RESP = '0;
        b_inf.VALID = 0;

        addr_msg_nxt = addr_msg_cur;

        state_nxt = state_cur;
        dr_state_nxt = dr_state_cur;
        b_state_nxt = b_state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;

        case(state_cur)
            AR: begin
                case(ar_state_cur)
                    AR_READY: begin
                        aw_inf.ARREADY = 1;
                        if(aw_inf.VALID) begin
                            state_nxt = AR_READ;
                        end else begin
                            state_nxt = AR;
                        end
                    end
                    AR_READ: begin
                        //Make an adress object
                        if(inf.ch_ar.ARADDR == dmac_utils::dmac_addr) begin
                            //We are being adressed, save it in the adress object
                            addr_msg_nxt.ID = inf.ch_ar.ARID;
                            addr_msg_nxt.ADDR = inf.ch_ar.ARADDR;
                            addr_msg_nxt.LEN = inf.ch_ar.ARLEN;
                            addr_msg_nxt.SIZE = inf.ch_ar.ARSIZE;
                            addr_msg_nxt.BURST = inf.ch_ar.ARBURST;
                            addr_msg_nxt.LOCK = inf.ch_ar.ARLOCK;
                            addr_msg_nxt.CACHE = inf.ch_ar.ARCACHE;
                            addr_msg_nxt.PROT = inf.ch_ar.ARPROT;
                            state_nxt = DR;
                        end
                        ar_state_nxt = AR_READY;
                    end
                endcase
            end
            DR: begin
                aw_inf.ARREADY = 0;
                case(dr_state_cur)
                    DR_READY: begin
                        dr_inf.RREADY = 1;
                        if(dr_inf.VALID) begin
                            dr_state_nxt = DR_READ;
                        end else begin
                            dr_state_nxt = DR_READY;
                        end
                    end
                    DR_READ: begin
                        data_msg_backbuffer_nxt[beats_cur] = '{ID: dr_inf.RID, DATA: dr_inf.RDATA, STRB: dr_inf.STRB};
                        if (dr_inf.VALID) begin
                            if (dr_inf.RLAST) begin
                                dr_inf.RREADY = 0; //Apply read response/delay here
                                assert (beats_nxt == target_beats_cur) else $fatal("AXI read: beats_nxt != beat_trgt_cur on last beat");
                                data_msg_frontbuffer_nxt = data_msg_backbuffer_cur; //Write through on the double buffer
                                valid_msg_id_nxt = data_msg_cur.ID;
                                dr_state_nxt = DR_READY;
                                state_nxt = AW;
                            end else begin
                                dr_inf.RREADY = 1;
                                dr_state_nxt = DR_READ;
                                state_nxt = DR;
                            end
                        end else begin
                            dr_state_nxt = DR_READY;
                            state_nxt = AW;
                        end
                    end
                endcase
            end
            B: begin
                case(b_state_cur)
                    B_VALID: begin
                        b_inf.VALID = 1;
                        b_inf.ID = valid_msg_id_cur;
                        b_inf.RESP = '0;
                        if(b_inf.READY) begin
                            b_state_nxt = B_WRITE;
                        end else begin
                            b_state_nxt = B_VALID;
                        end
                    end
                    B_WRITE: begin
                        //If all OK
                        b_inf.VALID = 0;
                        b_state_nxt = B_VALID;
                        state_nxt = AR;
                    end
                endcase
            end
        endcase
    end

    always_ff @(posedge inf.ch_global.clk or negedge inf.ch_global.rst_n) begin
        if (!inf.ch_global.rst) begin
            state_cur <= AR;
            ar_state_cur <= AR_READY;
            dr_state_cur <= DR_READY;
            b_state_cur <= B_VALID;
        end else begin
            state_cur <= state_nxt;
            ar_state_cur <= ar_state_nxt;
            dr_state_cur <= dr_state_nxt;
            b_state_cur <= b_state_nxt;
            target_beats_cur <= target_beats_nxt;
            valid_msg_id_cur <= valid_msg_id_nxt;
            data_msg_backbuffer_cur = data_msg_backbuffer_nxt;
            data_msg_frontbuffer_cur = data_msg_frontbuffer_nxt;
        end
    end
endmodule

                
                





