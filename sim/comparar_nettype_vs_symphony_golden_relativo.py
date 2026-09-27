import argparse
import math
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


SUBJECT_LABELS = {
    0: "Correlation",
    1: "FFT",
    2: "Golden",
}


def k_from_medida(medida: int) -> float:
    return (float(medida) + 1.0) / 10.0


def color_from_k(k_deg: float):
    k_clamped = min(max(k_deg, 0.1), 1.0)
    k_norm = (k_clamped - 0.1) / 0.9
    return plt.cm.RdYlGn_r(k_norm)


def detectar_cambios_decada(freqs) -> list[tuple[float, str]]:
    marcas = []
    decada_previa = None
    for frecuencia in sorted({float(f) for f in freqs if float(f) > 0.0}):
        decada = math.floor(math.log10(frecuencia))
        if decada != decada_previa:
            marcas.append((frecuencia, f"Shunt/range change\n$10^{decada}$ Hz decade"))
            decada_previa = decada
    return marcas


def anotar_cambios_decada(ax, marcas: list[tuple[float, str]], show_text: bool) -> None:
    for idx, (frecuencia, etiqueta) in enumerate(marcas):
        ax.axvline(frecuencia, color="gray", linestyle=":", linewidth=0.9, alpha=0.55)
        if show_text:
            ypos = 0.98 if idx % 2 == 0 else 0.86
            ax.text(
                frecuencia,
                ypos,
                etiqueta,
                rotation=90,
                transform=ax.get_xaxis_transform(),
                va="top",
                ha="right",
                fontsize=8,
                color="dimgray",
                bbox={"facecolor": "white", "edgecolor": "none", "alpha": 0.65, "pad": 1.5},
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
    return df


def cargar_csv(path: Path, flujo: str) -> pd.DataFrame:
    df = pd.read_csv(path, engine="c")
    df = preparar_dataframe(df)
    df["flujo_origen"] = flujo
    return df


def construir_errores(df: pd.DataFrame, flujo: str, sujeto_objetivo: int) -> pd.DataFrame:
    golden = (
        df[df["sujeto"] == 2][["medida", "frecuencia", "modulo", "fase"]]
        .rename(columns={"modulo": "modulo_golden", "fase": "fase_golden"})
        .drop_duplicates(subset=["medida", "frecuencia"])
    )

    test = df[df["sujeto"] == sujeto_objetivo].copy()
    test["method"] = test["sujeto"].map(SUBJECT_LABELS)
    test["flow"] = flujo
    test["series_label"] = test["flow"] + " - " + test["method"]

    merged = test.merge(golden, on=["medida", "frecuencia"], how="inner", validate="many_to_one")
    if merged.empty:
        raise ValueError(f"No overlap between target subject and golden model for flow '{flujo}'.")

    merged["error_modulo_abs"] = (merged["modulo"] - merged["modulo_golden"]).abs()
    merged["error_fase_abs"] = (merged["fase"] - merged["fase_golden"]).abs()
    merged["error_modulo_pct"] = 100.0 * merged["error_modulo_abs"] / merged["modulo_golden"].abs().replace(0, pd.NA)
    merged["sesgo_modulo"] = merged["modulo"] - merged["modulo_golden"]
    merged["sesgo_fase"] = merged["fase"] - merged["fase_golden"]

    return merged


def resumen_global(df_err: pd.DataFrame) -> pd.DataFrame:
    return (
        df_err.groupby(["flow", "method"], as_index=False)
        .agg(
            n_points=("frecuencia", "size"),
            mae_magnitude_ohm=("error_modulo_abs", "mean"),
            rmse_magnitude_ohm=("error_modulo_abs", lambda s: (s.pow(2).mean()) ** 0.5),
            mae_magnitude_pct=("error_modulo_pct", "mean"),
            mean_bias_magnitude_ohm=("sesgo_modulo", "mean"),
            mae_phase_deg=("error_fase_abs", "mean"),
            rmse_phase_deg=("error_fase_abs", lambda s: (s.pow(2).mean()) ** 0.5),
            mean_bias_phase_deg=("sesgo_fase", "mean"),
        )
        .sort_values(["method", "flow"])
    )


def resumen_por_medida(df_err: pd.DataFrame) -> pd.DataFrame:
    return (
        df_err.groupby(["flow", "method", "medida"], as_index=False)
        .agg(
            n_points=("frecuencia", "size"),
            mae_magnitude_ohm=("error_modulo_abs", "mean"),
            mae_magnitude_pct=("error_modulo_pct", "mean"),
            mean_bias_magnitude_ohm=("sesgo_modulo", "mean"),
            mae_phase_deg=("error_fase_abs", "mean"),
            mean_bias_phase_deg=("sesgo_fase", "mean"),
        )
        .sort_values(["method", "medida", "flow"])
    )


def graficar_respuestas_vs_golden(df_err: pd.DataFrame, ruta_png: Path, method_name: str) -> None:
    fig, axs = plt.subplots(2, 2, figsize=(18, 12), sharex=False)
    marcas_decada = detectar_cambios_decada(df_err["frecuencia"])

    rows = [
        ("Nettype", f"Nettype {method_name}", "o"),
        ("Symphony", f"Symphony {method_name}", "s"),
    ]

    for fila, (flow, panel_title, marker_style) in enumerate(rows):
        datos = df_err[df_err["flow"] == flow].copy()
        medidas = sorted(datos["medida"].unique())

        for medida in medidas:
            k_deg = k_from_medida(medida)
            color = color_from_k(k_deg)
            curva = datos[datos["medida"] == medida].sort_values("frecuencia")

            axs[fila, 0].plot(
                curva["frecuencia"],
                curva["modulo"],
                color=color,
                linestyle="-",
                marker=marker_style,
                markersize=2.5,
                linewidth=1.3,
                label=f"{panel_title} k={k_deg:.1f}",
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
                label=f"{panel_title} k={k_deg:.1f}",
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
        axs[fila, 0].set_yscale("log")
        axs[fila, 0].set_title(f"Frequency Response: Magnitude - {panel_title} vs Golden")
        axs[fila, 1].set_title(f"Frequency Response: Phase - {panel_title} vs Golden")
        axs[fila, 0].set_ylabel("Magnitude (Ω)")
        axs[fila, 1].set_ylabel("Phase (deg)")
        axs[fila, 0].set_xlabel("Frequency (Hz)")
        axs[fila, 1].set_xlabel("Frequency (Hz)")
        axs[fila, 0].grid(alpha=0.3)
        axs[fila, 1].grid(alpha=0.3)
        anotar_cambios_decada(axs[fila, 0], marcas_decada, show_text=True)
        anotar_cambios_decada(axs[fila, 1], marcas_decada, show_text=False)
        axs[fila, 0].legend(loc="best", fontsize=6, ncol=2)
        axs[fila, 1].legend(loc="best", fontsize=6, ncol=2)

    fig.suptitle(
        f"Nettype and Symphony {method_name} Responses Compared Against Golden Model",
        fontsize=17,
        fontweight="bold",
        y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    plt.close(fig)


def graficar_errores(df_err: pd.DataFrame, ruta_png: Path, method_name: str) -> None:
    fig, axs = plt.subplots(2, 2, figsize=(18, 12), sharex=False)
    marcas_decada = detectar_cambios_decada(df_err["frecuencia"])
    series_config = [
        (f"Nettype - {method_name}", "tab:orange", "o"),
        (f"Symphony - {method_name}", "tab:red", "s"),
    ]

    for series_label, color, marker in series_config:
        g = df_err[df_err["series_label"] == series_label].copy()
        por_frec = g.groupby("frecuencia", as_index=False).agg(
            mean_abs_magnitude_error=("error_modulo_abs", "mean"),
            mean_abs_phase_error=("error_fase_abs", "mean"),
            mean_pct_magnitude_error=("error_modulo_pct", "mean"),
            mean_bias_phase=("sesgo_fase", "mean"),
        )

        axs[0, 0].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_magnitude_error"],
            color=color,
            marker=marker,
            markersize=4,
            linewidth=1.4,
            label=series_label,
        )
        axs[0, 1].plot(
            por_frec["frecuencia"],
            por_frec["mean_abs_phase_error"],
            color=color,
            marker=marker,
            markersize=4,
            linewidth=1.4,
            label=series_label,
        )
        axs[1, 0].plot(
            por_frec["frecuencia"],
            por_frec["mean_pct_magnitude_error"],
            color=color,
            marker=marker,
            markersize=4,
            linewidth=1.4,
            label=series_label,
        )
        axs[1, 1].plot(
            por_frec["frecuencia"],
            por_frec["mean_bias_phase"],
            color=color,
            marker=marker,
            markersize=4,
            linewidth=1.4,
            label=series_label,
        )

    axs[0, 0].set_title("Mean Magnitude Error vs Frequency")
    axs[0, 1].set_title("Mean Phase Error vs Frequency")
    axs[1, 0].set_title("Mean Relative Magnitude Error vs Frequency")
    axs[1, 1].set_title("Mean Phase Bias vs Frequency")

    axs[0, 0].set_ylabel("|Δ Magnitude| (Ω)")
    axs[0, 1].set_ylabel("|Δ Phase| (deg)")
    axs[1, 0].set_ylabel("Relative Error (%)")
    axs[1, 1].set_ylabel("Signed Δ Phase (deg)")

    for ax in axs.flat:
        ax.set_xscale("log")
        ax.set_xlabel("Frequency (Hz)")
        ax.grid(alpha=0.3)
        anotar_cambios_decada(ax, marcas_decada, show_text=ax in (axs[0, 0], axs[1, 0]))
        ax.legend(loc="best", fontsize=8)
        
    axs[0, 0].set_yscale("log")
    axs[0, 1].set_yscale("log")
    axs[1, 0].set_yscale("log")

    fig.suptitle(
        f"{method_name} Error and Bias Against Golden Model",
        fontsize=16,
        fontweight="bold",
        y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare nettype and Symphony results against the golden model with graphical summaries."
    )
    parser.add_argument("--nettype", required=True, help="Path to the nettype CSV file.")
    parser.add_argument("--symphony", required=True, help="Path to the Symphony CSV file.")
    parser.add_argument(
        "--out-prefix",
        default="comparacion_nettype_vs_symphony_golden",
        help="Output filename prefix.",
    )
    parser.add_argument(
        "--subject",
        type=int,
        choices=[0, 1],
        default=0,
        help="Target subject to analyze: 0=Correlation, 1=FFT. Default: 0.",
    )
    args = parser.parse_args()

    df_nettype = cargar_csv(Path(args.nettype), "Nettype")
    df_symphony = cargar_csv(Path(args.symphony), "Symphony")
    method_name = SUBJECT_LABELS[args.subject]

    df_err = pd.concat(
        [
            construir_errores(df_nettype, "Nettype", args.subject),
            construir_errores(df_symphony, "Symphony", args.subject),
        ],
        ignore_index=True,
    )

    out_prefix = Path(args.out_prefix)
    ruta_global = out_prefix.with_name(f"{out_prefix.name}_global_summary.csv")
    ruta_medida = out_prefix.with_name(f"{out_prefix.name}_summary_by_measurement.csv")
    ruta_detalle = out_prefix.with_name(f"{out_prefix.name}_error_details.csv")
    ruta_resp = out_prefix.with_name(f"{out_prefix.name}_responses_vs_golden.png")
    ruta_err = out_prefix.with_name(f"{out_prefix.name}_errors_vs_golden.png")

    resumen_global_df = resumen_global(df_err)
    resumen_medida_df = resumen_por_medida(df_err)

    resumen_global_df.to_csv(ruta_global, index=False)
    resumen_medida_df.to_csv(ruta_medida, index=False)
    df_err.to_csv(ruta_detalle, index=False)

    graficar_respuestas_vs_golden(df_err, ruta_resp, method_name)
    graficar_errores(df_err, ruta_err, method_name)

    print("\n=== Global summary (lower is better) ===")
    print(resumen_global_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print(f"\n[OK] Global CSV: {ruta_global}")
    print(f"[OK] By-measurement CSV: {ruta_medida}")
    print(f"[OK] Error-detail CSV: {ruta_detalle}")
    print(f"[OK] Responses figure: {ruta_resp}")
    print(f"[OK] Errors figure: {ruta_err}")


if __name__ == "__main__":
    main()