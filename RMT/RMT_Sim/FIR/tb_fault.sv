`timescale 1ns / 1ps

module tb_core_top();

    // Segnali di test
    logic clk;
    logic reset;
    logic [31:0] pc_obs_T0, instr_obs_T0;
    logic [31:0] pc_obs_T1, instr_obs_T1;

    // Variabili di conteggio
    int cycle_count = 0;
    
    // Tempi e frequenze (200 MHz)
    localparam real CLK_PERIOD_NS = 5.0; 
    localparam real HALF_CLK_PERIOD_NS = 2.5;

    // Istanziazione del Top Level
    Core_top dut (
        .clk(clk),
        .reset(reset),
        .pc_obs_T0(pc_obs_T0),
        .instr_obs_T0(instr_obs_T0),
        .pc_obs_T1(pc_obs_T1),
        .instr_obs_T1(instr_obs_T1)
    ); 

    // =========================================================================
    // FAULT INJECTION UNIT (FIU) - TEST SUL DATO IN WRITEBACK (WB_data)
    // =========================================================================
    logic        fiu_active;
    logic [31:0] fiu_faulty_data;    // 
    int          fiu_internal_cycle;

   
    fault_injection_unit #(
        .WIDTH(32),         // Larghezza a 32 bit
        .START_CYCLE(123),   // SCELTA DELL'UTENTE: Metti il numero di un ciclo in cui avviene una scrittura
        .END_CYCLE(123)      // Dura 1 clock
    ) fiu (
        .clk(clk),
        .reset(reset),
        .fault_mask(32'h00000001),  // 
        
        
        .orig_signal(dut.core_inst.pc_src_T1),
        
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
                        
           
            force dut.core_inst.FC_EXE_pc_src_T1_w   = fiu_faulty_data;
            
        end else begin
            if (cycle_count > 0) begin 
                $display("[FIU] 🛡️ GUASTO RIMOSSO AL CICLO %0d. Cavo rilasciato.", cycle_count);
            end
            
            // Il comando release restituisce il controllo del cavo all'RTL
            release dut.core_inst.FC_EXE_pc_src_T1_w  ;
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
                wait(cycle_count == 6000);
                $display("\n[TIMEOUT] - Terminazione forzata dopo 100 cicli.");
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

        $display("==================================================");
        $display(" RISULTATI FINALI SMT");
        $display("==================================================");
        
        // Verifica dei registri flag
        $display("Thread 0 Flag (x31) : %0d", dut.core_inst.RF_T0_inst.reg_file[31]);
        $display("Thread 1 Flag (x31) : %0d", dut.core_inst.RF_T1_inst.reg_file[31]);
        
        // Verifica delle memorie
        $display("RAM[0] (Dato di T0) : %0d (Hex: %h)", $signed(dut.ram_inst.ram_memory[0]), dut.ram_inst.ram_memory[0]); 
        $display("RAM[2] (Dato di T1) : %0d (Hex: %h)", $signed(dut.ram_inst.ram_memory[2]), dut.ram_inst.ram_memory[2]);
        
        $display("--------------------------------------------------");
        $display(" Cicli eseguiti    : %0d", cycle_count);
        $display("==================================================");
        
        $stop;
    end

endmodule