module register_file (
    input wire clk,
    input wire rst_n,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    input wire [4:0] rd_addr,
    input wire [31:0] wr_data,
    input wire wr_en,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] regs [0:31];
    integer i;

    // Read ports (asynchronous)
    assign rs1_data = (rs1_addr == 0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 32'b0 : regs[rs2_addr];

    // Write port (synchronous)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (wr_en && (rd_addr != 0)) begin
            regs[rd_addr] <= wr_data;
        end
    end

endmodule
