# Script de PowerShell para compilar y simular el proyecto de FFT

# --- PASO 1: COMPILACIÓN ---
# Se imprime un mensaje en la terminal para informar al usuario.
Write-Host "Paso 1: Compilando el proyecto..." -ForegroundColor Green

# Si existe la carpeta 'work', se borra para una compilación limpia.
# Luego se crea de nuevo y se compilan los ficheros .sv y .c en un solo paso.
if (Test-Path -Path "work") {
    vdel -all
}
vlib work
vlog -sv tb_comparacion_3p_vs_4p.sv fft_mariposa.c

# Comprueba si el último comando (vlog) falló.
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error durante la compilación. Revisa los mensajes." -ForegroundColor Red
    # Detiene el script si hay un error
    exit $LASTEXITCODE
}

# --- PASO 2: SIMULACIÓN Y VISUALIZACIÓN ---
Write-Host "Paso 2: Lanzando la simulación con Visualizer..." -ForegroundColor Green
Write-Host "La terminal esperará hasta que cierres la ventana de Visualizer." -ForegroundColor Yellow

# Lanza vsim con Visualizer, cargando la configuración de ondas y ejecutando la simulación.
# vsim -voptargs="-access=rw+/." -nowlf -do run_terminal_3p.do top_sim
vsim -visualizer -voptargs="+acc"  -do run_terminal_4p_versus_3p.do top_sim

Write-Host "Simulación y visualización finalizadas." -ForegroundColor Green
