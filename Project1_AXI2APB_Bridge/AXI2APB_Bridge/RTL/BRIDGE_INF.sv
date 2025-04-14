interface brigde_inf #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    import bridge_utils::*;
    
endinterface

//Internal interface toward the axi_writer
interface axi_reader_inf #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    import bridge_utils::*;

    //Control between the axi_reader and the engine
    axi_w_in_state_t axi_r_in_state;
    axi_w_out_state_t axi_r_out_state;

    //Metadata and transfer information
    logic addr_info_valid;
    addr_info_t addr_info;

    logic resp_info_valid;
    resp_info_t resp_info;

    //Actual data
    logic data_valid;
    logic [DATA_WIDTH-1:0] data;

    modport reader(input axi_r_in_state, resp_info_valid, resp_info,
                   output axi_r_out_state, addr_info_valid, addr_info, 
                   output data_valid, data);

    modport engine(input axi_r_out_state, addr_info_valid, addr_info,
                   output axi_r_in_state, resp_info_valid, resp_info);

    modport fifo(output data_valid, data);
endinterface