`timescale 1ns/1ps

import bridge_utils::*;

module slave_axi_writer_tb();

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz
    parameter FIFO_DEPTH_LG2 = 4; // 16 entries

    logic clk;
    logic rst_n;

    logic [ID_WIDTH-1:0]      arid;
    logic [ADDR_WIDTH-1:0]    araddr;
    logic [3:0]               arlen;
    logic [2:0]               arsize;
    logic [1:0]               arburst;
    logic                     arvalid;
    logic                     arready;

    logic [ID_WIDTH-1:0]      rid;
    logic [DATA_WIDTH-1:0]    rdata;
    logic [1:0]               rresp;
    logic                     rlast;
    logic                     rvalid;
    logic                     rready;

    // Internal interface
    axi_writer_inf #(ADDR_WIDTH, DATA_WIDTH) axi_wr_inf();

    // FIFO signals
    logic fifo_full, fifo_empty;
    logic fifo_wren;
    logic [DATA_WIDTH-1:0] fifo_wdata;
    logic fifo_rden;
    logic [DATA_WIDTH-1:0] fifo_rdata;

    // DUT instantiation
    slave_axi_writer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arvalid(arvalid),
        .arready(arready),
        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),
        .axi_wr_inf(axi_wr_inf.slave_axi_wr)
    );

    // FIFO instantiation
    BRIDGE_FIFO #(
        .DEPTH_LG2(FIFO_DEPTH_LG2),
        .DATA_WIDTH(DATA_WIDTH)
    ) data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .full_o(fifo_full),
        .wren_i(fifo_wren),
        .wdata_i(fifo_wdata),
        .empty_o(fifo_empty),
        .rden_i(fifo_rden),
        .rdata_o(fifo_rdata)
    );

    // Connect FIFO to writer interface
    assign fifo_rden = axi_wr_inf.fifo_read;
    assign axi_wr_inf.data = fifo_rdata;

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 1'b0;
        #(CLK_PERIOD*2) rst_n = 1'b1;
    end

    // Test variables
    logic [DATA_WIDTH-1:0] test_data[0:15];
    logic [ADDR_WIDTH-1:0] test_addr;
    int burst_length;
    int data_index;
    int error_count = 0;

    // Task to initialize test data
    task init_test_data;
        for (int i = 0; i < 16; i++) begin
            test_data[i] = $urandom();
        end
        test_addr = 32'h2000_0000;
    endtask

    // Task to send AXI read address
    task send_read_address(input [ADDR_WIDTH-1:0] addr, input [3:0] len, input [2:0] size, input [1:0] burst);
        @(posedge clk);
        arvalid = 1'b1;
        arid = 4'h2;
        araddr = addr;
        arlen = len;
        arsize = size;
        arburst = burst;
        
        wait (arready);
        @(posedge clk);
        arvalid = 1'b0;
    endtask

    // Task to receive AXI read data
    task receive_read_data(input [3:0] len);
        for (int i = 0; i <= len; i++) begin
            rready = 1'b1;
            wait (rvalid);
            @(posedge clk);
            if (rvalid) begin
                if (rdata !== test_data[i]) begin
                    $display("ERROR: Data mismatch at index %0d. Expected %h, got %h", 
                             i, test_data[i], rdata);
                    error_count++;
                end else begin
                    $display("Data %0d received correctly: %h", i, rdata);
                end
                
                if (i == len) begin
                    if (!rlast) begin
                        $display("ERROR: RLAST not asserted on final beat");
                        error_count++;
                    end
                end else if (rlast) begin
                    $display("ERROR: RLAST asserted too early");
                    error_count++;
                end
            end
        end
        
        rready = 1'b0;
    endtask

    // Task to fill FIFO with test data
    task fill_fifo(input [3:0] len);
        @(posedge clk);
        for (int i = 0; i <= len; i++) begin
            fifo_wren = 1'b1;
            fifo_wdata = test_data[i];
            @(posedge clk);
        end
        fifo_wren = 1'b0;
        fifo_wdata = '0;
    endtask

    //Main sequence to run the tests
    initial begin
        // Initialize signals
        arid = 0;
        araddr = 0;
        arlen = 0;
        arsize = 0;
        arburst = 0;
        arvalid = 0;
        
        rready = 0;
        fifo_wren = 0;
        fifo_wdata = 0;
        
        axi_wr_inf.wr_cmd = W_DISABLE;
        
        // Wait for reset to complete
        wait(rst_n);
        #(CLK_PERIOD*2);
        
        // Initialize test data
        init_test_data();
        
        // Test 1: Single data read transfer
        $display("\nStarting Test 1: Single data read transfer");
        fill_fifo(0); // Fill FIFO with 1 word
        axi_wr_inf.wr_cmd = W_GET_ADDR;
        
        burst_length = 0; // Single transfer
        fork
            send_read_address(test_addr, burst_length, 3'b010, 2'b01); // 4-byte beats, INCR burst
        join_none
        
        #(5*CLK_PERIOD);
        axi_wr_inf.wr_cmd = W_GET_DATA;
        receive_read_data(burst_length);
        
        // Check if we're back to IDLE
        #(CLK_PERIOD*2);
        if (axi_wr_inf.wr_info !== W_IDLE) begin
            $display("ERROR: Module not in IDLE state after transfer");
            error_count++;
        end
        
        // Test 2: Burst read transfer (4 words)
        $display("\nStarting Test 2: Burst read transfer (4 words)");
        fill_fifo(3); // Fill FIFO with 4 words
        axi_wr_inf.wr_cmd = W_GET_ADDR;
        
        burst_length = 3; // 4 transfers
        fork
            send_read_address(test_addr, burst_length, 3'b010, 2'b01); // 4-byte beats, INCR burst
        join_none
        
        #(5*CLK_PERIOD);
        axi_wr_inf.wr_cmd = W_GET_DATA;
        receive_read_data(burst_length);
        
        // Test 3: Verify back-to-back transfers
        $display("\nStarting Test 3: Back-to-back transfers");
        
        // First transfer (2 words)
        fill_fifo(1); // Fill FIFO with 2 words
        axi_wr_inf.wr_cmd = W_GET_ADDR;
        burst_length = 1; // 2 transfers
        fork
            send_read_address(test_addr, burst_length, 3'b010, 2'b01);
        join_none
        
        #(5*CLK_PERIOD);
        axi_wr_inf.wr_cmd = W_GET_DATA;
        receive_read_data(burst_length);
        
        // Second transfer immediately after (3 words)
        fill_fifo(2); // Fill FIFO with 3 words
        axi_wr_inf.wr_cmd = W_GET_ADDR;
        burst_length = 2; // 3 transfers
        fork
            send_read_address(test_addr+32'h40, burst_length, 3'b010, 2'b01);
        join_none
        
        #(5*CLK_PERIOD);
        axi_wr_inf.wr_cmd = W_GET_DATA;
        receive_read_data(burst_length);
        
        // Summary
        #(CLK_PERIOD*2);
        if (error_count == 0) begin
            $display("\nTEST PASSED - All read transfers completed successfully");
        end else begin
            $display("\nTEST FAILED - %0d errors detected", error_count);
        end
        
        $finish;
    end

    // Monitor
    initial begin
        $timeformat(-9, 0, " ns", 6);
        $monitor("At time %t: state=%s, fifo_read=%b, fifo_empty=%b, rdata=%h, rvalid=%b, rready=%b, rlast=%b", 
                 $time, dut.state_cur.name(), axi_wr_inf.fifo_read, fifo_empty, 
                 rdata, rvalid, rready, rlast);
    end

endmodule