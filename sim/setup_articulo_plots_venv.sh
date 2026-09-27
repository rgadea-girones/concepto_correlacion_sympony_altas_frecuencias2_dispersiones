#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv_articulo_plots"

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r "$SCRIPT_DIR/requirements_articulo_plots.txt"

cat <<EOF

Environment ready.

Activate it with:
source "$VENV_DIR/bin/activate"

Run the golden-model comparison with:
python "$SCRIPT_DIR/comparar_nettype_vs_symphony_golden.py" \
  --nettype "$SCRIPT_DIR/datos_simulacion_exp_k_extremos_nettype_20260405_110540_423.csv" \
  --symphony "$SCRIPT_DIR/datos_simulacion_exp_k_extremos_symphony_20260405_174715_532.csv" \
  --out-prefix "$SCRIPT_DIR/comparacion_nettype_vs_symphony_golden_articulo"

Run the timing comparison with:
python "$SCRIPT_DIR/comparar_tiempos_nettype_vs_symphony.py" \
  --nettype "$SCRIPT_DIR/datos_simulacion_exp_k_extremos_nettype_20260405_110540_423.csv" \
  --symphony "$SCRIPT_DIR/datos_simulacion_exp_k_extremos_symphony_20260405_174715_532.csv" \
  --out-prefix "$SCRIPT_DIR/comparacion_tiempos_nettype_vs_symphony_articulo"

EOF