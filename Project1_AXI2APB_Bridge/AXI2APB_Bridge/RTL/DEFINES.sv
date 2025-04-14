package bridge_utils;
    parameter int unsigned ID_WIDTH = 1;
    parameter int unsigned ADDR_WIDTH = 32;
    parameter int unsigned DATA_WIDTH = 32;
    parameter int unsigned LG2_NUM_FIFOS = 1; //We start with one FIFO initially

    typedef enum {READ, WRITE} bb_type_t;
    
    //For reader
    typedef enum {R_DISABLE, R_GET_ADDR_DATA, R_GET_RESP} rd_cmd_t;
    typedef enum {R_IDLE, R_BUSY, R_SWITCH} rd_info_t;

    //For writer
    typedef enum {W_DISABLE, W_GET_ADDR, W_GET_DATA} wr_cmd_t;
    typedef enum {W_IDLE, W_BUSY, W_SWITCH} wr_info_t;

    typedef struct packed{
        logic [ID_WIDTH-1:0] id;            //ID of the transaction
        logic [ADDR_WIDTH-1:0] addr;        //Address the bridgebuffer is addressing
        logic [7:0] len;                    //How many words the transfer contains
        logic [1:0] burst;                  //Burst type (FIXED, INCR)
        logic [2:0] size;                   //How many byte each word contains
    } addr_info_t;

    typedef struct packed {
        logic [ID_WIDTH-1:0] id;            //ID of the transaction
        //logic [LGS2_NUM_FIFOS:0] fifo_ptr;  //Pointer to the FIFO that holds the data
        logic [1:0] resp;                   //A potential response on an read
    } data_info_t;

    typedef struct packed{
        logic [ID_WIDTH-1:0] id;            //ID of the transaction
        logic [1:0] resp;                   //A potential response on an write
    } resp_info_t;

    typedef struct packed bridgebuffer {
        bb_type_t type;
        logic [ID_WIDTH-1:0] id;
        addr_info_t addr_info;
        data_info_t data_info;
        resp_info_t resp_info;
    } bridgebuffer_t;

endpackage
