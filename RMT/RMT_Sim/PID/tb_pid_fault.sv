`timescale 1ns / 1ps

module tb_pid_fault();

    // Segnali di test
    logic clk;
    logic reset;
    logic [31:0] pc_obs_T0, instr_obs_T0;
    logic [31:0] pc_obs_T1, instr_obs_T1;
    
    // Segnale per eliminare i warning vsim-8822
    logic fault_detected_sig; 

    // Variabili di conteggio
    int cycle_count = 0;
    
    // Tempi e frequenze (200 MHz)
    localparam real CLK_PERIOD_NS = 5.0; 
    localparam real HALF_CLK_PERIOD_NS = 2.5;

    // Istanziazione del Top Level (DUT)
    Core_top dut (
        .clk(clk),
        .reset(reset),
        .pc_obs_T0(pc_obs_T0),
        .instr_obs_T0(instr_obs_T0),
        .pc_obs_T1(pc_obs_T1),
        .instr_obs_T1(instr_obs_T1),
        .fault_detected(fault_detected_sig)
    ); 
    // =========================================================================
    // FAULT INJECTION UNIT (FIU) - TEST SUL DATO IN WRITEBACK (WB_data)
    // =========================================================================
    logic        fiu_active;
    logic [31:0] fiu_faulty_data;    // 
    int          fiu_internal_cycle;

    
    fault_injection_unit #(
        .WIDTH(32),         // Larghezza a 32 bit
        .START_CYCLE(390),   // SCELTA DELL'UTENTE: Metti il numero di un ciclo in cui avviene una scrittura
        .END_CYCLE(390)      // Dura 1 clock
    ) fiu (
        .clk(clk),
        .reset(reset),
        .fault_mask(32'h00000001),  // 
        
        // PRELIEVO: Leggiamo il dato originario appena calcolato in WB
        .orig_signal(dut.core_inst.ex_mem_reg_q.alu_result_T0),
        
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
                        
            // Il comando force intercetta il cavo d'ingresso al Checker dello stadio WB
            force dut.core_inst.FC_MEM_alu_res_T0_w = fiu_faulty_data;
            
        end else begin
            if (cycle_count > 0) begin 
                $display("[FIU] 🛡️ GUASTO RIMOSSO AL CICLO %0d. Cavo rilasciato.", cycle_count);
            end
            
            // Il comando release restituisce il controllo del cavo all'RTL
            release dut.core_inst.FC_MEM_alu_res_T0_w  ;
        end
    end

    // Generazione Clock
    initial begin
        clk = 0;
        forever #(HALF_CLK_PERIOD_NS) clk = ~clk;
    end

    // Contatore cicli sincrono
    always @(posedge clk) begin
        if (!reset) cycle_count++;
    end

    // =========================================================================
    // HIL: MODELLO FISICO DEL MOTORE DC E LOGGING DEI DATI (Sincronizzato su NEGEDGE)
    // =========================================================================
    int physical_speed_internal = 0; // Accumulatore ad alta precisione
    int physical_speed = 0;          // Velocità finale letta dal Sensore
    int motor_command = 0;
    int fd_pid; 
    
    initial begin
        fd_pid = $fopen("pid_dump.txt", "w");
        if (fd_pid == 0) $display("❌ ERRORE: Impossibile creare pid_dump.txt");
        else $display("✅ File pid_dump.txt creato per il log del Motore.");

        forever begin
           
            @(negedge clk); 
            
            // 1. INTERCETTAZIONE COMANDO SCRITTURA (Indirizzo 8196)
            // Essendo su negedge, data_we e data_addr sono perfettamente stabili
            if (dut.data_we_T0_w == 1'b1 && dut.data_addr_T0_w == 32'd8196) begin
                motor_command = $signed(dut.data_wdata_T0_w);
                
                // Saturazione: Limite fisico dell'amplificatore PWM
                if (motor_command > 32000) motor_command = 32000;
                if (motor_command < -32000) motor_command = -32000;
                
                // Avanzamento della fisica del motore (Inerzia = 1024)
                physical_speed_internal = physical_speed_internal - (physical_speed_internal / 1024) + motor_command;
                physical_speed = physical_speed_internal / 1024;
                
                // Scrittura immediata sul file di log
                if (fd_pid != 0) $fdisplay(fd_pid, "%0t %d %d", $time, motor_command, physical_speed);
            end

            // 2. INIEZIONE VALORE SUL SENSORE (Indirizzo 8192) VIA FORCE/RELEASE
            // Agendo su negedge, copriamo in sicurezza la finestra di lettura del posedge successivo
            if (dut.data_addr_T0_w == 32'd8192) begin
                force dut.data_rdata_T0_w = physical_speed;
            end 
            else begin
                release dut.data_rdata_T0_w;
            end
        end
    end

    // =========================================================================
    // CONTROLLO DELLA SIMULAZIONE
    // =========================================================================
    initial begin
        $display("==================================================");
        $display(" INIZIO SIMULAZIONE CORE SMT (PID HIL)");
        $display(" Target Freq: 200 MHz");
        $display("==================================================");
        
        reset = 1;
        #25;  
        
        reset = 0; 
        $display("--> Reset rilasciato. Inizio simulazione...");
        
        // Aspettiamo il completamento della finestra di simulazione (15.000 cicli)
        wait(cycle_count == 20000);
        
        $display("\n[FINE] - Raggiunti i cicli impostati. Arresto simulazione.");
        if (fd_pid != 0) $fclose(fd_pid);
        
        $display("==================================================");
        $display(" SIMULAZIONE COMPLETATA CON SUCCESSO");
        $display(" Lancia 'python3 pid_analyzer.py' per vedere i grafici!");
        $display("==================================================");
        
        $finish;
    end

endmodule