library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;

entity DualPort_Data_RAM is
    generic (
        MEM_DEPTH          : integer := 1024;
        
        -- Configurazione Inizializzazione "Sicura"
        INIT_FILE_ENABLED  : boolean := false;              -- "false" ignora il file e inizializza a 0
        INIT_FILE_DATA     : string  := "";                 -- Di default vuoto (nessun file)
        START_INDEX_DATA   : integer := 0                   -- Indice da cui iniziare a caricare
    );
    port (
        clk      : in std_logic;
        
        -- Porta A (Thread 0)
        addr_A   : in  std_logic_vector(31 downto 0);
        din_A    : in  std_logic_vector(31 downto 0);
        we_A     : in  std_logic;
        dout_A   : out std_logic_vector(31 downto 0);
        
        -- Porta B (Thread 1)
        addr_B   : in  std_logic_vector(31 downto 0);
        din_B    : in  std_logic_vector(31 downto 0);
        we_B     : in  std_logic;
        dout_B   : out std_logic_vector(31 downto 0)
    );
end DualPort_Data_RAM;

architecture Behavioral of DualPort_Data_RAM is

    type ram_type is array (0 to MEM_DEPTH-1) of std_logic_vector(31 downto 0);
    
    -- =========================================================================
    -- Funzione per inizializzare la RAM (Resistente agli errori)
    -- =========================================================================
    impure function init_ram_from_file return ram_type is
        file text_file      : text;
        variable text_line  : line;
        variable open_status: file_open_status; -- Controlla se il file esiste davvero
        
        -- Inizializzazione sicura a 32-bit zeri
        variable ram_content: ram_type := (others => x"00000000");
        
        variable i          : integer := START_INDEX_DATA;
        variable temp_bv    : std_logic_vector(31 downto 0);
    begin
        -- Controlliamo che l'utente voglia usare il file e abbia messo un nome valido
        if INIT_FILE_ENABLED and INIT_FILE_DATA /= "" then
            
            -- Tentativo di apertura "sicuro"
            file_open(open_status, text_file, INIT_FILE_DATA, read_mode);
            
            -- Se il file esiste ed è stato aperto correttamente, lo leggiamo
            if open_status = open_ok then
                while not endfile(text_file) and i < MEM_DEPTH loop
                    readline(text_file, text_line);
                    
                    if text_line /= null then
                        if text_line'length > 0 then
                            hread(text_line, temp_bv);
                            ram_content(i) := temp_bv;
                            i := i + 1;
                        end if;
                    end if;
                end loop;
                file_close(text_file);
            else
                -- Opzionale: Vivado farà un warning (Report) dicendo che non ha trovato il file, 
                -- ma la compilazione NON fallirà. La RAM resterà a zero.
                report "File di inizializzazione RAM non trovato o vuoto. Inizializzazione a 0." severity warning;
            end if;
            
        end if;
        return ram_content;
    end function;

    signal ram_memory : ram_type := init_ram_from_file;

begin

    -- Processo di Scrittura (Sincrono al clock)
    process(clk)
    begin
        if rising_edge(clk) then
            -- Scrittura Porta A
            if we_A = '1' then
                if to_integer(unsigned(addr_A(31 downto 2))) < MEM_DEPTH then
                    ram_memory(to_integer(unsigned(addr_A(31 downto 2)))) <= din_A;
                end if;
            end if;
            -- Scrittura Porta B
            if we_B = '1' then
                if to_integer(unsigned(addr_B(31 downto 2))) < MEM_DEPTH then
                    ram_memory(to_integer(unsigned(addr_B(31 downto 2)))) <= din_B;
                end if;
            end if;
        end if;
    end process;

    -- Lettura puramente Combinatoria
    dout_A <= ram_memory(to_integer(unsigned(addr_A(31 downto 2)))) when (to_integer(unsigned(addr_A(31 downto 2))) < MEM_DEPTH) else (others => '0');
    dout_B <= ram_memory(to_integer(unsigned(addr_B(31 downto 2)))) when (to_integer(unsigned(addr_B(31 downto 2))) < MEM_DEPTH) else (others => '0');

end Behavioral;