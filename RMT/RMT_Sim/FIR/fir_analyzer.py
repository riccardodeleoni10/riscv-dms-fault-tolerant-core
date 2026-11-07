import os
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import firwin, lfilter
from scipy.interpolate import make_interp_spline

def hex_to_signed32(hex_str):
    """Converte una stringa esadecimale in un intero a 32-bit con segno (Complemento a 2)"""
    val = int(hex_str, 16)
    return val - 0x100000000 if val & 0x80000000 else val

def main():
    print("="*60)
    print(" 📊 ANALISI FIR: DUMP RAM HARDWARE (SMT/RMT)")
    print("="*60)

    # --- PARAMETRI DEL SISTEMA ---
    fs = 800
    Ts = 1 / fs
    N_samples = 100
    norm_factor = 32768.0
    fir_ord = 14

    samp = np.arange(N_samples)
    t = samp * Ts

    # --- 1. GENERAZIONE SEGNALI TEORICI ---
    sin_w = 0.45 * np.sin(2 * np.pi * 10 * t)
    ac_wave = 0.45 * np.sin(2 * np.pi * 200 * t)
    combined_waveform = sin_w + ac_wave

    fc_Hz = 50
    num_taps = fir_ord + 1
    fir_LP = firwin(num_taps, cutoff=fc_Hz, fs=fs, pass_zero='lowpass')
    fir_HP = firwin(num_taps, cutoff=fc_Hz, fs=fs, pass_zero='highpass')

    filtered_LP = lfilter(fir_LP, 1.0, combined_waveform)
    filtered_HP = lfilter(fir_HP, 1.0, combined_waveform)

    # --- 2. LETTURA DEL DUMP DELLA RAM ---
    ram_filename = 'fir_dump.txt'
    if not os.path.isfile(ram_filename):
        print(f"[ERRORE] File '{ram_filename}' non trovato. Lanciare prima la simulazione!")
        return

    # Lettura vigorosa ignorando le righe vuote
    with open(ram_filename, 'r') as f:
        ram_hex = [line.strip() for line in f if line.strip()]

    # L'assembly calcola dal campione 15 al 100 (86 campioni totali)
    num_calc_samples = 100 - fir_ord
    
    # Indici Python partono da 0 (quindi Matlab 301 -> Python 300)
    start_lp_idx = 300
    start_hp_idx = 400

    hw_lp_out = np.zeros(num_calc_samples)
    hw_hp_out = np.zeros(num_calc_samples)

    # Estrazione e Conversione
    for i in range(num_calc_samples):
        # Valori LP
        hex_str_lp = ram_hex[start_lp_idx + i]
        hw_lp_out[i] = hex_to_signed32(hex_str_lp) / norm_factor
        
        # Valori HP
        hex_str_hp = ram_hex[start_hp_idx + i]
        hw_hp_out[i] = hex_to_signed32(hex_str_hp) / norm_factor

    # L'asse dei tempi hardware parte dal 15esimo campione (Indice 14 in Python)
    time_hw = samp[fir_ord:100] * Ts

    # Controllo di attività: Se un array è tutto a zero, significa che il thread non ha girato
    # (Comodissimo per RMT dove gira un solo filtro alla volta)
    lp_active = np.any(hw_lp_out != 0)
    hp_active = np.any(hw_hp_out != 0)

    # --- INTERPOLAZIONE SPLINE ---
    time_interp = np.linspace(time_hw.min(), time_hw.max(), 1000)
    
    if lp_active:
        spl_lp = make_interp_spline(time_hw, hw_lp_out, k=3)
        hw_lp_interp = spl_lp(time_interp)
        
    if hp_active:
        spl_hp = make_interp_spline(time_hw, hw_hp_out, k=3)
        hw_hp_interp = spl_hp(time_interp)

    # --- 3. CREAZIONE DELLA DASHBOARD ---
    plt.style.use('bmh')
    fig, axs = plt.subplots(3, 1, figsize=(10, 8), sharex=True)
    fig.canvas.manager.set_window_title('Analisi Filtri da RAM Dump')

    # Subplot 1: Ingresso
    axs[0].plot(t, combined_waveform, color='green', linewidth=2, label='Ingresso (10Hz + 200Hz)')
    axs[0].set_title('Segnale Combinato iniettato nel Processore', fontweight='bold')
    
    # Subplot 2: Filtro Passa-Basso
    axs[1].plot(t, filtered_LP, color='gray', linestyle='--', linewidth=1.5, label='Ideale (lfilter)')
    if lp_active:
        axs[1].plot(time_interp, hw_lp_interp, color='blue', linewidth=2, label='Hardware LP (Spline)')
        axs[1].plot(time_hw, hw_lp_out, 'bo', markersize=4, markeredgecolor='black', label='Campioni RAM')
    axs[1].set_title('Confronto: Filtro Passa-Basso', fontweight='bold')
    
    axs[1].set_ylim([-0.6, 1.0])

    # Subplot 3: Filtro Passa-Alto
    axs[2].plot(t, filtered_HP, color='gray', linestyle='--', linewidth=1.5, label='Ideale (lfilter)')
    if hp_active:
        axs[2].plot(time_interp, hw_hp_interp, color='red', linewidth=2, label='Hardware HP (Spline)')
        axs[2].plot(time_hw, hw_hp_out, 'ro', markersize=4, markeredgecolor='black', label='Campioni RAM')
    axs[2].set_title('Confronto: Filtro Passa-Alto', fontweight='bold')
    axs[2].axhline(0, color='black', linestyle=':')
    axs[2].set_ylim([-0.6, 0.6])
    axs[2].set_xlabel('Tempo (secondi)')

    for ax in axs:
        ax.set_ylabel('Ampiezza')
        ax.grid(True, linestyle='--', alpha=0.7)
        ax.legend(loc='upper right')

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()