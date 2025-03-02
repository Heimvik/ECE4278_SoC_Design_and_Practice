module axi_tb;
    import axi_utils::*;
    //External interface
    axi4_inf inf();

    //Internal interface
    addr_msg addr_msg = '{default: '0};
    data_msg data_msg_buffer[data_read_buffer_size] = '{default: '0};
    int unsigned valid_msg_id_cur = 0;

    //Reader module
    axi_reader reader(
        .inf(inf),
        .addr_msg(addr_msg),
        .data_msg_frontbuffer_cur(data_msg_frontbuffer_cur),
        .valid_msg_id_cur(valid_msg_id_cur)
    );

    //Writer module

    //Clock generation
    initial begin
        inf.ch_global.rst = 1;
        #10 inf.ch_global.rst = 0;
        inf.ch_global.clk = 0;
        forever begin
            #5 inf.ch_global.clk = ~inf.ch_global.clk;
        end
    end

    //Testbench
    initial begin
        
    end
endmodule