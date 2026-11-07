`timescale 1ns / 1ps

module tb_core_top();

    // Segnali di test
    logic clk;
    logic reset;
    logic [31:0] pc_obs_T0, instr_obs_T0;
    logic [31:0] pc_obs_T1, instr_obs_T1;
    logic ft_mode;
    
    // Variabili di conteggio
    int cycle_count = 0;
    
    // Tempi e frequenze (200 MHz)
    localparam real CLK_PERIOD_NS = 5.0; 
    localparam real HALF_CLK_PERIOD_NS = 2.5;

    // Istanziazione del Top Level
    Core_top dut (
        .ft_mode(ft_mode),
        .clk(clk),
        .reset(reset),
        .pc_obs_T0(pc_obs_T0),
        .instr_obs_T0(instr_obs_T0),
        .pc_obs_T1(pc_obs_T1),
        .instr_obs_T1(instr_obs_T1)
    ); 

    // =========================================================================
    // DATA LOGGER: INTERCETTAZIONE SCRITTURE IN RAM E SEGNALI DI CONTROLLO
    // =========================================================================
    int fd_t0, fd_t1, fd_ft;

    initial begin
        // Apre i file in scrittura
        fd_t0 = $fopen("fir_out_t0.txt", "w");
        fd_t1 = $fopen("fir_out_t1.txt", "w");
        fd_ft = $fopen("ft_mode_log.txt", "w");
        
        if (fd_t0 == 0 || fd_t1 == 0 || fd_ft == 0) $display("ERRORE: Impossibile creare i file di log.");
        else $display("✅ File di log pronti: T0, T1 e FT_MODE.");
        
        // Logga lo stato iniziale del segnale ft_mode al tempo 0
        #1;
        if (fd_ft != 0) $fdisplay(fd_ft, "%0t %0d", $time, ft_mode);
    end

    // Processo di Sniffing: Guarda i cavi RAM a ogni colpo di clock
    always @(posedge clk) begin
        if (!reset) begin
            // 1. Sniffing Thread 0 (Passa-Basso) -> Scrive da 1200 in poi
            if (dut.core_inst.data_we_T0 == 1'b1) begin
                if (dut.core_inst.data_addr_T0 >= 32'd1200 && dut.core_inst.data_addr_T0 < 32'd1600) begin
                    if (fd_t0 != 0) $fdisplay(fd_t0, "%0t %0d", $time, $signed(dut.core_inst.data_wdata_T0));
                end
            end
            
            // 2. Sniffing Thread 1 (Passa-Alto) -> Scrive da 1600 in poi
            if (dut.core_inst.data_we_T1 == 1'b1) begin
                if (dut.core_inst.data_addr_T1 >= 32'd1600 && dut.core_inst.data_addr_T1 < 32'd2000) begin
                    if (fd_t1 != 0) $fdisplay(fd_t1, "%0t %0d", $time, $signed(dut.core_inst.data_wdata_T1));
                end
            end
        end
    end

    // Processo di Sniffing: Logga le variazioni dell'interruttore ft_mode
    always @(ft_mode) begin
        if (fd_ft != 0) $fdisplay(fd_ft, "%0t %0d", $time, ft_mode);
    end

    // =========================================================================
    // FAULT INJECTION UNIT (FIU) - TEST SUL DATO IN WRITEBACK (WB_data)
    // =========================================================================
    logic        fiu_active;
    logic [31:0] fiu_faulty_data;    
    int          fiu_internal_cycle;

    fault_injection_unit #(
        .WIDTH(32),         
        .START_CYCLE(1113),   
        .END_CYCLE(1113)      
    ) fiu(
        .clk(clk),
        .reset(reset),
        .fault_mask(32'h00005000),  
        .orig_signal(dut.core_inst.WB_data_T1),
        .faulty_signal(fiu_faulty_data),
        .inject_active(fiu_active),
        .fiu_cycle_count(fiu_internal_cycle)
    );

    // =========================================================================
    // LOGICA DI FORZATURA E RILASCIO (SystemVerilog 'force')
    // =========================================================================
    always @(fiu_active) begin
        if (fiu_active) begin
            $display("\n[FIU] ⚡ INIEZIONE GUASTO SU 'WB_data' (DATO CORROTTO) IN WB AL CICLO %0d! ⚡", cycle_count);
            force dut.core_inst.FC_WB_data_T1_w  = fiu_faulty_data;
        end else begin
            if (cycle_count > 0) begin 
                $display("[FIU] 🛡️ GUASTO RIMOSSO AL CICLO %0d. Cavo rilasciato.", cycle_count);
            end
            release dut.core_inst.FC_WB_data_T1_w  ;
        end
    end

    // Generazione Clock
    initial begin
        clk = 0;
        forever #(HALF_CLK_PERIOD_NS) clk = ~clk;
    end

    // Contatore cicli
    always @(posedge clk) begin
        if (!reset) cycle_count++;
    end

    // Monitor a terminale
    initial begin
        $monitor("T: %0t | Cyc: %0d | T0_PC: %0d Instr: 0x%08h | T1_PC: %0d Instr: 0x%08h", 
                 $time, cycle_count, pc_obs_T0, instr_obs_T0, pc_obs_T1, instr_obs_T1);
    end
    
    // segnale di ft_mode
    initial begin
        ft_mode = 0;    
        #(CLK_PERIOD_NS*1100);
        ft_mode = 1;
        #(CLK_PERIOD_NS*1100);
        ft_mode = 0;  
    end
    
    // Blocco Main
    initial begin
        $display("==================================================");
        $display(" INIZIO SIMULAZIONE CORE SMT (PIPELINED)");
        $display(" Target Freq: 200 MHz");
        $display("==================================================");
        
        reset = 1;
        #25;  
        
        reset = 0; 
        $display("--> Reset rilasciato. Inizio esecuzione dei 2 Thread...");
        
        fork
            begin
                wait(cycle_count == 8000);
                $display("\n[TIMEOUT] - Terminazione forzata dopo 8000 cicli.");
            end
            
            begin
                wait(dut.core_inst.RF_T0_inst.reg_file[31] != 32'd0 && 
                     dut.core_inst.RF_T1_inst.reg_file[31] != 32'd0);
                
                @(posedge clk);
                @(posedge clk);
                
                $display("\n[SUCCESSO] - Scrittura nel registro x31 rilevata per ENTRAMBI i Thread al ciclo %0d!", cycle_count);
            end
        join_any
        
        disable fork; 

        // Logga lo stato finale di ft_mode per chiudere correttamente il grafico in MATLAB
        if (fd_ft != 0) $fdisplay(fd_ft, "%0t %0d", $time, ft_mode);

        $display("==================================================");
        $display(" RISULTATI FINALI SMT");
        $display("==================================================");
        $display("Thread 0 Flag (x31) : %0d", dut.core_inst.RF_T0_inst.reg_file[31]);
        $display("Thread 1 Flag (x31) : %0d", dut.core_inst.RF_T1_inst.reg_file[31]);
        
        if (fd_t0 != 0) $fclose(fd_t0);
        if (fd_t1 != 0) $fclose(fd_t1);
        if (fd_ft != 0) $fclose(fd_ft);
        
        $finish;
    end

endmodule