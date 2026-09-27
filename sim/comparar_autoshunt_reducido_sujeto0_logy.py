import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def load_csv(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, engine="c")
    numeric_cols = [
        "sujeto",
        "medida",
        "frecuencia",
        "modulo",
        "fase",
        "modulo_b",
        "fase_b",
    ]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    df = df.dropna(subset=["sujeto", "medida", "frecuencia", "modulo", "fase"])
    df["sujeto"] = df["sujeto"].astype(int)
    df["medida"] = df["medida"].astype(int)
    return df


def decade_from_frequency(freq: pd.Series) -> pd.Series:
    return np.floor(np.log10(freq.astype(float))).astype(int)


def build_subject0_direct(on_df: pd.DataFrame, off_df: pd.DataFrame) -> pd.DataFrame:
    s0_on = on_df[on_df["sujeto"] == 0].copy()
    s0_off = off_df[off_df["sujeto"] == 0].copy()
    merged = s0_on.merge(s0_off, on=["medida", "frecuencia"], suffixes=("_on", "_off"))
    merged["diff_modulo"] = merged["modulo_off"] - merged["modulo_on"]
    merged["abs_diff_modulo"] = merged["diff_modulo"].abs()
    merged["diff_fase"] = merged["fase_off"] - merged["fase_on"]
    merged["abs_diff_fase"] = merged["diff_fase"].abs()
    merged["ratio_modulo_b_on_off"] = merged["modulo_b_on"] / merged["modulo_b_off"].replace(0, np.nan)
    merged["decada"] = decade_from_frequency(merged["frecuencia"])
    return merged


def build_error_vs_golden(df: pd.DataFrame, label: str) -> pd.DataFrame:
    s0 = df[df["sujeto"] == 0][["medida", "frecuencia", "modulo", "fase"]].rename(
        columns={"modulo": "modulo_s0", "fase": "fase_s0"}
    )
    s2 = df[df["sujeto"] == 2][["medida", "frecuencia", "modulo", "fase"]].rename(
        columns={"modulo": "modulo_golden", "fase": "fase_golden"}
    )
    merged = s0.merge(s2, on=["medida", "frecuencia"], how="inner")
    merged["case"] = label
    merged["err_modulo"] = merged["modulo_s0"] - merged["modulo_golden"]
    merged["abs_err_modulo"] = merged["err_modulo"].abs()
    merged["err_fase"] = merged["fase_s0"] - merged["fase_golden"]
    merged["abs_err_fase"] = merged["err_fase"].abs()
    merged["pct_err_modulo"] = 100.0 * merged["abs_err_modulo"] / merged["modulo_golden"].replace(0, np.nan)
    merged["decada"] = decade_from_frequency(merged["frecuencia"])
    return merged


def build_compact_table(direct_df: pd.DataFrame, err_on: pd.DataFrame, err_off: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for measure in ["Global", 0, 9]:
        if measure == "Global":
            direct_sel = direct_df
            on_sel = err_on
            off_sel = err_off
            measure_label = "Global"
        else:
            direct_sel = direct_df[direct_df["medida"] == measure]
            on_sel = err_on[err_on["medida"] == measure]
            off_sel = err_off[err_off["medida"] == measure]
            measure_label = f"Measure {measure}"

        rows.append(
            {
                "scope": measure_label,
                "direct_mae_mod_ohm": direct_sel["abs_diff_modulo"].mean(),
                "direct_max_mod_ohm": direct_sel["abs_diff_modulo"].max(),
                "direct_mae_phase_deg": direct_sel["abs_diff_fase"].mean(),
                "autoshunt_on_mae_mod_ohm": on_sel["abs_err_modulo"].mean(),
                "autoshunt_off_mae_mod_ohm": off_sel["abs_err_modulo"].mean(),
                "autoshunt_on_mae_phase_deg": on_sel["abs_err_fase"].mean(),
                "autoshunt_off_mae_phase_deg": off_sel["abs_err_fase"].mean(),
                "autoshunt_gain_mod_ohm": off_sel["abs_err_modulo"].mean() - on_sel["abs_err_modulo"].mean(),
                "autoshunt_gain_phase_deg": off_sel["abs_err_fase"].mean() - on_sel["abs_err_fase"].mean(),
            }
        )
    return pd.DataFrame(rows)


def build_decade_table(err_on: pd.DataFrame, err_off: pd.DataFrame) -> pd.DataFrame:
    on_group = err_on.groupby(["medida", "decada"], as_index=False).agg(
        autoshunt_on_mae_mod_ohm=("abs_err_modulo", "mean"),
        autoshunt_on_mae_phase_deg=("abs_err_fase", "mean"),
    )
    off_group = err_off.groupby(["medida", "decada"], as_index=False).agg(
        autoshunt_off_mae_mod_ohm=("abs_err_modulo", "mean"),
        autoshunt_off_mae_phase_deg=("abs_err_fase", "mean"),
    )
    merged = on_group.merge(off_group, on=["medida", "decada"], how="outer")
    merged["autoshunt_gain_mod_ohm"] = merged["autoshunt_off_mae_mod_ohm"] - merged["autoshunt_on_mae_mod_ohm"]
    merged["autoshunt_gain_phase_deg"] = merged["autoshunt_off_mae_phase_deg"] - merged["autoshunt_on_mae_phase_deg"]
    return merged.sort_values(["medida", "decada"])


def build_top_points_table(direct_df: pd.DataFrame, err_on: pd.DataFrame, err_off: pd.DataFrame) -> pd.DataFrame:
    comp = err_on.merge(err_off, on=["medida", "frecuencia"], suffixes=("_on", "_off"))
    comp["autoshunt_gain_mod_ohm"] = comp["abs_err_modulo_off"] - comp["abs_err_modulo_on"]
    comp["autoshunt_gain_phase_deg"] = comp["abs_err_fase_off"] - comp["abs_err_fase_on"]
    direct_cols = direct_df[["medida", "frecuencia", "modulo_on", "modulo_off", "diff_modulo", "fase_on", "fase_off", "diff_fase"]]
    comp = comp.merge(direct_cols, on=["medida", "frecuencia"], how="left")
    return comp.sort_values("autoshunt_gain_mod_ohm", ascending=False).head(20)


def write_markdown_table(df: pd.DataFrame, path: Path) -> None:
    formatted = df.copy()
    for col in formatted.columns:
        if pd.api.types.is_numeric_dtype(formatted[col]):
            formatted[col] = formatted[col].map(lambda x: f"{x:.3f}" if pd.notna(x) else "")
    headers = [str(col) for col in formatted.columns]
    rows = formatted.astype(str).values.tolist()
    header_line = "| " + " | ".join(headers) + " |"
    separator_line = "| " + " | ".join(["---"] * len(headers)) + " |"
    row_lines = ["| " + " | ".join(row) + " |" for row in rows]
    path.write_text("\n".join([header_line, separator_line] + row_lines) + "\n", encoding="utf-8")


def add_decade_lines(ax: plt.Axes, freqs: pd.Series) -> None:
    decades = sorted({float(v) for v in freqs if float(v) > 0 and np.isclose(np.log10(v), round(np.log10(v)), atol=1e-9)})
    for freq in decades:
        ax.axvline(freq, color="gray", linestyle=":", linewidth=0.8, alpha=0.5)


def plot_figure(direct_df: pd.DataFrame, err_on: pd.DataFrame, err_off: pd.DataFrame, out_path: Path) -> None:
    plt.style.use("default")
    fig, axs = plt.subplots(2, 2, figsize=(15, 10), sharex="col")
    measure_titles = {0: "Minimum degradation (measure 0)", 9: "Maximum degradation (measure 9)"}
    colors = {
        "on": "#0f766e",
        "off": "#b45309",
        "golden": "#1f2937",
        "delta": "#7c3aed",
    }

    for col, measure in enumerate([0, 9]):
        sub_on = err_on[err_on["medida"] == measure].sort_values("frecuencia")
        sub_off = err_off[err_off["medida"] == measure].sort_values("frecuencia")
        sub_direct = direct_df[direct_df["medida"] == measure].sort_values("frecuencia")

        ax_top = axs[0, col]
        ax_top.plot(sub_on["frecuencia"], sub_on["modulo_golden"], color=colors["golden"], linestyle="--", linewidth=1.8, label="Golden")
        ax_top.plot(sub_on["frecuencia"], sub_on["modulo_s0"], color=colors["on"], linewidth=1.5, label="Subject 0 with autoshunt")
        ax_top.plot(sub_off["frecuencia"], sub_off["modulo_s0"], color=colors["off"], linewidth=1.5, label="Subject 0 without autoshunt")
        ax_top.set_xscale("log")
        ax_top.set_yscale("log")
        ax_top.set_title(measure_titles[measure])
        ax_top.set_ylabel("Magnitude (ohm)")
        ax_top.grid(alpha=0.25)
        add_decade_lines(ax_top, sub_on["frecuencia"])

        ax_bottom = axs[1, col]
        ax_bottom.plot(sub_on["frecuencia"], sub_on["abs_err_modulo"], color=colors["on"], linewidth=1.5, label="|Error| with autoshunt")
        ax_bottom.plot(sub_off["frecuencia"], sub_off["abs_err_modulo"], color=colors["off"], linewidth=1.5, label="|Error| without autoshunt")
        ax_bottom.plot(sub_direct["frecuencia"], sub_direct["abs_diff_modulo"], color=colors["delta"], linewidth=1.2, linestyle=":", label="Direct |delta| between both runs")
        ax_bottom.set_xscale("log")
        ax_bottom.set_yscale("log")
        ax_bottom.set_xlabel("Frequency (Hz)")
        ax_bottom.set_ylabel("Absolute magnitude error (ohm)")
        ax_bottom.grid(alpha=0.25)
        add_decade_lines(ax_bottom, sub_on["frecuencia"])

    handles, labels = axs[0, 0].get_legend_handles_labels()
    handles2, labels2 = axs[1, 0].get_legend_handles_labels()
    fig.legend(handles + handles2, labels + labels2, loc="upper center", ncol=3, frameon=False, bbox_to_anchor=(0.5, 0.98))
    fig.suptitle("Reduced nettype experiment: subject 0 with and without autoshunt", fontsize=16, fontweight="bold", y=0.995)
    fig.tight_layout(rect=[0, 0, 1, 0.93])
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare reduced nettype subject 0 with and without autoshunt.")
    parser.add_argument("--autoshunt-on", required=True, help="CSV for reduced nettype run with autoshunt enabled.")
    parser.add_argument("--autoshunt-off", required=True, help="CSV for reduced nettype run with autoshunt disabled.")
    parser.add_argument("--out-prefix", required=True, help="Output file prefix.")
    args = parser.parse_args()

    on_df = load_csv(Path(args.autoshunt_on))
    off_df = load_csv(Path(args.autoshunt_off))

    direct_df = build_subject0_direct(on_df, off_df)
    err_on = build_error_vs_golden(on_df, "autoshunt_on")
    err_off = build_error_vs_golden(off_df, "autoshunt_off")

    compact_table = build_compact_table(direct_df, err_on, err_off)
    decade_table = build_decade_table(err_on, err_off)
    top_points = build_top_points_table(direct_df, err_on, err_off)

    out_prefix = Path(args.out_prefix)
    compact_csv = out_prefix.with_name(out_prefix.name + "_compact_table.csv")
    compact_md = out_prefix.with_name(out_prefix.name + "_compact_table.md")
    decade_csv = out_prefix.with_name(out_prefix.name + "_decade_table.csv")
    top_csv = out_prefix.with_name(out_prefix.name + "_top_points.csv")
    figure_png = out_prefix.with_name(out_prefix.name + "_figure.png")

    compact_table.to_csv(compact_csv, index=False)
    write_markdown_table(compact_table, compact_md)
    decade_table.to_csv(decade_csv, index=False)
    top_points.to_csv(top_csv, index=False)
    plot_figure(direct_df, err_on, err_off, figure_png)

    print(f"Wrote {compact_csv}")
    print(f"Wrote {compact_md}")
    print(f"Wrote {decade_csv}")
    print(f"Wrote {top_csv}")
    print(f"Wrote {figure_png}")


if __name__ == "__main__":
    main()