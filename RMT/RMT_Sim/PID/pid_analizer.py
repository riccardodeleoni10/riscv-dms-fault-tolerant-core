import matplotlib.pyplot as plt
import os
import sys

def main():
    filename = 'pid_dump.txt'

    time_vals = []
    cmd_vals = []
    speed_vals = []
    setpoint_vals = []
    error_vals = []  # Array per l'Errore del PID

    SETPOINT = 1000  # Il gradino richiesto nel programma Assembly

    print("="*60)
    print(" ⚙️ ANALISI CONTROLLORE PID (Con Iniezione Guasto)")
    print("="*60)

    # 1. CONTROLLO ESISTENZA FILE
    if not os.path.isfile(filename):
        print(f"[ERRORE] File '{filename}' non trovato.")
        print("Fai girare la simulazione in QuestaSim prima di lanciare lo script!")
        sys.exit(1)
        
    # 2. LETTURA SICURA DEI DATI (Mostra eventuali errori di parsing)
    print(f"[*] Lettura dei dati da {filename}...")
    try:
        with open(filename, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) == 3:
                    # Estrazione: time_ns, command, physical_speed
                    t = float(parts[0])
                    cmd = float(parts[1])
                    speed = float(parts[2])
                    
                    # Calcolo matematico dell'errore (e(t) = Setpoint - Process Variable)
                    pid_error = SETPOINT - speed
                    
                    time_vals.append(t)
                    cmd_vals.append(cmd)
                    speed_vals.append(speed)
                    setpoint_vals.append(SETPOINT)
                    error_vals.append(pid_error)
                    
        if not time_vals:
            print(f"[AVVISO] Il file '{filename}' è stato letto, ma sembra vuoto o mal formattato.")
            sys.exit(1)
            
    except Exception as e:
        print(f"\n[ERRORE DI LETTURA] Impossibile parsare il file. Dettaglio tecnico:")
        print(f"-> {e}")
        sys.exit(1)

    print(f"[OK] Letti {len(time_vals)} campioni. Generazione Dashboard in corso...")

    # 3. CREAZIONE DELLA DASHBOARD A 3 SUBPLOT
    plt.style.use('bmh') # Stile elegante come nel FIR
    fig, axs = plt.subplots(3, 1, figsize=(12, 10), sharex=True)
    fig.canvas.manager.set_window_title("Risposta a Gradino PID - Analisi Guasti")

    # Grafico 1: Velocità (La risposta del sistema)
    axs[0].plot(time_vals, setpoint_vals, 'k--', linewidth=2, label='Target (Setpoint = 1000)')
    axs[0].plot(time_vals, speed_vals, 'b-', linewidth=2.5, label='Velocità Motore (Sensore)')
    axs[0].set_title('RISC-V PID Controller: Risposta a Gradino', fontsize=14, fontweight='bold')
    axs[0].set_ylabel('Velocità')
    axs[0].legend(loc='lower right')
    axs[0].grid(True, linestyle='--', alpha=0.7)
    
    # Grafico 2: Comando (Lo sforzo di controllo)
    axs[1].plot(time_vals, cmd_vals, 'r-', linewidth=1.5, label='Sforzo di Controllo (Voltaggio PID)')
    axs[1].set_title('Azione di Controllo del Processore', fontsize=12, fontweight='bold')
    axs[1].set_ylabel('Comando PWM')
    axs[1].legend(loc='upper right')
    axs[1].grid(True, linestyle='--', alpha=0.7)
    
    # Grafico 3: L'Errore del PID (e(t))
    axs[2].plot(time_vals, error_vals, 'm-', linewidth=2, label='Errore di Inseguimento (e(t))')
    axs[2].axhline(0, color='black', linestyle=':', label='Zero Error Line')
    axs[2].set_title('Dinamica dell\'Errore', fontsize=12, fontweight='bold')
    axs[2].set_xlabel('Tempo di Simulazione (ns)')
    axs[2].set_ylabel('Errore (RPM)')
    axs[2].legend(loc='upper right')
    axs[2].grid(True, linestyle='--', alpha=0.7)
    
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()