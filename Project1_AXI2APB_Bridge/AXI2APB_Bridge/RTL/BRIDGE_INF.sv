
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
    addr_info_t addr_info;

    //Actual data
    logic data_write;
    logic [DATA_WIDTH-1:0] data;

    modport reader(input rd_cmd,
                   output rd_info, 
                   output addr_info,
                   output data_write, data);

    modport engine(input rd_info, 
                   output rd_cmd);

    modport addr_info_reg(input addr_info);
    modport data_fifo(input data_write, data);
    modport tb(output rd_cmd, 
               input rd_info, 
               input addr_info, 
               input data_write, data);
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
    addr_info_t addr_info;  

    //Actual data
    logic data_read;
    logic [DATA_WIDTH-1:0] data;

    modport writer(input wr_cmd,
                   output wr_info, 
                   output addr_info, 
                   output data_read, input data);

    modport engine(input wr_info,
                   output wr_cmd);

    modport addr_info_reg(input addr_info);
    modport data_fifo(input data_read, output data);
    modport tb(output wr_cmd, 
               input wr_info, 
               input addr_info, 
               input data_read, output data);
endinterface