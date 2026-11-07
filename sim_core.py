#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess
import argparse
import json

# --- CONFIGURAZIONE PERCORSI FISSI ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FIRMWARE_DIR = os.path.join(BASE_DIR, "firmware", "compilati")
RMT_SIM_DIR = os.path.join(BASE_DIR, "RMT", "RMT_Sim")
DMS_SIM_DIR = os.path.join(BASE_DIR, "DMS", "DMS_sim") # Nuova cartella DMS
PROG_DEST = os.path.join(RMT_SIM_DIR, "prog.txt")
CONFIG_FILE = os.path.join(BASE_DIR, ".sim_config.json")

# Mappa delle scelte firmware ai rispettivi file compilati
FIRMWARE_MAP = {
    "PID": "pid_prog.txt",
    "HP": "hp.txt",
    "LP": "lp.txt"
}

def print_header():
    print("="*60)
    print(" 🚀 CORE RMT-DMS - AUTOMATION SIMULATION TOOL")
    print("="*60)

def setup_environment():
    """Cerca la licenza e l'eseguibile di QuestaSim nell'ambiente o nel file config."""
    print_header()
    print("🔍 CONTROLLO AMBIENTE E DIPENDENZE...")
    
    config = {}
    config_updated = False
    
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                config = json.load(f)
        except json.JSONDecodeError:
            pass

    # 1. CONTROLLO LICENZA
    lic_cache = config.get("LICENSE_FILE") or config.get("LM_LICENSE_FILE")
    
    if lic_cache:
        os.environ["LM_LICENSE_FILE"] = lic_cache
        os.environ["MGLS_LICENSE_FILE"] = lic_cache
        print(f"[OK] Licenza caricata dalla memoria cache: {lic_cache}")
        if "LM_LICENSE_FILE" in config:
            config["LICENSE_FILE"] = lic_cache
            del config["LM_LICENSE_FILE"]
            config_updated = True
    else:
        lic_env = os.environ.get("MGLS_LICENSE_FILE") or os.environ.get("LM_LICENSE_FILE")
        if lic_env:
            print(f"[OK] Licenza rilevata nel sistema: {lic_env}")
        else:
            print("\n[ATTENZIONE] Variabile di licenza QuestaSim non rilevata!")
            user_lic = input(">>> Inserisci la licenza (o premi INVIO per ignorare): ").strip()
            if user_lic:
                os.environ["LM_LICENSE_FILE"] = user_lic
                os.environ["MGLS_LICENSE_FILE"] = user_lic
                config["LICENSE_FILE"] = user_lic
                config_updated = True
                print(f"[OK] Licenza salvata in memoria.")
            else:
                print("[AVVISO] Nessuna licenza inserita.")

    # 2. CONTROLLO PATH QUESTASIM
    questasim_dir = None
    vsim_path = shutil.which("vsim")
    
    if vsim_path:
        questasim_dir = os.path.dirname(vsim_path)
        print(f"[OK] QuestaSim trovato nel PATH di sistema: {questasim_dir}")
    else:
        env_path = os.environ.get("QUESTASIM_PATH")
        if env_path and os.path.exists(os.path.join(env_path, "vsim")):
            questasim_dir = env_path
            print(f"[OK] QuestaSim trovato tramite variabile d'ambiente: {env_path}")
        elif "QUESTASIM_PATH" in config and os.path.exists(os.path.join(config["QUESTASIM_PATH"], "vsim")):
            questasim_dir = config["QUESTASIM_PATH"]
            print(f"[OK] QuestaSim caricato dalla cache: {questasim_dir}")
        else:
            print("\n[ATTENZIONE] Eseguibile 'vsim' non trovato nel sistema.")
            while True:
                user_path = input(">>> Inserisci Path assoluto cartella 'bin' QuestaSim: ").strip()
                if not user_path:
                    continue
                
                test_vsim = os.path.join(user_path, "vsim")
                if os.path.exists(test_vsim) and os.access(test_vsim, os.X_OK):
                    questasim_dir = user_path
                    config["QUESTASIM_PATH"] = user_path
                    config_updated = True
                    print(f"[OK] Path configurato con successo!")
                    break
                else:
                    print(f"[ERRORE] Eseguibile non valido in '{user_path}'. Riprova.\n")

    if config_updated:
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=4)
            
    return questasim_dir


def copy_firmware_rmt(firmware_choice):
    src_file = os.path.join(FIRMWARE_DIR, FIRMWARE_MAP[firmware_choice])
    if not os.path.exists(src_file):
        print(f"[ERRORE] File firmware non trovato: {src_file}")
        sys.exit(1)
    print(f"\n[*] Copia del firmware '{firmware_choice}' in corso...")
    shutil.copy(src_file, PROG_DEST)
    print(f"[OK] Firmware caricato in: {PROG_DEST}\n")

def run_questasim(questasim_path, project_dir, mpf_file, tb_name, do_file, post_cmd=""):
    print(f"[*] Avvio di QuestaSim in BATCH MODE nella directory: {os.path.basename(project_dir)}")
    print("[*] Generazione script TCL e simulazione in corso...")
    
    tcl_script_path = os.path.join(project_dir, "auto_run.do")
    
    tcl_content = f"""project open {mpf_file}
project compileall
vsim work.{tb_name}
log -r /*
onbreak {{resume}}
run -all
{post_cmd}
dataset save sim wave_results.wlf
quit -f
"""
    with open(tcl_script_path, "w") as f:
        f.write(tcl_content)
    
    vsim_exe = os.path.join(questasim_path, "vsim")
    cmd = [vsim_exe, "-c", "-do", "auto_run.do"]
    
    sim_env = os.environ.copy()
    
    try:
        subprocess.run(cmd, cwd=project_dir, check=True, env=sim_env)
        print(f"[OK] Simulazione completata con successo nella directory: {os.path.basename(project_dir)}")
        return True
    except FileNotFoundError:
        print("\n[ERRORE CRITICO] Il comando 'vsim' non è stato trovato!")
        sys.exit(1)
    except subprocess.CalledProcessError:
        print("[ERRORE] QuestaSim ha restituito un errore.")
        return False

def interactive_menu():
    print("\nScegli l'architettura da simulare:")
    print("1. RMT (Redundant Multi-Threading)")
    print("2. DMS (Dynamic Mode-Switching - SMT Parallelo)")
    
    core_choice = input("Scelta [1/2]: ").strip()
    
    if core_choice == "2":
        # Per il DMS non serve chiedere il firmware, carica in automatico LP e HP
        return "DMS", "BOTH"
    elif core_choice == "1":
        print("\nScegli il firmware da testare:")
        print("1. PID (Controllore Motore)")
        print("2. LP (Filtro Passa-Basso FIR)")
        print("3. HP (Filtro Passa-Alto FIR)")
        
        fw_choice = input("Scelta [1/2/3]: ").strip()
        fw_map = {"1": "PID", "2": "LP", "3": "HP"}
        
        if fw_choice not in fw_map:
            print("Scelta non valida.")
            sys.exit(1)
            
        return "RMT", fw_map[fw_choice]
    else:
        print("Scelta non valida.")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="RMT Simulation Automator")
    parser.add_argument("-c", "--core", choices=["RMT", "DMS"], help="Seleziona il tipo di Core")
    parser.add_argument("-f", "--firmware", choices=["PID", "LP", "HP"], help="Seleziona il firmware (Solo per RMT)")
    
    args = parser.parse_args()
    
    questasim_path = setup_environment()
    
    # MENU INTERATTIVO / CLI
    if not args.core:
        core_type, fw_type = interactive_menu()
    else:
        core_type = args.core
        # Se avviato da CLI come DMS, ignora il firmware
        fw_type = args.firmware if (core_type == "RMT" and args.firmware) else "BOTH"

    print(f"\n>>> CONFIGURAZIONE SCELTA: Core={core_type} | Firmware={fw_type} <<<\n")

    # ==========================================
    # LOGICA DI ESECUZIONE: RMT (LOCK-STEP)
    # ==========================================
    if core_type == "RMT":
        copy_firmware_rmt(fw_type)
        
        if fw_type == "PID":
            pid_dir = os.path.join(RMT_SIM_DIR, "PID")
            sim_success = run_questasim(questasim_path, pid_dir, "pid_sim.mpf", "tb_pid_fault", "waves_pid_fault.do")
            if sim_success:
                analyzer = os.path.join(pid_dir, "pid_analizer.py")
                if os.path.exists(analyzer):
                    print("\n[*] Avvio dell'analisi PID in corso...")
                    subprocess.run([sys.executable, "pid_analizer.py"], cwd=pid_dir, check=True)
            else:
                sys.exit(1)
        
        elif fw_type in ["LP", "HP"]:
            fir_dir = os.path.join(RMT_SIM_DIR, "FIR")
            dump_cmd = "mem save -o fir_dump.txt -f mti -noaddress -data hex -addr hex -wordsperline 1 /tb_core_top/dut/ram_inst/ram_memory;"
            
            sim_success = run_questasim(questasim_path, fir_dir, "fir_sim.mpf", "tb_core_top", "waves_fault.do", post_cmd=dump_cmd)
            
            if sim_success:
                print(f"\n[*] Avvio dell'analisi FIR ({fw_type}) in corso...")
                subprocess.run([sys.executable, "fir_analyzer.py"], cwd=fir_dir, check=True)

    # ==========================================
    # LOGICA DI ESECUZIONE: DMS (SMT PARALLELO)
    # ==========================================
    elif core_type == "DMS":
        src_lp = os.path.join(FIRMWARE_DIR, FIRMWARE_MAP["LP"])
        src_hp = os.path.join(FIRMWARE_DIR, FIRMWARE_MAP["HP"])
        dest_t0 = os.path.join(DMS_SIM_DIR, "prog_T0.txt")
        dest_t1 = os.path.join(DMS_SIM_DIR, "prog_T1.txt")
        
        if not os.path.exists(src_lp) or not os.path.exists(src_hp):
            print(f"[ERRORE] File firmware {FIRMWARE_MAP['LP']} o {FIRMWARE_MAP['HP']} mancanti in {FIRMWARE_DIR}.")
            sys.exit(1)
            
        print("\n[*] Preparazione memorie I-RAM per esecuzione SMT parallela...")
        shutil.copy(src_lp, dest_t0)
        shutil.copy(src_hp, dest_t1)
        print(f"[OK] Thread 0 -> {FIRMWARE_MAP['LP']}")
        print(f"[OK] Thread 1 -> {FIRMWARE_MAP['HP']}\n")
        
        
        sim_success = run_questasim(questasim_path, DMS_SIM_DIR, "dms_sim.mpf", "tb_core_top", "waves_fault.do")
        
        if sim_success:
            print("\n[OK] Simulazione DMS completata correttamente.")
            
            # Lanciamo il nuovo analizzatore DMS a 3 grafici
            analyzer_script = os.path.join(DMS_SIM_DIR, "dms_analyzer.py")
            if os.path.exists(analyzer_script):
                print("[*] Avvio dell'analisi grafica DMS in corso...")
                subprocess.run([sys.executable, "dms_analyzer.py"], cwd=DMS_SIM_DIR, check=True)
            else:
                print("\n[AVVISO] Script 'dms_analyzer.py' non trovato nella cartella DMS_sim.")

if __name__ == "__main__":
    main()