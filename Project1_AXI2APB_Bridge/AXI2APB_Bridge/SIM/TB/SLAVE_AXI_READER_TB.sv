`timescale 1ns/1ps

import bridge_utils::*;

module slave_axi_reader_tb();

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz
    parameter FIFO_DEPTH_LG2 = 4; // 16 entries

    // Signals
    logic clk;
    logic rst_n;

    // AXI signals
    logic [ID_WIDTH-1:0] awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [3:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;
    logic awvalid;
    logic awready;

    logic [3:0] wid;
    logic [DATA_WIDTH-1:0] wdata;
    logic [3:0] wstrb;
    logic wlast;
    logic wvalid;
    logic wready;

    logic [3:0] bid;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;

    // Internal interface
    axi_reader_inf #(ADDR_WIDTH, DATA_WIDTH) axi_rd_inf();

    // FIFO signals
    logic fifo_full, fifo_empty;
    logic fifo_wren;
    logic [DATA_WIDTH-1:0] fifo_wdata;
    logic fifo_rden;
    logic [DATA_WIDTH-1:0] fifo_rdata;

    // DUT instantiation
    slave_axi_reader #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awvalid(awvalid),
        .awready(awready),
        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),
        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),
        .axi_rd_inf(axi_rd_inf.slave_axi_rd)
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

    // Connect FIFO to reader interface
    assign fifo_wren = axi_rd_inf.fifo_write;
    assign fifo_wdata = axi_rd_inf.data;
    assign fifo_rden = 1'b0; // Not used in reader testbench

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
        test_addr = 32'h1000_0000;
    endtask

    // Task to send AXI write address
    task send_write_address(input [ADDR_WIDTH-1:0] addr, input [3:0] len, input [2:0] size, input [1:0] burst);
        @(posedge clk);
        awvalid = 1'b1;
        awid = 4'h1;
        awaddr = addr;
        awlen = len;
        awsize = size;
        awburst = burst;
        
        wait (awready);
        @(posedge clk);
        awvalid = 1'b0;
    endtask

    // Task to send AXI write data
    task send_write_data(input [3:0] len);
        for (int i = 0; i <= len; i++) begin
            @(posedge clk);
            wvalid = 1'b1;
            wid = 4'h1;
            wdata = test_data[i];
            wstrb = 4'b1111; // All bytes enabled
            wlast = (i == len);
            
            wait (wready);
            @(negedge clk);
            // Check FIFO write happened correctly
            if (axi_rd_inf.fifo_write) begin
                if (fifo_wdata !== test_data[i]) begin
                    $display("ERROR: Data written to FIFO mismatch at index %0d. Expected %h, got %h", 
                             i, test_data[i], fifo_wdata);
                    error_count++;
                end
                if (fifo_full) begin
                    $display("ERROR: FIFO overflow during write");
                    error_count++;
                end
            end
        end
        
        @(posedge clk);
        wvalid = 1'b0;
        wlast = 1'b0;
        @(posedge clk);
    endtask

    // Task to receive AXI write response
    task receive_write_response;
        @(posedge clk);
        bready = 1'b1;
        
        wait (bvalid);
        @(posedge clk);
        if (bresp !== 2'b00) begin
            $display("ERROR: Unexpected write response %b", bresp);
            error_count++;
        end
        
        bready = 1'b0;
    endtask

    // Main test sequence
    initial begin
        // Initialize signals
        awid = 0;
        awaddr = 0;
        awlen = 0;
        awsize = 0;
        awburst = 0;
        awvalid = 0;
        
        wid = 0;
        wdata = 0;
        wstrb = 0;
        wlast = 0;
        wvalid = 0;
        
        bready = 0;
        
        axi_rd_inf.rd_cmd = R_DISABLE;
        
        // Wait for reset to complete
        wait(rst_n);
        #(CLK_PERIOD*2);
        
        // Initialize test data
        init_test_data();
        
        // Test 1: Single data transfer
        $display("\nStarting Test 1: Single data transfer");
        axi_rd_inf.rd_cmd = R_GET_ADDR_DATA;
        
        burst_length = 0; // Single transfer
        send_write_address(test_addr, burst_length, 3'b010, 2'b01); // 4-byte beats, INCR burst
        send_write_data(burst_length);
        #(5*CLK_PERIOD);
        axi_rd_inf.rd_cmd = R_GET_RESP;
        receive_write_response();
        
        // Check if we're back to IDLE
        #(CLK_PERIOD*2);
        if (axi_rd_inf.rd_info !== R_IDLE) begin
            $display("ERROR: Module not in IDLE state after transfer");
            error_count++;
        end
        
        // Test 2: Burst transfer (4 words)
        $display("\nStarting Test 2: Burst transfer (4 words)");
        axi_rd_inf.rd_cmd = R_GET_ADDR_DATA;
        
        burst_length = 3; // 4 transfers
        send_write_address(test_addr, burst_length, 3'b010, 2'b01); // 4-byte beats, INCR burst
        send_write_data(burst_length);
        #(5*CLK_PERIOD);
        axi_rd_inf.rd_cmd = R_GET_RESP;
        receive_write_response();
        
        // Test 3: Verify response handling
        $display("\nStarting Test 3: Response handling");
        axi_rd_inf.rd_cmd = R_GET_ADDR_DATA;
        
        burst_length = 1; // 2 transfers
        send_write_address(test_addr, burst_length, 3'b010, 2'b01);
        send_write_data(burst_length);
        #(CLK_PERIOD*5);
        axi_rd_inf.rd_cmd = R_GET_RESP;
        receive_write_response();
        
        // Summary
        #(CLK_PERIOD*2);
        if (error_count == 0) begin
            $display("\nTEST PASSED - All transfers completed successfully");
        end else begin
            $display("\nTEST FAILED - %0d errors detected", error_count);
        end
        
        $finish;
    end

    // Monitor
    initial begin
        $timeformat(-9, 0, " ns", 6);
        $monitor("At time %t: state=%s, fifo_write=%b, fifo_wdata=%h, fifo_full=%b", 
                 $time, dut.state_cur.name(), axi_rd_inf.fifo_write, fifo_wdata, fifo_full);
    end

endmodule