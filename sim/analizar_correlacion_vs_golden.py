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

    # Optional detail columns
    for col in ["modulo_a", "fase_a", "modulo_b", "fase_b"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    return df


def construir_errores_por_sujeto(df: pd.DataFrame, sujeto: int, method_label: str) -> pd.DataFrame:
    golden = (
        df[df["sujeto"] == 2][["medida", "frecuencia", "modulo", "fase"]]
        .rename(columns={"modulo": "modulo_golden", "fase": "fase_golden"})
        .drop_duplicates(subset=["medida", "frecuencia"])
    )

    test = df[df["sujeto"] == sujeto].copy()
    test["method"] = method_label

    merged = test.merge(golden, on=["medida", "frecuencia"], how="inner", validate="many_to_one")
    if merged.empty:
        raise ValueError(f"No overlap between test subject ({sujeto}) and golden model (2).")

    merged["error_modulo_abs"] = (merged["modulo"] - merged["modulo_golden"]).abs()
    merged["error_fase_abs"] = (merged["fase"] - merged["fase_golden"]).abs()
    merged["error_modulo_pct"] = 100.0 * merged["error_modulo_abs"] / merged["modulo_golden"].abs().replace(0, pd.NA)
    merged["sujeto"] = sujeto

    return merged


def construir_errores(df: pd.DataFrame) -> pd.DataFrame:
    partes = [
        construir_errores_por_sujeto(df, 0, "Correlation (Subject 0)"),
        construir_errores_por_sujeto(df, 1, "Correlation Calibrated (Subject 1)")
    ]
    return pd.concat(partes, ignore_index=True)


def resumen_global(df_err: pd.DataFrame) -> pd.DataFrame:
    return (
        df_err.groupby("method", as_index=False)
        .agg(
            n_points=("frecuencia", "size"),
            mae_magnitude_ohm=("error_modulo_abs", "mean"),
            rmse_magnitude_ohm=("error_modulo_abs", lambda s: float((s.pow(2).mean()) ** 0.5)),
            mae_magnitude_pct=("error_modulo_pct", "mean"),
            mae_phase=("error_fase_abs", "mean"),
            rmse_phase=("error_fase_abs", lambda s: float((s.pow(2).mean()) ** 0.5)),
        )
        .sort_values("method")
    )


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


def graficar_resultados(df_err: pd.DataFrame, ruta_png: Path) -> None:
    fig, axs = plt.subplots(2, 2, figsize=(18, 12), sharex=False)
    marker_style = "o"
    for method_label, style in [
        ("Correlation (Subject 0)", "tab:orange"),
        ("Correlation Calibrated (Subject 1)", "tab:purple"),
    ]:
        datos_sujeto = df_err[df_err["method"] == method_label]
        medidas = sorted(datos_sujeto["medida"].unique())

        for medida in medidas:
            k_deg = k_from_medida(medida)
            curva = datos_sujeto[datos_sujeto["medida"] == medida].sort_values("frecuencia")

            axs[0, 0].plot(
                curva["frecuencia"], curva["modulo"],
                color=style, linestyle="-", marker=marker_style,
                markersize=2.5, linewidth=1.3, label=f"{method_label} k={k_deg:.1f}",
            )
            axs[0, 0].plot(
                curva["frecuencia"], curva["modulo_golden"],
                color="0.35", linestyle="--", linewidth=1.0,
                alpha=0.7, label=f"Golden k={k_deg:.1f}" if method_label == "Correlation (Subject 0)" else None,
            )
            axs[0, 1].plot(
                curva["frecuencia"], curva["fase"],
                color=style, linestyle="-", marker=marker_style,
                markersize=2.5, linewidth=1.3, label=f"{method_label} k={k_deg:.1f}",
            )
            axs[0, 1].plot(
                curva["frecuencia"], curva["fase_golden"],
                color="0.35", linestyle="--", linewidth=1.0,
                alpha=0.7, label=f"Golden k={k_deg:.1f}" if method_label == "Correlation (Subject 0)" else None,
            )

    axs[0, 0].set_xscale("log")
    axs[0, 1].set_xscale("log")
    axs[0, 0].set_title("Frequency Response: Magnitude - Subject 0/1 vs Golden")
    axs[0, 1].set_title("Frequency Response: Phase - Subject 0/1 vs Golden")
    axs[0, 0].set_ylabel("Magnitude (Ω)")
    axs[0, 1].set_ylabel("Phase (deg)")
    axs[0, 0].grid(alpha=0.3)
    axs[0, 1].grid(alpha=0.3)
    axs[0, 0].legend(loc="best", fontsize=7, ncol=2)
    axs[0, 1].legend(loc="best", fontsize=7, ncol=2)

    for method_label, color in [("Correlation (Subject 0)", "tab:orange"), ("Correlation Calibrated (Subject 1)", "tab:purple")]:
        datos_sujeto = df_err[df_err["method"] == method_label]
        por_frec = datos_sujeto.groupby("frecuencia", as_index=False).agg(
            mean_abs_magnitude_error=("error_modulo_abs", "mean"),
            mean_abs_phase_error=("error_fase_abs", "mean"),
        )
        axs[1, 0].plot(
            por_frec["frecuencia"], por_frec["mean_abs_magnitude_error"],
            marker=marker_style, markersize=4, linewidth=1.4,
            color=color, label=method_label,
        )
        axs[1, 1].plot(
            por_frec["frecuencia"], por_frec["mean_abs_phase_error"],
            marker=marker_style, markersize=4, linewidth=1.4,
            color=color, label=method_label,
        )

    axs[1, 0].set_xscale("log")
    axs[1, 1].set_xscale("log")
    axs[1, 0].set_title("Mean Absolute Magnitude Error vs Frequency")
    axs[1, 1].set_title("Mean Absolute Phase Error vs Frequency")
    axs[1, 0].set_ylabel("|Δ Magnitude| (Ω)")
    axs[1, 1].set_ylabel("|Δ Phase| (deg)")
    for ax in axs[1, :]:
        ax.set_xlabel("Frequency (Hz)")
        ax.grid(alpha=0.3)
        ax.legend(loc="best")

    fig.suptitle(
        f"Analysis: {method_label} vs Golden Model",
        fontsize=17, fontweight="bold", y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.03, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    plt.close(fig)


def graficar_ab_subfiguras(df: pd.DataFrame, ruta_png: Path) -> None:
    """Figure with modulo_a, modulo_b (left) and fase_a, fase_b (right)."""
    cols_needed = {"modulo_a", "fase_a", "modulo_b", "fase_b"}
    if not cols_needed.issubset(df.columns):
        print("[INFO] Columns modulo_a/fase_a/modulo_b/fase_b not present – skipping AB figure.")
        return

    df = df[df["sujeto"] == 0].copy()
    if df.empty:
        print("[INFO] No data for subject 0 found for AB figure.")
        return

    fig, axs = plt.subplots(2, 2, figsize=(16, 12), sharex=True)

    method_label = "Correlation"
    marker_style = "o"
    lstyle = "-"

    ab_config = [
        (0, "modulo_a", "fase_a", "Terminal A"),
        (1, "modulo_b", "fase_b", "Terminal B"),
    ]

    for row, (_, col_mod, col_fase, terminal_label) in enumerate(ab_config):
        ax_mod = axs[row, 0]
        ax_fase = axs[row, 1]
        medidas = sorted(df["medida"].unique())

        for medida in medidas:
            k_deg = k_from_medida(medida)
            color = color_from_k(k_deg)
            curva = df[df["medida"] == medida].sort_values("frecuencia")

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
        ax_mod.set_title(f"Magnitude {terminal_label} – {method_label} (k sweep)")
        ax_fase.set_title(f"Phase {terminal_label} – {method_label} (k sweep)")
        ax_mod.set_ylabel("Magnitude (Ω)")
        ax_fase.set_ylabel("Phase (deg)")
        ax_mod.grid(alpha=0.3)
        ax_fase.grid(alpha=0.3)
        ax_mod.legend(loc="best", fontsize=7, ncol=2)
        ax_fase.legend(loc="best", fontsize=7, ncol=2)

    for ax in axs[1, :]:
        ax.set_xlabel("Frequency (Hz)")

    fig.suptitle(
        f"Terminal A & B Measurements for {method_label}",
        fontsize=15, fontweight="bold", y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.03, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    print(f"[OK] AB figure: {ruta_png}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Analyze Subject 0 (Correlation) against Golden model (Subject 2)."
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
        default="analisis_correlacion_vs_golden",
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
    ruta_fig = out_prefix.with_name(f"{out_prefix.name}_results.png")
    ruta_fig_ab = out_prefix.with_name(f"{out_prefix.name}_terminals_ab.png")

    resumen_global_df.to_csv(ruta_global, index=False)
    resumen_medida_df.to_csv(ruta_medida, index=False)
    df_err.to_csv(ruta_errores, index=False)

    graficar_resultados(df_err, ruta_fig)
    graficar_ab_subfiguras(df, ruta_fig_ab)

    print("\n=== Global summary (lower is better) ===")
    print(resumen_global_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print(f"\n[OK] Global CSV: {ruta_global}")
    print(f"[OK] By-measurement CSV: {ruta_medida}")
    print(f"[OK] Error-detail CSV: {ruta_errores}")
    print(f"[OK] Results figure: {ruta_fig}")


if __name__ == "__main__":
    main()