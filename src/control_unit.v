`include "defines.v"

module control_unit (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    output reg branch,
    output reg jump,
    output reg mem_read,
    output reg mem_write,
    output reg reg_write,
    output reg [1:0] alu_src_a, // 0: rs1, 1: pc
    output reg alu_src_b,       // 0: rs2, 1: imm
    output reg [3:0] alu_ctrl,
    output reg [1:0] result_src // 0: alu, 1: mem, 2: pc+4
);

    always @(*) begin
        // Defaults
        branch = 0;
        jump = 0;
        mem_read = 0;
        mem_write = 0;
        reg_write = 0;
        alu_src_a = 0;
        alu_src_b = 0;
        alu_ctrl = 0;
        result_src = 0;

        case (opcode)
            `OPCODE_R_TYPE: begin
                reg_write = 1;
                alu_src_b = 0;
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5]) ? `ALU_SUB : `ALU_ADD;
                    3'b001: alu_ctrl = `ALU_SLL;
                    3'b010: alu_ctrl = `ALU_SLT;
                    3'b011: alu_ctrl = `ALU_SLTU;
                    3'b100: alu_ctrl = `ALU_XOR;
                    3'b101: alu_ctrl = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_ctrl = `ALU_OR;
                    3'b111: alu_ctrl = `ALU_AND;
                endcase
            end
            `OPCODE_I_TYPE: begin
                reg_write = 1;
                alu_src_b = 1;
                case (funct3)
                    3'b000: alu_ctrl = `ALU_ADD;
                    3'b001: alu_ctrl = `ALU_SLL;
                    3'b010: alu_ctrl = `ALU_SLT;
                    3'b011: alu_ctrl = `ALU_SLTU;
                    3'b100: alu_ctrl = `ALU_XOR;
                    3'b101: alu_ctrl = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_ctrl = `ALU_OR;
                    3'b111: alu_ctrl = `ALU_AND;
                endcase
            end
            `OPCODE_LOAD: begin
                reg_write = 1;
                mem_read = 1;
                alu_src_b = 1;
                alu_ctrl = `ALU_ADD;
                result_src = 1;
            end
            `OPCODE_STORE: begin
                mem_write = 1;
                alu_src_b = 1;
                alu_ctrl = `ALU_ADD;
            end
            `OPCODE_BRANCH: begin
                branch = 1;
                alu_src_b = 0;
                alu_ctrl = `ALU_SUB; // Comparison done via subtraction/flags
            end
            `OPCODE_JAL: begin
                jump = 1;
                reg_write = 1;
                alu_src_a = 1; // PC
                alu_src_b = 1; // Imm
                alu_ctrl = `ALU_ADD; // PC + Imm
                result_src = 2; // Store PC+4
            end
            `OPCODE_JALR: begin
                jump = 1;
                reg_write = 1;
                alu_src_a = 0; // rs1
                alu_src_b = 1; // Imm
                alu_ctrl = `ALU_ADD;
                result_src = 2;
            end
            `OPCODE_LUI: begin
                reg_write = 1;
                alu_src_b = 1;
                alu_ctrl = `ALU_ADD; // LUI is handled by imm_gen + add 0? No, usually just pass imm. 
                // Simplified: Treat as add x0, imm.
                // But LUI imm is shifted. imm_gen handles shift.
                // We need to add 0.
                // rs1 is x0 (0).
            end
            // ... other opcodes
        endcase
    end

endmodule
