`include "../TB/AXI_TYPEDEF.svh"

module AXI_MASTER #(
    parameter ADDR_WIDTH = `AXI_ADDR_WIDTH,
    parameter DATA_WIDTH = `AXI_DATA_WIDTH,
    parameter ID_WIDTH   = `AXI_ID_WIDTH
)(
    input  logic         clk,
    input  logic         rst_n,

    AXI_AW_CH           aw_ch,
    AXI_W_CH            w_ch,
    AXI_B_CH            b_ch,
    AXI_AR_CH           ar_ch,
    AXI_R_CH            r_ch
);

    // Write burst task
    task automatic write_burst(input int addr, input logic [31:0] data[], input logic [1:0] burst_type, input int burst_len);
        // Write address channel

        aw_ch.awvalid = 1;
        aw_ch.awid    = '0;
        aw_ch.awaddr  = addr;
        aw_ch.awlen   = burst_len - 1;
        aw_ch.awsize  = $clog2(DATA_WIDTH/8);
        aw_ch.awburst = burst_type;

        wait (aw_ch.awready);
        @(posedge clk);
        aw_ch.awvalid = 0;

        // Write data channel
        for (int i = 0; i < burst_len; i++) begin
            w_ch.wvalid = 1;
            w_ch.wid    = '0;
            w_ch.wdata  = data[i];
            w_ch.wstrb  = '1;
            w_ch.wlast  = (i == burst_len - 1);
            @(posedge clk);
            while (w_ch.wready==1'b0) begin
                @(posedge clk);
            end
             w_ch.wvalid = 0;  
        end

        w_ch.wvalid = 0;
        // Write response channel
        b_ch.bready = 1;
        wait (b_ch.bvalid);
        $display("[AXI_MASTER] WRITE_RESP: burst_len : %0d", burst_len);
        @(posedge clk);
        b_ch.bready = 0;
    endtask

    // Read burst task
    task automatic read_burst(input int addr, input int burst_len, input logic [1:0] burst_type, output logic [31:0] data_out[]);
        int i;
        data_out = new[burst_len];
        ar_ch.arvalid   = 1;
        ar_ch.arid      = '0;
        ar_ch.araddr    = addr;
        ar_ch.arlen     = burst_len - 1;
        ar_ch.arsize    = $clog2(DATA_WIDTH/8);
        ar_ch.arburst   = burst_type;

        @(posedge clk);
        while (ar_ch.arready==1'b0) begin
            @(posedge clk);
        end
        ar_ch.arvalid  = 0;

        i = 0;
        r_ch.rready     = 1;

        while (i < burst_len) begin
            @(posedge clk);
            if (r_ch.rvalid) begin
                data_out[i] = r_ch.rdata;
                $display("[AXI_MASTER] READ_RESP[%0d] = 0x%08x", i, r_ch.rdata);
                i++;
            end
        end
        r_ch.rready     = 0;
    endtask

endmodule
