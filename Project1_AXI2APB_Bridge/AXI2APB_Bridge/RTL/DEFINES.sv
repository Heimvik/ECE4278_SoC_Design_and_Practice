package bridge_utils;
    parameter int unsigned ID_WIDTH = 1;
    parameter int unsigned ADDR_WIDTH = 32;
    parameter int unsigned DATA_WIDTH = 32;
    parameter int unsigned LG2_NUM_FIFOS = 1; //We start with one FIFO initially

    
    //For axi reader
    typedef enum {R_DISABLE, R_GET_ADDR_DATA, R_GET_RESP} rd_cmd_t;
    typedef enum {R_IDLE, R_BUSY, R_SWITCH} rd_info_t;
    
    //For axi writer
    typedef enum {W_DISABLE, W_GET_ADDR, W_GET_DATA} wr_cmd_t;
    typedef enum {W_IDLE, W_BUSY, W_SWITCH} wr_info_t;
    
    //For apb
    typedef enum {APB_DISABLE, APB_READ, APB_WRITE} apb_cmd_t; //Commands from the engine
    typedef enum {APB_IDLE, APB_BUSY, APB_SWITCH} apb_info_t; //Status of the bridge buffer
    typedef enum {READ = 0, WRITE = 1} access_type_t;

    //For internal communication
    typedef struct packed{
        logic [ADDR_WIDTH-1:0] addr;        //Address the bridgebuffer is addressing
        logic [3:0] len;                    //How many words the transfer contains
        logic [2:0] size;                   //How many byte each word contains
        logic [1:0] burst;                  //Burst type (FIXED, INCR)
    } addr_info_t;

    typedef struct packed {
        logic [3:0] strb;                  //Byte enable for the data
        //logic [LGS2_NUM_FIFOS:0] fifo_ptr;  //Pointer to the FIFO that holds the data
        logic [1:0] resp;                   //A potential response on an read
    } data_info_t;

    typedef struct packed{
        logic [1:0] resp;                   //A potential response on an write
    } resp_info_t;

endpackage
