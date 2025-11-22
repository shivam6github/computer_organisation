`timescale 1ns / 1ps

module tb_riscv;

    reg clk;
    reg rst_n;
    wire [31:0] pc_out;
    wire [31:0] alu_result_out;

    // Instantiate the Core
    riscv_core core (
        .clk(clk),
        .rst_n(rst_n),
        .pc_out(pc_out),
        .alu_result_out(alu_result_out)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        #20;
        rst_n = 1;

        // Run simulation
        #500;
        
        // Print Register File State
        $display("\nFinal Register State:");
        $display("x1 (10) = %d", core.regfile.regs[1]);
        $display("x2 (20) = %d", core.regfile.regs[2]);
        $display("x3 (5)  = %d  <-- Delay Slot Executed!", core.regfile.regs[3]);
        $display("x4 (0)  = %d  <-- Skipped Instruction!", core.regfile.regs[4]);
        $display("x5 (30) = %d  <-- Branch Target Reached!", core.regfile.regs[5]);

        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time=%0t | PC=%h | ALU_Res=%h", $time, pc_out, alu_result_out);
    end

    // Waveform dump
    initial begin
        $dumpfile("riscv_core.vcd");
        $dumpvars(0, tb_riscv);
    end

endmodule
