import argparse
import math
from pathlib import Path
from typing import Optional, List

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap


NUM_MEDIDAS_TOTAL = 5.0


def set_num_medidas(n: float) -> None:
    global NUM_MEDIDAS_TOTAL
    NUM_MEDIDAS_TOTAL = float(n)


def k_from_medida(medida: int) -> float:
    return (float(medida) + 1.0) / float(NUM_MEDIDAS_TOTAL)


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

    test = df[df["sujeto"].isin([0, 1])].copy()
    test["method"] = test["sujeto"].map({0: "Correlation (Subject 0)", 1: "Calibrated Correlation (Subject 1)"})

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


def graficar_8_subfiguras(df_err: pd.DataFrame, ruta_png: Path, fmax_hz: float) -> None:
    fig, axs = plt.subplots(4, 2, figsize=(18, 22), sharex=False)

    response_config = [
        (0, "4P Correlation", "o"),
        (1, "4P Calibrated Correlation", "s"),
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
        axs[fila, 0].set_xlim(40.0, fmax_hz)
        axs[fila, 1].set_xlim(40.0, fmax_hz)
        axs[fila, 0].set_title(f"Frequency Response: Magnitude - {method_label} vs Golden (k sweep)")
        axs[fila, 1].set_title(f"Frequency Response: Phase - {method_label} vs Golden (k sweep)")
        axs[fila, 0].set_ylabel("Magnitude (Ω)")
        axs[fila, 1].set_ylabel("Phase (deg)")
        axs[fila, 0].set_xlabel("Frequency (Hz)")
        axs[fila, 1].set_xlabel("Frequency (Hz)")
        axs[fila, 0].grid(alpha=0.3)
        axs[fila, 1].grid(alpha=0.3)
        axs[fila, 0].legend(loc="best", fontsize=6, ncol=2)
        axs[fila, 1].legend(loc="best", fontsize=6, ncol=2)

    # Usar response_config para consistencia
    for sujeto_id, _, marker_style in response_config:
        # Prevent index error if filtered dataset is empty for this subject
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
        axs[2, 0].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_magnitude_error"],
            marker=marker_style,
            markersize=4,
            linewidth=1.4,
            color=color,
            label=method_name,
        )
        axs[2, 1].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_phase_error"],
            marker=marker_style,
            markersize=4,
            linewidth=1.4,
            color=color,
            label=method_name,
        )

    axs[2, 0].set_xscale("log")
    axs[2, 1].set_xscale("log")
    axs[2, 0].set_xlim(40.0, fmax_hz)
    axs[2, 1].set_xlim(40.0, fmax_hz)
    axs[2, 0].set_title("Mean Magnitude Error vs Frequency")
    axs[2, 1].set_title("Mean Phase Error vs Frequency")
    axs[2, 0].set_ylabel("|Δ Magnitude| (Ω)")
    axs[2, 1].set_ylabel("|Δ Phase| (deg)")
    axs[2, 0].set_xlabel("Frequency (Hz)")
    axs[2, 1].set_xlabel("Frequency (Hz)")
    axs[2, 0].grid(alpha=0.3)
    axs[2, 1].grid(alpha=0.3)
    axs[2, 0].legend(loc="best")
    axs[2, 1].legend(loc="best")

    box_mag = [
        df_err[df_err["method"] == "Correlation (Subject 0)"]["error_modulo_abs"],
        df_err[df_err["method"] == "Calibrated Correlation (Subject 1)"]["error_modulo_abs"],
    ]
    box_phase = [
        df_err[df_err["method"] == "Correlation (Subject 0)"]["error_fase_abs"],
        df_err[df_err["method"] == "Calibrated Correlation (Subject 1)"]["error_fase_abs"],
    ]
    # Filter out empty distributions for box plots
    labels = []
    box_colors = []
    valid_box_mag = []
    valid_box_phase = []
    
    if len(box_mag[0]) > 0:
        labels.append("Correlation")
        box_colors.append('tab:orange')
        valid_box_mag.append(box_mag[0])
        valid_box_phase.append(box_phase[0])
        
    if len(box_mag[1]) > 0:
        labels.append("Calib. Corr.")
        box_colors.append('tab:purple')
        valid_box_mag.append(box_mag[1])
        valid_box_phase.append(box_phase[1])

    if len(valid_box_mag) > 0:
        bplot_mag = axs[3, 0].boxplot(valid_box_mag, labels=labels, showfliers=False, patch_artist=True)
        for patch, color in zip(bplot_mag['boxes'], box_colors):
            patch.set_facecolor(color)
        for median in bplot_mag['medians']:
            median.set_color('black')
            
        bplot_phase = axs[3, 1].boxplot(valid_box_phase, labels=labels, showfliers=False, patch_artist=True)
        for patch, color in zip(bplot_phase['boxes'], box_colors):
            patch.set_facecolor(color)
        for median in bplot_phase['medians']:
            median.set_color('black')
            
    axs[3, 0].set_title("Distribution of |Δ Magnitude|")
    axs[3, 0].set_ylabel("Error (Ω)")
    axs[3, 0].set_xlabel("Method")
    axs[3, 0].grid(alpha=0.3)

    axs[3, 1].set_title("Distribution of |Δ Phase|")
    axs[3, 1].set_ylabel("Error (deg)")
    fig.suptitle(
        "Combined Plots: Frequency Responses and Errors vs Golden Model",
        fontsize=17,
        fontweight="bold",
        y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)


def graficar_ab_subfiguras(df: pd.DataFrame, ruta_png: Path, fmax_hz: float) -> None:
    """Figure with modulo_a, modulo_b (left column) and fase_a, fase_b (right column)."""
    cols_needed = {"modulo_a", "fase_a", "modulo_b", "fase_b"}
    if not cols_needed.issubset(df.columns):
        print("[INFO] Columns modulo_a/fase_a/modulo_b/fase_b not present – skipping AB figure.")
        return

    fig, axs = plt.subplots(2, 2, figsize=(16, 12), sharex=True)

    subject_config = [
        (0, "Correlation", "o", "-"),
        (1, "Calib. Corr.", "s", "--"),
    ]

    ab_config = [
        (0, "modulo_a", "fase_a", "Terminal A"),
        (1, "modulo_b", "fase_b", "Terminal B"),
    ]

    for row, (_, col_mod, col_fase, terminal_label) in enumerate(ab_config):
        ax_mod  = axs[row, 0]
        ax_fase = axs[row, 1]

        all_medidas = sorted(df["medida"].unique())

        # --- Plot Golden data (terminal-specific) ---
        # This plots the phase_a/phase_b from the golden model
        for medida in all_medidas:
            curva_golden_terminal = df[(df["sujeto"] == 2) & (df["medida"] == medida)].sort_values("frecuencia")
            if not curva_golden_terminal.empty:
                ax_mod.plot(
                    curva_golden_terminal["frecuencia"], curva_golden_terminal[col_mod],
                    color='black', linestyle=':', linewidth=1.5, alpha=0.8,
                    label="_nolegend_"
                )
                ax_fase.plot(
                    curva_golden_terminal["frecuencia"], curva_golden_terminal[col_fase],
                    color='black', linestyle=':', linewidth=1.5, alpha=0.8,
                    label="_nolegend_"
                )
        # Add a single legend entry for the terminal-specific golden
        ax_mod.plot([], [], color='black', linestyle=':', linewidth=1.5, label='Golden Terminal')
        ax_fase.plot([], [], color='black', linestyle=':', linewidth=1.5, label='Golden Terminal')

        # --- NEW: Plot the overall Golden Bioimpedance Phase ---
        # This plots the 'fase' column from the golden model (sujeto=2)
        # Get all unique measures present in the data (from any subject)
        df_overall_golden = df[df["sujeto"] == 2].copy()
        if not df_overall_golden.empty:
            for medida in all_medidas:
                curva_overall_golden = df_overall_golden[df_overall_golden["medida"] == medida].sort_values("frecuencia")
                if not curva_overall_golden.empty:
                    ax_fase.plot(
                        curva_overall_golden["frecuencia"], curva_overall_golden["fase"],
                        color='red', linestyle='--', linewidth=2.5, alpha=0.9,
                        label="_nolegend_" # Will add a single dummy entry for legend
                    )
            # Add a single legend entry for the overall Golden Bioimpedance Phase
            ax_fase.plot([], [], color='red', linestyle='--', linewidth=2.5, label='Overall Golden Bioimpedance')

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

                if not curva_test.empty:
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
        ax_mod.set_xlim(40.0, fmax_hz)
        ax_fase.set_xlim(40.0, fmax_hz)
        ax_mod.set_title(f"Magnitude {terminal_label} – Correlation vs Calib. Corr. (k sweep)")
        ax_fase.set_title(f"Phase {terminal_label} – Correlation vs Calib. Corr. (k sweep)")
        ax_mod.set_ylabel("Magnitude (Ω)")
        ax_fase.set_ylabel("Phase (deg)")
        ax_mod.set_xlabel("Frequency (Hz)")
        ax_fase.set_xlabel("Frequency (Hz)")
        ax_mod.grid(alpha=0.3)
        ax_fase.grid(alpha=0.3)
        ax_mod.legend(loc="best", fontsize=6, ncol=2)
        ax_fase.legend(loc="best", fontsize=6, ncol=2)

    fig.suptitle(
        "Terminals A and B: Magnitude (left) and Phase (right)",
        fontsize=15, fontweight="bold", y=0.995,
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
        default="comparacion_correlacion_vs_calibrada_k_select",
        help="Output filename prefix.",
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
    parser.add_argument(
        "--k",
        type=float,
        nargs="+",
        help="Specific k values to include in the plots. E.g., --k 0.1 0.5 1.0",
    )
    parser.add_argument(
        "--num-medidas",
        type=float,
        default=None,
        help="Total number of measures used in sweep to compute k (default: auto-detect from data or 5.0).",
    )
    args = parser.parse_args()

    archivo = resolver_archivo_datos(args.archivo)
    print(f"[INFO] Using file: {archivo}")

    df = pd.read_csv(archivo, engine="c")
    df = preparar_dataframe(df)

    if args.num_medidas is not None:
        set_num_medidas(args.num_medidas)
        print(f"[INFO] Number of measures set by user: {args.num_medidas}")
    elif "medida" in df.columns and not df.empty:
        max_medida = int(df["medida"].max())
        if max_medida <= 4:
            set_num_medidas(5.0)
            print("[INFO] Auto-detected 5-measure sweep (NUM_MEDIDAS=5.0).")
        else:
            set_num_medidas(10.0)
            print("[INFO] Auto-detected 10-measure sweep (NUM_MEDIDAS=10.0).")
    
    # Acotar el análisis al rango de frecuencia solicitado.
    df = df[df['frecuencia'] <= args.fmax].copy()

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

    # Filtrar por K si fue solicitado
    if args.k:
        # Calcular K para cada fila
        df['k_val'] = df['medida'].apply(k_from_medida)
        # Filtrar usando isclose por problemas de precision de floats
        k_mask = df['k_val'].apply(lambda val: any(math.isclose(val, req_k, abs_tol=1e-3) for req_k in args.k))
        df = df[k_mask].drop(columns=['k_val'])
        print(f"[INFO] Filtering for k in {args.k}")

    if df.empty:
        print("[WARNING] DataFrame is empty after filtering! Check your --k arguments.")
        return

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

    graficar_8_subfiguras(df_err, ruta_fig, args.fmax)
    graficar_ab_subfiguras(df, ruta_fig_ab, args.fmax)

    print("\n=== Global Summary (lower is better) ===")
    print(resumen_global_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print(f"\n[OK] CSV Global: {ruta_global}")
    print(f"[OK] CSV por medida: {ruta_medida}")
    print(f"[OK] CSV detalle de errores: {ruta_errores}")
    print(f"[OK] Figura principal: {ruta_fig}")


if __name__ == "__main__":
    main()
