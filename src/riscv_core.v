`include "defines.v"

module riscv_core (
    input wire clk,
    input wire rst_n,
    output wire [31:0] pc_out,
    output wire [31:0] alu_result_out
);

    // ===========================================================================
    // Internal Signals & Pipeline Registers
    // ===========================================================================

    // IF Stage
    wire [31:0] if_pc;
    wire [31:0] if_inst;
    wire [31:0] if_pc_plus_4;
    wire [31:0] next_pc;
    wire pc_src; // 0: PC+4, 1: Branch Target

    // IF/ID Pipeline Register
    reg [31:0] id_pc;
    reg [31:0] id_inst;
    reg [31:0] id_pc_plus_4;

    // ID Stage
    wire [6:0] id_opcode;
    wire [2:0] id_funct3;
    wire [6:0] id_funct7;
    wire [4:0] id_rs1_addr, id_rs2_addr, id_rd_addr;
    wire [31:0] id_rs1_data, id_rs2_data;
    wire [31:0] id_imm;
    wire id_branch, id_jump, id_mem_read, id_mem_write, id_reg_write, id_alu_src_b;
    wire [1:0] id_alu_src_a, id_result_src;
    wire [3:0] id_alu_ctrl;
    wire [31:0] id_branch_target;
    wire id_branch_taken;

    // ID/EX Pipeline Register
    reg [31:0] ex_pc;
    reg [31:0] ex_rs1_data, ex_rs2_data;
    reg [31:0] ex_imm;
    reg [4:0] ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    reg ex_reg_write, ex_mem_read, ex_mem_write, ex_alu_src_b;
    reg ex_branch, ex_jump; // Added missing declarations
    reg [1:0] ex_alu_src_a, ex_result_src;
    reg [3:0] ex_alu_ctrl;
    reg [31:0] ex_pc_plus_4;

    // EX Stage
    wire [31:0] ex_alu_in_a, ex_alu_in_b;
    wire [31:0] ex_alu_result;
    wire ex_zero;
    wire [31:0] ex_forward_a_val, ex_forward_b_val;

    // EX/MEM Pipeline Register
    reg [31:0] mem_alu_result;
    reg [31:0] mem_rs2_data; // For store
    reg [4:0] mem_rd_addr;
    reg mem_reg_write, mem_mem_read, mem_mem_write;
    reg [1:0] mem_result_src;
    reg [31:0] mem_pc_plus_4;

    // MEM Stage
    wire [31:0] mem_read_data;

    // MEM/WB Pipeline Register
    reg [31:0] wb_alu_result;
    reg [31:0] wb_read_data;
    reg [4:0] wb_rd_addr;
    reg wb_reg_write;
    reg [1:0] wb_result_src;
    reg [31:0] wb_pc_plus_4;

    // WB Stage
    reg [31:0] wb_write_data;

    // Hazard / Forwarding
    wire stall_if, stall_id;
    wire flush_id; // Not used for branches in delayed branching!
    wire [1:0] forward_a, forward_b;

    // ===========================================================================
    // IF Stage
    // ===========================================================================
    
    assign if_pc_plus_4 = if_pc + 4;
    
    // PC Mux
    // In delayed branching, if branch is taken in ID, we update PC to target.
    // The instruction currently in IF (Delay Slot) is allowed to proceed.
    assign next_pc = (pc_src) ? id_branch_target : if_pc_plus_4;

    program_counter pc_module (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_if),
        .next_pc(next_pc),
        .pc(if_pc)
    );

    instruction_memory imem (
        .addr(if_pc),
        .inst(if_inst)
    );

    // IF/ID Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc <= 0;
            id_inst <= 0; // NOP
            id_pc_plus_4 <= 0;
        end else if (!stall_id) begin
            // No flush for branch! That's the delay slot feature.
            id_pc <= if_pc;
            id_inst <= if_inst;
            id_pc_plus_4 <= if_pc_plus_4;
        end
    end

    // ===========================================================================
    // ID Stage
    // ===========================================================================

    assign id_opcode = id_inst[6:0];
    assign id_rd_addr = id_inst[11:7];
    assign id_funct3 = id_inst[14:12];
    assign id_rs1_addr = id_inst[19:15];
    assign id_rs2_addr = id_inst[24:20];
    assign id_funct7 = id_inst[31:25];

    control_unit ctrl (
        .opcode(id_opcode),
        .funct3(id_funct3),
        .funct7(id_funct7),
        .branch(id_branch),
        .jump(id_jump),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .reg_write(id_reg_write),
        .alu_src_a(id_alu_src_a),
        .alu_src_b(id_alu_src_b),
        .alu_ctrl(id_alu_ctrl),
        .result_src(id_result_src)
    );

    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(id_rs1_addr),
        .rs2_addr(id_rs2_addr),
        .rd_addr(wb_rd_addr),
        .wr_data(wb_write_data),
        .wr_en(wb_reg_write),
        .rs1_data(id_rs1_data),
        .rs2_data(id_rs2_data)
    );

    imm_gen ig (
        .inst(id_inst),
        .imm(id_imm)
    );

    // Branch Logic (Resolve in ID)
    // Simple comparison for BEQ (using XOR result from ALU would be EX stage, 
    // but for ID resolution we need comparators here or assume simple equality)
    // For full RISC-V compliance we need full comparators. 
    // Let's implement simple equality check in ID for BEQ/BNE.
    // For BLT/BGE we need a subtractor.
    // To keep it simple and synthesizable, let's instantiate a comparator.
    
    wire [31:0] op_a = (forward_a == 2'b01) ? mem_alu_result : // Forwarding from MEM (not WB because WB writes in first half? No, standard forwarding)
                       (forward_a == 2'b10) ? wb_write_data : id_rs1_data; // Wait, forwarding logic is usually for EX stage.
                       // For ID stage branch resolution, we need to forward from EX and MEM stages if they write to rs1/rs2.
    
    // Simplified: We will assume the test code avoids data hazards for the branch condition itself 
    // or we implement full forwarding to ID.
    // Let's implement basic forwarding to ID for the branch comparator.
    
    wire [31:0] id_val_rs1 = (mem_rd_addr == id_rs1_addr && mem_reg_write && mem_rd_addr != 0) ? mem_alu_result :
                             (wb_rd_addr == id_rs1_addr && wb_reg_write && wb_rd_addr != 0) ? wb_write_data : id_rs1_data;
    wire [31:0] id_val_rs2 = (mem_rd_addr == id_rs2_addr && mem_reg_write && mem_rd_addr != 0) ? mem_alu_result :
                             (wb_rd_addr == id_rs2_addr && wb_reg_write && wb_rd_addr != 0) ? wb_write_data : id_rs2_data;

    wire branch_cond_met;
    assign branch_cond_met = (id_funct3 == 3'b000) ? (id_val_rs1 == id_val_rs2) : // BEQ
                             (id_funct3 == 3'b001) ? (id_val_rs1 != id_val_rs2) : // BNE
                             (id_funct3 == 3'b100) ? ($signed(id_val_rs1) < $signed(id_val_rs2)) : // BLT
                             (id_funct3 == 3'b101) ? ($signed(id_val_rs1) >= $signed(id_val_rs2)) : // BGE
                             0;

    assign id_branch_taken = (id_branch && branch_cond_met) || id_jump;
    assign id_branch_target = (id_jump && id_opcode == `OPCODE_JALR) ? (id_val_rs1 + id_imm) : (id_pc + id_imm);

    assign pc_src = id_branch_taken; // Controls PC Mux

    // ID/EX Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_pc <= 0;
            ex_rs1_data <= 0;
            ex_rs2_data <= 0;
            ex_imm <= 0;
            ex_rs1_addr <= 0;
            ex_rs2_addr <= 0;
            ex_rd_addr <= 0;
            ex_reg_write <= 0;
            ex_mem_read <= 0;
            ex_mem_write <= 0;
            ex_alu_src_b <= 0;
            ex_alu_src_a <= 0;
            ex_result_src <= 0;
            ex_alu_ctrl <= 0;
            ex_pc_plus_4 <= 0;
        end else begin
            // If we stall (load-use hazard), we insert a bubble (NOP)
            if (stall_id) begin
                ex_reg_write <= 0;
                ex_mem_write <= 0;
                ex_mem_read <= 0;
                ex_branch <= 0;
                ex_jump <= 0;
            end else begin
                ex_pc <= id_pc;
                ex_rs1_data <= id_rs1_data;
                ex_rs2_data <= id_rs2_data;
                ex_imm <= id_imm;
                ex_rs1_addr <= id_rs1_addr;
                ex_rs2_addr <= id_rs2_addr;
                ex_rd_addr <= id_rd_addr;
                ex_reg_write <= id_reg_write;
                ex_mem_read <= id_mem_read;
                ex_mem_write <= id_mem_write;
                ex_branch <= id_branch;
                ex_jump <= id_jump;
                ex_alu_src_b <= id_alu_src_b;
                ex_alu_src_a <= id_alu_src_a;
                ex_result_src <= id_result_src;
                ex_alu_ctrl <= id_alu_ctrl;
                ex_pc_plus_4 <= id_pc_plus_4;
            end
        end
    end

    // ===========================================================================
    // EX Stage
    // ===========================================================================

    // Forwarding Logic for ALU
    assign forward_a = (mem_reg_write && (mem_rd_addr != 0) && (mem_rd_addr == ex_rs1_addr)) ? 2'b10 :
                       (wb_reg_write && (wb_rd_addr != 0) && (wb_rd_addr == ex_rs1_addr)) ? 2'b01 : 2'b00;
    
    assign forward_b = (mem_reg_write && (mem_rd_addr != 0) && (mem_rd_addr == ex_rs2_addr)) ? 2'b10 :
                       (wb_reg_write && (wb_rd_addr != 0) && (wb_rd_addr == ex_rs2_addr)) ? 2'b01 : 2'b00;

    assign ex_forward_a_val = (forward_a == 2'b10) ? mem_alu_result :
                              (forward_a == 2'b01) ? wb_write_data : ex_rs1_data;

    assign ex_forward_b_val = (forward_b == 2'b10) ? mem_alu_result :
                              (forward_b == 2'b01) ? wb_write_data : ex_rs2_data;

    assign ex_alu_in_a = (ex_alu_src_a == 1) ? ex_pc : ex_forward_a_val;
    assign ex_alu_in_b = (ex_alu_src_b == 1) ? ex_imm : ex_forward_b_val;

    alu alu_inst (
        .a(ex_alu_in_a),
        .b(ex_alu_in_b),
        .alu_ctrl(ex_alu_ctrl),
        .result(ex_alu_result),
        .zero(ex_zero)
    );

    // EX/MEM Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_alu_result <= 0;
            mem_rs2_data <= 0;
            mem_rd_addr <= 0;
            mem_reg_write <= 0;
            mem_mem_read <= 0;
            mem_mem_write <= 0;
            mem_result_src <= 0;
            mem_pc_plus_4 <= 0;
        end else begin
            mem_alu_result <= ex_alu_result;
            mem_rs2_data <= ex_forward_b_val; // Store data needs forwarding too
            mem_rd_addr <= ex_rd_addr;
            mem_reg_write <= ex_reg_write;
            mem_mem_read <= ex_mem_read;
            mem_mem_write <= ex_mem_write;
            mem_result_src <= ex_result_src;
            mem_pc_plus_4 <= ex_pc_plus_4;
        end
    end

    // ===========================================================================
    // MEM Stage
    // ===========================================================================

    data_memory dmem (
        .clk(clk),
        .wr_en(mem_mem_write),
        .addr(mem_alu_result),
        .wr_data(mem_rs2_data),
        .rd_data(mem_read_data)
    );

    // MEM/WB Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_alu_result <= 0;
            wb_read_data <= 0;
            wb_rd_addr <= 0;
            wb_reg_write <= 0;
            wb_result_src <= 0;
            wb_pc_plus_4 <= 0;
        end else begin
            wb_alu_result <= mem_alu_result;
            wb_read_data <= mem_read_data;
            wb_rd_addr <= mem_rd_addr;
            wb_reg_write <= mem_reg_write;
            wb_result_src <= mem_result_src;
            wb_pc_plus_4 <= mem_pc_plus_4;
        end
    end

    // ===========================================================================
    // WB Stage
    // ===========================================================================

    always @(*) begin
        case (wb_result_src)
            0: wb_write_data = wb_alu_result;
            1: wb_write_data = wb_read_data;
            2: wb_write_data = wb_pc_plus_4;
            default: wb_write_data = 0;
        endcase
    end

    // Hazard Detection Unit (Load-Use)
    // If ID stage uses a register that EX stage is loading from memory, stall.
    // Also stall if Branch in ID depends on EX stage result (ALU or Load)
    wire load_use_hazard = (ex_mem_read && ((ex_rd_addr == id_rs1_addr) || (ex_rd_addr == id_rs2_addr)));
    
    wire branch_hazard = (id_branch && (
        (ex_reg_write && ex_rd_addr != 0 && (ex_rd_addr == id_rs1_addr || ex_rd_addr == id_rs2_addr)) ||
        (mem_mem_read && mem_rd_addr != 0 && (mem_rd_addr == id_rs1_addr || mem_rd_addr == id_rs2_addr))
    ));

    assign stall_id = load_use_hazard || branch_hazard;
    assign stall_if = stall_id;

    // Outputs for testbench
    assign pc_out = if_pc;
    assign alu_result_out = ex_alu_result;

endmodule
