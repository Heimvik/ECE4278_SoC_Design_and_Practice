/*
Slave module towards the CPU. This module is custom and should respond
Module to respond to a read/write request from a master that follows the AXI protocol.
During operation it should:
1. Respond to a write request from the CPU (transferring all 3 registers of info)
2. Respond to another write request from the CPU (the transfer of the data to write)
*DMA in the working*
3. Respond to a read request from the CPU (transferring the data it has read, back to the CPU)
*/

