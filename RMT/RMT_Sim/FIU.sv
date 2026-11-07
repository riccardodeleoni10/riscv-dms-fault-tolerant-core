`timescale 1ns / 1ps

// ==============================================================================
// FAULT INJECTION UNIT (FIU)
// Generatore di SEU (Single Event Upset) e transienti hardware.
// ==============================================================================

module fault_injection_unit #(
    parameter int WIDTH = 32,
    parameter int START_CYCLE = 50,  // Ciclo in cui inizia il guasto
    parameter int END_CYCLE = 50     // Ciclo in cui finisce (START=END -> 1 colpo di clock)
)(
    input  logic             clk,
    input  logic             reset,
    
    // Configurazione Maschera di Errore
    input  logic [WIDTH-1:0] fault_mask, 
    
    // Interfaccia Datapath
    input  logic [WIDTH-1:0] orig_signal,   // Segnale SANO letto dall'hardware
    output logic [WIDTH-1:0] faulty_signal, // Segnale INFETTO generato
    
    // Flag di stato per il Testbench
    output logic             inject_active,
    
    // Uscita per monitorare il ciclo corrente della FIU
    output int               fiu_cycle_count
);

    int cycle_count = 0;
    
    
    assign fiu_cycle_count = cycle_count;

    // Contatore cicli sincronizzato col processore
    always @(posedge clk) begin
        if (reset) begin
            cycle_count <= 0;
            inject_active <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            
            // Finestra temporale di attivazione del guasto
            if (cycle_count >= START_CYCLE && cycle_count <= END_CYCLE) begin
                inject_active <= 1;
            end else begin
                inject_active <= 0;
            end
        end
    end

    // Logica di corruzione: Applica lo XOR solo quando il guasto è attivo
    assign faulty_signal = inject_active ? (orig_signal ^ fault_mask) : orig_signal;

endmodule