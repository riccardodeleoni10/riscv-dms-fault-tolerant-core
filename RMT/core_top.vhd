library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity Core_top is
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
    fault_detected  : out std_logic
);
end Core_top;

architecture Strutturale of Core_top is

--------------------------------------------------------------------------------
-- SEGNALI CORE-ROM & ROM-CORE
--------------------------------------------------------------------------------
signal pc_out_2_rom_T0_w : std_logic_vector(31 downto 0);
signal pc_out_2_rom_T1_w : std_logic_vector(31 downto 0);
signal instr_out_T0_w    : std_logic_vector(31 downto 0);
signal instr_out_T1_w    : std_logic_vector(31 downto 0);

--------------------------------------------------------------------------------
-- SEGNALI CORE-RAM & RAM-CORE (Solo per T0, unificati dal Checker)
--------------------------------------------------------------------------------
signal data_we_T0_w      : std_logic;
signal data_addr_T0_w    : std_logic_vector(31 downto 0);
signal data_rdata_T0_w   : std_logic_vector(31 downto 0);
signal data_wdata_T0_w   : std_logic_vector(31 downto 0);

begin

    -- =========================================================================
    -- ISTANZIAZIONE CORE RMT (Ex SMT)
    -- =========================================================================
    core_inst: entity work.Core_SMT(Strutturale) 
        port map (
            clk              => clk,
            reset            => reset,
            pc_obs_T0        => pc_obs_T0,
            instr_obs_T0     => instr_obs_T0,
            pc_obs_T1        => pc_obs_T1,
            instr_obs_T1     => instr_obs_T1,
            
            pc_out_T0        => pc_out_2_rom_T0_w,
            instr_in_T0      => instr_out_T0_w,
            pc_out_T1        => pc_out_2_rom_T1_w,
            instr_in_T1      => instr_out_T1_w,
            
            -- Interfaccia Unificata Sicura (Porta A)
            data_addr_T0     => data_addr_T0_w, 
            data_wdata_T0    => data_wdata_T0_w,
            data_we_T0       => data_we_T0_w,
            data_rdata_T0    => data_rdata_T0_w,
            
            -- Interfaccia T1 disabilitata (Il Core internamente la ignora/azzera)
            data_addr_T1     => open,
            data_wdata_T1    => open,
            data_we_T1       => open,
            data_rdata_T1    => (others => '0'),
            
            -- uscita fault checker
            fault_detected_out => fault_detected
        );

    -- =========================================================================
    -- ISTANZIAZIONE INSTRUCTION ROM
    -- =========================================================================
    rom_inst: entity work.DualPort_Instruction_ROM(Behavioral)
        generic map (
            MEM_DEPTH         => 1024,
            DUAL_PROGRAM_MODE => false, -- DISABILITATO! Entrambi i thread leggono T0
            INIT_FILE_T0      => "../prog.txt",
            INIT_FILE_T1      => "",    -- Non serve più
            START_INDEX_T1    => 0      -- Partono entrambi dallo stesso indirizzo (0x0)
        )
        port map (
            -- I due PC leggono istruzioni dalla stessa ROM
            addr_A => pc_out_2_rom_T0_w,
            dout_A => instr_out_T0_w,
            addr_B => pc_out_2_rom_T1_w,
            dout_B => instr_out_T1_w
        );

    -- =========================================================================
    -- ISTANZIAZIONE DATA RAM
    -- =========================================================================
    ram_inst: entity work.DualPort_Data_RAM(Behavioral)
        generic map (
            MEM_DEPTH         => 1024,
            INIT_FILE_ENABLED => true,
            INIT_FILE_DATA    => "../data_init.txt",
            START_INDEX_DATA  => 0  
        )
        port map (
            clk      => clk,
            
            -- Porta A (Collegata all'uscita sicura del Core)
            addr_A   => data_addr_T0_w,
            din_A    => data_wdata_T0_w,
            we_A     => data_we_T0_w,
            dout_A   => data_rdata_T0_w,
            
            -- Porta B (CHIUSA / DISABILITATA FISICAMENTE)
            addr_B   => (others => '0'),
            din_B    => (others => '0'),
            we_B     => '0',
            dout_B   => open
        );
        
end Strutturale;