
//Internal interface toward the axi_reader
interface axi_reader_inf #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    import bridge_utils::*;

    //Control between the axi_reader and the engine
    rd_cmd_t rd_cmd;
    rd_info_t rd_info;

    //Metadata and transfer information
    logic addr_info_valid;  //Input to middle register
    addr_info_t addr_info;

    //Actual data
    logic data_valid;
    logic [DATA_WIDTH-1:0] data;

    modport reader(input rd_cmd,
                   output rd_info, 
                   output addr_info_valid, addr_info,
                   output data_info_valid, data_info, 
                   output data_valid, data
                   input resp_info);

    modport engine(input rd_info, 
                   output rd_cmd);

    modport addr_info_reg(input addr_info_valid, addr_info);
    modport data_fifo(input data_valid, data);
endinterface

//Internal interface toward the axi_writer
interface axi_writer_inf #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    import bridge_utils::*;

    //Control between the axi_reader and the engine
    wr_cmd_t wr_cmd;
    wr_info_t wr_info;

    //Metadata and transfer information
    logic addr_info_valid;  //Input to middle register
    addr_info_t addr_info;  

    //Actual data
    logic data_ready;
    logic [DATA_WIDTH-1:0] data;

    modport writer(input wr_cmd,
                   output wr_info, 
                   output addr_info_valid, addr_info, 
                   output data_ready, input data);

    modport engine(input wr_info,
                   output wr_cmd);

    modport addr_info_reg(input addr_info_valid, addr_info);
    modport data_fifo(input data_ready, output data);
endinterface