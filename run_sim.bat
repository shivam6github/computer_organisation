@echo off
echo Compiling Verilog files...
iverilog -I src -o riscv_sim.vvp test/tb_riscv.v src/riscv_core.v src/alu.v src/control_unit.v src/data_memory.v src/imm_gen.v src/instruction_memory.v src/program_counter.v src/register_file.v

if %errorlevel% neq 0 (
    echo Compilation failed!
    pause
    exit /b %errorlevel%
)

echo Running Simulation...
vvp riscv_sim.vvp

if %errorlevel% neq 0 (
    echo Simulation failed!
    pause
    exit /b %errorlevel%
)

echo.
echo Simulation successful! 
echo To view waveforms, run: gtkwave riscv_core.vcd
pause
