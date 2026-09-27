import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


SUBJECT_LABELS = {
    0: "Correlation (Subject 0)",
    1: "FFT (Subject 1)",
    2: "Golden (Subject 2)",
}

FLOW_COLORS = {
    "Nettype": "tab:blue",
    "Symphony": "tab:red",
}

SUBJECT_MARKERS = {
    0: "o",
    1: "s",
    2: "^",
}


def medida_label(medida: int) -> str:
    if medida == 0:
        return "Minimum degradation"
    if medida == 9:
        return "Maximum degradation"
    return f"Measure {medida}"


def preparar_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    columnas = {
        "sujeto",
        "medida",
        "frecuencia",
        "tiempo_simulacion",
        "tiempo_transcurrido_real",
    }
    faltantes = columnas.difference(df.columns)
    if faltantes:
        raise ValueError(f"Missing required columns: {sorted(faltantes)}")

    df = df.copy()
    for col in ["sujeto", "medida"]:
        df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
    for col in ["frecuencia", "tiempo_simulacion", "tiempo_transcurrido_real"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df = df.dropna(subset=["sujeto", "medida", "frecuencia", "tiempo_simulacion", "tiempo_transcurrido_real"])
    df["sujeto"] = df["sujeto"].astype(int)
    df["medida"] = df["medida"].astype(int)
    df["tiempo_simulacion_s"] = df["tiempo_simulacion"] / 1e9
    df["tiempo_real_s"] = df["tiempo_transcurrido_real"]
    return df


def cargar_csv(path: Path, flujo: str, sujeto_objetivo: int) -> pd.DataFrame:
    df = pd.read_csv(path, engine="c")
    df = preparar_dataframe(df)
    df = df[df["sujeto"] == sujeto_objetivo].copy()
    df["flow"] = flujo
    df["subject_label"] = df["sujeto"].map(SUBJECT_LABELS)
    return df


def construir_comparacion(df_net: pd.DataFrame, df_sym: pd.DataFrame) -> pd.DataFrame:
    key_cols = ["sujeto", "medida", "frecuencia"]
    left = df_net[key_cols + ["tiempo_simulacion_s", "tiempo_real_s"]].rename(
        columns={
            "tiempo_simulacion_s": "net_tiempo_sim_s",
            "tiempo_real_s": "net_tiempo_real_s",
        }
    )
    right = df_sym[key_cols + ["tiempo_simulacion_s", "tiempo_real_s"]].rename(
        columns={
            "tiempo_simulacion_s": "sym_tiempo_sim_s",
            "tiempo_real_s": "sym_tiempo_real_s",
        }
    )

    merged = left.merge(right, on=key_cols, how="inner", validate="one_to_one")
    if merged.empty:
        raise ValueError("No common timing points between nettype and Symphony.")

    merged["subject_label"] = merged["sujeto"].map(SUBJECT_LABELS)
    merged["real_time_ratio_sym_over_net"] = merged["sym_tiempo_real_s"] / merged["net_tiempo_real_s"].replace(0, pd.NA)
    merged["real_time_delta_s"] = merged["sym_tiempo_real_s"] - merged["net_tiempo_real_s"]
    merged["sim_time_delta_s"] = merged["sym_tiempo_sim_s"] - merged["net_tiempo_sim_s"]

    merged = merged.sort_values(["sujeto", "medida", "frecuencia"])
    merged["point_index"] = merged.groupby(["sujeto", "medida"]).cumcount() + 1
    return merged


def resumen_global(df: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for (flow, sujeto), g in df.groupby(["flow", "sujeto"], sort=True):
        g = g.sort_values(["medida", "frecuencia"])
        sim_span = g["tiempo_simulacion_s"].max() - g["tiempo_simulacion_s"].min()
        real_span = g["tiempo_real_s"].max() - g["tiempo_real_s"].min()
        filas.append(
            {
                "flow": flow,
                "sujeto": sujeto,
                "subject_label": SUBJECT_LABELS.get(sujeto, str(sujeto)),
                "n_points": len(g),
                "sim_time_start_s": g["tiempo_simulacion_s"].min(),
                "sim_time_end_s": g["tiempo_simulacion_s"].max(),
                "sim_time_span_s": sim_span,
                "real_time_start_s": g["tiempo_real_s"].min(),
                "real_time_end_s": g["tiempo_real_s"].max(),
                "real_time_span_s": real_span,
                "real_seconds_per_simulated_second": real_span / sim_span if sim_span else pd.NA,
                "simulated_seconds_per_real_second": sim_span / real_span if real_span else pd.NA,
            }
        )
    return pd.DataFrame(filas).sort_values(["sujeto", "flow"])


def resumen_por_medida(df: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for (flow, sujeto, medida), g in df.groupby(["flow", "sujeto", "medida"], sort=True):
        g = g.sort_values("frecuencia")
        sim_span = g["tiempo_simulacion_s"].max() - g["tiempo_simulacion_s"].min()
        real_span = g["tiempo_real_s"].max() - g["tiempo_real_s"].min()
        filas.append(
            {
                "flow": flow,
                "sujeto": sujeto,
                "subject_label": SUBJECT_LABELS.get(sujeto, str(sujeto)),
                "medida": medida,
                "n_points": len(g),
                "freq_start_hz": g["frecuencia"].min(),
                "freq_end_hz": g["frecuencia"].max(),
                "sim_time_span_s": sim_span,
                "real_time_span_s": real_span,
                "real_seconds_per_simulated_second": real_span / sim_span if sim_span else pd.NA,
            }
        )
    return pd.DataFrame(filas).sort_values(["sujeto", "medida", "flow"])


def resumen_comparativo(df_cmp: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for (sujeto, medida), g in df_cmp.groupby(["sujeto", "medida"], sort=True):
        filas.append(
            {
                "sujeto": sujeto,
                "subject_label": SUBJECT_LABELS.get(sujeto, str(sujeto)),
                "medida": medida,
                "n_points": len(g),
                "net_real_end_s": g["net_tiempo_real_s"].max(),
                "sym_real_end_s": g["sym_tiempo_real_s"].max(),
                "slowdown_final_sym_over_net": g["sym_tiempo_real_s"].max() / g["net_tiempo_real_s"].max(),
                "mean_ratio_sym_over_net": g["real_time_ratio_sym_over_net"].mean(),
                "median_ratio_sym_over_net": g["real_time_ratio_sym_over_net"].median(),
                "max_ratio_sym_over_net": g["real_time_ratio_sym_over_net"].max(),
                "max_real_gap_s": g["real_time_delta_s"].max(),
                "mean_real_gap_s": g["real_time_delta_s"].mean(),
                "max_abs_sim_gap_s": g["sim_time_delta_s"].abs().max(),
            }
        )
    return pd.DataFrame(filas).sort_values(["sujeto", "medida"])


def graficar_tiempos(df: pd.DataFrame, df_cmp: pd.DataFrame, ruta_png: Path) -> None:
    fig, axs = plt.subplots(3, 2, figsize=(18, 16), sharex=False)

    for (flow, sujeto), g in df.groupby(["flow", "sujeto"], sort=True):
        g = g.sort_values(["medida", "frecuencia"])
        axs[0, 0].plot(
            g["tiempo_simulacion_s"],
            g["tiempo_real_s"],
            color=FLOW_COLORS[flow],
            marker=SUBJECT_MARKERS[sujeto],
            markersize=3,
            linewidth=1.3,
            alpha=0.85,
            label=f"{flow} - {SUBJECT_LABELS[sujeto]}",
        )

    for sujeto in sorted(df_cmp["sujeto"].unique()):
        g = df_cmp[df_cmp["sujeto"] == sujeto].sort_values(["medida", "frecuencia"])
        axs[0, 1].plot(
            g["net_tiempo_sim_s"],
            g["real_time_ratio_sym_over_net"],
            marker=SUBJECT_MARKERS[sujeto],
            markersize=3,
            linewidth=1.3,
            label=SUBJECT_LABELS[sujeto],
        )

    medidas_labels = []
    x_positions = []
    width = 0.35
    cursor = 0
    for sujeto in sorted(df["sujeto"].unique()):
        for medida in sorted(df[df["sujeto"] == sujeto]["medida"].unique()):
            net_slice = df[(df["flow"] == "Nettype") & (df["sujeto"] == sujeto) & (df["medida"] == medida)].copy()
            sym_slice = df[(df["flow"] == "Symphony") & (df["sujeto"] == sujeto) & (df["medida"] == medida)].copy()
            net_slice = net_slice.sort_values("frecuencia")
            sym_slice = sym_slice.sort_values("frecuencia")

            net_span = 0.0
            sym_span = 0.0
            if not net_slice.empty:
                net_span = net_slice["tiempo_real_s"].max() - net_slice["tiempo_real_s"].min()
            if not sym_slice.empty:
                sym_span = sym_slice["tiempo_real_s"].max() - sym_slice["tiempo_real_s"].min()

            x_positions.append(cursor)
            medidas_labels.append(f"{SUBJECT_LABELS[sujeto].split(' (')[0]}\n{medida_label(medida)}")
            axs[1, 0].bar(cursor - width / 2, net_span, width=width, color=FLOW_COLORS["Nettype"])
            axs[1, 0].bar(cursor + width / 2, sym_span, width=width, color=FLOW_COLORS["Symphony"])
            cursor += 1

    for (flow, sujeto), g in df.groupby(["flow", "sujeto"], sort=True):
        g = g.sort_values(["medida", "frecuencia"]).copy()
        g["delta_real_s"] = g["tiempo_real_s"].diff().fillna(g["tiempo_real_s"])
        axs[1, 1].plot(
            range(1, len(g) + 1),
            g["delta_real_s"],
            color=FLOW_COLORS[flow],
            marker=SUBJECT_MARKERS[sujeto],
            markersize=3,
            linewidth=1.1,
            alpha=0.8,
            label=f"{flow} - {SUBJECT_LABELS[sujeto]}",
        )

    axs[0, 0].set_title("Elapsed Real Time vs Simulated Time")
    axs[0, 0].set_xlabel("Simulated Time (s)")
    axs[0, 0].set_ylabel("Elapsed Real Time (s)")
    axs[0, 0].grid(alpha=0.3)
    axs[0, 0].legend(loc="best", fontsize=8)

    axs[0, 1].set_title("Symphony / Nettype Real-Time Ratio")
    axs[0, 1].set_xlabel("Simulated Time (s)")
    axs[0, 1].set_ylabel("Slowdown Ratio")
    axs[0, 1].grid(alpha=0.3)
    axs[0, 1].legend(loc="best", fontsize=8)

    axs[1, 0].set_title("Real Time Spent per Measurement")
    axs[1, 0].set_xlabel("Method and k Extremum")
    axs[1, 0].set_ylabel("Real Time Span (s)")
    axs[1, 0].set_xticks(x_positions)
    axs[1, 0].set_xticklabels(medidas_labels, rotation=45, ha="right")
    axs[1, 0].grid(alpha=0.3, axis="y")
    axs[1, 0].legend(handles=[
        plt.Line2D([0], [0], color=FLOW_COLORS["Nettype"], lw=8, label="Nettype"),
        plt.Line2D([0], [0], color=FLOW_COLORS["Symphony"], lw=8, label="Symphony"),
    ], loc="best")

    axs[1, 1].set_title("Incremental Real Time per Saved Point")
    axs[1, 1].set_xlabel("Saved Point Index")
    axs[1, 1].set_ylabel("Δ Real Time (s)")
    axs[1, 1].grid(alpha=0.3)
    axs[1, 1].legend(loc="best", fontsize=8)

    slowdown_rows = []
    for _, row in df_cmp.groupby(["sujeto", "medida"], sort=True).agg(
        mean_ratio_sym_over_net=("real_time_ratio_sym_over_net", "mean"),
        median_ratio_sym_over_net=("real_time_ratio_sym_over_net", "median"),
    ).reset_index().iterrows():
        slowdown_rows.append(row)

    slowdown_labels = []
    slowdown_means = []
    slowdown_medians = []
    for row in slowdown_rows:
        slowdown_labels.append(f"{SUBJECT_LABELS[int(row['sujeto'])].split(' (')[0]}\n{medida_label(int(row['medida']))}")
        slowdown_means.append(float(row["mean_ratio_sym_over_net"]))
        slowdown_medians.append(float(row["median_ratio_sym_over_net"]))

    x = range(len(slowdown_labels))
    axs[2, 0].bar([i - width / 2 for i in x], slowdown_means, width=width, color="tab:purple", label="Mean slowdown")
    axs[2, 0].bar([i + width / 2 for i in x], slowdown_medians, width=width, color="tab:cyan", label="Median slowdown")
    axs[2, 0].set_title("Symphony-to-Nettype Slowdown by Measurement")
    axs[2, 0].set_xlabel("Method and degradation level")
    axs[2, 0].set_ylabel("Slowdown ratio")
    axs[2, 0].set_xticks(list(x))
    axs[2, 0].set_xticklabels(slowdown_labels, rotation=0)
    axs[2, 0].grid(alpha=0.3, axis="y")
    axs[2, 0].legend(loc="best")

    axs[2, 1].axis("off")
    if slowdown_means:
        summary_text = "\n".join(
            f"{label}: mean {mean:.2f}x, median {median:.2f}x"
            for label, mean, median in zip(slowdown_labels, slowdown_means, slowdown_medians)
        )
        axs[2, 1].text(
            0.02,
            0.98,
            "Slowdown Summary\n\n" + summary_text,
            va="top",
            ha="left",
            fontsize=11,
            bbox={"facecolor": "whitesmoke", "edgecolor": "lightgray", "boxstyle": "round,pad=0.5"},
        )

    fig.suptitle(
        "Detailed Timing Comparison: Nettype vs Symphony",
        fontsize=16,
        fontweight="bold",
        y=0.995,
    )
    fig.tight_layout(rect=[0.0, 0.0, 1.0, 0.97])
    fig.savefig(ruta_png, dpi=150)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Analyze simulated time and PC real time for Nettype vs Symphony."
    )
    parser.add_argument("--nettype", required=True, help="Path to the nettype CSV file.")
    parser.add_argument("--symphony", required=True, help="Path to the Symphony CSV file.")
    parser.add_argument(
        "--out-prefix",
        default="comparacion_tiempos_nettype_vs_symphony",
        help="Output filename prefix.",
    )
    parser.add_argument(
        "--subject",
        type=int,
        choices=[0, 1, 2],
        default=0,
        help="Target subject to analyze: 0=Correlation, 1=FFT, 2=Golden. Default: 0.",
    )
    args = parser.parse_args()

    df_net = cargar_csv(Path(args.nettype), "Nettype", args.subject)
    df_sym = cargar_csv(Path(args.symphony), "Symphony", args.subject)
    df_all = pd.concat([df_net, df_sym], ignore_index=True)
    df_cmp = construir_comparacion(df_net, df_sym)

    out_prefix = Path(args.out_prefix)
    ruta_global = out_prefix.with_name(f"{out_prefix.name}_global_summary.csv")
    ruta_medida = out_prefix.with_name(f"{out_prefix.name}_summary_by_measurement.csv")
    ruta_cmp = out_prefix.with_name(f"{out_prefix.name}_comparison_details.csv")
    ruta_fig = out_prefix.with_name(f"{out_prefix.name}_timing_plots.png")

    global_df = resumen_global(df_all)
    medida_df = resumen_por_medida(df_all)
    comparativo_df = resumen_comparativo(df_cmp)

    global_df.to_csv(ruta_global, index=False)
    medida_df.to_csv(ruta_medida, index=False)
    df_cmp.to_csv(ruta_cmp, index=False)
    graficar_tiempos(df_all, df_cmp, ruta_fig)

    print("\n=== Global timing summary ===")
    print(global_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print("\n=== Comparative summary ===")
    print(comparativo_df.to_string(index=False, float_format=lambda x: f"{x:,.6f}"))
    print(f"\n[OK] Global CSV: {ruta_global}")
    print(f"[OK] By-measurement CSV: {ruta_medida}")
    print(f"[OK] Comparison-detail CSV: {ruta_cmp}")
    print(f"[OK] Figure: {ruta_fig}")


if __name__ == "__main__":
    main()