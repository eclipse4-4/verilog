module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 8
)(
    // ?? ??? ?? wr,rd_rstb? ??? ??? ????? top module?? ???? ????? ???.
    input                       clk_wr,
    input                       wr_rstb,
    input                       wr_en,
    input      [DATA_WIDTH-1:0] wr_data,
    output wire                 full,

    // ?? ??? ??
    input                       clk_rd,
    input                       rd_rstb,
    input                       rd_en,
    output reg [DATA_WIDTH-1:0] rd_data,
    output wire                 empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam PTR_WIDTH  = ADDR_WIDTH + 1;//1bit? ?????? MSB? ?? full check.

    // --- ?? ??? 
    reg  [DATA_WIDTH-1:0] memory[DEPTH-1:0];
    reg  [PTR_WIDTH-1:0]  wr_ptr_bin, rd_ptr_bin; //?? ?? ???
    wire [PTR_WIDTH-1:0]  wr_ptr_gray, rd_ptr_gray; //????? gray? ??? ???
    wire [PTR_WIDTH-1:0]  rd_ptr_synced, wr_ptr_synced; // gray? ??? ???? 2f/f? ?? ???
    wire [DATA_WIDTH-1:0] rd_data_from_mem; // hw 1clk ??? ???? ?? ?? read??? ???? ??clk? ??? ??

    /* --- ??? ?? ? Full/Empty ??
	gray?? ????? ????? ??? ??? ?? ??? ?? ???? ?? ? ???? ??? ??? ????? 
	???? ????? ??? ??? ???? gray??? ???? ???? ??? ?? ????. */ 
    assign wr_ptr_gray = (wr_ptr_bin >> 1) ^ wr_ptr_bin;
    assign rd_ptr_gray = (rd_ptr_bin >> 1) ^ rd_ptr_bin;

    assign empty = (rd_ptr_gray == wr_ptr_synced);
// full ????? gray ??? MSB ??? ???????? 2?? ??? ???.
    assign full =  (wr_ptr_gray[PTR_WIDTH-1]   != rd_ptr_synced[PTR_WIDTH-1]  ) &&
                   (wr_ptr_gray[PTR_WIDTH-2]   != rd_ptr_synced[PTR_WIDTH-2]  ) &&
                   (wr_ptr_gray[PTR_WIDTH-3:0] == rd_ptr_synced[PTR_WIDTH-3:0]);


    // === ??(Write) ?? - clk_wr ?? ===
cdc_sync #(PTR_WIDTH) rd_sync_inst (.clk(clk_wr), .rstb(wr_rstb), .din(rd_ptr_gray), .dout(rd_ptr_synced));
    always @(posedge clk_wr or negedge wr_rstb) begin
        if (!wr_rstb) begin
            wr_ptr_bin <= 0;
        end else begin
            if (wr_en && !full) begin
                memory[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;// MSB? ?? ??? ??? ?? bit slicing? ??
                wr_ptr_bin <= wr_ptr_bin + 1;
            end
        end
    end

    // === ??(Read) ?? - clk_rd ?? ===
    cdc_sync #(PTR_WIDTH) wr_sync_inst (.clk(clk_rd), .rstb(rd_rstb), .din(wr_ptr_gray), .dout(wr_ptr_synced));

    assign rd_data_from_mem = memory[rd_ptr_bin[ADDR_WIDTH-1:0]];

    always @(posedge clk_rd or negedge rd_rstb) begin
        if (!rd_rstb) begin
            rd_ptr_bin <= 0;
            rd_data    <= 0;
        end else begin
            if (rd_en && !empty) begin
                rd_ptr_bin <= rd_ptr_bin + 1;
                rd_data    <= rd_data_from_mem;
            end
        end
    end

endmodule
