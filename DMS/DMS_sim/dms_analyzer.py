import os
import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.interpolate import make_interp_spline

def load_data(filename, scale_factor=1.0):
    """Legge il file in modo sicuro ed evita crash su file vuoti."""
    if not os.path.isfile(filename) or os.path.getsize(filename) == 0:
        return None, None
    data = np.loadtxt(filename)
    if data.size == 0:
        return None, None
    
    # Se c'è solo una riga, numpy la legge come array 1D. La forziamo a 2D.
    if data.ndim == 1:
        data = np.array([data])
        
    t = data[:, 0]
    y = data[:, 1] / scale_factor
    return t, y

def main():
    print("="*60)
    print(" 📊 ANALISI TEMPORALE DASHBOARD SMT/RMT (DMS)")
    print("="*60)

    # Nomi dei file generati dal testbench DMS
    file_t0 = 'fir_out_t0.txt'
    file_t1 = 'fir_out_t1.txt'
    file_ft = 'ft_mode_log.txt'
    norm_factor = 32768.0

    print("--- Caricamento Dati Hardware ---")
    
    # 1. LETTURA DATI
    t_t0, y_t0 = load_data(file_t0, norm_factor)
    if t_t0 is not None:
        print(f"✅ Trovati {len(t_t0)} campioni per Thread 0.")

    t_t1, y_t1 = load_data(file_t1, norm_factor)
    if t_t1 is not None:
        print(f"✅ Trovati {len(t_t1)} campioni per Thread 1.")

    t_ft, y_ft = load_data(file_ft)
    if t_ft is not None:
        print(f"✅ Trovati stati per FT_MODE.")

    # 2. CREAZIONE DASHBOARD CON 3 SUBPLOT
    plt.style.use('bmh')
    fig, axs = plt.subplots(3, 1, figsize=(10, 8), sharex=True)
    fig.canvas.manager.set_window_title('Analisi Temporale Dashboard SMT/RMT')

    # --- SUBPLOT 1: THREAD 0 (Passa-Basso Leader) ---
    if t_t0 is not None:
        if len(t_t0) > 3: # La Spline cubica richiede almeno 4 punti
            time_interp_t0 = np.linspace(t_t0.min(), t_t0.max(), 1000)
            spl_t0 = make_interp_spline(t_t0, y_t0, k=3)
            axs[0].plot(time_interp_t0, spl_t0(time_interp_t0), 'b-', linewidth=1.5, label='T0 (Spline)')
        axs[0].plot(t_t0, y_t0, 'bo', markersize=4, label='Campioni HW')

    
    axs[0].set_title('Thread 0: Filtro Passa-Basso Leader (SMT/RMT continuo)', fontsize=12, fontweight='bold')
    axs[0].set_ylabel('Ampiezza')
    axs[0].set_ylim([-0.2, 1.0])
    axs[0].legend(loc='best')

    # --- SUBPLOT 2: THREAD 1 (Passa-Alto Ombra) ---
    if t_t1 is not None:
        if len(t_t1) > 3:
            time_interp_t1 = np.linspace(t_t1.min(), t_t1.max(), 1000)
            spl_t1 = make_interp_spline(t_t1, y_t1, k=3)
            axs[1].plot(time_interp_t1, spl_t1(time_interp_t1), 'r-', linewidth=1.5, label='T1 (Spline)')
        axs[1].plot(t_t1, y_t1, 'ro', markersize=4, label='Campioni HW')

    axs[1].axhline(0, color='k', linestyle=':', linewidth=1.2, label='Zero Baseline')
    axs[1].set_title('Thread 1: Filtro Passa-Alto Ombra (Mancanza dati = Ibernazione RMT)', fontsize=12, fontweight='bold')
    axs[1].set_ylabel('Ampiezza')
    axs[1].set_ylim([-0.5, 0.5])
    axs[1].legend(loc='best')

    # --- SUBPLOT 3: SEGNALE FT_MODE ---
    if t_ft is not None:
        # Funzione step con where='post' replica l'esatto comportamento di stairs di MATLAB
        axs[2].step(t_ft, y_ft, where='post', color='m', linewidth=2.5)

    axs[2].set_title('Stato Modalità (0 = SMT, 1 = RMT Lockstep)', fontsize=12, fontweight='bold')
    axs[2].set_xlabel('Tempo di Simulazione (ns)')
    axs[2].set_ylabel('Logica')
    axs[2].set_ylim([-0.2, 1.2])
    axs[2].set_yticks([0, 1])
    axs[2].set_yticklabels(['SMT (Perf.)', 'RMT (Safe)'])

    print("--- Dashboard Generata con Successo! ---")
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()