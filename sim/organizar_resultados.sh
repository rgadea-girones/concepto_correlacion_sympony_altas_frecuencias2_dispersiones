#!/bin/bash
set -e

# Config file argument (default: qrun_experimento_ina_2adcs_configurable_to_fpga_v3.f)
CONFIG_FILE="${1:-qrun_experimento_ina_2adcs_configurable_to_fpga_v3.f}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[Error] Fichero de configuración $CONFIG_FILE no existe en $SCRIPT_DIR"
    exit 1
fi

echo "=========================================================="
echo " Lanzando simulación: $CONFIG_FILE"
echo "=========================================================="

# 1. Extraer versión si existe en el nombre de archivo
VERSION="v3"
if [[ "$CONFIG_FILE" =~ v[0-9]+ ]]; then
    VERSION="$(echo "$CONFIG_FILE" | grep -oP 'v[0-9]+')"
fi

# 2. Lanzar la simulación qrun / symphony
if [[ "$CONFIG_FILE" =~ "symphony" ]]; then
    cp -f modelsim.ini questa.ini 2>/dev/null || true
    rm -f qwave.db.lock
    rm -rf qrun.out qrun_opt* symphony.out
    symphony -deluxe -anaformat psf -conf symphony_v3.conf -lconfig all -lconfigname symphony_v3.log -afs -l analog_v3.log -j 60 symphony_v3_input.scs -f psfbin --offrunobj --escchars -end -qrun -f "$CONFIG_FILE" -end -vams +incdir+/root/solido_symphony/solidosim/questasim/verilog_src/adms_vlams/ ../src/dac_ams_wrapper.vams ../src/adc_ams_wrapper.vams ../src/analog_top_4p_portable_to_fpga_ina_v3_ams.vams ../src/top_bioimpedancia_ams_v3.vams -end
else
    qrun -f "$CONFIG_FILE"
fi

# 3. Detectar el CSV generado por la simulación
CSV=$(ls -t datos_simulacion_*.csv 2>/dev/null | head -n 1)

if [ -z "$CSV" ] || [ ! -f "$CSV" ]; then
    echo "[Error] No se encontró ningún archivo datos_simulacion_*.csv tras la simulación."
    exit 1
fi

# Extraer el tag de parámetros directamente del CSV generado
TAG=$(echo "$CSV" | sed -E 's/^datos_simulacion_//; s/\.csv$//')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Formato de la carpeta: YYYYMMDD_HHMMSS_<versión>_<TAG>
OUT_DIR="resultados/${TIMESTAMP}_${VERSION}_${TAG}"
mkdir -p "$OUT_DIR"

# Mover CSV e incluir ficheros de apoyo
mv "$CSV" "$OUT_DIR/"
cp "$CONFIG_FILE" "$OUT_DIR/"

LOG_FILE=$(grep -oP '\-l\s+\K\S+' "$CONFIG_FILE" || true)
if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    cp "$LOG_FILE" "$OUT_DIR/"
fi

echo "[OK] Fichero CSV trasladado a: $OUT_DIR/$CSV"

# 4. Ejecutar script de Python para análisis y gráficos
PYTHON_ENV="./.venv_articulo_plots/bin/python3"
if [ ! -f "$PYTHON_ENV" ]; then
    PYTHON_ENV="python3"
fi

echo "=========================================================="
echo " Generando gráficos y análisis en Python..."
echo "=========================================================="
"$PYTHON_ENV" comparar_correlacion_vs_calibrada_detalle.py \
    --archivo "$OUT_DIR/$CSV" \
    --out-prefix "$OUT_DIR/comparacion" \
    --unwrap-phase || echo "[Info] Análisis de Python completado con avisos."

echo "=========================================================="
echo " Simulación organizada con éxito:"
echo " Carpeta creada : $OUT_DIR"
echo " Fichero CSV     : $OUT_DIR/$CSV"
echo "=========================================================="
