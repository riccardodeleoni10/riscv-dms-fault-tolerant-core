library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;

entity DualPort_Instruction_ROM is
    generic (
        MEM_DEPTH         : integer := 1024;
        
        -- Configurazione Multi-Programma e Inizializzazione Sicura
        DUAL_PROGRAM_MODE : boolean := true;                -- "true" abilita il caricamento del secondo file
        INIT_FILE_T0      : string  := "";                  -- File per il Thread 0 (vuoto = ignora)
        INIT_FILE_T1      : string  := "";                  -- File per il Thread 1 (vuoto = ignora)
        START_INDEX_T1    : integer := 256                  -- Indice (in Word) da cui parte il programma 1
    );
    port (
        -- Porta A (Thread 0)
        addr_A : in  std_logic_vector(31 downto 0);
        dout_A : out std_logic_vector(31 downto 0);
        
        -- Porta B (Thread 1)
        addr_B : in  std_logic_vector(31 downto 0);
        dout_B : out std_logic_vector(31 downto 0)
    );
end DualPort_Instruction_ROM;

architecture Behavioral of DualPort_Instruction_ROM is

    type rom_type is array (0 to MEM_DEPTH-1) of std_logic_vector(31 downto 0);
    
    -- =========================================================================
    -- Funzione per caricare la ROM (Resistente agli errori)
    -- =========================================================================
    impure function init_rom_from_files return rom_type is
        file text_file      : text;
        variable text_line  : line;
        variable open_status: file_open_status; -- Controlla se il file esiste davvero
        
        -- Inizializzazione sicura a 32-bit zeri
        variable rom_content: rom_type := (others => x"00000000");
        variable i          : integer := 0;
        variable temp_bv    : std_logic_vector(31 downto 0);
    begin
        -- -------------------------------------------------------------
        -- 1. Caricamento del PRIMO file (Programma T0)
        -- -------------------------------------------------------------
        if INIT_FILE_T0 /= "" then
            file_open(open_status, text_file, INIT_FILE_T0, read_mode);
            
            if open_status = open_ok then
                while not endfile(text_file) and i < MEM_DEPTH loop
                    readline(text_file, text_line);
                    
                    if text_line /= null then
                        if text_line'length > 0 then
                            hread(text_line, temp_bv);
                            rom_content(i) := temp_bv;
                            i := i + 1;
                        end if;
                    end if;
                end loop;
                file_close(text_file);
            else
                report "File T0 non trovato o nome vuoto. ROM(T0) inizializzata a 0." severity warning;
            end if;
        end if;

        -- -------------------------------------------------------------
        -- 2. Caricamento del SECONDO file (Programma T1)
        -- -------------------------------------------------------------
        if DUAL_PROGRAM_MODE and INIT_FILE_T1 /= "" then
            i := START_INDEX_T1; -- Saltiamo all'indirizzo di partenza richiesto
            
            file_open(open_status, text_file, INIT_FILE_T1, read_mode);
            
            if open_status = open_ok then
                while not endfile(text_file) and i < MEM_DEPTH loop
                    readline(text_file, text_line);
                    
                    if text_line /= null then
                        if text_line'length > 0 then
                            hread(text_line, temp_bv);
                            rom_content(i) := temp_bv;
                            i := i + 1;
                        end if;
                    end if;
                end loop;
                file_close(text_file);
            else
                report "File T1 non trovato o nome vuoto. ROM(T1) inizializzata a 0." severity warning;
            end if;
        end if;
        
        return rom_content;
    end function;

    -- =========================================================================
    -- Inizializzazione della ROM al momento della sintesi/simulazione
    -- =========================================================================
    signal rom_memory : rom_type := init_rom_from_files;

begin

    -- Lettura puramente Combinatoria (Asincrona)
    dout_A <= rom_memory(to_integer(unsigned(addr_A(31 downto 2)))) when (to_integer(unsigned(addr_A(31 downto 2))) < MEM_DEPTH) else (others => '0');
    dout_B <= rom_memory(to_integer(unsigned(addr_B(31 downto 2)))) when (to_integer(unsigned(addr_B(31 downto 2))) < MEM_DEPTH) else (others => '0');

end Behavioral;