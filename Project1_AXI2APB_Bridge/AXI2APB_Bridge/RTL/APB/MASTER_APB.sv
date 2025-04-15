/*
This module should (as the other ones) respond to its commands from the engine.
It should also when invoking switch, and the engine responds with disable, put it in idle
*/
import bridge_utils::*;

module slave_axi_writer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,

    // APB interface
    output wire [ADDR_WIDTH-1:0]    paddr,
    output wire [DATA_WIDTH-1:0]    pwdata,
    output wire                     pwrite,
    output wire                     penable,
    output wire [1:0]               psel,
    input  wire [DATA_WIDTH-1:0]    prdata,
    input  wire                     pready,
    input  wire                     pslverr,

    apb_inf.master i_inf

);
    typedef enum {IDLE,AR,WAIT_W,W} w_state;

endmodule

