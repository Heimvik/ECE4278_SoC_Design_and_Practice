module axi_tb;
    import axi_utils::*;

    //External interface
    axi4 inf();

    //Instanciate the input and output variables
    addr_msg addr_msg_write;
    data_msg data_msg_buffer_tx[axi_data_buffer_size] = '{default: '0};
    data_msg data_msg_buffer_rx[axi_data_buffer_size] = '{default: '0};
    resp_msg resp_msg_tx;
    int unsigned valid_msg_id_tx = 0;
    int unsigned valid_msg_id_rx = 0;

    //Test1: Get the axi_master_writer and the axi_slave_writer to communicate
    axi_master_writer master_writer(
        .inf(inf),
        .addr_msg(addr_msg_write),
        .data_msg_buffer(data_msg_buffer_tx),
        .resp_msg_buffer_cur(resp_msg_tx),
        .valid_msg_id_cur(valid_msg_id_tx)
    );
    axi_slave_writer slave_writer(
        .inf(inf),
        .data_msg_frontbuffer_cur(data_msg_buffer_rx),
        .valid_msg_id_cur(valid_msg_id_rx)
    );

    function void display_data_buffers();
        int i;
        $display("=== TX Buffer ===");
        for (i = 0; i < axi_data_buffer_size; i++) begin
            $display("TX[%0d] -> ID: %0d, DATA: %h, STRB: %b", 
                    i, data_msg_buffer_tx[i].ID, data_msg_buffer_tx[i].DATA, data_msg_buffer_tx[i].STRB);
        end

        $display("=== RX Buffer ===");
        for (i = 0; i < axi_data_buffer_size; i++) begin
            $display("RX[%0d] -> ID: %0d, DATA: %h, STRB: %b", 
                    i, data_msg_buffer_rx[i].ID, data_msg_buffer_rx[i].DATA, data_msg_buffer_rx[i].STRB);
        end
    endfunction

    //Clock generation
    initial begin
        inf.ch_global.rst = 0;
        inf.ch_global.clk = 0;
        forever begin
            #5 inf.ch_global.clk = ~inf.ch_global.clk;
        end
    end

    //Testbench
    initial begin
        addr_msg_write = '{ID: 4, ADDR: 32'h00000001, LEN: 4'b1111, SIZE: 3'b010, BURST: 2'b01, LOCK: 0, CACHE: 0, PROT: 0};
        //Fill the addr_msg and data_msg_buffer_tx
        for(int i = 0; i < axi_data_buffer_size; i++) begin
            data_msg_buffer_tx[i].ID = 5;
            data_msg_buffer_tx[i].DATA = i;
            data_msg_buffer_tx[i].STRB = 15;
        end
        wait(valid_msg_id_rx == valid_msg_id_tx && valid_msg_id_tx != 0);
        $display("Ids: %0d %0d", valid_msg_id_rx, valid_msg_id_tx);
        if(1) begin
            display_data_buffers();
            $display("Test passed");
        end else begin
            display_data_buffers();
            $display("Test failed");
        end
        $finish;
    end
endmodule