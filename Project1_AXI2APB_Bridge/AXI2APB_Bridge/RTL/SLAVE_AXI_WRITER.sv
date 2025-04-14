/*
Module SALVE_AXI_WRITE
This module implements the AXI slave read channels, which it writes to and has an axi interface to the outside.
*/
module slave_axi_writer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
)(
    input logic clk,
    input logic rst_n,

    // AXI interface
    // AXI Read Address Channel
    input  logic                     arid,
    input  logic [ADDR_WIDTH-1:0]    araddr,
    input  logic [3:0]               arlen,
    input  logic [2:0]               arsize,
    input  logic [1:0]               arburst,
    input  logic                     arvalid,
    output logic                     arready,

    // AXI Read Data Channel
    output logic                     rid,
    output logic [DATA_WIDTH-1:0]    rdata,
    output logic [1:0]               rresp,
    output logic                     rlast,
    output logic                     rvalid,
    input  logic                     rready,

    // Write Response Channel
    input logic [3:0] bid,