module FIFO
#(
    parameter DATA_WIDTH    = 32,
    parameter DATA_DEPTH_LG2= 4,
    parameter ALMOST_FULL   = (1<<DATA_DEPTH_LG2)-1,
    parameter ALMOST_EMPTY  = 1
 )
(
    input   wire                        clk,
    input   wire                        rst_n,

    // push interface
    output  wire                        full_o,
    output  wire                        afull_o,    // almost full
    input   wire                        wren_i,
    input   wire    [DATA_WIDTH-1:0]    wdata_i,

    // pop interface
    output  wire                        empty_o,
    output  wire                        aempty_o,   // almost empty
    input   wire                        rden_i,
    output  wire    [DATA_WIDTH-1:0]    rdata_o
);

localparam  DATA_DEPTH      = (1<<DATA_DEPTH_LG2);
localparam  PTR_WIDTH       = DATA_DEPTH_LG2+1;

reg [DATA_WIDTH-1:0][DATA_DEPTH]        data;

reg [PTR_WIDTH-1:0]             wrptr,      wrptr_n,
                                rdptr,      rdptr_n;
                                cnt,        cnt_n;

always @(posedge clk)
    if (!rst_n) begin
        wrptr                   <= 'd0;
        rdptr                   <= 'd0;
        cnt                     <= 'd0;
    end
    else begin
        wrptr                   <= wrptr_n;
        rdptr                   <= rdptr_n;
        cnt                     <= cnt_n;
    end

always_comb begin
    wrptr_n                 = wrptr;
    rdptr_n                 = rdptr;
    cnt_n                   = cnt;

    if (wren_i) begin
        wrptr_n                 = wrptr + 'd1;
        cnt_n                   = cnt + 'd1;
    end
    if (rden_i) begin
        rdptr_n                 = rdptr + 'd1;
        // must be cnt_n to cover simultaneous wren and rden
        cnt_n                   = cnt_n - 'd1;
    end
end

always @(posedge clk)
    if (!rst_n) begin
        for (int i=0; i<DATA_DEPTH; i++) begin
            data[i]                 <= 'd0;
        end
    end
    else begin
        if (wren_i) begin
            data[wrptr]             <= wdata_i;
        end
    end

assign  full_o                  = (cnt==DATA_DEPTH);
assign  afull_o                 = (cnt==ALMOST_FULL);
assign  empty_o                 = (cnt=='d0);
assign  aempty_o                = (cnt==ALMOST_EMPTY);
assign  rdata_o                 = data[rdptr];

endmodule
