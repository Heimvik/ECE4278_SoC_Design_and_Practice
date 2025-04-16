`timescale 1ns/1ps
`include "../TB/AXI_TYPEDEF.svh"

//SLV 1 
`define SLV1_REGION_START    32'h0001_F000
`define SLV1_REGION_SIZE     32'h0000_1000   // 4KB
// SLV 2 
`define SLV2_REGION_START    32'h0002_F000
`define SLV2_REGION_SIZE     32'h0000_1000   // 4KB

`define RANDOM_SEED     12123344
`define TIMEOUT_DELAY 	99999999

module TOP_TB;

    // inject random seed
    initial begin
        $urandom(`RANDOM_SEED); //NB! HAD TO CHANGE THIS FOR BEING ABLE TO SIMULATE
        //$srandom(`RANDOM_SEED); 
    end

    //----------------------------------------------------------
    // clock and reset generation
    //----------------------------------------------------------
    reg                     clk;
    reg                     rst_n;

    // clock generation
    initial begin
        clk                     = 1'b0;

        forever #10 clk         = !clk;
    end


    // reset generation
    initial begin
        rst_n                   = 1'b0;     // active at time 0

        repeat (3) @(posedge clk);          // after 3 cycles,
        rst_n                   = 1'b1;     // release the reset
    end

	initial begin
		#`TIMEOUT_DELAY $display("Timeout!");
		$finish;
	end

    // enable waveform dump
    initial begin
        $dumpvars(0, dut);
        $dumpfile("dump.vcd");
    end


    //----------------------------------------------------------
    // Connection between DUT and test modules
    //----------------------------------------------------------
    AXI_AW_CH aw_if (.clk(clk));
    AXI_W_CH  w_if  (.clk(clk));
    AXI_B_CH  b_if  (.clk(clk));
    AXI_AR_CH ar_if (.clk(clk));
    AXI_R_CH  r_if  (.clk(clk));

    APB       apb_if_slave_0 (.clk(clk));
    APB       apb_if_slave_1 (.clk(clk));


    // AXI Master
    AXI_MASTER axi_master (
        .clk    (clk),
        .rst_n  (rst_n),
        .aw_ch  (aw_if),
        .w_ch   (w_if),
        .b_ch   (b_if),
        .ar_ch  (ar_if),
        .r_ch   (r_if)
    );

    // APB DUT-to-slaves signal routing
    wire [31:0] paddr_o, pwdata_o;
    wire        pwrite_o, penable_o;
    wire [1:0]  psel_o;
    wire [31:0] prdata_i;
    wire        pready_i, pslverr_i;

    AXI2APB_TOP #(
        .ADDR_WIDTH (`AXI_ADDR_WIDTH),
        .DATA_WIDTH (`AXI_DATA_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),

        // AXI AW channel
        .awid_i         (aw_if.awid),
        .awaddr_i       (aw_if.awaddr),
        .awlen_i        (aw_if.awlen),
        .awsize_i       (aw_if.awsize),
        .awburst_i      (aw_if.awburst),
        .awvalid_i      (aw_if.awvalid),
        .awready_o      (aw_if.awready),

        // AXI W channel
        .wid_i          (w_if.wid),
        .wdata_i        (w_if.wdata),
        .wstrb_i        (w_if.wstrb),
        .wlast_i        (w_if.wlast),
        .wvalid_i       (w_if.wvalid),
        .wready_o       (w_if.wready),


        // AXI B channel
        .bid_o          (b_if.bid),
        .bresp_o        (b_if.bresp),
        .bvalid_o       (b_if.bvalid),
        .bready_i       (b_if.bready),

        // AXI AR channel
        .arid_i         (ar_if.arid),
        .araddr_i       (ar_if.araddr),
        .arlen_i        (ar_if.arlen),
        .arsize_i       (ar_if.arsize),
        .arburst_i      (ar_if.arburst),
        .arvalid_i      (ar_if.arvalid),
        .arready_o      (ar_if.arready),


        // AXI R channel
        .rid_o          (r_if.rid),
        .rdata_o        (r_if.rdata),
        .rresp_o        (r_if.rresp),
        .rlast_o        (r_if.rlast),
        .rvalid_o       (r_if.rvalid),
        .rready_i       (r_if.rready),
        
        // APB interface
        .paddr_o        (paddr_o),
        .pwdata_o       (pwdata_o),
        .pwrite_o       (pwrite_o),
        .penable_o      (penable_o),
        .psel_o         (psel_o),
        .prdata_i       (prdata_i),
        .pready_i       (pready_i),
        .pslverr_i      (pslverr_i)
    );


   // APB Slave 0
    APB_SLAVE #(
        .REGION_START(`SLV1_REGION_START),
        .REGION_SIZE (`SLV1_REGION_SIZE)
    ) slave_0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .apb    (apb_if_slave_0),
        .aw_ch  (aw_if),
        .w_ch   (w_if)
    );
 
    // APB Slave 1
    APB_SLAVE #(
        .REGION_START(`SLV2_REGION_START),
        .REGION_SIZE (`SLV2_REGION_SIZE)
    ) slave_1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .apb    (apb_if_slave_1),
        .aw_ch  (aw_if),
        .w_ch   (w_if)
    );


    assign apb_if_slave_0.paddr   = psel_o[0] ? paddr_o   : '0;
    assign apb_if_slave_1.paddr   = psel_o[1] ? paddr_o   : '0;

    assign apb_if_slave_0.pwdata  = psel_o[0] ? pwdata_o  : '0;
    assign apb_if_slave_1.pwdata  = psel_o[1] ? pwdata_o  : '0;

    assign apb_if_slave_0.pwrite  = psel_o[0] ? pwrite_o  : 1'b0;
    assign apb_if_slave_1.pwrite  = psel_o[1] ? pwrite_o  : 1'b0;

    assign apb_if_slave_0.penable = psel_o[0] ? penable_o : 1'b0;
    assign apb_if_slave_1.penable = psel_o[1] ? penable_o : 1'b0;

    assign apb_if_slave_0.psel    = psel_o[0];
    assign apb_if_slave_1.psel    = psel_o[1];

    // Read/response muxing
    assign prdata_i  = psel_o[0] ? apb_if_slave_0.prdata  :
                    psel_o[1] ? apb_if_slave_1.prdata  : 32'h0;

    assign pready_i  = psel_o[0] ? apb_if_slave_0.pready  :
                    psel_o[1] ? apb_if_slave_1.pready  : 1'b0;

    assign pslverr_i = psel_o[0] ? apb_if_slave_0.pslverr :
                    psel_o[1] ? apb_if_slave_1.pslverr : 1'b0;


    //----------------------------------------------------------
    // Testbench starts
    //----------------------------------------------------------

    task test_init();
        int data;
        // AXI init
        aw_if.init();
        w_if.init();
        b_if.init();
        ar_if.init();
        r_if.init();

        @(posedge rst_n);                   // wait for a release of the reset
        repeat (10) @(posedge clk);         // wait another 10 cycles

        for (int i=0; i<`SLV1_REGION_SIZE; i=i+4) begin
            slave_0.write_word(`SLV1_REGION_START+i, $random);
        end
        for (int i=0; i<`SLV2_REGION_SIZE; i=i+4) begin
            slave_1.write_word(`SLV2_REGION_START+i, $random);
        end
    endtask
    
    // this task must be declared automatic so that each invocation uses
    task automatic test_bridge(
        input int base_addr,
        input int burst_type,
        input int repeat_cnt,
        input string name
    );
        logic [31:0] curr_addr;
        // logic [1:0] burst_type;
        int len;
        int max_burst_bytes;
        logic [31:0] write_data[$];
        logic [31:0] read_data[$];

        for (int i = 0; i < repeat_cnt; i++) begin
            // burst type: FIXED(0) or INCR(1)
            // burst 길이: 1~16 beats (awlen = len - 1)            
            len = i+1;
            max_burst_bytes = (len + 1) * 4;

            // 주소 생성 (32-aligned)
            curr_addr = base_addr + ($urandom_range(0, 4096 - max_burst_bytes) & ~3);

            // 랜덤 데이터 생성
            write_data.delete();
            for (int j = 0; j < len; j++) begin
                write_data.push_back($random);
                $display("[AXI_MASTER] Write_data[%0d] : %h", j, write_data[j]);
            end

            // Write
            axi_master.write_burst(
                .addr(curr_addr),
                .data(write_data),
                .burst_type(burst_type),
                .burst_len(len)
            );

            // Read
            read_data.delete();

            axi_master.read_burst(
                .addr(curr_addr),
                .burst_len(len),
                .burst_type(burst_type),
                .data_out(read_data)
            );

            // Compare 
            for (int j = 0; j < len; j++) begin
                int check_idx = (burst_type == 0) ? len-1 : j;
                if (read_data[j] !== write_data[check_idx]) begin
                    $display("[%s] FAIL @%0h idx=%0d → W:%08x, R:%08x",
                            name, curr_addr + j*4, j, write_data[check_idx], read_data[j]);
                    $finish;
                end
            end
                     
            $display("[%s] PASS: burst[%0d] @%08x len=%0d type=%s\n\n", 
                    name, i, curr_addr, len, (burst_type == 0 ? "FIXED" : "INCR"));
        end
    endtask
    
    always @(psel_o) begin
        if (psel_o[0] && psel_o[1]) begin
            $display("[ERROR] Both psel_o[0] and psel_o[1] are asserted at the same time at time %0t", $time);
            $fatal(1, "Only one slave should be selected at a time.");
        end
    end

    initial begin
        time start_time, end_time;

        start_time = $time;  

        test_init();

        test_bridge(`SLV1_REGION_START, 0, 16, "SLV1");
        test_bridge(`SLV2_REGION_START, 0, 16, "SLV2");

        test_bridge(`SLV1_REGION_START, 1, 16, "SLV1");
        test_bridge(`SLV2_REGION_START, 1, 16, "SLV2");

        end_time = $time;    

        $display("\n==============================");
        $display(" Test completed.");
        $display(" Simulation time: %0t ns", end_time - start_time);
        $display("==============================\n");

        $finish;
    end


endmodule
