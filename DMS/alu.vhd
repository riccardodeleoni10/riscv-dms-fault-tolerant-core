library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU_Unit is
    Port (
        op1         : in  std_logic_vector(31 downto 0);
        op2         : in  std_logic_vector(31 downto 0);
        alu_ctrl    : in  std_logic_vector(3 downto 0);
        alu_result  : out std_logic_vector(31 downto 0);
        zero_flag   : out std_logic
    );
end ALU_Unit;

architecture Combinatoria of ALU_Unit is
begin

    process(all)
        -- Variabile a 64-bit per contenere il risultato della moltiplicazione (32x32=64)
        variable mul_temp : signed(63 downto 0);
        variable res_temp : std_logic_vector(31 downto 0);
    begin
        -- Inizializzazione di default
        res_temp := (others => '0');
        mul_temp := (others => '0');

        case alu_ctrl is 
        
            when "0000" => 
                res_temp := op1 and op2;
                
            when "0001" => 
                res_temp := op1 or op2;
                
            when "0010" => 
                res_temp := std_logic_vector(signed(op1) + signed(op2));
                
            when "0110" => 
                res_temp := std_logic_vector(signed(op1) - signed(op2));
            
            -- =======================================================
            -- ESTENSIONE M (Moltiplicazioni per Filtro FIR / DSP)
            -- =======================================================
            --when "1000" => -- MUL (Prende i 32 bit bassi del risultato)
           --     mul_temp := signed(op1) * signed(op2);
           --     res_temp := std_logic_vector(mul_temp(31 downto 0));
                
           -- when "1001" => -- MULH (Prende i 32 bit alti del risultato)
           --     mul_temp := signed(op1) * signed(op2);
           --     res_temp := std_logic_vector(mul_temp(63 downto 32));
            when "1100" => --SRA
                res_temp := std_logic_vector(shift_right(signed(op1), to_integer(unsigned(op2(4 downto 0)))));
            when "1101" => --SRL
                res_temp := std_logic_vector(shift_right(unsigned(op1), to_integer(unsigned(op2(4 downto 0)))));
            when "1110" => -- SLL
                res_temp := std_logic_vector(shift_left(unsigned(op1),to_integer(signed(op2(4 downto 0))))); 
            when others => 
                res_temp := (others => '0');
        end case;

        -- Assegnazione all'uscita
        alu_result <= res_temp;

        
        if res_temp = x"00000000" then
            zero_flag <= '1';
        else
            zero_flag <= '0';
        end if;

    end process;

end Combinatoria;