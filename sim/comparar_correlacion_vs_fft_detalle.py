import argparse
from pathlib import Path
from typing import Optional

import matplotlib.pyplot as plt
import pandas as pd


def k_from_medida(medida: int) -> float:
    return (float(medida) + 1.0) / 10.0


def color_from_k(k_deg: float):
    k_clamped = min(max(k_deg, 0.1), 1.0)
    k_norm = (k_clamped - 0.1) / 0.9
    return plt.cm.RdYlGn_r(k_norm)


def resolver_archivo_datos(ruta_entrada: Optional[str]) -> Path:
    candidatos = []

    if ruta_entrada:
        p = Path(ruta_entrada)
        candidatos.append(p)
        if p.suffix.lower() == ".sv":
            candidatos.append(p.with_suffix(".csv"))

    candidatos.extend(
        [
            Path("datos_simulacion_nuevo.sv"),
            Path("datos_simulacion_nuevo.csv"),
        ]
    )

    for candidato in candidatos:
        if candidato.exists() and candidato.is_file():
            return candidato

    raise FileNotFoundError(
        "Data file not found. Tried: " + ", ".join(str(c) for c in candidatos)
    )


def preparar_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    columnas_necesarias = {"sujeto", "medida", "frecuencia", "modulo", "fase"}
    faltantes = columnas_necesarias.difference(df.columns)
    if faltantes:
        raise ValueError(f"Missing required columns: {sorted(faltantes)}")

    df = df.copy()
    for col in ["sujeto", "medida"]:
        df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
    for col in ["frecuencia", "modulo", "fase"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df = df.dropna(subset=["sujeto", "medida", "frecuencia", "modulo", "fase"])
    df["sujeto"] = df["sujeto"].astype(int)
    df["medida"] = df["medida"].astype(int)

    # Optional detail columns (present in dpi_guardar_datos_detalle output)
    for col in ["modulo_a", "fase_a", "modulo_b", "fase_b"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    return df


def construir_errores(df: pd.DataFrame) -> pd.DataFrame:
    golden = (
        df[df["sujeto"] == 2][["medida", "frecuencia", "modulo", "fase"]]
        .rename(columns={"modulo": "modulo_golden", "fase": "fase_golden"})
        .drop_duplicates(subset=["medida", "frecuencia"])
    )

    test = df[df["sujeto"].isin([0, 1])].copy()
    test["method"] = test["sujeto"].map({0: "Correlation (Subject 0)", 1: "FFT (Subject 1)"})

    merged = test.merge(golden, on=["medida", "frecuencia"], how="inner", validate="many_to_one")
    if merged.empty:
        raise ValueError("No overlap between test subjects (0/1) and golden model (2).")

    merged["error_modulo_abs"] = (merged["modulo"] - merged["modulo_golden"]).abs()
    merged["error_fase_abs"] = (merged["fase"] - merged["fase_golden"]).abs()
    merged["error_modulo_pct"] = 100.0 * merged["error_modulo_abs"] / merged["modulo_golden"].abs().replace(0, pd.NA)

    return merged


def resumen_global(df_err: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for metodo, g in df_err.groupby("method", sort=False):
        filas.append(
            {
                "method": metodo,
                "n_points": len(g),
                "mae_magnitude_ohm": g["error_modulo_abs"].mean(),
                "rmse_magnitude_ohm": (g["error_modulo_abs"].pow(2).mean()) ** 0.5,
                "mae_magnitude_pct": g["error_modulo_pct"].mean(),
                "mae_phase": g["error_fase_abs"].mean(),
                "rmse_phase": (g["error_fase_abs"].pow(2).mean()) ** 0.5,
            }
        )
    return pd.DataFrame(filas)


def resumen_por_medida(df_err: pd.DataFrame) -> pd.DataFrame:
    return (
        df_err.groupby(["method", "medida"], as_index=False)
        .agg(
            n_points=("frecuencia", "size"),
            mae_magnitude_ohm=("error_modulo_abs", "mean"),
            mae_magnitude_pct=("error_modulo_pct", "mean"),
            mae_phase=("error_fase_abs", "mean"),
        )
        .sort_values(["medida", "method"])
    )


def graficar_8_subfiguras(df_err: pd.DataFrame, ruta_png: Path) -> None:
    fig, axs = plt.subplots(4, 2, figsize=(18, 22), sharex=False)

    response_config = [
        (0, "4-Point Correlation", "o"),
        (1, "4 -Point FFT", "s"),
    ]

    for fila, (sujeto_id, method_label, marker_style) in enumerate(response_config):
        datos_sujeto = df_err[df_err["sujeto"] == sujeto_id].copy()
        medidas = sorted(datos_sujeto["medida"].unique())

        for medida in medidas:
            k_deg = k_from_medida(medida)
            color = color_from_k(k_deg)
            curva = datos_sujeto[datos_sujeto["medida"] == medida].sort_values("frecuencia")

            axs[fila, 0].plot(
                curva["frecuencia"],
                curva["modulo"],
                color=color,
                linestyle="-",
                marker=marker_style,
                markersize=2.5,
                linewidth=1.3,
                label=f"{method_label} k={k_deg:.1f}",
            )
            axs[fila, 0].plot(
                curva["frecuencia"],
                curva["modulo_golden"],
                color=color,
                linestyle="--",
                linewidth=1.4,
                alpha=0.95,
                label=f"Golden k={k_deg:.1f}",
            )

            axs[fila, 1].plot(
                curva["frecuencia"],
                curva["fase"],
                color=color,
                linestyle="-",
                marker=marker_style,
                markersize=2.5,
                linewidth=1.3,
                label=f"{method_label} k={k_deg:.1f}",
            )
            axs[fila, 1].plot(
                curva["frecuencia"],
                curva["fase_golden"],
                color=color,
                linestyle="--",
                linewidth=1.4,
                alpha=0.95,
                label=f"Golden k={k_deg:.1f}",
            )

        axs[fila, 0].set_xscale("log")
        axs[fila, 1].set_xscale("log")
        axs[fila, 0].set_title(f"Frequency Response: Magnitude - {method_label} vs Golden (k sweep)")
        axs[fila, 1].set_title(f"Frequency Response: Phase - {method_label} vs Golden (k sweep)")
        axs[fila, 0].set_ylabel("Magnitude (Ω)")
        axs[fila, 1].set_ylabel("Phase")
        axs[fila, 0].set_xlabel("Frequency (Hz)")
        axs[fila, 1].set_xlabel("Frequency (Hz)")
        axs[fila, 0].grid(alpha=0.3)
        axs[fila, 1].grid(alpha=0.3)
        axs[fila, 0].legend(loc="best", fontsize=6, ncol=2)
        axs[fila, 1].legend(loc="best", fontsize=6, ncol=2)

    for method_name, marker, color in [
        ("FFT (Subject 1)", "o", "tab:blue"),
        ("Correlation (Subject 0)", "o", "tab:orange"),
    ]:
        g = df_err[df_err["method"] == method_name].copy()
        por_frec = g.groupby("frecuencia", as_index=False).agg(
            mean_abs_magnitude_error=("error_modulo_abs", "mean"),
            mean_abs_phase_error=("error_fase_abs", "mean"),
        )
        axs[2, 0].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_magnitude_error"],
            marker=marker,
            markersize=4,
            linewidth=1.4,
            color=color,
            label=method_name,
        )
        axs[2, 1].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_phase_error"],
            marker="s",
            markersize=4,
            linewidth=1.4,
            color=color,
            label=method_name,
        )

    axs[2, 0].set_xscale("log")
    axs[2, 1].set_xscale("log")
    axs[2, 0].set_title("Mean Magnitude Error vs Frequency")
    axs[2, 1].set_title("Mean Phase Error vs Frequency")
    axs[2, 0].set_ylabel("|Δ Magnitude| (Ω)")
    axs[2, 1].set_ylabel("|Δ Phase|")
    axs[2, 0].set_xlabel("Frequency (Hz)")
    axs[2, 1].set_xlabel("Frequency (Hz)")
    axs[2, 0].grid(alpha=0.3)
    axs[2, 1].grid(alpha=0.3)
    axs[2, 0].legend(loc="best")
    axs[2, 1].legend(loc="best")

    box_mag = [
        df_err[df_err["method"] == "Correlation (Subject 0)"]["error_modulo_abs"],
        df_err[df_err["method"] == "FFT (Subject 1)"]["error_modulo_abs"],
    ]
    box_phase = [
        df_err[df_err["method"] == "Correlation (Subject 0)"]["error_fase_abs"],
        df_err[df_err["method"] == "FFT (Subject 1)"]["error_fase_abs"],
    ]
    labels = ["Correlation", "FFT"]

    axs[3, 0].boxplot(box_mag, labels=labels, showfliers=False)
    axs[3, 0].set_title("Distribution of |Δ Magnitude|")
    axs[3, 0].set_ylabel("Error (Ω)")
    axs[3, 0].set_xlabel("Method")
    axs[3, 0].grid(alpha=0.3)

    axs[3, 1].boxplot(box_phase, labels=labels, showfliers=False)
    axs[3, 1].set_title("Distribution of |Δ Phase|")
    axs[3, 1].set_ylabel("Error")
    axs[3, 1].set_xlabel("Method")
    axs[3, 1].grid(alpha=0.3)

    fig.suptitle(
        "Combined 8 Plots: Frequency Responses and Errors vs Golden Model",
        fontsize=17,
        fontweight="bold",
        y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)


def graficar_ab_subfiguras(df: pd.DataFrame, ruta_png: Path) -> None:
    """Figure with modulo_a, modulo_b (left column) and fase_a, fase_b (right column)."""
    cols_needed = {"modulo_a", "fase_a", "modulo_b", "fase_b"}
    if not cols_needed.issubset(df.columns):
        print("[INFO] Columns modulo_a/fase_a/modulo_b/fase_b not present – skipping AB figure.")
        return

    fig, axs = plt.subplots(2, 2, figsize=(16, 12), sharex=False)

    subject_config = [
        (0, "Correlation", "o", "-"),
        (1, "FFT",         "s", "--"),
    ]

    ab_config = [
        (0, "modulo_a", "fase_a", "Terminal A"),
        (1, "modulo_b", "fase_b", "Terminal B"),
    ]

    for row, (_, col_mod, col_fase, terminal_label) in enumerate(ab_config):
        ax_mod  = axs[row, 0]
        ax_fase = axs[row, 1]

        for sujeto_id, method_label, marker_style, lstyle in subject_config:
            datos = df[df["sujeto"] == sujeto_id].copy()
            medidas = sorted(datos["medida"].unique())

            for medida in medidas:
                k_deg = k_from_medida(medida)
                color = color_from_k(k_deg)
                curva = datos[datos["medida"] == medida].sort_values("frecuencia")

                lbl = f"{method_label} k={k_deg:.1f}"
                ax_mod.plot(
                    curva["frecuencia"], curva[col_mod],
                    color=color, linestyle=lstyle,
                    marker=marker_style, markersize=2.5, linewidth=1.3,
                    label=lbl,
                )
                ax_fase.plot(
                    curva["frecuencia"], curva[col_fase],
                    color=color, linestyle=lstyle,
                    marker=marker_style, markersize=2.5, linewidth=1.3,
                    label=lbl,
                )

        ax_mod.set_xscale("log")
        ax_fase.set_xscale("log")
        ax_mod.set_title(f"Magnitude {terminal_label} – Correlation vs FFT (k sweep)")
        ax_fase.set_title(f"Phase {terminal_label} – Correlation vs FFT (k sweep)")
        ax_mod.set_ylabel("Magnitude (Ω)")
        ax_fase.set_ylabel("Phase")
        ax_mod.set_xlabel("Frequency (Hz)")
        ax_fase.set_xlabel("Frequency (Hz)")
        ax_mod.grid(alpha=0.3)
        ax_fase.grid(alpha=0.3)
        ax_mod.legend(loc="best", fontsize=6, ncol=2)
        ax_fase.legend(loc="best", fontsize=6, ncol=2)

    fig.suptitle(
        "Terminal A & B: Magnitude (left) and Phase (right)",
        fontsize=15, fontweight="bold", y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    print(f"[OK] AB figure: {ruta_png}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare Subject 0 (Correlation) vs Subject 1 (FFT) against Golden model (Subject 2)."
    )
    parser.add_argument(
        "--archivo",
        type=str,
        default="datos_simulacion_nuevo.sv",
        help="Path to data file (.sv or .csv). If .sv is not found, .csv is tried automatically.",
    )
    parser.add_argument(
        "--out-prefix",
        type=str,
        default="comparacion_correlacion_vs_fft",
        help="Output filename prefix.",
    )
    args = parser.parse_args()

    archivo = resolver_archivo_datos(args.archivo)
    print(f"[INFO] Using file: {archivo}")

    df = pd.read_csv(archivo, engine="c")
    df = preparar_dataframe(df)
    df_err = construir_errores(df)

    out_prefix = Path(args.out_prefix)
    resumen_global_df = resumen_global(df_err)
    resumen_medida_df = resumen_por_medida(df_err)

    ruta_global = out_prefix.with_name(f"{out_prefix.name}_global_summary.csv")
    ruta_medida = out_prefix.with_name(f"{out_prefix.name}_summary_by_measurement.csv")
    ruta_errores = out_prefix.with_name(f"{out_prefix.name}_error_details.csv")
    ruta_fig = out_prefix.with_name(f"{out_prefix.name}_all_8_subplots.png")
    ruta_fig_ab = out_prefix.with_name(f"{out_prefix.name}_terminals_ab.png")

    resumen_global_df.to_csv(ruta_global, index=False)
    resumen_medida_df.to_csv(ruta_medida, index=False)
    df_err.to_csv(ruta_errores, index=False)

    graficar_8_subfiguras(df_err, ruta_fig)
    graficar_ab_subfiguras(df, ruta_fig_ab)

    print("\n=== Global summary (lower is better) ===")
    print(resumen_global_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print(f"\n[OK] Global CSV: {ruta_global}")
    print(f"[OK] By-measurement CSV: {ruta_medida}")
    print(f"[OK] Error-detail CSV: {ruta_errores}")
    print(f"[OK] Figure: {ruta_fig}")


if __name__ == "__main__":
    main()