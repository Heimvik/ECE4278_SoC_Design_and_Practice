/*
Module to read a spesific adress from the axi bus.
Inputs: addr_msg specifying the adress to read from
Outputs: data_msg containing the data read from the adress

Once the id appears on the valid msg id output, the message is read from the bus with the given error code.
*/
module axi_master_reader(
    input axi4_inf inf, 
    input axi_utils::addr_msg addr_msg,
    output axi_utils::data_msg data_msg_frontbuffer_cur[axi_utils::axi_data_buffer_size],
    output int unsigned valid_msg_id_cur
);
    import axi_utils::*;

    ch_state state_cur, state_nxt = AW;
    dr_state dr_state_cur, dr_state_nxt = DR_READY;

    `define ar_inf inf.ch_addr_read.tx;
    `define dr_inf inf.ch_data_read.rx;

    int unsigned target_beats_cur, target_beats_nxt = 0;
    int unsigned beats_cur, beats_nxt = 0;

    int unsigned valid_msg_id_nxt;

    data_msg data_msg_frontbuffer_nxt[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_backbuffer_cur[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_backbuffer_nxt[axi_data_buffer_size] = '{default: '0};

    always_comb begin
        state_nxt = state_cur;
        ar_inf.ARVALID = 0;
        ar_inf.ARID = '0;
        ar_inf.ARADDR = '0;
        ar_inf.ARLEN = '0;
        ar_inf.ARSIZE = '0;
        ar_inf.ARBURST = '0;
        ar_inf.ARLOCK = '0;
        ar_inf.ARCACHE = '0;
        ar_inf.ARPROT = '0;

        dr_inf.RREADY = 0;

        state_nxt = state_cur;
        dr_state_nxt = dr_state_cur;
        target_beats_nxt = target_beats_cur;
        valid_msg_id_nxt = valid_msg_id_cur;
        data_msg_frontbuffer_nxt = data_msg_frontbuffer_cur;
        data_msg_backbuffer_nxt = data_msg_backbuffer_cur;
    
        case (state_cur)
            //Need to do a AW to the AR channel
            AW: begin 
                ar_inf.ARVALID = 1;
                ar_inf.ARID = addr_msg.ID;
                ar_inf.ARADDR = addr_msg.ADDR;
                ar_inf.ARLEN = addr_msg.LEN;
                ar_inf.ARSIZE = addr_msg.SIZE;
                ar_inf.ARBURST = addr_msg.BURST;
                ar_inf.ARLOCK = addr_msg.LOCK;
                ar_inf.ARCACHE = addr_msg.CACHE;
                ar_inf.ARPROT = addr_msg.PROT;
                target_beats_nxt = addr_msg.LEN;
                if (inf.ch_ar.ARREADY) begin
                    state_nxt = DR;
                end else begin
                    state_nxt = AW;
                end
            end
            DR: begin
                ar_inf.ARVALID = 0; //Could fuck up if running multiple in paralell
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
        endcase
    end

    always_ff @(posedge inf.ch_global.clk or negedge inf.ch_global.rst_n) begin
        if (!inf.ch_global.rst_n) begin
            state_cur <= AW;
            dr_state_cur <= DR_READ;
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
            data_msg_backbuffer_cur = data_msg_backbuffer_nxt;
            data_msg_frontbuffer_cur = data_msg_frontbuffer_nxt;
        end
    end
endmodule
