import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


def k_from_medida(medida: int) -> float:
    return (float(medida) + 1.0) / 10.0


def color_from_k(k_deg: float):
    k_clamped = min(max(k_deg, 0.1), 1.0)
    k_norm = (k_clamped - 0.1) / 0.9
    return plt.cm.RdYlGn_r(k_norm)


def graficar_sujeto_con_golden(df: pd.DataFrame, sujeto_id: int, titulo: str, archivo_salida: str):
    df_sujeto = df[df["sujeto"] == sujeto_id].copy()
    df_golden = df[df["sujeto"] == 2].copy()

    if df_sujeto.empty:
        print(f"[Python] Aviso: no hay datos para sujeto {sujeto_id}")
        return

    medidas = sorted(df_sujeto["medida"].unique())

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(13, 9), sharex=True)

    marcador = "o" if sujeto_id == 0 else "s"
    etiqueta_sujeto = "4P_correlacion" if sujeto_id == 0 else "4P_FFT"

    for medida in medidas:
        k_deg = k_from_medida(medida)
        color = color_from_k(k_deg)

        curva = (
            df_sujeto[df_sujeto["medida"] == medida]
            .sort_values("frecuencia")
        )
        golden = (
            df_golden[df_golden["medida"] == medida]
            .sort_values("frecuencia")
        )

        if not curva.empty:
            ax1.plot(
                curva["frecuencia"],
                curva["modulo"],
                color=color,
                linestyle="-",
                marker=marcador,
                markersize=3.5,
                linewidth=1.8,
                label=f"{etiqueta_sujeto} k={k_deg:.1f}",
            )
            ax2.plot(
                curva["frecuencia"],
                curva["fase"],
                color=color,
                linestyle="-",
                marker=marcador,
                markersize=3.5,
                linewidth=1.8,
            )

        if not golden.empty:
            ax1.plot(
                golden["frecuencia"],
                golden["modulo"],
                color=color,
                linestyle="--",
                linewidth=2.0,
                alpha=0.95,
                label=f"Golden k={k_deg:.1f}",
            )
            ax2.plot(
                golden["frecuencia"],
                golden["fase"],
                color=color,
                linestyle="--",
                linewidth=2.0,
                alpha=0.95,
            )

    ax1.set_xscale("log")
    ax1.set_ylabel("Magnitude (Ω)")
    ax1.set_title(f"Frequency Response: Magnitude - {titulo}", fontweight="bold")
    ax1.legend(loc="best", fontsize=8, ncol=2)
    ax1.grid(True, alpha=0.3)

    ax2.set_xscale("log")
    ax2.set_ylabel("Phase (degrees)")
    ax2.set_xlabel("Frequency (Hz)")
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(archivo_salida, dpi=150)
    print(f"[Python] Plot generated successfully: {archivo_salida}")


def principal():
    archivo = "datos_simulacion_nuevo.csv"

    if not os.path.exists(archivo):
        archivos_csv = [f for f in os.listdir('.') if f.endswith('.csv')]
        if archivos_csv:
            archivo = archivos_csv[0]
            print(f"Usando archivo alternativo: {archivo}")

    if os.path.exists(archivo):
        df = pd.read_csv(archivo, engine="c")
        sns.set_theme(style="whitegrid")

        graficar_sujeto_con_golden(
            df,
            sujeto_id=0,
            titulo="4-Point Correlation vs Golden (k_degradacion sweep)",
            archivo_salida="frequency_response_4p_correlacion_kdeg.png",
        )

        graficar_sujeto_con_golden(
            df,
            sujeto_id=1,
            titulo="4-Point FFT vs Golden (k_degradacion sweep)",
            archivo_salida="frequency_response_4p_FFT_kdeg.png",
        )

        plt.show()
    else:
        print(f"Error: No se encontró {archivo}")


if __name__ == "__main__":
    principal()
