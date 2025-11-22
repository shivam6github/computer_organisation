module data_memory (
    input wire clk,
    input wire wr_en,
    input wire [31:0] addr,
    input wire [31:0] wr_data,
    output wire [31:0] rd_data
);

    reg [31:0] mem [0:1023]; // 4KB data memory

    assign rd_data = mem[addr[11:2]];

    always @(posedge clk) begin
        if (wr_en) begin
            mem[addr[11:2]] <= wr_data;
        end
    end

endmodule
