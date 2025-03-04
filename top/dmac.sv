
package dmac_utils;
    parameter int data_buffer_size = 1024; //Words
    parameter int num_control_regs = 3;
    parameter int control_reg_width = 32;
    parameter logic [31:0] dmac_addr = 32'h00000001;

    typedef struct {
        logic [control_reg_width-1:0] adress;
        logic [control_reg_width-1:0] byte_count_reg;
        logic [control_reg_width-1:0] control_reg;
    } awc_regs;

    typedef struct {
        logic [control_reg_width-1:0] data_buffer[data_buffer_size-1:0];
        awc_regs control_regs[num_control_regs-1:0];
    } dmac_regs;
endpackage

//Internal interface for the DMAC module
interface dmac_inf();
    //AXI slave writer needs write access to the control registers and the data buffer (save from CPU)
    //AXI slave reader needs read access to the data buffer (readback to CPU)
    //AXI master writer needs read access to the data buffer (write to peripheral)
    //AXI master reader needs read access to the data buffer (read from peripheral)
    import dmac_utils::*;
    dmac_regs control_regs;

endinterface
