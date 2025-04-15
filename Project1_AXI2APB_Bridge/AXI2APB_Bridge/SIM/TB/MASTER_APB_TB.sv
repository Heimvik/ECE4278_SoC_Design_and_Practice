`timescale 1ns/1ps

import bridge_utils::*;

module master_apb_tb();

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz
    parameter FIFO_DEPTH_LG2 = 4; // 16 entries

    // Signals
    logic clk;
    logic rst_n;

    // APB interface
    logic [ADDR_WIDTH-1:0]    paddr;
    logic [DATA_WIDTH-1:0]    pwdata;
    logic                     pwrite;
    logic                     penable;
    logic [1:0]               psel;
    logic [DATA_WIDTH-1:0]    prdata;
    logic                     pready;
    logic                     pslverr;

    // Internal interface
    apb_inf #(ADDR_WIDTH, DATA_WIDTH) apb_rw_inf();

    // FIFO signals
    logic wr_fifo_full, wr_fifo_empty;
    logic rd_fifo_full, rd_fifo_empty;
    logic wr_fifo_wren;
    logic rd_fifo_rden;
    logic [DATA_WIDTH-1:0] wr_fifo_wdata;
    logic [DATA_WIDTH-1:0] wr_fifo_rdata;
    logic [DATA_WIDTH-1:0] rd_fifo_wdata;
    logic [DATA_WIDTH-1:0] rd_fifo_rdata;

    // Test variables
    logic [DATA_WIDTH-1:0] test_data[0:15];
    logic [ADDR_WIDTH-1:0] test_addr;
    int burst_length;
    int error_count = 0;

    logic [1:0] testing_slave;


    // DUT instantiation
    slave_axi_writer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .apb_rw_inf(apb_rw_inf.master_apb)
    );

    // Write FIFO (stores data to be written to APB slaves)
    BRIDGE_FIFO #(
        .DEPTH_LG2(FIFO_DEPTH_LG2),
        .DATA_WIDTH(DATA_WIDTH)
    ) wr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .full_o(wr_fifo_full),
        .wren_i(wr_fifo_wren), // Not used in this testbench
        .wdata_i(wr_fifo_wdata),  // Not used in this testbench
        .empty_o(wr_fifo_empty),
        .rden_i(apb_rw_inf.fifo_read),
        .rdata_o(wr_fifo_rdata)
    );

    // Read FIFO (stores data read from APB slaves)
    BRIDGE_FIFO #(
        .DEPTH_LG2(FIFO_DEPTH_LG2),
        .DATA_WIDTH(DATA_WIDTH)
    ) rd_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .full_o(rd_fifo_full),
        .wren_i(apb_rw_inf.fifo_write),
        .wdata_i(apb_rw_inf.data_out),
        .empty_o(rd_fifo_empty),
        .rden_i(rd_fifo_rden), // Not used in this testbench
        .rdata_o(rd_fifo_rdata)     // Not used in this testbench
    );

    // Connect FIFOs to interface
    assign apb_rw_inf.data_in = wr_fifo_rdata;
    assign rd_fifo_wdata = apb_rw_inf.data_out;

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

    // Task to initialize test data
    task init_test_data;
        for (int i = 0; i < 16; i++) begin
            test_data[i] = $urandom();
        end
        test_addr = 32'h0001_F000; // Slave 0
    endtask

    // Task to simulate APB slave response
    task apb_slave_response(input [3:0] len);
        automatic int delay;
        for (int i = 0; i <= len; i++) begin
            // ----------- SETUP PHASE -----------
            @(posedge clk);

            // ----------- ACCESS PHASE -----------
            wait (penable);
            verify_psel(); // Verify psel based on address

            delay = $urandom_range(0, 3);
            repeat(delay) @(posedge clk);

            pready = 1'b1;
            prdata = test_data[i]; // Provide data during read

            @(posedge clk);
            pready = 1'b0; // Lower pready after access phase
        end
    endtask

    // Task to fill write FIFO with test data
    task fill_write_fifo(input [3:0] len);
        // Wait for reset to complete if needed
        @(posedge clk iff rst_n);

        // Fill FIFO through proper write interface
        for (int i = 0; i <= len; i++) begin
            wr_fifo_wren = 1'b1;
            wr_fifo_wdata = test_data[i];
            @(posedge clk);
        end

        // Deassert write enable
        wr_fifo_wren = 1'b0;
        wr_fifo_wdata = '0;
    endtask

    // Task to check read FIFO contents
    task check_read_fifo(input [3:0] len);
        // Wait for reset to complete if needed
        @(posedge clk iff rst_n);
        
        for (int i = 0; i <= len; i++) begin
            rd_fifo_rden = 1'b1;
            @(posedge clk);

            // Check data
            if (rd_fifo_rdata !== test_data[i]) begin
                $display("ERROR: Data mismatch at index %0d. Expected %h, got %h", 
                        i, test_data[i], rd_fifo_rdata);
                error_count++;
            end else begin
                $display("INFO: Data match at index %0d. Value: %h", i, rd_fifo_rdata);
            end
        end
        rd_fifo_rden = 1'b0;
    endtask

    // Function to generate random 4-byte aligned address within bounds
    function logic [ADDR_WIDTH-1:0] gen_random_addr(input logic[1:0] slave_sel);
        logic [ADDR_WIDTH-1:0] base_addr, max_addr;
        begin
            if (slave_sel == 0) begin
                base_addr = 32'h0001_F000;
                max_addr = 32'h0001_FFFF;
            end else begin
                base_addr = 32'h0002_F000;
                max_addr = 32'h0002_FFFF;
            end
            
            // Generate random offset (multiple of 4) within range
            gen_random_addr = base_addr + ($urandom_range(0, (max_addr-base_addr) >> 2) << 2);
        end
    endfunction

    task automatic verify_psel();
        logic [1:0] expected_psel= 2'b00;
        
        if ((paddr >= 32'h0001_F000) && (paddr <= 32'h0001_FFFF)) begin
            expected_psel = 2'b01;  // Slave 0
        end else if ((paddr >= 32'h0002_F000) && (paddr <= 32'h0002_FFFF)) begin
            expected_psel = 2'b10;  // Slave 1
        end
        
        if (psel !== expected_psel) begin
            $display("ERROR: psel mismatch! Addr=0x%h, Expected=2'b%b, Actual=2'b%b",
            paddr, expected_psel, psel);
            error_count++;
        end
    endtask

    // Main test sequence
    initial begin
        // Initialize signals
        pready = 1'b0;
        prdata = '0;
        pslverr = 1'b0;
        
        apb_rw_inf.apb_cmd = APB_DISABLE;
        apb_rw_inf.addr_info_rd = '{addr: 0, len: 0, size: 3'b100, burst: 2'b00};
        apb_rw_inf.addr_info_wr = '{addr: 0, len: 0, size: 3'b100, burst: 2'b00};
        
        // Wait for reset to complete
        wait(rst_n);
        #(CLK_PERIOD*2);
        
        // Initialize test data
        init_test_data();
        
        // Test 1: Single write transfer
        $display("\nStarting Test 1: Single write transfer");
        fill_write_fifo(0); // Fill FIFO with 1 word
        
        // Configure write transfer
        testing_slave = 1; // Select slave 1
        test_addr = gen_random_addr(testing_slave); // Generate random address for slave 1
        apb_rw_inf.addr_info_wr = '{addr: test_addr, len: 0, size: 3'b010, burst: 2'b00};
        apb_rw_inf.apb_cmd = APB_WRITE;
        
        apb_slave_response(0);
        
        wait(apb_rw_inf.apb_info == APB_SWITCH);
        apb_rw_inf.apb_cmd = APB_DISABLE;
        #(2*CLK_PERIOD);
        
        // Test 2: Burst read transfer (4 words)
        $display("\nStarting Test 2: Burst read transfer (4 words)");
        
        testing_slave = 1; // Select slave 1
        test_addr = gen_random_addr(testing_slave); // Generate random address for slave 1
        apb_rw_inf.addr_info_rd = '{addr: test_addr, len: 3, size: 3'b100, burst: 2'b00};
        apb_rw_inf.apb_cmd = APB_READ;
        
        apb_slave_response(3);
        
        check_read_fifo(3);

        wait(apb_rw_inf.apb_info == APB_SWITCH);
        apb_rw_inf.apb_cmd = APB_DISABLE;
        #(2*CLK_PERIOD);
        
        // Test 3: Verify back-to-back transfers
        $display("\nStarting Test 3: Back-to-back transfers");
        
        // First transfer (write 2 words)
        testing_slave = 1; // Select slave 1
        test_addr = gen_random_addr(testing_slave); // Generate random address for slave 1
        fill_write_fifo(1);
        apb_rw_inf.addr_info_wr = '{addr: test_addr, len: 1, size: 3'b100, burst: 2'b00};
        apb_rw_inf.apb_cmd = APB_WRITE;
        
        apb_slave_response(1);
        
        wait(apb_rw_inf.apb_info == APB_SWITCH);
        apb_rw_inf.apb_cmd = APB_DISABLE;
        #(2*CLK_PERIOD);
        
        // Second transfer (read 16 words)
        testing_slave = 1; // Select slave 1
        test_addr = gen_random_addr(testing_slave); // Generate random address for slave 1
        apb_rw_inf.addr_info_rd = '{addr: test_addr, len: 15, size: 3'b100, burst: 2'b00};
        apb_rw_inf.apb_cmd = APB_READ;
        
        apb_slave_response(15);
        
        check_read_fifo(15);

        wait(apb_rw_inf.apb_info == APB_SWITCH);
        apb_rw_inf.apb_cmd = APB_DISABLE;
        #(2*CLK_PERIOD);
        
        // Summary
        #(CLK_PERIOD*2);
        if (error_count == 0) begin
            $display("\nTEST PASSED - All APB transfers completed successfully");
        end else begin
            $display("\nTEST FAILED - %0d errors detected", error_count);
        end
        
        $finish;
    end

    // Monitor
    initial begin
        $timeformat(-9, 0, " ns", 6);
        forever begin
            @(posedge clk);
            $display("--------------------------------------------------");
            $display("At time %t:", $time);
            $display("DUT State: %s", dut.state_cur.name());
            $display("APB: paddr=%h, pwrite=%b, penable=%b, psel=%b", 
                    paddr, pwrite, penable, psel);
            $display("FIFOs: wr_empty=%b, rd_full=%b", 
                    wr_fifo_empty, rd_fifo_full);
            $display("Control: cmd=%s, info=%s", 
                    apb_rw_inf.apb_cmd.name(), apb_rw_inf.apb_info.name());
        end
    end

endmodule