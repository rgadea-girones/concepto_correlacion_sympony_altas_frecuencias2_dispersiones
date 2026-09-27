import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os


def graficar_grupo(df_test_grupo, df_golden, titulo_grupo, archivo_salida):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 9), sharex=True)

    sns.lineplot(
        data=df_test_grupo,
        x='frecuencia',
        y='modulo',
        hue='sujeto',
        palette='viridis',
        ax=ax1,
        alpha=0.7,
        marker='o',
        errorbar='sd',
        err_style='band'
    )

    if not df_golden.empty:
        ax1.plot(
            df_golden['frecuencia'],
            df_golden['modulo'],
            color='black',
            linewidth=4,
            linestyle='--',
            label='GOLDEN MODEL (Subject 2)',
            zorder=10
        )

    ax1.set_xscale('log')
    ax1.set_ylabel('Magnitude (Ω)')
    ax1.set_title(f'Frequency Response: Magnitude - {titulo_grupo}', fontweight='bold')
    ax1.legend(loc='best')

    sns.lineplot(
        data=df_test_grupo,
        x='frecuencia',
        y='fase',
        hue='sujeto',
        palette='viridis',
        ax=ax2,
        alpha=0.7,
        marker='s',
        errorbar='sd',
        err_style='band'
    )

    if not df_golden.empty:
        ax2.plot(
            df_golden['frecuencia'],
            df_golden['fase'],
            color='black',
            linewidth=4,
            linestyle='--',
            zorder=10
        )

    ax2.set_xscale('log')
    ax2.set_ylabel('Phase (degrees)')
    ax2.set_xlabel('Frequency (Hz)')

    plt.tight_layout()
    plt.savefig(archivo_salida)
    print(f"[Python] Plot generated successfully: {archivo_salida}")

def principal():
    candidatos_preferidos = [
        "datos_simulacion_nuevo_tiempos.csv",
        "datos_simulacion_nuevo_nettype.csv",
        "datos_simulacion_nuevo.csv",
    ]
    archivo = candidatos_preferidos[-1]
    for candidato in candidatos_preferidos:
        if os.path.exists(candidato):
            archivo = candidato
            break

    if not os.path.exists(archivo):
        archivos_csv = sorted(f for f in os.listdir('.') if f.endswith('.csv'))
        if archivos_csv:
            archivo = archivos_csv[0]
            print(f"Usando archivo alternativo: {archivo}")
    
    if os.path.exists(archivo):
        # 1. Cargar el DataFrame
        df = pd.read_csv(archivo, engine='c')
        
        # --- LÓGICA DEL GOLDEN MODEL (SUJETO 2) ---
        # Extraemos el sujeto 2 como referencia única
        df_golden = df[df['sujeto'] == 2].drop_duplicates(subset=['frecuencia'])
        # Resto de sujetos (0 y 1)
        df_test = df[df['sujeto'] != 2]
        # ------------------------------------------

        sns.set_theme(style="whitegrid")
        df_test_pares = df_test[df_test['medida'] % 2 == 0]
        df_test_impares = df_test[df_test['medida'] % 2 == 1]

        graficar_grupo(
            df_test_pares,
            df_golden,
            'Even Measurements (Frozen Tuna)',
            'frequency_response_even_measurements.png'
        )
        graficar_grupo(
            df_test_impares,
            df_golden,
            'Odd Measurements (Thawed Tuna)',
            'frequency_response_odd_measurements.png'
        )

        plt.show()  # This window won't block Questa anymore
        
    else:
        print(f"Error: No se encontró {archivo}")

if __name__ == "__main__":
    principal()