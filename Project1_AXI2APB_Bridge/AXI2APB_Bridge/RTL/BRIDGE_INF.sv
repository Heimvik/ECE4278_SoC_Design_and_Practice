
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
    logic fifo_write;
    logic [DATA_WIDTH-1:0] data;

    modport slave_axi_reader(input rd_cmd,
                   output rd_info, 
                   output addr_info,
                   output fifo_write, data);

    modport bridge_engine(input rd_info, 
                   output rd_cmd);

    modport apb_rd_adr(input addr_info);
    modport wr_fifo(input fifo_write, data);
    modport tb(output rd_cmd, 
               input rd_info, 
               input addr_info, 
               input fifo_write, data);
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
    logic fifo_read;
    logic [DATA_WIDTH-1:0] data;

    modport slave_axi_writer(
                    input wr_cmd,
                    output wr_info, 
                    output addr_info, 
                    output fifo_read, input data);

    modport bridge_engine(input wr_info,
                   output wr_cmd);

    modport master_apb(input addr_info);
    modport rd_fifo(input fifo_read, output data);
    modport tb(
                output wr_cmd, 
                input wr_info, 
                input addr_info, 
                input fifo_read, output data);
endinterface

interface apb_inf#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    import bridge_utils::*;

    //Control between the axi_reader and the engine
    apb_cmd_t apb_cmd;
    apb_info_t apb_info;

    //Metadata and transfer information
    addr_info_t addr_info_rd;
    addr_info_t addr_info_wr; 

    //Actual data
    logic fifo_read;
    logic [DATA_WIDTH-1:0] data_in;
    logic fifo_write;
    logic [DATA_WIDTH-1:0] data_out;

    modport master_apb(
                    input apb_cmd,
                    output apb_info, 
                    input addr_info_rd, //From axi writer (a read operation writes the AXI)
                    input addr_info_wr, //From axi reader (a read operation reads the AXI)
                    output fifo_read, input data_in,
                    output fifo_write, output data_out);

    modport bridge_engine(
                    input apb_info,
                    output apb_cmd);

    modport rd_fifo(input fifo_write, input data_out); //Under a read operation from the AXI, the APB must write to the read FIFO 
    modport wr_fifo(input fifo_read, output data_in); //Under a write operation from the AXI, the APB must read from the write FIFO
    modport tb(output apb_cmd, 
               input apb_info, 
               output addr_info_rd, 
               output addr_info_wr, 
               input fifo_read, output data_in,
               input fifo_write, input data_out);

endinterface