# ==============================================================================
# SCRIPT TCL/DO PER CARICAMENTO WAVEFORM IN MODELSIM / QUESTASIM
# Esegui dalla console di ModelSim con il comando: do load_waves.do
# ==============================================================================

# Pulisce la schermata delle wave attuale
delete wave *

# Disabilita il path completo per rendere i nomi leggibili (es: mostra solo "instr_T0")
config wave -signalnamewidth 1

# ==============================================================================
# 1. MEMORIE E REGISTER FILE
# ==============================================================================
add wave -noupdate -group "Memorie e RF" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/RF_T0_inst/reg_file
add wave -noupdate -group "Memorie e RF" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/RF_T1_inst/reg_file
add wave -noupdate -group "Memorie e RF" -radix hexadecimal sim:/tb_pid_fault/dut/ram_inst/ram_memory

# ==============================================================================
# 2. INTERFACCIA RAM (Output dal Checker)
# ==============================================================================
add wave -noupdate -group "Interfaccia RAM" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/data_addr_T0
add wave -noupdate -group "Interfaccia RAM" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/data_rdata_T0
add wave -noupdate -group "Interfaccia RAM" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/data_wdata_T0
add wave -noupdate -group "Interfaccia RAM" sim:/tb_pid_fault/dut/core_inst/data_we_T0

# ==============================================================================
# 3. PROGRAM COUNTERS E SALTI
# ==============================================================================
add wave -noupdate -group "Program Counters" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/PC_next_T0
add wave -noupdate -group "Program Counters" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/PC_next_T1
add wave -noupdate -group "Program Counters" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/pc_obs_T0
add wave -noupdate -group "Program Counters" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/pc_obs_T1
add wave -noupdate -group "Program Counters" sim:/tb_pid_fault/dut/core_inst/pc_src_T0
add wave -noupdate -group "Program Counters" sim:/tb_pid_fault/dut/core_inst/pc_src_T1

# ==============================================================================
# 4. ISTRUZIONI NELLA PIPELINE
# ==============================================================================
add wave -noupdate -group "Pipeline Istruzioni" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/if_id_reg_d.instr_T0
add wave -noupdate -group "Pipeline Istruzioni" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/if_id_reg_d.instr_T1
add wave -noupdate -group "Pipeline Istruzioni" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/id_ex_reg_d.instr_T0
add wave -noupdate -group "Pipeline Istruzioni" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/id_ex_reg_d.instr_T1
add wave -noupdate -group "Pipeline Istruzioni" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_mem_reg_d.instr_T0
add wave -noupdate -group "Pipeline Istruzioni" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_mem_reg_d.instr_T1

# ==============================================================================
# 5. EXECUTE (ALU IN & OUT)
# ==============================================================================
add wave -noupdate -group "Execute & ALU" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_alu_in_a_T0
add wave -noupdate -group "Execute & ALU" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_alu_in_a_T1
add wave -noupdate -group "Execute & ALU" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_alu_in_b_T0
add wave -noupdate -group "Execute & ALU" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_alu_in_b_T1
add wave -noupdate -group "Execute & ALU" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_mem_reg_d.alu_result_T0
add wave -noupdate -group "Execute & ALU" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/ex_mem_reg_d.alu_result_T1

# ==============================================================================
# 6. WRITEBACK (WB)
# ==============================================================================
add wave -noupdate -group "WriteBack Stage" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/WB_data_T0
add wave -noupdate -group "WriteBack Stage" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/WB_data_T1
add wave -noupdate -group "WriteBack Stage" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/mem_wb_reg_d.pc_T0
add wave -noupdate -group "WriteBack Stage" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/mem_wb_reg_d.pc_T1

# ==============================================================================
# 7. FAULT CHECKER (Segnali interni e Check)
# ==============================================================================
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/fiu_active 
add wave -noupdate -group "Fault Checker (RMT)" -radix unsigned sim:/tb_pid_fault/fiu_internal_cycle 
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/fault_on_EXE
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/fault_checker_inst/fault_on_MEM
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/fault_checker_inst/fault_on_WB 
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/fault_checker_inst/fault_on_PC 


add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_branch_T0_out
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_branch_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_branch_T1_out
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_branch_T1_w
add wave -noupdate -group "Fault Checker (RMT)"  sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_src_T0_out
add wave -noupdate -group "Fault Checker (RMT)"  sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_src_T0_w
add wave -noupdate -group "Fault Checker (RMT)"  sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_src_T1_out
add wave -noupdate -group "Fault Checker (RMT)"  sim:/tb_pid_fault/dut/core_inst/FC_EXE_pc_src_T1_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_EXE_PC_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_EXE_PC_T1_w



add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_PC_RB
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_alu_res_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_alu_res_T1_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_rdata2_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_rdata2_T1_w
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_MEM_data_we_T0_w
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_MEM_data_we_T1_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_PC_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_PC_T1_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_data_waddr_out
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_MEM_data_wdata_out
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_MEM_data_we_out

add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_WB_data_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_WB_data_T1_w
add wave -noupdate -group "Fault Checker (RMT)" -radix unsigned sim:/tb_pid_fault/dut/core_inst/FC_WB_rd_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix unsigned sim:/tb_pid_fault/dut/core_inst/FC_WB_rd_T1_w
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_WB_rf_we_T0_w
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_WB_rf_we_T1_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_WB_PC_T0_w
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_WB_PC_T1_w

add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_WB_data_T0_out
add wave -noupdate -group "Fault Checker (RMT)" -radix hexadecimal sim:/tb_pid_fault/dut/core_inst/FC_WB_data_T1_out
add wave -noupdate -group "Fault Checker (RMT)" -radix unsigned sim:/tb_pid_fault/dut/core_inst/FC_WB_rd_T0_out
add wave -noupdate -group "Fault Checker (RMT)" -radix unsigned sim:/tb_pid_fault/dut/core_inst/FC_WB_rd_T1_out
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_WB_rf_we_T0_out
add wave -noupdate -group "Fault Checker (RMT)" sim:/tb_pid_fault/dut/core_inst/FC_WB_rf_we_T1_out

# Aggiorna la vista
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update

