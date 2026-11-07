#!/bin/bash

echo "======================================================="
echo " 🚀 CORE MORPH / RMT - AMBIENTE DI VERIFICA (UBUNTU)"
echo "======================================================="

# 1. CONTROLLO E GESTIONE DELLA LICENZA
if [ -z "$LM_LICENSE_FILE" ] && [ -z "$MGLS_LICENSE_FILE" ]; then
    echo -e "\n[ATTENZIONE] Variabile di licenza QuestaSim non rilevata!"
    echo "Se QuestaSim richiede un server di licenza o un file .dat, inseriscilo qui sotto."
    echo "(Esempio: 1717@licenze.unimi.it  OPPURE  /opt/questasim/license.dat)"
    read -p ">>> Inserisci il path/server (o premi INVIO per ignorare): " user_lic

    if [ ! -z "$user_lic" ]; then
        export LM_LICENSE_FILE=$user_lic
        echo "[OK] Licenza impostata temporaneamente per questa sessione: $LM_LICENSE_FILE"
    else
        echo "[AVVISO] Nessuna licenza inserita. Se QuestaSim fallisce, riavvia lo script."
    fi
else
    echo "[OK] Licenza EDA rilevata nel sistema."
fi

echo "======================================================="

# 2. AVVIO DELLO SCRIPT PYTHON (che ora gestirà tutto in batch)
# Controlliamo se esiste python3 o python
if command -v python3 &>/dev/null; then
    python3 sim_core.py
else
    python sim_core.py
fi