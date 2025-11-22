`include "defines.v"

module imm_gen (
    input wire [31:0] inst,
    output reg [31:0] imm
);

    wire [6:0] opcode = inst[6:0];

    always @(*) begin
        case (opcode)
            `OPCODE_I_TYPE, `OPCODE_LOAD, `OPCODE_JALR: 
                imm = {{20{inst[31]}}, inst[31:20]};
            `OPCODE_STORE:
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            `OPCODE_BRANCH:
                imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            `OPCODE_LUI, `OPCODE_AUIPC: 
                imm = {inst[31:12], 12'b0};
            `OPCODE_JAL: 
                imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            default: 
                imm = 32'b0;
        endcase
    end

endmodule
