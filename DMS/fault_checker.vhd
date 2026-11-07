library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fault_checker is
    Port (
        ft_mode           : in std_logic;        -- decide se il Core lavora in RMT o SMT
        -- check sulle branch (Stadio EXE)
        EXE_pc_branch_T0  : in std_logic_vector(31 downto 0);
        EXE_pc_src_T0     : in std_logic;
        EXE_pc_branch_T1  : in std_logic_vector(31 downto 0);
        EXE_pc_src_T1     : in std_logic;
        EXE_PC_T0         : in std_logic_vector(31 downto 0);
        EXE_PC_T1         : in std_logic_vector(31 downto 0);

        -- check in mem per le store (e Early Detection ALU)
        MEM_alu_res_T0    : in std_logic_vector(31 downto 0);
        MEM_alu_res_T1    : in std_logic_vector(31 downto 0);
        MEM_read_data2_T0 : in std_logic_vector(31 downto 0);
        MEM_read_data2_T1 : in std_logic_vector(31 downto 0);
        MEM_data_we_T0    : in std_logic;
        MEM_data_we_T1    : in std_logic;
        MEM_PC_T0         : in std_logic_vector(31 downto 0);
        MEM_PC_T1         : in std_logic_vector(31 downto 0);

        -- check per le scritture in register file
        WB_data_T0        : in std_logic_vector(31 downto 0);
        WB_data_T1        : in std_logic_vector(31 downto 0);
        WB_rd_T0          : in std_logic_vector(4 downto 0);
        WB_rd_T1          : in std_logic_vector(4 downto 0);
        WB_rf_we_T0       : in std_logic;
        WB_rf_we_T1       : in std_logic;
        WB_PC_T0          : in std_logic_vector(31 downto 0);
        WB_PC_T1          : in std_logic_vector(31 downto 0);

        -- uscite filtrate
        FC_EXE_pc_branch_T0: out std_logic_vector(31 downto 0);
        FC_pc_src_T0       : out std_logic;
        FC_EXE_pc_branch_T1: out std_logic_vector(31 downto 0);
        FC_pc_src_T1       : out std_logic;

        FC_MEM_data_we     : out std_logic;
        FC_MEM_data_wdata  : out std_logic_vector(31 downto 0);
        FC_MEM_data_waddr  : out std_logic_vector(31 downto 0);

        FC_WB_data_T0      : out std_logic_vector(31 downto 0);
        FC_WB_data_T1      : out std_logic_vector(31 downto 0);
        FC_WB_rd_T0        : out std_logic_vector(4 downto 0);
        FC_WB_rd_T1        : out std_logic_vector(4 downto 0);
        FC_WB_rf_we_T0     : out std_logic;
        FC_WB_rf_we_T1     : out std_logic;
        
        -- allarmi e PC
        fault_detected     : out std_logic;
        fault_on_EXE       : out std_logic;
        fault_on_MEM       : out std_logic;
        fault_on_WB        : out std_logic;
        fault_on_PC        : out std_logic;
        FC_PC_RB           : out std_logic_vector(31 downto 0)
    );
end fault_checker;

architecture Combinatoria of fault_checker is
begin

exe_branch_check_proc: process(all)
begin
      if (ft_mode = '1') then 
        if (EXE_pc_src_T0 /= EXE_pc_src_T1) then 
            fault_on_EXE <= '1';
            FC_EXE_pc_branch_T0  <=  (others  => '0');
            FC_EXE_pc_branch_T1  <=  (others  => '0');
            FC_pc_src_T0         <= '0';
            FC_pc_src_T1         <= '0';
            
        elsif (EXE_pc_src_T0 = '1') then
            if (EXE_pc_branch_T0 /= EXE_pc_branch_T1) then
                fault_on_EXE <= '1';
                FC_EXE_pc_branch_T0  <=  (others  => '0');
                FC_EXE_pc_branch_T1  <=  (others  => '0');
                FC_pc_src_T0         <= '0';
                FC_pc_src_T1         <= '0';
            else
                fault_on_EXE <= '0';
                FC_EXE_pc_branch_T0  <= EXE_pc_branch_T0;
                FC_EXE_pc_branch_T1  <= EXE_pc_branch_T1;
                FC_pc_src_T0         <= '1';
                FC_pc_src_T1         <= '1';
            end if;
            
        else
            fault_on_EXE <= '0';
            FC_EXE_pc_branch_T0  <= EXE_pc_branch_T0;
            FC_EXE_pc_branch_T1  <= EXE_pc_branch_T1;
            FC_pc_src_T0         <= '0';
            FC_pc_src_T1         <= '0';
        end if;
    else
        -- se sono in SMT le uscite propagano
            fault_on_EXE <= '0';
            FC_EXE_pc_branch_T0  <= EXE_pc_branch_T0;
            FC_EXE_pc_branch_T1  <= EXE_pc_branch_T1;
            FC_pc_src_T0         <= EXE_pc_src_T0;
            FC_pc_src_T1         <= EXE_pc_src_T1;
    end if; 
end process;

mem_check_proc: process(all)
begin
    if ft_mode = '1' then 
        if (MEM_data_we_T0 /= MEM_data_we_T1) or 
           (MEM_alu_res_T0 /= MEM_alu_res_T1) or 
           (MEM_read_data2_T0 /= MEM_read_data2_T1) then
            
            fault_on_MEM <= '1';
            FC_MEM_data_we <= '0';  
            FC_MEM_data_wdata <= (others => '0');
            FC_MEM_data_waddr <= (others => '0');
            
        elsif (MEM_data_we_T0 = '1') then
            -- Nessun errore rilevato e l'istruzione vuole scrivere in RAM
            fault_on_MEM <= '0';
            FC_MEM_data_we <= '1';  
            FC_MEM_data_wdata <= MEM_read_data2_T0;
            FC_MEM_data_waddr <= MEM_alu_res_T0;
            
        else 
            -- Nessun errore rilevato, ma NON è una Store
            fault_on_MEM <= '0';
            FC_MEM_data_we <= '0';  
            FC_MEM_data_wdata <= MEM_read_data2_T0;
            FC_MEM_data_waddr <= MEM_alu_res_T0;
        end if;
    else 
            fault_on_MEM      <= '0';
            FC_MEM_data_we    <= MEM_data_we_T0;  
            FC_MEM_data_wdata <= MEM_read_data2_T0;
            FC_MEM_data_waddr <= MEM_alu_res_T0;
    end if;
end process;

wb_check_proc: process(all)
begin
    if ft_mode = '1' then 
        if (WB_rf_we_T0 /= WB_rf_we_T1) then
            fault_on_WB <= '1';
            FC_WB_data_T0 <= (others => '0');
            FC_WB_data_T1 <= (others => '0');
            FC_WB_rd_T0 <= (others => '0');
            FC_WB_rd_T1 <= (others => '0');
            FC_WB_rf_we_T0 <= '0';
            FC_WB_rf_we_T1 <= '0';
        elsif (WB_rf_we_T0 = '1') then
            if (WB_rd_T0 /= WB_rd_T1) then
                fault_on_WB <= '1';
                FC_WB_data_T0 <= (others => '0');
                FC_WB_data_T1 <= (others => '0');
                FC_WB_rd_T0 <= (others => '0');
                FC_WB_rd_T1 <= (others => '0');
                FC_WB_rf_we_T0 <= '0';
                FC_WB_rf_we_T1 <= '0';
            
            elsif (WB_data_T0 = WB_data_T1) then 
                FC_WB_data_T0 <= WB_data_T0;
                FC_WB_data_T1 <= WB_data_T1;
                FC_WB_rd_T0 <= WB_rd_T0;
                FC_WB_rd_T1 <= WB_rd_T1;
                FC_WB_rf_we_T0 <= '1';
                FC_WB_rf_we_T1 <= '1';
                fault_on_WB <= '0';
            else 
                FC_WB_data_T0 <= (others => '0');
                FC_WB_data_T1 <= (others => '0');
                FC_WB_rd_T0 <= (others => '0');
                FC_WB_rd_T1 <= (others => '0');
                FC_WB_rf_we_T0 <= '0';
                FC_WB_rf_we_T1 <= '0';
                fault_on_WB <= '1';
            end if; 
        else 
            FC_WB_data_T0 <= (others => '0');
            FC_WB_data_T1 <= (others => '0');
            FC_WB_rd_T0 <= (others => '0');
            FC_WB_rd_T1 <= (others => '0');
            FC_WB_rf_we_T0 <= '0';
            FC_WB_rf_we_T1 <= '0';
            fault_on_WB <= '0'; 
        end if;
    else
          FC_WB_data_T0 <= WB_data_T0;
            FC_WB_data_T1 <= WB_data_T1;
            FC_WB_rd_T0 <= WB_rd_T0;
            FC_WB_rd_T1 <= WB_rd_T1;
            FC_WB_rf_we_T0 <= WB_rf_we_T0;
            FC_WB_rf_we_T1 <= WB_rf_we_T1;
            fault_on_WB <= '0'; 
    end if;
end process;

pc_check_proc: process(all)
begin
    if (ft_mode = '1') then 
        if (MEM_PC_T0 /= MEM_PC_T1) or (WB_PC_T0 /= WB_PC_T1) or (EXE_PC_T0 /= EXE_PC_T1)then 
            fault_on_PC <= '1';
        else 
            fault_on_PC <= '0';
        end if;
    else 
        fault_on_PC  <=  '0';
    end if;
end process;

pc_rollback_proc: process(all)
begin
    if (fault_on_PC = '1') then
        -- Mismatch grave del control flow: si va verso un Hard Reset.
        -- Mandiamo il PC alla base per sicurezza.
        FC_PC_RB <= (others => '0');
    elsif (fault_on_WB = '1') then
        FC_PC_RB <= WB_PC_T0;
    elsif (fault_on_MEM = '1') then
        FC_PC_RB <= MEM_PC_T0;
    elsif (fault_on_EXE = '1') then
        FC_PC_RB <= EXE_PC_T0;
    else 
        FC_PC_RB <= WB_PC_T0;  
    end if;
end process;

fault_detected <= fault_on_WB or fault_on_MEM or fault_on_EXE or fault_on_PC;

end Combinatoria;