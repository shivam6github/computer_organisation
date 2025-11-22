# Delayed Branch Implementation in RISC-V Core

[cite_start]**Course:** EE-326: Computer Organization & Processor Architecture Design [cite: 2]
[cite_start]**Author:** Shivam (Roll No: B23293) [cite: 6, 7]
[cite_start]**Institute:** IIT Mandi [cite: 1]

## 📌 Project Overview
[cite_start]This project implements a custom 32-bit RISC-V processor core (RV32I base integer instruction set) featuring a **Delayed Branching** mechanism[cite: 3, 36].

[cite_start]In standard pipelined processors, control hazards (branch hazards) introduce stall cycles ("bubbles") while waiting for the branch condition to resolve[cite: 18, 24]. [cite_start]This project mitigates that penalty by modifying the hardware to always execute the instruction immediately following a branch (the **Delay Slot**), regardless of the branch outcome[cite: 27, 28].

## ⚙️ Architecture Design
[cite_start]The core utilizes a classic 5-stage pipeline structure[cite: 37]:
1.  **IF:** Instruction Fetch
2.  **ID:** Instruction Decode
3.  **EX:** Execute
4.  **MEM:** Memory Access
5.  **WB:** Writeback

### Key Modifications for Delayed Branching
* [cite_start]**Early Branch Resolution:** Branch comparison logic was moved from the Execute (EX) stage to the Decode (ID) stage to reduce latency[cite: 52].
* [cite_start]**No Flushing:** The standard flush signal for the `IF/ID` pipeline register is disabled for branch instructions[cite: 59]. [cite_start]This allows the instruction currently in the Fetch stage (the delay slot instruction) to proceed validly into the pipeline[cite: 60].
* [cite_start]**Hazard Detection:** Includes a Hazard Detection Unit to handle Load-Use hazards and Branch Data hazards[cite: 65, 66].

## 📂 File Structure
[cite_start]The project is modularized into the following Verilog files[cite: 46]:

* [cite_start]`riscv_core.v`: Top-level module connecting pipeline stages and implementing delay slot logic[cite: 50, 57].
* [cite_start]`alu.v`: Arithmetic Logic Unit[cite: 47].
* [cite_start]`control_unit.v`: Generates control signals based on Opcode/Funct3[cite: 49].
* [cite_start]`register_file.v`: 32x32-bit Register File[cite: 48].
* [cite_start]`tb_riscv.v`: Testbench for verification[cite: 72].
* [cite_start]`program.hex`: Custom assembly program for testing slot filling[cite: 72].

## 🧪 Simulation & Testing
[cite_start]The design was verified using **Icarus Verilog**[cite: 137].

### Test Case: Slot Filling
[cite_start]The following assembly sequence demonstrates the delayed branch logic [cite: 77-87]:

```assembly
addi x1, x0, 10    // Initialize x1 = 10
addi x2, x0, 20    // Initialize x2 = 20
beq  x1, x1, 12    // Branch to Target (PC+12) if x1==x1 (Always Taken)
addi x3, x0, 5     // [DELAY SLOT] This must execute!
addi x4, x0, 68    // This must be SKIPPED
addi x5, x0, 30    // Branch Target
