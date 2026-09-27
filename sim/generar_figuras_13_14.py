import argparse
from pathlib import Path
from typing import Optional

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap

# Set font sizes to be legible but not too large
plt.rcParams.update({
    'font.size': 14,
    'axes.titlesize': 16,
    'axes.labelsize': 14,
    'xtick.labelsize': 12,
    'ytick.labelsize': 12,
    'legend.fontsize': 12,
    'figure.titlesize': 18
})


def k_from_medida(medida: int) -> float:
    return (float(medida) + 1.0) / 10.0


cmap_uncalibrated = plt.cm.RdYlGn_r # Green for low k, Red for high k
cmap_calibrated = LinearSegmentedColormap.from_list('BlueBrown', ['blue', 'saddlebrown']) # Blue for low k, Brown for high k


def color_from_k(k_deg: float, cmap=cmap_uncalibrated):
    k_clamped = min(max(k_deg, 0.1), 1.0)
    k_norm = (k_clamped - 0.1) / 0.9
    return cmap(k_norm)


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

    test = df[df["sujeto"] == 0].copy()
    test["method"] = "Correlation (Subject 0)"

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


def graficar_8_subfiguras(df_err: pd.DataFrame, ruta_png: Path, fmin_hz: float, fmax_hz: float) -> None:
    fig, axs = plt.subplots(3, 2, figsize=(18, 16.5), sharex=False)

    response_config = [
        (0, "4P Correlation", "o"),
    ]

    for fila, (sujeto_id, method_label, marker_style) in enumerate(response_config):
        datos_sujeto = df_err[df_err["sujeto"] == sujeto_id].copy()
        medidas = sorted(datos_sujeto["medida"].unique())

        for medida in medidas:
            k_deg = k_from_medida(medida)
            current_cmap = cmap_uncalibrated if sujeto_id == 0 else cmap_calibrated
            color = color_from_k(k_deg, current_cmap)
            curva = datos_sujeto[datos_sujeto["medida"] == medida].sort_values("frecuencia")
            
            line_width = 1.3
            marker_size = 2.5
            if sujeto_id == 1: # Calibrated curves
                line_width = 1.8 # Slightly thicker
                marker_size = 3.5 # Slightly larger

            axs[fila, 0].plot(
                curva["frecuencia"],
                curva["modulo"],
                color=color,
                linestyle="-",
                marker=marker_style,
                markersize=marker_size,
                linewidth=line_width,
                label=f"{method_label} k={k_deg:.1f}",
            )
            axs[fila, 0].plot(
                curva["frecuencia"],
                curva["modulo_golden"],
                color=color,
                linestyle="--",
                linewidth=line_width + 0.5, # Golden should also be thicker if test is
                alpha=0.95,
                label=f"Golden k={k_deg:.1f}",
            )

            axs[fila, 1].plot(
                curva["frecuencia"],
                curva["fase"],
                color=color,
                linestyle="-",
                marker=marker_style,
                markersize=marker_size,
                linewidth=line_width,
                label=f"{method_label} k={k_deg:.1f}",
            )
            axs[fila, 1].plot(
                curva["frecuencia"],
                curva["fase_golden"],
                color=color,
                linestyle="--",
                linewidth=line_width + 0.5,
                alpha=0.95,
                label=f"Golden k={k_deg:.1f}",
            )

        axs[fila, 0].set_xscale("log")
        axs[fila, 1].set_xscale("log")
        axs[fila, 0].set_xlim(fmin_hz, fmax_hz)
        axs[fila, 1].set_xlim(fmin_hz, fmax_hz)
        axs[fila, 0].set_title(f"Frequency Response: Magnitude - {method_label} vs Golden (k sweep)")
        axs[fila, 1].set_title(f"Frequency Response: Phase - {method_label} vs Golden (k sweep)")
        axs[fila, 0].set_ylabel("Magnitude (Ω)")
        axs[fila, 1].set_ylabel("Phase (deg)")
        axs[fila, 0].set_xlabel("Frequency (Hz)")
        axs[fila, 1].set_xlabel("Frequency (Hz)")
        axs[fila, 0].grid(alpha=0.3)
        axs[fila, 1].grid(alpha=0.3)
        axs[fila, 0].legend(loc="best", fontsize=10, ncol=2)
        axs[fila, 1].legend(loc="best", fontsize=10, ncol=2)

    # Usar response_config para consistencia
    for sujeto_id, _, marker_style in response_config:
        subject_data = df_err[df_err["sujeto"] == sujeto_id]
        if subject_data.empty:
            continue
            
        method_name = subject_data["method"].iloc[0]
        color = "tab:purple" if sujeto_id == 1 else "tab:orange" # Use distinct colors for error plots

        g = df_err[df_err["method"] == method_name].copy()
        por_frec = g.groupby("frecuencia", as_index=False).agg(
            mean_abs_magnitude_error=("error_modulo_abs", "mean"),
            mean_abs_phase_error=("error_fase_abs", "mean"),
        )
        axs[1, 0].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_magnitude_error"],
            marker=marker_style,
            markersize=4,
            linewidth=1.4,
            color=color,
            label=method_name,
        )
        axs[1, 1].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_phase_error"],
            marker=marker_style,
            markersize=4,
            linewidth=1.4,
            color=color,
            label=method_name,
        )

    axs[1, 0].set_xscale("log")
    axs[1, 1].set_xscale("log")
    axs[1, 0].set_xlim(fmin_hz, fmax_hz)
    axs[1, 1].set_xlim(fmin_hz, fmax_hz)
    axs[1, 0].set_title("Mean Magnitude Error vs Frequency")
    axs[1, 1].set_title("Mean Phase Error vs Frequency")
    axs[1, 0].set_ylabel("|Δ Magnitude| (Ω)")
    axs[1, 1].set_ylabel("|Δ Phase| (deg)")
    axs[1, 0].set_xlabel("Frequency (Hz)")
    axs[1, 1].set_xlabel("Frequency (Hz)")
    axs[1, 0].grid(alpha=0.3)
    axs[1, 1].grid(alpha=0.3)
    axs[1, 0].legend(loc="best")
    axs[1, 1].legend(loc="best")

    box_mag = [
        df_err[df_err["method"] == "Correlation (Subject 0)"]["error_modulo_abs"],
    ]
    box_phase = [
        df_err[df_err["method"] == "Correlation (Subject 0)"]["error_fase_abs"],
    ]
    
    labels = []
    box_colors = []
    valid_box_mag = []
    valid_box_phase = []
    
    if len(box_mag[0]) > 0:
        labels.append("Correlation")
        box_colors.append('tab:orange')
        valid_box_mag.append(box_mag[0])
        valid_box_phase.append(box_phase[0])

    if len(valid_box_mag) > 0:
        bplot_mag = axs[2, 0].boxplot(valid_box_mag, labels=labels, showfliers=False, patch_artist=True)
        for patch, color in zip(bplot_mag['boxes'], box_colors):
            patch.set_facecolor(color)
        for median in bplot_mag['medians']:
            median.set_color('black')
            
        bplot_phase = axs[2, 1].boxplot(valid_box_phase, labels=labels, showfliers=False, patch_artist=True)
        for patch, color in zip(bplot_phase['boxes'], box_colors):
            patch.set_facecolor(color)
        for median in bplot_phase['medians']:
            median.set_color('black')
            
    axs[2, 0].set_title("Distribution of |Δ Magnitude|")
    axs[2, 0].set_ylabel("Error (Ω)")
    axs[2, 0].set_xlabel("Method")
    axs[2, 0].grid(alpha=0.3)

    axs[2, 1].set_title("Distribution of |Δ Phase|")
    axs[2, 1].set_ylabel("Error (deg)")
    axs[2, 1].set_xlabel("Method")
    axs[2, 1].grid(alpha=0.3)
    fig.suptitle(
        "Combined Plots: Frequency Responses and Errors vs Golden Model",
        fontweight="bold",
        y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)


def graficar_ab_subfiguras(df: pd.DataFrame, ruta_png: Path, fmin_hz: float, fmax_hz: float) -> None:
    """Figure with modulo_a, modulo_b (left column) and fase_a, fase_b (right column)."""
    cols_needed = {"modulo_a", "fase_a", "modulo_b", "fase_b"}
    if not cols_needed.issubset(df.columns):
        print("[INFO] Columns modulo_a/fase_a/modulo_b/fase_b not present – skipping AB figure.")
        return

    fig, axs = plt.subplots(2, 2, figsize=(16, 12), sharex=True)

    subject_config = [
        (0, "Correlation", "o", "-"),
    ]

    ab_config = [
        (0, "modulo_a", "fase_a", "Terminal A"),
        (1, "modulo_b", "fase_b", "Terminal B"),
    ]

    for row, (_, col_mod, col_fase, terminal_label) in enumerate(ab_config):
        ax_mod  = axs[row, 0]
        ax_fase = axs[row, 1]

        all_medidas = sorted(df["medida"].unique())

        # No dibujamos el Golden Model para los terminales A y B porque sus valores son 0 y distorsionan la escala.

        for sujeto_id, method_label, marker_style, lstyle in subject_config:
            for medida in all_medidas: # Iterate through all measures for subjects 0 and 1
                k_deg = k_from_medida(medida)
                # Filter for the specific subject and measure
                curva_test = df[(df["sujeto"] == sujeto_id) & (df["medida"] == medida)].sort_values("frecuencia")
                current_cmap = cmap_uncalibrated if sujeto_id == 0 else cmap_calibrated
                color = color_from_k(k_deg, current_cmap)
                
                line_width = 1.3
                marker_size = 2.5
                if sujeto_id == 1: # Calibrated curves
                    line_width = 1.8
                    marker_size = 3.5

                lbl = f"{method_label} k={k_deg:.1f}"
                ax_mod.plot(
                    curva_test["frecuencia"], curva_test[col_mod],
                    color=color, linestyle=lstyle,
                    marker=marker_style, markersize=marker_size, linewidth=line_width,
                    label=lbl,
                )
                ax_fase.plot(
                    curva_test["frecuencia"], curva_test[col_fase],
                    color=color, linestyle=lstyle,
                    marker=marker_style, markersize=marker_size, linewidth=line_width,
                    label=lbl,
                )

        ax_mod.set_xscale("log")
        ax_fase.set_xscale("log")
        ax_mod.set_xlim(fmin_hz, fmax_hz)
        ax_fase.set_xlim(fmin_hz, fmax_hz)
        ax_mod.set_title(f"Magnitude {terminal_label} – Correlation vs Calib. Corr. (k sweep)")
        ax_fase.set_title(f"Phase {terminal_label} – Correlation vs Calib. Corr. (k sweep)")
        ax_mod.set_ylabel("Magnitude (Ω)")
        ax_fase.set_ylabel("Phase (deg)")
        ax_mod.set_xlabel("Frequency (Hz)")
        ax_fase.set_xlabel("Frequency (Hz)")
        ax_mod.grid(alpha=0.3)
        ax_fase.grid(alpha=0.3)
        ax_mod.legend(loc="best", ncol=2)
        ax_fase.legend(loc="best", ncol=2)

    fig.suptitle(
        "Terminals A and B: Magnitude (left) and Phase (right)",
        fontweight="bold", y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    print(f"[OK] Figura terminales AB: {ruta_png}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare Subject 0 (Correlation) vs Subject 1 (Calibrated Correlation) against Golden model (Subject 2)."
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
        default="comparacion_correlacion_vs_calibrada",
        help="Output filename prefix.",
    )
    parser.add_argument(
        "--fmin",
        type=float,
        default=40.0,
        help="Minimum frequency (Hz) to include in analysis and plots.",
    )
    parser.add_argument(
        "--fmax",
        type=float,
        default=1.0e6,
        help="Maximum frequency (Hz) to include in analysis and plots.",
    )
    parser.add_argument(
        "--unwrap-phase",
        action="store_true",
        help="Unwrap the phase to avoid jumps when crossing -180 / +180 degrees.",
    )
    args = parser.parse_args()

    archivo = resolver_archivo_datos(args.archivo)
    print(f"[INFO] Using file: {archivo}")

    df = pd.read_csv(archivo, engine="c")
    df = preparar_dataframe(df)
    
    # Acotar el análisis al rango de frecuencia solicitado.
    df = df[(df['frecuencia'] >= args.fmin) & (df['frecuencia'] <= args.fmax)].copy()

    if args.unwrap_phase:
        import numpy as np
        df = df.sort_values(by=["sujeto", "medida", "frecuencia"])
        for (sujeto, medida), group in df.groupby(["sujeto", "medida"]):
            df.loc[group.index, "fase"] = np.rad2deg(np.unwrap(np.deg2rad(group["fase"])))
            if "fase_a" in group.columns and group["fase_a"].notna().all():
                df.loc[group.index, "fase_a"] = np.rad2deg(np.unwrap(np.deg2rad(group["fase_a"])))
            if "fase_b" in group.columns and group["fase_b"].notna().all():
                df.loc[group.index, "fase_b"] = np.rad2deg(np.unwrap(np.deg2rad(group["fase_b"])))
        print("[INFO] Phase unwrapping applied.")

    df_err = construir_errores(df)

    out_prefix = Path(args.out_prefix)
    resumen_global_df = resumen_global(df_err)
    resumen_medida_df = resumen_por_medida(df_err)

    ruta_global = out_prefix.with_name(f"{out_prefix.name}_global_summary.csv")
    ruta_medida = out_prefix.with_name(f"{out_prefix.name}_summary_by_measurement.csv")
    ruta_errores = out_prefix.with_name(f"{out_prefix.name}_error_details.csv")
    ruta_fig = out_prefix.with_name(f"{out_prefix.name}_all_8_subplots.png")
    ruta_fig_ab = out_prefix.with_name(f"{out_prefix.name}_terminales_ab.png")

    resumen_global_df.to_csv(ruta_global, index=False)
    resumen_medida_df.to_csv(ruta_medida, index=False)
    df_err.to_csv(ruta_errores, index=False)

    graficar_8_subfiguras(df_err, ruta_fig, args.fmin, args.fmax)
    graficar_ab_subfiguras(df, ruta_fig_ab, args.fmin, args.fmax)

    print("\n=== Global Summary (lower is better) ===")
    print(resumen_global_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print(f"\n[OK] CSV Global: {ruta_global}")
    print(f"[OK] CSV por medida: {ruta_medida}")
    print(f"[OK] CSV detalle de errores: {ruta_errores}")
    print(f"[OK] Figura principal: {ruta_fig}")


if __name__ == "__main__":
    main()
