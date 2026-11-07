library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Core_SMT is
Port (
clk             : in std_logic;
reset           : in std_logic;

-- ==========================================
-- PORTE DI OSSERVAZIONE (Per Testbench/Debug)
-- ==========================================
pc_obs_T0       : out std_logic_vector(31 downto 0);
instr_obs_T0    : out std_logic_vector(31 downto 0);
pc_obs_T1       : out std_logic_vector(31 downto 0);
instr_obs_T1    : out std_logic_vector(31 downto 0);

-- ==========================================
-- INTERFACCIA INSTRUCTION MEMORY (Dual Port)
-- ==========================================
pc_out_T0       : out std_logic_vector(31 downto 0);
instr_in_T0     : in  std_logic_vector(31 downto 0);

pc_out_T1       : out std_logic_vector(31 downto 0);
instr_in_T1     : in  std_logic_vector(31 downto 0);

-- ==========================================
-- INTERFACCIA DATA MEMORY (SMT -> RMT Unificata)
-- ==========================================
-- Porta A (Thread 0 / RAM Unificata)
data_addr_T0    : out std_logic_vector(31 downto 0);
data_wdata_T0   : out std_logic_vector(31 downto 0);
data_we_T0      : out std_logic;
data_rdata_T0   : in  std_logic_vector(31 downto 0);

-- Porta B (Thread 1 - Inutilizzata in RMT)                                   
data_addr_T1    : out std_logic_vector(31 downto 0);
data_wdata_T1   : out std_logic_vector(31 downto 0);
data_we_T1      : out std_logic;
data_rdata_T1   : in  std_logic_vector(31 downto 0);


-- safe - mode

ft_mode         : in std_logic; -- 0 = SMT, 1 = RMT (Sicura)

-- ==========================================
-- FAULT-CHECK OUT
-- ==========================================
fault_detected_out: out std_logic


);
end Core_SMT;

architecture Strutturale of Core_SMT is

-- 1. DICHIARAZIONE DEI COMPONENTI INTERNI

component Register_File is
port (
clk         : in std_logic;
we          : in std_logic;
read_addr1  : in std_logic_vector(4 downto 0);
read_addr2  : in std_logic_vector(4 downto 0);
write_addr  : in std_logic_vector(4 downto 0);
write_data  : in std_logic_vector(31 downto 0);
read_data1  : out std_logic_vector(31 downto 0);
read_data2  : out std_logic_vector(31 downto 0)
);
end component;

component ALU_Unit is
port (
op1         : in std_logic_vector(31 downto 0);
op2         : in std_logic_vector(31 downto 0);
alu_ctrl    : in std_logic_vector(3 downto 0);
alu_result  : out std_logic_vector(31 downto 0);
zero_flag   : out std_logic
);
end component;

component fault_checker is
port (
ft_mode           : in std_logic;
EXE_pc_branch_T0  : in std_logic_vector(31 downto 0);
EXE_pc_src_T0     : in std_logic;
EXE_pc_branch_T1  : in std_logic_vector(31 downto 0);
EXE_pc_src_T1     : in std_logic;
EXE_PC_T0         : in std_logic_vector(31 downto 0);
EXE_PC_T1         : in std_logic_vector(31 downto 0);

MEM_alu_res_T0    : in  std_logic_vector(31 downto 0);
MEM_alu_res_T1    : in  std_logic_vector(31 downto 0);
MEM_read_data2_T0 : in  std_logic_vector(31 downto 0);
MEM_read_data2_T1 : in  std_logic_vector(31 downto 0);
MEM_data_we_T0    : in  std_logic;
MEM_data_we_T1    : in  std_logic;
MEM_PC_T0         : in  std_logic_vector(31 downto 0);
MEM_PC_T1         : in  std_logic_vector(31 downto 0);

WB_data_T0        : in  std_logic_vector(31 downto 0);
WB_data_T1        : in  std_logic_vector(31 downto 0);
WB_rd_T0          : in  std_logic_vector(4 downto 0);
WB_rd_T1          : in  std_logic_vector(4 downto 0);
WB_rf_we_T0       : in  std_logic;
WB_rf_we_T1       : in  std_logic;
WB_PC_T0          : in  std_logic_vector(31 downto 0);
WB_PC_T1          : in  std_logic_vector(31 downto 0);

FC_EXE_pc_branch_T0: out std_logic_vector(31 downto 0);
FC_pc_src_T0       : out std_logic;
FC_EXE_pc_branch_T1: out std_logic_vector(31 downto 0);
FC_pc_src_T1       : out std_logic;

FC_MEM_data_we    : out std_logic;
FC_MEM_data_wdata : out std_logic_vector(31 downto 0);
FC_MEM_data_waddr : out std_logic_vector(31 downto 0);

FC_WB_data_T0     : out std_logic_vector(31 downto 0);
FC_WB_data_T1     : out std_logic_vector(31 downto 0);
FC_WB_rd_T0       : out std_logic_vector(4 downto 0);
FC_WB_rd_T1       : out std_logic_vector(4 downto 0);
FC_WB_rf_we_T0    : out std_logic;
FC_WB_rf_we_T1    : out std_logic;

fault_detected    : out std_logic;
fault_on_EXE      : out std_logic;
fault_on_MEM      : out std_logic;
fault_on_WB       : out std_logic;
fault_on_PC       : out std_logic;
FC_PC_RB          : out std_logic_vector(31 downto 0)


);

end component fault_checker;

-- PROTEZIONE SINTETIZZATORE

attribute DONT_TOUCH : string;
attribute DONT_TOUCH of RF_T0_inst  : label is "TRUE";
attribute DONT_TOUCH of RF_T1_inst  : label is "TRUE";
attribute DONT_TOUCH of ALU_T0_inst : label is "TRUE";
attribute DONT_TOUCH of ALU_T1_inst : label is "TRUE";
attribute DONT_TOUCH of fault_checker_inst : label is "TRUE";

-- OPC_codes & Costanti

constant OP_IRRI     : std_logic_vector(6 downto 0) := "0110011";
constant OP_STORE    : std_logic_vector(6 downto 0) := "0100011";
constant OP_LOAD     : std_logic_vector(6 downto 0) := "0000011";
constant OP_BRANCH   : std_logic_vector(6 downto 0) := "1100011";
constant OP_IMM      : std_logic_vector(6 downto 0) := "0010011";
constant OP_MUL      : std_logic_vector(6 downto 0) := "0110011";
constant OP_JAL      : std_logic_vector(6 downto 0) := "1101111"; -- Aggiunto OP_JAL

-- SEGNALI SWITCH MODALITA E SALVATAGGIO CONTESTO

signal ft_mode_old   : std_logic := '0'; -- Partenza in SMT (0)
signal flush_req     : std_logic := '0';
signal PC_T1_saved   : std_logic_vector(31 downto 0) := (others => '0');
-- SHIFT REGISTER A 2 STADI
signal ft_mode_d1  : std_logic := '0';
signal ft_mode_d2  : std_logic := '0';
-- PROGRAM COUNTER

signal PC_T0_s, PC_T1_s : std_logic_vector(31 downto 0) := (others => '0');
signal PC_next_T0, PC_next_T1 : std_logic_vector(31 downto 0);
signal PC_p4_T0, PC_p4_T1 : std_logic_vector(31 downto 0);
signal pc_src_T0, pc_src_T1 : std_logic;

-- REGISTRI PIPELINE

type if_id_reg_t is record
pc_T0, pc_T1       : std_logic_vector(31 downto 0);
instr_T0, instr_T1 : std_logic_vector(31 downto 0);
end record;
constant IF_ID_RESET : if_id_reg_t := ( (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0') );
signal if_id_reg_d, if_id_reg_q : if_id_reg_t;

type id_ex_reg_t is record
instr_T0, instr_T1           : std_logic_vector(31 downto 0);
pc_T0, pc_T1                 : std_logic_vector(31 downto 0);
read_data_1_T0, read_data_1_T1 : std_logic_vector(31 downto 0);
read_data_2_T0, read_data_2_T1 : std_logic_vector(31 downto 0);
imm_T0, imm_T1               : std_logic_vector(31 downto 0);
rd_T0, rd_T1                 : std_logic_vector(4 downto 0);
funct3_T0, funct3_T1         : std_logic_vector(2 downto 0);
funct7_b5_T0, funct7_b5_T1   : std_logic;
funct7_b0_T0, funct7_b0_T1   : std_logic;
alu_src_T0, alu_src_T1       : std_logic;
alu_op_T0, alu_op_T1         : std_logic_vector(1 downto 0);
mem_we_T0, mem_we_T1         : std_logic;
mem_read_T0, mem_read_T1     : std_logic;
is_mul_T0, is_mul_T1         : std_logic;
reg_we_T0, reg_we_T1         : std_logic;
mem_to_reg_T0, mem_to_reg_T1 : std_logic;
branch_T0, branch_T1         : std_logic;
jump_T0, jump_T1             : std_logic; -- Aggiunto FLAG JUMP
end record;
constant ID_EX_RESET : id_ex_reg_t := ( (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0','0','0','0','0','0', "00", "00", '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0' );
signal id_ex_reg_d, id_ex_reg_q : id_ex_reg_t;

type ex_mem_reg_t is record
instr_T0, instr_T1           : std_logic_vector(31 downto 0);
alu_result_T0, alu_result_T1 : std_logic_vector(31 downto 0);
pc_T0,pc_T1                  : std_logic_vector(31 downto 0);
mul_op_a_T0, mul_op_a_T1     : std_logic_vector(31 downto 0);
mul_op_b_T0, mul_op_b_T1     : std_logic_vector(31 downto 0);
read_data_2_T0, read_data_2_T1: std_logic_vector(31 downto 0);
rd_T0, rd_T1                 : std_logic_vector(4 downto 0);
mem_we_T0, mem_we_T1         : std_logic;
is_mul_T0,is_mul_T1          : std_logic;
is_mulH_T0,is_mulH_T1        : std_logic;
mem_read_T0, mem_read_T1     : std_logic;
reg_we_T0, reg_we_T1         : std_logic;
mem_to_reg_T0, mem_to_reg_T1 : std_logic;
end record;
constant EX_MEM_RESET : ex_mem_reg_t := ( (others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0','0','0','0','0', '0', '0', '0', '0', '0', '0', '0' );
signal ex_mem_reg_d, ex_mem_reg_q : ex_mem_reg_t;

type mem_wb_reg_t is record
pc_T0,pc_T1                  : std_logic_vector(31 downto 0);
mul_res_T0, mul_res_T1       : std_logic_vector(31 downto 0);
alu_result_T0, alu_result_T1 : std_logic_vector(31 downto 0);
mem_data_T1_rmt,mem_data_T1_smt : std_logic_vector(31 downto 0);
mem_data_T0                  : std_logic_vector(31 downto 0);
rd_T0, rd_T1                 : std_logic_vector(4 downto 0);
is_mul_T0, is_mul_T1         : std_logic;
reg_we_T0, reg_we_T1         : std_logic;
mem_to_reg_T0, mem_to_reg_T1 : std_logic;
end record;
constant MEM_WB_RESET : mem_wb_reg_t := ( (others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'),(others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0','0','0', '0', '0', '0' );
signal mem_wb_reg_d, mem_wb_reg_q : mem_wb_reg_t;
-- SEGNALI INTERNI

signal WB_data_T0, WB_data_T1 : std_logic_vector(31 downto 0);
signal rf_read_data1_T0, rf_read_data2_T0 : std_logic_vector(31 downto 0);
signal rf_read_data1_T1, rf_read_data2_T1 : std_logic_vector(31 downto 0);

signal ex_alu_in_a_T0, ex_alu_in_b_T0 : std_logic_vector(31 downto 0);
signal ex_alu_in_a_T1, ex_alu_in_b_T1 : std_logic_vector(31 downto 0);
signal alu_res_T0, alu_res_T1 : std_logic_vector(31 downto 0);
signal ex_ALU_ctrl_T0, ex_ALU_ctrl_T1 : std_logic_vector(3 downto 0);
signal ex_zero_T0, ex_zero_T1 : std_logic;
signal is_eq_T0, is_eq_T1 : std_logic;
signal is_less_T0, is_less_T1: std_logic;
signal ex_pc_branch_T0, ex_pc_branch_T1 : std_logic_vector(31 downto 0);

-- BYPASS SIGNALS
signal forwardA_T0, forwardB_T0 : std_logic_vector(1 downto 0);
signal forwardA_T1, forwardB_T1 : std_logic_vector(1 downto 0);

-- =============================================================================
-- SEGNALI DI STALLO E DECODIFICA (Hazard Detection)
-- =============================================================================
signal stall_T0, stall_T1 : std_logic;

signal opcode_T0, opcode_T1 : std_logic_vector(6 downto 0);
signal uses_rs1_T0, uses_rs2_T0 : std_logic;
signal uses_rs1_T1, uses_rs2_T1 : std_logic;

-- =============================================================================
-- SEGNALI PER IL FAULT CHECK
-- =============================================================================
-- Segnali per EXE
signal FC_EXE_pc_branch_T0_w, FC_EXE_pc_branch_T1_w : std_logic_vector(31 downto 0);
signal FC_EXE_pc_src_T0_w, FC_EXE_pc_src_T1_w       : std_logic;
signal FC_EXE_PC_T0_w, FC_EXE_PC_T1_w           : std_logic_vector(31 downto 0);

-- Segnali per MEM
signal FC_MEM_alu_res_T0_w,   FC_MEM_alu_res_T1_w   : std_logic_vector(31 downto 0);
signal FC_MEM_rdata2_T0_w,    FC_MEM_rdata2_T1_w    : std_logic_vector(31 downto 0);
signal FC_MEM_data_we_T0_w,   FC_MEM_data_we_T1_w   : std_logic;
signal FC_MEM_PC_T0_w,        FC_MEM_PC_T1_w        : std_logic_vector(31 downto 0);

-- Segnali per WB
signal FC_WB_data_T0_w,       FC_WB_data_T1_w       : std_logic_vector(31 downto 0);
signal FC_WB_rd_T0_w,         FC_WB_rd_T1_w         : std_logic_vector(4 downto 0);
signal FC_WB_rf_we_T0_w,      FC_WB_rf_we_T1_w      : std_logic;
signal FC_WB_PC_T0_w,         FC_WB_PC_T1_w         : std_logic_vector(31 downto 0);

-- Uscite filtrate per EXE
signal FC_EXE_pc_branch_T0_out, FC_EXE_pc_branch_T1_out : std_logic_vector(31 downto 0);
signal FC_EXE_pc_src_T0_out,    FC_EXE_pc_src_T1_out    : std_logic;

-- Uscite Filtrate per MEM
signal FC_MEM_data_we_out    : std_logic;
signal FC_MEM_data_wdata_out : std_logic_vector(31 downto 0);
signal FC_MEM_data_waddr_out : std_logic_vector(31 downto 0);

-- Uscite Filtrate per WB
signal FC_WB_data_T0_out,     FC_WB_data_T1_out     : std_logic_vector(31 downto 0);
signal FC_WB_rd_T0_out,       FC_WB_rd_T1_out       : std_logic_vector(4 downto 0);
signal FC_WB_rf_we_T0_out,    FC_WB_rf_we_T1_out    : std_logic;

-- Allarmi e Rollback
signal fault_on_EXE, fault_on_MEM, fault_on_WB, fault_on_PC : std_logic;
signal FC_PC_RB : std_logic_vector(31 downto 0);
signal hard_reset_w : std_logic;

begin
-- =============================================================================
-- ISTANZIAZIONE DELL'HARDWARE (I MODULI)
-- =============================================================================

-- Register File T0
RF_T0_inst : Register_File port map(
clk         => clk,
we          => FC_WB_rf_we_T0_out, -- Completamente sincrono
read_addr1  => if_id_reg_q.instr_T0(19 downto 15),
read_addr2  => if_id_reg_q.instr_T0(24 downto 20),
write_addr  => FC_WB_rd_T0_out,
write_data  => FC_WB_data_T0_out,
read_data1  => rf_read_data1_T0,
read_data2  => rf_read_data2_T0
);

-- Register File T1
RF_T1_inst : Register_File port map(
clk         => clk,
-- TECNICA DELL'IBERNAZIONE: Se ft_mode = '1' (RMT), blocchiamo la scrittura in T1
we          => FC_WB_rf_we_T1_out and (not ft_mode),
read_addr1  => if_id_reg_q.instr_T1(19 downto 15),
read_addr2  => if_id_reg_q.instr_T1(24 downto 20),
write_addr  => FC_WB_rd_T1_out,
write_data  => FC_WB_data_T1_out,
read_data1  => rf_read_data1_T1,
read_data2  => rf_read_data2_T1
);

-- ALU
ALU_T0_inst : ALU_Unit port map(
op1         => ex_alu_in_a_T0,
op2         => ex_alu_in_b_T0,
alu_ctrl    => ex_ALU_ctrl_T0,
alu_result  => alu_res_T0,
zero_flag   => open
);

ALU_T1_inst : ALU_Unit port map(
op1         => ex_alu_in_a_T1,
op2         => ex_alu_in_b_T1,
alu_ctrl    => ex_ALU_ctrl_T1,
alu_result  => alu_res_T1,
zero_flag   => open
);

-- FAULT CHECK LOGIC
fault_checker_inst : fault_checker port map (
ft_mode             => ft_mode_d2 ,
EXE_pc_branch_T0    => FC_EXE_pc_branch_T0_w,
EXE_pc_src_T0       => FC_EXE_pc_src_T0_w,
EXE_pc_branch_T1    => FC_EXE_pc_branch_T1_w,
EXE_pc_src_T1       => FC_EXE_pc_src_T1_w,
EXE_PC_T0           => FC_EXE_PC_T0_w,
EXE_PC_T1           => FC_EXE_PC_T1_w,

MEM_alu_res_T0      => FC_MEM_alu_res_T0_w,

MEM_alu_res_T1      => FC_MEM_alu_res_T1_w,

MEM_read_data2_T0   => FC_MEM_rdata2_T0_w,
MEM_read_data2_T1   => FC_MEM_rdata2_T1_w,
MEM_data_we_T0      => FC_MEM_data_we_T0_w,
MEM_data_we_T1      => FC_MEM_data_we_T1_w,
MEM_PC_T0           => FC_MEM_PC_T0_w,

MEM_PC_T1           => FC_MEM_PC_T1_w,

WB_data_T0          => FC_WB_data_T0_w,

WB_data_T1          => FC_WB_data_T1_w,

WB_rd_T0            => FC_WB_rd_T0_w,

WB_rd_T1            => FC_WB_rd_T1_w,

WB_rf_we_T0         => FC_WB_rf_we_T0_w,

WB_rf_we_T1         => FC_WB_rf_we_T1_w,

WB_PC_T0            => FC_WB_PC_T0_w,
WB_PC_T1            => FC_WB_PC_T1_w,

FC_EXE_pc_branch_T0 => FC_EXE_pc_branch_T0_out,
FC_pc_src_T0        => FC_EXE_pc_src_T0_out,
FC_EXE_pc_branch_T1 => FC_EXE_pc_branch_T1_out,
FC_pc_src_T1        => FC_EXE_pc_src_T1_out,

FC_MEM_data_we      => FC_MEM_data_we_out,

FC_MEM_data_wdata   => FC_MEM_data_wdata_out,

FC_MEM_data_waddr   => FC_MEM_data_waddr_out,

FC_WB_data_T0       => FC_WB_data_T0_out,

FC_WB_data_T1       => FC_WB_data_T1_out,

FC_WB_rd_T0         => FC_WB_rd_T0_out,

FC_WB_rd_T1         => FC_WB_rd_T1_out,

FC_WB_rf_we_T0      => FC_WB_rf_we_T0_out,

FC_WB_rf_we_T1      => FC_WB_rf_we_T1_out,

fault_detected      => fault_detected_out,
fault_on_EXE        => fault_on_EXE,
fault_on_MEM        => fault_on_MEM,
fault_on_WB         => fault_on_WB,
fault_on_PC         => fault_on_PC,
FC_PC_RB            => FC_PC_RB
);

-- =============================================================================
-- ASSEGNAZIONE DELLE USCITE DI OSSERVAZIONE (DEBUG)
-- =============================================================================
pc_obs_T0    <= PC_T0_s;
instr_obs_T0 <= if_id_reg_q.instr_T0;

pc_obs_T1    <= PC_T1_s;
instr_obs_T1 <= if_id_reg_q.instr_T1;

-- =============================================================================
-- GESTIONE DEL MODE SWITCHING (EDGE DETECTOR) E SALVATAGGIO CONTESTO
-- =============================================================================
mode_switch_proc: process(clk)
begin
if rising_edge(clk) then
if reset = '1' then
ft_mode_old <= ft_mode;
flush_req   <= '0';
PC_T1_saved <= (others => '0');
ft_mode_d1  <= '0';
ft_mode_d2  <= '0';
else
ft_mode_old <= ft_mode;

        -- Propagazione del ritardo (2 Cicli)
        ft_mode_d1  <= ft_mode;
        ft_mode_d2  <= ft_mode_d1; 
        
        if ft_mode_old /= ft_mode then
            flush_req <= '1';
            if ft_mode = '1' then
                PC_T1_saved <= ex_mem_reg_q.pc_T1;
            end if;
        else
            flush_req <= '0';
        end if;
    end if;
end if;


end process;
-- =============================================================================
-- LOGICA PROGRAM COUNTER, FETCH E ROLLBACK
-- =============================================================================
pc_out_T0 <= PC_T0_s;
pc_out_T1 <= PC_T1_s;

PC_p4_T0   <= std_logic_vector(unsigned(PC_T0_s) + to_unsigned(4, 32));
PC_p4_T1   <= std_logic_vector(unsigned(PC_T1_s) + to_unsigned(4, 32));

-- Se c'è un fault recuperabile (MEM o WB), carichiamo il PC di Rollback (FC_PC_RB)
-- Se c'è un flush, ripartiamo dall'istruzione in MEM
PC_next_T0 <= ex_mem_reg_q.pc_T0 when flush_req = '1' else
FC_PC_RB when (fault_on_WB = '1' or fault_on_MEM = '1' or fault_on_EXE = '1') else
FC_EXE_pc_branch_T0_out when FC_EXE_pc_src_T0_out = '1' else PC_p4_T0;

PC_next_T1 <= ex_mem_reg_q.pc_T0 when (flush_req = '1' and ft_mode = '1') else -- In RMT si allinea a T0
PC_T1_saved        when (flush_req = '1' and ft_mode = '0') else -- In SMT recupera il suo
FC_PC_RB when (fault_on_WB = '1' or fault_on_MEM = '1' or fault_on_EXE = '1') else
FC_EXE_pc_branch_T1_out when FC_EXE_pc_src_T1_out = '1' else PC_p4_T1;

-- Hard Reset (Reset fisico o Fault di disallineamento PC grave)
hard_reset_w <= reset or fault_on_PC;

-- =============================================================================
-- HAZARD DETECTION UNIT
-- =============================================================================
opcode_T0 <= if_id_reg_q.instr_T0(6 downto 0);
opcode_T1 <= if_id_reg_q.instr_T1(6 downto 0);

uses_rs1_T0 <= '1' when (opcode_T0 = "0110011" or opcode_T0 = "0010011" or
opcode_T0 = "0000011" or opcode_T0 = "0100011" or
opcode_T0 = "1100011" or opcode_T0 = "1100111") else '0';

uses_rs1_T1 <= '1' when (opcode_T1 = "0110011" or opcode_T1 = "0010011" or
opcode_T1 = "0000011" or opcode_T1 = "0100011" or
opcode_T1 = "1100011" or opcode_T1 = "1100111") else '0';

uses_rs2_T0 <= '1' when (opcode_T0 = "0110011" or opcode_T0 = "0100011" or
opcode_T0 = "1100011") else '0';

uses_rs2_T1 <= '1' when (opcode_T1 = "0110011" or opcode_T1 = "0100011" or
opcode_T1 = "1100011") else '0';

stall_T0 <= '1' when (id_ex_reg_q.mem_read_T0 = '1' or id_ex_reg_q.is_mul_T0 = '1') and
(id_ex_reg_q.rd_T0 /= "00000") and
( (id_ex_reg_q.rd_T0 = if_id_reg_q.instr_T0(19 downto 15) and uses_rs1_T0 = '1') or
(id_ex_reg_q.rd_T0 = if_id_reg_q.instr_T0(24 downto 20) and uses_rs2_T0 = '1') )
else '0';

stall_T1 <= '1' when (id_ex_reg_q.mem_read_T1 = '1' or id_ex_reg_q.is_mul_T1 = '1') and
(id_ex_reg_q.rd_T1 /= "00000") and
( (id_ex_reg_q.rd_T1 = if_id_reg_q.instr_T1(19 downto 15) and uses_rs1_T1 = '1') or
(id_ex_reg_q.rd_T1 = if_id_reg_q.instr_T1(24 downto 20) and uses_rs2_T1 = '1') )
else '0';

-- =============================================================================
-- AVANZAMENTO DELLA PIPELINE E GESTIONE DEL ROLLBACK
-- =============================================================================
pipeline_update: process(clk)
begin
if rising_edge(clk) then
if hard_reset_w = '1' then
-- Reset totale (Accensione o Disallineamento Grave PC)
PC_T0_s <= (others => '0');
if ft_mode = '1' then
PC_T1_s <= (others => '0');
else
PC_T1_s <= x"00000400";
end if;

if_id_reg_q  <= IF_ID_RESET;
id_ex_reg_q  <= ID_EX_RESET;
ex_mem_reg_q <= EX_MEM_RESET;
mem_wb_reg_q <= MEM_WB_RESET;

-- ==================================================================
-- FLUSH PER CAMBIO MODALITÀ (SMT <-> RMT)
-- ==================================================================
elsif flush_req = '1' then
-- Uccidiamo tutte le istruzioni in volo.
-- Le scritture in RAM prevengono i danni fermandosi al check flush_req = '1'.
-- L'istruzione in WB viene lasciata sopravvivere (mem_wb_reg_q non azzerata qui in lettura,
-- ma il record viene resettato per il prossimo giro).
if_id_reg_q  <= IF_ID_RESET;
id_ex_reg_q  <= ID_EX_RESET;
ex_mem_reg_q <= EX_MEM_RESET;
mem_wb_reg_q <= MEM_WB_RESET;

-- Riallineiamo i PC (Valutati nei MUX sopra)
PC_T0_s <= PC_next_T0; 
PC_T1_s <= PC_next_T1;


-- ==================================================================
-- GESTIONE DEL ROLLBACK GERARCHICO
-- ==================================================================
elsif fault_on_WB = '1' then
-- Errore nell'istruzione più vecchia. Flush Totale.
PC_T0_s <= PC_next_T0; -- Carica FC_PC_RB
PC_T1_s <= PC_next_T1; -- Carica FC_PC_RB
if_id_reg_q  <= IF_ID_RESET;
id_ex_reg_q  <= ID_EX_RESET;
ex_mem_reg_q <= EX_MEM_RESET;
mem_wb_reg_q <= MEM_WB_RESET; -- kill dell'istruzione in WB!

elsif fault_on_MEM = '1' then
-- Errore intermedio in MEM. Flush fino a MEM.
PC_T0_s <= PC_next_T0; -- Carica FC_PC_RB
PC_T1_s <= PC_next_T1; -- Carica FC_PC_RB
if_id_reg_q  <= IF_ID_RESET;
id_ex_reg_q  <= ID_EX_RESET;
ex_mem_reg_q <= EX_MEM_RESET; -- kill del'istruzione in MEM!

-- L'istruzione in WB è sana e si conclude!
mem_wb_reg_q <= mem_wb_reg_d;


elsif fault_on_EXE = '1' then
PC_T0_s <= PC_next_T0; -- Carica FC_PC_RB
PC_T1_s <= PC_next_T1; -- Carica FC_PC_RB
if_id_reg_q  <= IF_ID_RESET;
id_ex_reg_q  <= ID_EX_RESET;
ex_mem_reg_q  <= ex_mem_reg_d;
mem_wb_reg_q  <= mem_wb_reg_d;

else
-- NESSUN ERRORE: FUNZIONAMENTO NORMALE
-- IL PC AVANZA SOLO SE NON C'E' STALLO
if stall_T0 = '0' then PC_T0_s <= PC_next_T0; end if;
if stall_T1 = '0' then PC_T1_s <= PC_next_T1; end if;

-- ==========================
-- AGGIORNAMENTO T0
-- ==========================
if FC_EXE_pc_src_T0_out = '1' then 
    if_id_reg_q.pc_T0 <= (others => '0'); 
    if_id_reg_q.instr_T0 <= (others => '0');
    id_ex_reg_q.instr_T0 <= (others => '0'); 
    id_ex_reg_q.reg_we_T0 <= '0'; 
    id_ex_reg_q.mem_we_T0 <= '0'; 
    id_ex_reg_q.branch_T0 <= '0';
    id_ex_reg_q.jump_T0   <= '0';
elsif stall_T0 = '1' then
    id_ex_reg_q.instr_T0 <= (others => '0'); 
    id_ex_reg_q.reg_we_T0 <= '0'; 
    id_ex_reg_q.mem_we_T0 <= '0'; 
    id_ex_reg_q.mem_read_T0 <= '0';
    id_ex_reg_q.is_mul_T0 <= '0';
    id_ex_reg_q.branch_T0 <= '0';
    id_ex_reg_q.jump_T0   <= '0';
else
    if_id_reg_q.pc_T0 <= if_id_reg_d.pc_T0; 
    if_id_reg_q.instr_T0 <= if_id_reg_d.instr_T0;
    
    id_ex_reg_q.pc_T0 <= id_ex_reg_d.pc_T0; 
    id_ex_reg_q.instr_T0 <= id_ex_reg_d.instr_T0;
    id_ex_reg_q.read_data_1_T0 <= id_ex_reg_d.read_data_1_T0; 
    id_ex_reg_q.read_data_2_T0 <= id_ex_reg_d.read_data_2_T0;
    id_ex_reg_q.imm_T0 <= id_ex_reg_d.imm_T0; 
    id_ex_reg_q.rd_T0 <= id_ex_reg_d.rd_T0;
    id_ex_reg_q.funct3_T0 <= id_ex_reg_d.funct3_T0; 
    id_ex_reg_q.funct7_b5_T0 <= id_ex_reg_d.funct7_b5_T0;
    id_ex_reg_q.funct7_b0_T0 <= id_ex_reg_d.funct7_b0_T0; 
    id_ex_reg_q.alu_src_T0 <= id_ex_reg_d.alu_src_T0; 
    id_ex_reg_q.alu_op_T0 <= id_ex_reg_d.alu_op_T0;
    id_ex_reg_q.mem_we_T0 <= id_ex_reg_d.mem_we_T0;
    id_ex_reg_q.mem_read_T0 <= id_ex_reg_d.mem_read_T0;
    id_ex_reg_q.is_mul_T0 <= id_ex_reg_d.is_mul_T0;
    id_ex_reg_q.reg_we_T0 <= id_ex_reg_d.reg_we_T0; 
    id_ex_reg_q.mem_to_reg_T0 <= id_ex_reg_d.mem_to_reg_T0;
    id_ex_reg_q.branch_T0 <= id_ex_reg_d.branch_T0;
    id_ex_reg_q.jump_T0   <= id_ex_reg_d.jump_T0;
end if;

-- ==========================
-- AGGIORNAMENTO T1
-- ==========================
if FC_EXE_pc_src_T1_out = '1' then 
    if_id_reg_q.pc_T1 <= (others => '0'); 
    if_id_reg_q.instr_T1 <= (others => '0');
    id_ex_reg_q.instr_T1 <= (others => '0');
    id_ex_reg_q.reg_we_T1 <= '0'; 
    id_ex_reg_q.mem_we_T1 <= '0'; 
    id_ex_reg_q.branch_T1 <= '0';
    id_ex_reg_q.jump_T1   <= '0';
elsif stall_T1 = '1' then
    id_ex_reg_q.instr_T1 <= (others => '0'); 
    id_ex_reg_q.reg_we_T1 <= '0'; 
    id_ex_reg_q.mem_we_T1 <= '0';
    id_ex_reg_q.mem_read_T1 <= '0';
    id_ex_reg_q.is_mul_T1 <= '0';
    id_ex_reg_q.branch_T1 <= '0';
    id_ex_reg_q.jump_T1   <= '0';
else
    if_id_reg_q.pc_T1 <= if_id_reg_d.pc_T1; 
    if_id_reg_q.instr_T1 <= if_id_reg_d.instr_T1;
    
    id_ex_reg_q.pc_T1 <= id_ex_reg_d.pc_T1; 
    id_ex_reg_q.instr_T1 <= id_ex_reg_d.instr_T1;
    id_ex_reg_q.read_data_1_T1 <= id_ex_reg_d.read_data_1_T1; 
    id_ex_reg_q.read_data_2_T1 <= id_ex_reg_d.read_data_2_T1;
    id_ex_reg_q.imm_T1 <= id_ex_reg_d.imm_T1; 
    id_ex_reg_q.rd_T1 <= id_ex_reg_d.rd_T1;
    id_ex_reg_q.funct3_T1 <= id_ex_reg_d.funct3_T1; 
    id_ex_reg_q.funct7_b5_T1 <= id_ex_reg_d.funct7_b5_T1;
    id_ex_reg_q.funct7_b0_T1 <= id_ex_reg_d.funct7_b0_T1; 
    id_ex_reg_q.alu_src_T1 <= id_ex_reg_d.alu_src_T1; 
    id_ex_reg_q.alu_op_T1 <= id_ex_reg_d.alu_op_T1;
    id_ex_reg_q.mem_we_T1 <= id_ex_reg_d.mem_we_T1; 
    id_ex_reg_q.mem_read_T1 <= id_ex_reg_d.mem_read_T1;
    id_ex_reg_q.is_mul_T1 <= id_ex_reg_d.is_mul_T1;
    id_ex_reg_q.reg_we_T1 <= id_ex_reg_d.reg_we_T1;
    id_ex_reg_q.mem_to_reg_T1 <= id_ex_reg_d.mem_to_reg_T1;
    id_ex_reg_q.branch_T1 <= id_ex_reg_d.branch_T1;
    id_ex_reg_q.jump_T1   <= id_ex_reg_d.jump_T1;
end if;

-- Scorrimento
ex_mem_reg_q <= ex_mem_reg_d; 
mem_wb_reg_q <= mem_wb_reg_d;


end if;

end if;

end process;

-- 1. LOGICA IF (Fetch) E 2. LOGICA ID (Decode)

if_id_reg_d.pc_T0    <= PC_T0_s;
if_id_reg_d.instr_T0 <= instr_in_T0;

if_id_reg_d.pc_T1    <= PC_T1_s;
if_id_reg_d.instr_T1 <= instr_in_T1;

decode_T0_proc: process(all)
variable opcode : std_logic_vector(6 downto 0);
begin
id_ex_reg_d.pc_T0 <= if_id_reg_q.pc_T0;
id_ex_reg_d.instr_T0 <= if_id_reg_q.instr_T0;

if (mem_wb_reg_q.reg_we_T0 = '1') and (mem_wb_reg_q.rd_T0 /= "00000") and (mem_wb_reg_q.rd_T0 = if_id_reg_q.instr_T0(19 downto 15)) then
id_ex_reg_d.read_data_1_T0 <= WB_data_T0;
else
id_ex_reg_d.read_data_1_T0 <= rf_read_data1_T0;
end if;

if (mem_wb_reg_q.reg_we_T0 = '1') and (mem_wb_reg_q.rd_T0 /= "00000") and (mem_wb_reg_q.rd_T0 = if_id_reg_q.instr_T0(24 downto 20)) then
id_ex_reg_d.read_data_2_T0 <= WB_data_T0;
else
id_ex_reg_d.read_data_2_T0 <= rf_read_data2_T0;
end if;

id_ex_reg_d.rd_T0 <= if_id_reg_q.instr_T0(11 downto 7);
id_ex_reg_d.funct3_T0 <= if_id_reg_q.instr_T0(14 downto 12);
id_ex_reg_d.funct7_b5_T0 <= if_id_reg_q.instr_T0(30);
id_ex_reg_d.funct7_b0_T0 <= if_id_reg_q.instr_T0(25);

id_ex_reg_d.alu_src_T0 <= '0'; id_ex_reg_d.mem_to_reg_T0 <= '0'; id_ex_reg_d.reg_we_T0 <= '0';
id_ex_reg_d.mem_read_T0 <= '0'; id_ex_reg_d.mem_we_T0 <= '0'; id_ex_reg_d.branch_T0 <= '0';
id_ex_reg_d.is_mul_T0 <= '0'; id_ex_reg_d.jump_T0 <= '0';
id_ex_reg_d.alu_op_T0 <= "00"; id_ex_reg_d.imm_T0 <= (others => '0');

opcode := if_id_reg_q.instr_T0(6 downto 0);

case opcode is
when OP_IRRI   =>
id_ex_reg_d.reg_we_T0 <= '1';
id_ex_reg_d.alu_op_T0 <= "10";
if if_id_reg_q.instr_T0(25) = '1' then id_ex_reg_d.is_mul_T0 <= '1'; end if;
when OP_LOAD   => id_ex_reg_d.alu_src_T0 <= '1'; id_ex_reg_d.mem_to_reg_T0 <= '1'; id_ex_reg_d.reg_we_T0 <= '1'; id_ex_reg_d.mem_read_T0 <= '1';
when OP_STORE  => id_ex_reg_d.alu_src_T0 <= '1'; id_ex_reg_d.mem_we_T0 <= '1';
when OP_BRANCH => id_ex_reg_d.branch_T0 <= '1'; id_ex_reg_d.alu_op_T0 <= "01";
when OP_IMM    => id_ex_reg_d.alu_src_T0 <= '1'; id_ex_reg_d.reg_we_T0 <= '1'; id_ex_reg_d.alu_op_T0 <= "11";
when OP_JAL    => id_ex_reg_d.jump_T0 <= '1'; id_ex_reg_d.reg_we_T0 <= '1'; id_ex_reg_d.alu_op_T0 <= "00"; -- JAL
when others    => NULL;
end case;

case opcode is
when OP_LOAD | OP_IMM =>
id_ex_reg_d.imm_T0(11 downto 0) <= if_id_reg_q.instr_T0(31 downto 20);
id_ex_reg_d.imm_T0(31 downto 12) <= (others => if_id_reg_q.instr_T0(31));
when OP_STORE =>
id_ex_reg_d.imm_T0(11 downto 5) <= if_id_reg_q.instr_T0(31 downto 25);
id_ex_reg_d.imm_T0(4 downto 0)  <= if_id_reg_q.instr_T0(11 downto 7);
id_ex_reg_d.imm_T0(31 downto 12)<= (others => if_id_reg_q.instr_T0(31));
when OP_BRANCH =>
id_ex_reg_d.imm_T0(11) <= if_id_reg_q.instr_T0(7);
id_ex_reg_d.imm_T0(0)  <= '0';
id_ex_reg_d.imm_T0(10 downto 5) <= if_id_reg_q.instr_T0(30 downto 25);
id_ex_reg_d.imm_T0(4 downto 1)  <= if_id_reg_q.instr_T0(11 downto 8);
id_ex_reg_d.imm_T0(31 downto 12)<= (others => if_id_reg_q.instr_T0(31));
when OP_JAL =>
id_ex_reg_d.imm_T0(20) <= if_id_reg_q.instr_T0(31);
id_ex_reg_d.imm_T0(19 downto 12) <= if_id_reg_q.instr_T0(19 downto 12);
id_ex_reg_d.imm_T0(11) <= if_id_reg_q.instr_T0(20);
id_ex_reg_d.imm_T0(10 downto 1) <= if_id_reg_q.instr_T0(30 downto 21);
id_ex_reg_d.imm_T0(0)  <= '0';
id_ex_reg_d.imm_T0(31 downto 21) <= (others => if_id_reg_q.instr_T0(31));
when others => NULL;
end case;

end process;

decode_T1_proc: process(all)
variable opcode : std_logic_vector(6 downto 0);
begin
id_ex_reg_d.pc_T1 <= if_id_reg_q.pc_T1;
id_ex_reg_d.instr_T1 <= if_id_reg_q.instr_T1;

if ft_mode = '1' then
-- MODALITÀ RMT: T1 è "bendato" e legge/inoltra i dati a T0
if (mem_wb_reg_q.reg_we_T0 = '1') and (mem_wb_reg_q.rd_T0 /= "00000") and (mem_wb_reg_q.rd_T0 = if_id_reg_q.instr_T1(19 downto 15)) then
id_ex_reg_d.read_data_1_T1 <= WB_data_T0;
else
id_ex_reg_d.read_data_1_T1 <= rf_read_data1_T0;
end if;

if (mem_wb_reg_q.reg_we_T0 = '1') and (mem_wb_reg_q.rd_T0 /= "00000") and (mem_wb_reg_q.rd_T0 = if_id_reg_q.instr_T1(24 downto 20)) then
id_ex_reg_d.read_data_2_T1 <= WB_data_T0;
else
id_ex_reg_d.read_data_2_T1 <= rf_read_data2_T0;
end if;

else
-- MODALITÀ SMT: T1 normalmente
if (mem_wb_reg_q.reg_we_T1 = '1') and (mem_wb_reg_q.rd_T1 /= "00000") and (mem_wb_reg_q.rd_T1 = if_id_reg_q.instr_T1(19 downto 15)) then
id_ex_reg_d.read_data_1_T1 <= WB_data_T1;
else
id_ex_reg_d.read_data_1_T1 <= rf_read_data1_T1;
end if;

if (mem_wb_reg_q.reg_we_T1 = '1') and (mem_wb_reg_q.rd_T1 /= "00000") and (mem_wb_reg_q.rd_T1 = if_id_reg_q.instr_T1(24 downto 20)) then
id_ex_reg_d.read_data_2_T1 <= WB_data_T1;
else
id_ex_reg_d.read_data_2_T1 <= rf_read_data2_T1;
end if;

end if;

id_ex_reg_d.rd_T1 <= if_id_reg_q.instr_T1(11 downto 7);
id_ex_reg_d.funct3_T1 <= if_id_reg_q.instr_T1(14 downto 12);
id_ex_reg_d.funct7_b5_T1 <= if_id_reg_q.instr_T1(30);
id_ex_reg_d.funct7_b0_T1 <= if_id_reg_q.instr_T1(25);

id_ex_reg_d.alu_src_T1 <= '0'; id_ex_reg_d.mem_to_reg_T1 <= '0'; id_ex_reg_d.reg_we_T1 <= '0';
id_ex_reg_d.mem_read_T1 <= '0'; id_ex_reg_d.mem_we_T1 <= '0'; id_ex_reg_d.branch_T1 <= '0';
id_ex_reg_d.is_mul_T1 <= '0'; id_ex_reg_d.jump_T1 <= '0';
id_ex_reg_d.alu_op_T1 <= "00"; id_ex_reg_d.imm_T1 <= (others => '0');

opcode := if_id_reg_q.instr_T1(6 downto 0);

case opcode is
when OP_IRRI   =>
id_ex_reg_d.reg_we_T1 <= '1';
id_ex_reg_d.alu_op_T1 <= "10";
if if_id_reg_q.instr_T1(25) = '1' then id_ex_reg_d.is_mul_T1 <= '1'; end if;
when OP_LOAD   => id_ex_reg_d.alu_src_T1 <= '1'; id_ex_reg_d.mem_to_reg_T1 <= '1'; id_ex_reg_d.reg_we_T1 <= '1'; id_ex_reg_d.mem_read_T1 <= '1';
when OP_STORE  => id_ex_reg_d.alu_src_T1 <= '1'; id_ex_reg_d.mem_we_T1 <= '1';
when OP_BRANCH => id_ex_reg_d.branch_T1 <= '1'; id_ex_reg_d.alu_op_T1 <= "01";
when OP_IMM    => id_ex_reg_d.alu_src_T1 <= '1'; id_ex_reg_d.reg_we_T1 <= '1'; id_ex_reg_d.alu_op_T1 <= "11";
when OP_JAL    => id_ex_reg_d.jump_T1 <= '1'; id_ex_reg_d.reg_we_T1 <= '1'; id_ex_reg_d.alu_op_T1 <= "00"; -- JAL
when others    => NULL;
end case;

case opcode is
when OP_LOAD | OP_IMM =>
id_ex_reg_d.imm_T1(11 downto 0) <= if_id_reg_q.instr_T1(31 downto 20);
id_ex_reg_d.imm_T1(31 downto 12) <= (others => if_id_reg_q.instr_T1(31));
when OP_STORE =>
id_ex_reg_d.imm_T1(11 downto 5) <= if_id_reg_q.instr_T1(31 downto 25);
id_ex_reg_d.imm_T1(4 downto 0)  <= if_id_reg_q.instr_T1(11 downto 7);
id_ex_reg_d.imm_T1(31 downto 12)<= (others => if_id_reg_q.instr_T1(31));
when OP_BRANCH =>
id_ex_reg_d.imm_T1(11) <= if_id_reg_q.instr_T1(7);
id_ex_reg_d.imm_T1(0)  <= '0';
id_ex_reg_d.imm_T1(10 downto 5) <= if_id_reg_q.instr_T1(30 downto 25);
id_ex_reg_d.imm_T1(4 downto 1)  <= if_id_reg_q.instr_T1(11 downto 8);
id_ex_reg_d.imm_T1(31 downto 12)<= (others => if_id_reg_q.instr_T1(31));
when OP_JAL =>
id_ex_reg_d.imm_T1(20) <= if_id_reg_q.instr_T1(31);
id_ex_reg_d.imm_T1(19 downto 12) <= if_id_reg_q.instr_T1(19 downto 12);
id_ex_reg_d.imm_T1(11) <= if_id_reg_q.instr_T1(20);
id_ex_reg_d.imm_T1(10 downto 1) <= if_id_reg_q.instr_T1(30 downto 21);
id_ex_reg_d.imm_T1(0)  <= '0';
id_ex_reg_d.imm_T1(31 downto 21) <= (others => if_id_reg_q.instr_T1(31));
when others => NULL;
end case;

end process;

-- 3. LOGICA BYPASS (Risoluzione Hazard)

bypass_logic_T0: process(id_ex_reg_q.instr_T0, ex_mem_reg_q.reg_we_T0, ex_mem_reg_q.rd_T0, mem_wb_reg_q.reg_we_T0, mem_wb_reg_q.rd_T0)
variable ex_rs1, ex_rs2 : std_logic_vector(4 downto 0);
begin
forwardA_T0 <= "00"; forwardB_T0 <= "00";
ex_rs1 := id_ex_reg_q.instr_T0(19 downto 15);
ex_rs2 := id_ex_reg_q.instr_T0(24 downto 20);

if (ex_mem_reg_q.reg_we_T0 = '1') and (ex_mem_reg_q.rd_T0 /= "00000") and (ex_rs1 = ex_mem_reg_q.rd_T0) then forwardA_T0 <= "10";
elsif (mem_wb_reg_q.reg_we_T0 = '1') and (mem_wb_reg_q.rd_T0 /= "00000") and (ex_rs1 = mem_wb_reg_q.rd_T0) then forwardA_T0 <= "01";
end if;

if (ex_mem_reg_q.reg_we_T0 = '1') and (ex_mem_reg_q.rd_T0 /= "00000") and (ex_rs2 = ex_mem_reg_q.rd_T0) then forwardB_T0 <= "10";
elsif (mem_wb_reg_q.reg_we_T0 = '1') and (mem_wb_reg_q.rd_T0 /= "00000") and (ex_rs2 = mem_wb_reg_q.rd_T0) then forwardB_T0 <= "01";
end if;

end process;

bypass_logic_T1: process(id_ex_reg_q.instr_T1, ex_mem_reg_q.reg_we_T1, ex_mem_reg_q.rd_T1, mem_wb_reg_q.reg_we_T1, mem_wb_reg_q.rd_T1)
variable ex_rs1, ex_rs2 : std_logic_vector(4 downto 0);
begin
forwardA_T1 <= "00"; forwardB_T1 <= "00";
ex_rs1 := id_ex_reg_q.instr_T1(19 downto 15);
ex_rs2 := id_ex_reg_q.instr_T1(24 downto 20);

if (ex_mem_reg_q.reg_we_T1 = '1') and (ex_mem_reg_q.rd_T1 /= "00000") and (ex_rs1 = ex_mem_reg_q.rd_T1) then forwardA_T1 <= "10";
elsif (mem_wb_reg_q.reg_we_T1 = '1') and (mem_wb_reg_q.rd_T1 /= "00000") and (ex_rs1 = mem_wb_reg_q.rd_T1) then forwardA_T1 <= "01";
end if;

if (ex_mem_reg_q.reg_we_T1 = '1') and (ex_mem_reg_q.rd_T1 /= "00000") and (ex_rs2 = ex_mem_reg_q.rd_T1) then forwardB_T1 <= "10";
elsif (mem_wb_reg_q.reg_we_T1 = '1') and (mem_wb_reg_q.rd_T1 /= "00000") and (ex_rs2 = mem_wb_reg_q.rd_T1) then forwardB_T1 <= "01";
end if;

end process;

-- 4. LOGICA EX (ALU Control, Mux & Branch)

alu_control_proc: process(all)
begin
ex_ALU_ctrl_T0 <= "0000";
case id_ex_reg_q.alu_op_T0 is
when "00" => ex_ALU_ctrl_T0 <= "0010";
when "01" => ex_ALU_ctrl_T0 <= "0110";
when "10" | "11" =>
case id_ex_reg_q.funct3_T0 is
when "000" =>
if id_ex_reg_q.alu_op_T0="10" and id_ex_reg_q.funct7_b0_T0='1' then ex_ALU_ctrl_T0 <= "1000";
elsif id_ex_reg_q.alu_op_T0="10" and id_ex_reg_q.funct7_b5_T0='1' then ex_ALU_ctrl_T0 <= "0110";
else ex_ALU_ctrl_T0 <= "0010"; end if;
when "001" =>
if id_ex_reg_q.alu_op_T0="10" and id_ex_reg_q.funct7_b0_T0='1' then ex_ALU_ctrl_T0 <= "1001";
else ex_ALU_ctrl_T0 <= "1110"; end if;
when "101" =>
if id_ex_reg_q.funct7_b5_T0 = '1' then ex_ALU_ctrl_T0 <= "1100"; -- SRA
else ex_ALU_ctrl_T0 <= "1101"; end if; -- SRL
when "111" => ex_ALU_ctrl_T0 <= "0000";
when "110" => ex_ALU_ctrl_T0 <= "0001";
when others => NULL;
end case;
when others => NULL;
end case;

ex_ALU_ctrl_T1 <= "0000";
case id_ex_reg_q.alu_op_T1 is
when "00" => ex_ALU_ctrl_T1 <= "0010";
when "01" => ex_ALU_ctrl_T1 <= "0110";
when "10" | "11" =>
case id_ex_reg_q.funct3_T1 is
when "000" =>
if id_ex_reg_q.alu_op_T1="10" and id_ex_reg_q.funct7_b0_T1='1' then ex_ALU_ctrl_T1 <= "1000";
elsif id_ex_reg_q.alu_op_T1="10" and id_ex_reg_q.funct7_b5_T1='1' then ex_ALU_ctrl_T1 <= "0110";
else ex_ALU_ctrl_T1 <= "0010"; end if;
when "001" =>
if id_ex_reg_q.alu_op_T1="10" and id_ex_reg_q.funct7_b0_T1='1' then ex_ALU_ctrl_T1 <= "1001";
else ex_ALU_ctrl_T1 <= "1110"; end if;
when "101" =>
if id_ex_reg_q.funct7_b5_T1 = '1' then ex_ALU_ctrl_T1 <= "1100";
else ex_ALU_ctrl_T1 <= "1101"; end if;
when "111" => ex_ALU_ctrl_T1 <= "0000";
when "110" => ex_ALU_ctrl_T1 <= "0001";
when others => NULL;
end case;
when others => NULL;
end case;

-- JAL Override Muxes for T0
if id_ex_reg_q.instr_T0(6 downto 0) = OP_JAL then ex_alu_in_a_T0 <= id_ex_reg_q.pc_T0;
elsif forwardA_T0 = "10" then ex_alu_in_a_T0 <= ex_mem_reg_q.alu_result_T0;
elsif forwardA_T0 = "01" then ex_alu_in_a_T0 <= WB_data_T0;
else ex_alu_in_a_T0 <= id_ex_reg_q.read_data_1_T0; end if;

if id_ex_reg_q.instr_T0(6 downto 0) = OP_JAL then ex_alu_in_b_T0 <= x"00000004";
elsif id_ex_reg_q.alu_src_T0 = '1' then ex_alu_in_b_T0 <= id_ex_reg_q.imm_T0;
elsif forwardB_T0 = "10" then ex_alu_in_b_T0 <= ex_mem_reg_q.alu_result_T0;
elsif forwardB_T0 = "01" then ex_alu_in_b_T0 <= WB_data_T0;
else ex_alu_in_b_T0 <= id_ex_reg_q.read_data_2_T0; end if;

-- JAL Override Muxes for T1
if id_ex_reg_q.instr_T1(6 downto 0) = OP_JAL then ex_alu_in_a_T1 <= id_ex_reg_q.pc_T1;
elsif forwardA_T1 = "10" then ex_alu_in_a_T1 <= ex_mem_reg_q.alu_result_T1;
elsif forwardA_T1 = "01" then ex_alu_in_a_T1 <= WB_data_T1;
else ex_alu_in_a_T1 <= id_ex_reg_q.read_data_1_T1; end if;

if id_ex_reg_q.instr_T1(6 downto 0) = OP_JAL then ex_alu_in_b_T1 <= x"00000004";
elsif id_ex_reg_q.alu_src_T1 = '1' then ex_alu_in_b_T1 <= id_ex_reg_q.imm_T1;
elsif forwardB_T1 = "10" then ex_alu_in_b_T1 <= ex_mem_reg_q.alu_result_T1;
elsif forwardB_T1 = "01" then ex_alu_in_b_T1 <= WB_data_T1;
else ex_alu_in_b_T1 <= id_ex_reg_q.read_data_2_T1; end if;

end process;

ex_pc_branch_T0 <= std_logic_vector(signed(id_ex_reg_q.pc_T0) + signed(id_ex_reg_q.imm_T0));
is_less_T0  <=  '1' when (signed(ex_alu_in_a_T0) < signed(ex_alu_in_b_T0)) else '0';
is_eq_T0 <= '1' when (ex_alu_in_a_T0 = ex_alu_in_b_T0) else '0';
ex_zero_T0 <= is_eq_T0 when id_ex_reg_q.funct3_T0 = "000" else not is_eq_T0 when id_ex_reg_q.funct3_T0 = "001" else is_less_T0 when id_ex_reg_q.funct3_T0 = "100" else '0';
pc_src_T0  <= (ex_zero_T0 and id_ex_reg_q.branch_T0) or id_ex_reg_q.jump_T0; 

-- Assegnazione per il Fault check in EXE T0
FC_EXE_pc_branch_T0_w  <= ex_pc_branch_T0;
FC_EXE_pc_src_T0_w     <= pc_src_T0;
FC_EXE_PC_T0_w         <= id_ex_reg_q.pc_T0;

ex_mem_reg_d.instr_T0 <= id_ex_reg_q.instr_T0;
ex_mem_reg_d.pc_T0    <= id_ex_reg_q.pc_T0;
ex_mem_reg_d.alu_result_T0 <= alu_res_T0;
ex_mem_reg_d.rd_T0 <= id_ex_reg_q.rd_T0;
ex_mem_reg_d.reg_we_T0 <= id_ex_reg_q.reg_we_T0;
ex_mem_reg_d.mem_we_T0 <= id_ex_reg_q.mem_we_T0;
ex_mem_reg_d.mem_read_T0 <= id_ex_reg_q.mem_read_T0;
ex_mem_reg_d.mem_to_reg_T0 <= id_ex_reg_q.mem_to_reg_T0;
ex_mem_reg_d.read_data_2_T0 <= ex_mem_reg_q.alu_result_T0 when forwardB_T0="10" else WB_data_T0 when forwardB_T0="01" else id_ex_reg_q.read_data_2_T0;

-- MOLTIPLICATORE

-- T0
ex_mem_reg_d.mul_op_a_T0  <= ex_alu_in_a_T0;
ex_mem_reg_d.mul_op_b_T0  <= ex_alu_in_b_T0;
ex_mem_reg_d.is_mul_T0    <= id_ex_reg_q.is_mul_T0;
ex_mem_reg_d.is_mulH_T0   <= id_ex_reg_q.funct3_T0(0);
-- T1
ex_mem_reg_d.mul_op_a_T1  <= ex_alu_in_a_T1;
ex_mem_reg_d.mul_op_b_T1  <= ex_alu_in_b_T1;
ex_mem_reg_d.is_mul_T1    <= id_ex_reg_q.is_mul_T1;
ex_mem_reg_d.is_mulH_T1   <= id_ex_reg_q.funct3_T1(0);

ex_pc_branch_T1 <= std_logic_vector(signed(id_ex_reg_q.pc_T1) + signed(id_ex_reg_q.imm_T1));
is_less_T1  <= '1' when (signed(ex_alu_in_a_T1) < signed(ex_alu_in_b_T1)) else '0';
is_eq_T1 <= '1' when (ex_alu_in_a_T1 = ex_alu_in_b_T1) else '0';
ex_zero_T1 <= is_eq_T1 when id_ex_reg_q.funct3_T1 = "000" else not is_eq_T1 when id_ex_reg_q.funct3_T1 = "001" else is_less_T1 when id_ex_reg_q.funct3_T1 = "100" else '0';
pc_src_T1  <= (ex_zero_T1 and id_ex_reg_q.branch_T1) or id_ex_reg_q.jump_T1; 
-- Assegnazione per il Fault check in EXE T1
FC_EXE_pc_branch_T1_w  <= ex_pc_branch_T1;
FC_EXE_pc_src_T1_w     <= pc_src_T1;
FC_EXE_PC_T1_w         <= id_ex_reg_q.pc_T1;

ex_mem_reg_d.instr_T1 <= id_ex_reg_q.instr_T1;
ex_mem_reg_d.pc_T1    <= id_ex_reg_q.pc_T1;
ex_mem_reg_d.alu_result_T1 <= alu_res_T1;
ex_mem_reg_d.rd_T1 <= id_ex_reg_q.rd_T1;
ex_mem_reg_d.reg_we_T1 <= id_ex_reg_q.reg_we_T1;
ex_mem_reg_d.mem_we_T1 <= id_ex_reg_q.mem_we_T1;
ex_mem_reg_d.mem_read_T1 <= id_ex_reg_q.mem_read_T1;
ex_mem_reg_d.mem_to_reg_T1 <= id_ex_reg_q.mem_to_reg_T1;
ex_mem_reg_d.read_data_2_T1 <= ex_mem_reg_q.alu_result_T1 when forwardB_T1="10" else WB_data_T1 when forwardB_T1="01" else id_ex_reg_q.read_data_2_T1;

-- 5. LOGICA MEM & INTERFACCIA CON FAULT CHECKER

-- MOLTIPLICATORE

mult_proc_T0: process(all)
variable mul_temp : signed(63 downto 0);
variable res_temp : std_logic_vector(31 downto 0);
begin
res_temp := (others => '0');
mul_temp := (others => '0');
if ex_mem_reg_q.is_mulH_T0 = '0' then
mul_temp := signed(ex_mem_reg_q.mul_op_a_T0) * signed(ex_mem_reg_q.mul_op_b_T0);
res_temp := std_logic_vector(mul_temp(31 downto 0));
else
mul_temp := signed(ex_mem_reg_q.mul_op_a_T0) * signed(ex_mem_reg_q.mul_op_b_T0);
res_temp := std_logic_vector(mul_temp(63 downto 32));
end if;
mem_wb_reg_d.mul_res_T0  <= res_temp;
end process;

mult_proc_T1: process(all)
variable mul_temp : signed(63 downto 0);
variable res_temp : std_logic_vector(31 downto 0);
begin
res_temp := (others => '0');
mul_temp := (others => '0');
if ex_mem_reg_q.is_mulH_T1 = '0' then
mul_temp := signed(ex_mem_reg_q.mul_op_a_T1) * signed(ex_mem_reg_q.mul_op_b_T1);
res_temp := std_logic_vector(mul_temp(31 downto 0));
else
mul_temp := signed(ex_mem_reg_q.mul_op_a_T1) * signed(ex_mem_reg_q.mul_op_b_T1);
res_temp := std_logic_vector(mul_temp(63 downto 32));
end if;
mem_wb_reg_d.mul_res_T1  <= res_temp;
end process;

mem_wb_reg_d.is_mul_T0  <= ex_mem_reg_q.is_mul_T0;

mem_wb_reg_d.is_mul_T1  <= ex_mem_reg_q.is_mul_T1;

-- Sicurezza: Le scritture in RAM vengono soppresse se c'è un comando di flush
data_addr_T0  <= FC_MEM_data_waddr_out;
data_wdata_T0 <= FC_MEM_data_wdata_out;
data_we_T0    <= FC_MEM_data_we_out and not flush_req;

data_addr_T1  <= (others => '0') when ft_mode = '1' else ex_mem_reg_q.alu_result_T1;
data_wdata_T1 <= (others => '0') when ft_mode = '1' else ex_mem_reg_q.read_data_2_T1;
data_we_T1    <= '0' when ft_mode = '1' else (ex_mem_reg_q.mem_we_T1 and not flush_req);

-- Ingressi al Fault Checker per lo stadio MEM
FC_MEM_rdata2_T0_w  <= ex_mem_reg_q.read_data_2_T0;
FC_MEM_data_we_T0_w <= ex_mem_reg_q.mem_we_T0;
FC_MEM_alu_res_T0_w <= ex_mem_reg_q.alu_result_T0;
FC_MEM_PC_T0_w      <= ex_mem_reg_q.pc_T0;

FC_MEM_rdata2_T1_w  <= ex_mem_reg_q.read_data_2_T1;
FC_MEM_data_we_T1_w <= ex_mem_reg_q.mem_we_T1;
FC_MEM_alu_res_T1_w <= ex_mem_reg_q.alu_result_T1;
FC_MEM_PC_T1_w      <= ex_mem_reg_q.pc_T1;

-- Costruzione dati verso WB (T0)
mem_wb_reg_d.mem_data_T0 <= data_rdata_T0 when ex_mem_reg_q.mem_read_T0 = '1' else (others => '0');
mem_wb_reg_d.alu_result_T0 <= ex_mem_reg_q.alu_result_T0;
mem_wb_reg_d.rd_T0         <= ex_mem_reg_q.rd_T0;
mem_wb_reg_d.reg_we_T0     <= ex_mem_reg_q.reg_we_T0;
mem_wb_reg_d.mem_to_reg_T0 <= ex_mem_reg_q.mem_to_reg_T0;
mem_wb_reg_d.pc_T0         <= ex_mem_reg_q.pc_T0;

-- Costruzione dati verso WB (T1) (T1 legge da data_rdata_T0 per il Lockstep in RMT)
mem_wb_reg_d.mem_data_T1_rmt <= data_rdata_T0 when ex_mem_reg_q.mem_read_T1 = '1' else (others => '0');
mem_wb_reg_d.mem_data_T1_smt <= data_rdata_T1 when ex_mem_reg_q.mem_read_T1 = '1' else (others => '0');
mem_wb_reg_d.alu_result_T1 <= ex_mem_reg_q.alu_result_T1;
mem_wb_reg_d.rd_T1         <= ex_mem_reg_q.rd_T1;
mem_wb_reg_d.reg_we_T1     <= ex_mem_reg_q.reg_we_T1;
mem_wb_reg_d.mem_to_reg_T1 <= ex_mem_reg_q.mem_to_reg_T1;
mem_wb_reg_d.pc_T1         <= ex_mem_reg_q.pc_T1;

-- 6. LOGICA WB E INGRESSI CHECKER WB

-- Preparazione Dati per T0
WB_data_T0 <= mem_wb_reg_q.mul_res_T0 when mem_wb_reg_q.is_mul_T0 = '1' else mem_wb_reg_q.mem_data_T0 when mem_wb_reg_q.mem_to_reg_T0 = '1' else mem_wb_reg_q.alu_result_T0;
FC_WB_data_T0_w  <= WB_data_T0;
FC_WB_rd_T0_w    <= mem_wb_reg_q.rd_T0;
FC_WB_rf_we_T0_w <= mem_wb_reg_q.reg_we_T0;
FC_WB_PC_T0_w    <= mem_wb_reg_q.pc_T0;

-- Preparazione Dati per T1
WB_data_T1 <= mem_wb_reg_q.mem_data_T1_rmt when (mem_wb_reg_q.mem_to_reg_T1 = '1' and ft_mode = '1') else
mem_wb_reg_q.mem_data_T1_smt when (mem_wb_reg_q.mem_to_reg_T1 = '1' and ft_mode = '0')
else mem_wb_reg_q.mul_res_T1 when mem_wb_reg_q.is_mul_T1 = '1' else
mem_wb_reg_q.alu_result_T1;
FC_WB_data_T1_w  <= WB_data_T1;
FC_WB_rd_T1_w    <= mem_wb_reg_q.rd_T1;
FC_WB_rf_we_T1_w <= mem_wb_reg_q.reg_we_T1;
FC_WB_PC_T1_w    <= mem_wb_reg_q.pc_T1;

end Strutturale;