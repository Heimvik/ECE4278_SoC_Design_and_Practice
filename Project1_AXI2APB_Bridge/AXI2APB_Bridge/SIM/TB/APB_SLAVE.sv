// `include "../TB/APB_TYPEDEF.svh"

module APB_SLAVE 
#(
    parameter ADDR_WIDTH        = 20,
    parameter DATA_WIDTH        = 32,
    parameter PREADY_DELAY      = 3,

    // 추가된 주소 범위 파라미터
    parameter REGION_START      = 32'h0000_0000,
    parameter REGION_SIZE       = 32'h0000_1000
)(
    input  wire                 clk,
    input  wire                 rst_n,  // _n means active low
    // APB interface
    APB                         apb,
    AXI_AW_CH                   aw_ch,
    AXI_W_CH                    w_ch
);

    localparam DATA_DEPTH = 1 << ADDR_WIDTH;

    // Memory array (byte-based)
    logic [7:0] mem [DATA_DEPTH];


    // Byte-level write
    function void write_byte(int addr, input bit [7:0] wdata);
        if ((addr >= REGION_START) && (addr < (REGION_START + REGION_SIZE))) begin
            mem[addr - REGION_START] = wdata;
        end else begin
            $fatal(1, "[SLAVE] Write BYTE address out of range: 0x%0h", addr);
        end
    endfunction


    // Word-level write
    function void write_word(int addr, input bit [31:0] wdata);
        if ((addr + 3 >= (REGION_START + REGION_SIZE)) || (addr < REGION_START)) begin
            $fatal(1, "[SLAVE] Write WORD address out of range: 0x%0h", addr);
            return;
        end

        for (int i = 0; i < 4; i++) begin
           
            write_byte(addr + i, wdata[i*8 +: 8]);
        end
    endfunction

    // Byte-level read
    function bit [7:0] read_byte(int addr);
        if ((addr >= REGION_START) && (addr < (REGION_START + REGION_SIZE))) begin
            return mem[addr - REGION_START];
        end else begin
            $fatal(1, "[SLAVE] Read BYTE address out of range: 0x%0h", addr);
            return 8'h00;
        end
    endfunction

    // Word-level read
    function bit [31:0] read_word(int addr);
        for (int i = 0; i < 4; i++) begin
            read_word[i*8 +: 8] = read_byte(addr + i);
        end
    endfunction

    // FSM states
    localparam S_IDLE           = 2'd0,
               S_DELAY          = 2'd1,
               S_ACCESS         = 2'd2;

    logic [1:0] state, state_n;
    logic [7:0] delay_cnt, delay_cnt_n;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state               <= S_IDLE;
            delay_cnt           <= '0;
        end 
        else begin
            state               <= state_n;
            delay_cnt           <= delay_cnt_n;
        end
    end

    // Combinational logic
    always_comb begin
        state_n                 = state;
        delay_cnt_n             = delay_cnt;

        apb.pready              = 1'b0;
        apb.prdata              = 32'h0000_0000;
        apb.pslverr             = 1'b0;

        case (state)
            S_IDLE: begin
                if (apb.psel && apb.penable) begin
                    if (PREADY_DELAY == 0) begin
                        state_n         = S_ACCESS;
                    end else begin
                        delay_cnt_n     = PREADY_DELAY - 1;
                        state_n         = S_DELAY;
                    end
                end
            end

            S_DELAY: begin
                if (delay_cnt == 0) begin
                    state_n             = S_ACCESS;
                end else begin
                    delay_cnt_n         = delay_cnt - 1;
                end
            end

            S_ACCESS: begin
                apb.pready = 1'b1;
                if (apb.pwrite) begin
                    write_word(apb.paddr, apb.pwdata);
                    state_n             = S_IDLE;
                end 
                else begin
                    apb.prdata          = read_word(apb.paddr);
                    state_n             = S_IDLE;
                end
            end

            default: begin
                state_n             = S_IDLE;
            end
        endcase
    end

    mailbox         axi_wdata_mbx = new(0);
    logic [31:0]    axi_wdata, apb_wdata;
 
    initial begin
        forever begin
            @(posedge clk)
            #1
            if (aw_ch.awready) begin
                axi_wdata_mbx = new(0);
            end
            if (w_ch.wvalid & w_ch.wready) begin
                axi_wdata_mbx.put(w_ch.wdata);
            end
            else if (state == S_ACCESS) begin
                if (axi_wdata_mbx.num > 0) begin
                    if (apb.pwrite) begin
                        apb_wdata = apb.pwdata;
                        axi_wdata_mbx.try_get(axi_wdata);
                        if (axi_wdata != apb_wdata) begin
                            $fatal(1, "Mismatch! AXI MASTER WRITE DATA=0x%08x, APB WRITE DATA=0x%08x", axi_wdata, apb_wdata);
                        end
                    end
                end
            end
        end
    end

endmodule
