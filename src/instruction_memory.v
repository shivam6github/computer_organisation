module instruction_memory (
    input wire [31:0] addr,
    output wire [31:0] inst
);

    reg [31:0] mem [0:1023]; // 4KB instruction memory
    integer i;

    initial begin
        // Initialize with NOPs
        for (i = 0; i < 1024; i = i + 1) mem[i] = 32'b0;
        
        // Load program
        $readmemh("program.hex", mem);
    end

    // Word aligned access
    assign inst = mem[addr[11:2]];

endmodule
