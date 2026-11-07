library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity Register_File is

port (      clk         : in std_logic;
            we          : in std_logic;
            read_addr1  : in std_logic_vector(4 downto 0);
            read_addr2  : in std_logic_vector(4 downto 0);
            write_addr  : in std_logic_vector(4 downto 0);
            write_data  : in std_logic_vector(31 downto 0);
            read_data1  : out std_logic_vector(31 downto 0);
            read_data2  : out std_logic_vector(31 downto 0)
        );
end Register_File;

architecture Behavioral of register_file is
type reg_file_t is array (0 to 31) of std_logic_vector(31 downto 0);
signal reg_file: reg_file_t :=(others => (others => '0'));
begin
--------------------------------------------------------------------------------
-- Processo di scrittura sincrono
--------------------------------------------------------------------------------
write_process: process(clk)
begin
    if rising_edge(clk) then 
        if we = '1' then
            if write_addr /= "00000" then       -- protezione dallo scrivere in R0
                reg_file(to_integer(unsigned(write_addr))) <= write_data;
            end if;
        end if;
    end if;
end process;
--------------------------------------------------------------------------------
-- Processo di lettura asincrono
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Processo di lettura asincrono
--------------------------------------------------------------------------------
read_data1 <= (others => '0') when read_addr1 = "00000" else reg_file(to_integer(unsigned(read_addr1)));

read_data2 <= (others => '0') when read_addr2 = "00000" else reg_file(to_integer(unsigned(read_addr2)));
end Behavioral;