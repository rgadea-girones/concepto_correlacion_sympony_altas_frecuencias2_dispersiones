import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Set font sizes to be at least 14
plt.rcParams.update({
    'font.size': 18,
    'axes.titlesize': 20,
    'axes.labelsize': 18,
    'xtick.labelsize': 16,
    'ytick.labelsize': 16,
    'legend.fontsize': 16,
    'figure.titlesize': 22
})

def main():
    # File paths
    csv_path = "sim/tablas_comparativas/comparacion_tiempos_nettype_vs_symphony_articulo_comparison_details.csv"
    output_dir = "sim/tablas_comparativas"
    
    # Load data
    print(f"Loading data from {csv_path}...")
    df = pd.read_csv(csv_path)
    
    # Sort data to ensure continuous plotting
    df = df.sort_values(by=['medida', 'point_index'])
    
    # Extract columns
    sim_time = df['net_tiempo_sim_s'] # same as sym_tiempo_sim_s
    net_real = df['net_tiempo_real_s']
    sym_real = df['sym_tiempo_real_s']
    ratio = df['real_time_ratio_sym_over_net']
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # -------------------------------------------------------------
    # Plot 1: Elapsed Real Time vs Simulated Time (Linear scale)
    # -------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(10, 7))
    ax.plot(sim_time, sym_real, color='tab:red', linewidth=2.5, label='Symphony (Analog/Digital Mixed-Signal)')
    ax.plot(sim_time, net_real, color='tab:blue', linewidth=2.5, label='Nettype (SystemVerilog RNM)')
    
    ax.set_title("Simulation Elapsed Real Time vs. Simulated Time", pad=15, fontweight='bold')
    ax.set_xlabel("Simulated Time (s)", labelpad=10)
    ax.set_ylabel("Elapsed Real Time (s)", labelpad=10)
    ax.grid(True, linestyle='--', alpha=0.6)
    
    # Add text annotations for final values
    final_sim = sim_time.iloc[-1]
    final_net = net_real.iloc[-1]
    final_sym = sym_real.iloc[-1]
    
    # Symphony final label
    ax.text(final_sim - 0.2, final_sym - 12000, 
            f"Symphony: {final_sym/3600:.1f} hours\n({final_sym:,.0f} s)", 
            color='tab:red', ha='right', va='top', fontweight='bold',
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="tab:red", alpha=0.8))
    
    # Nettype final label
    ax.text(final_sim - 0.2, final_net + 8000, 
            f"Nettype: {final_net/60:.1f} mins\n({final_net:,.0f} s)", 
            color='tab:blue', ha='right', va='bottom', fontweight='bold',
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="tab:blue", alpha=0.8))
    
    ax.legend(loc='upper left')
    plt.tight_layout()
    fig1_path = os.path.join(output_dir, "clear_elapsed_real_time.png")
    plt.savefig(fig1_path, dpi=300)
    plt.close()
    print(f"Saved: {fig1_path}")
    
    # -------------------------------------------------------------
    # Plot 2: Slowdown Ratio (Symphony / Nettype)
    # -------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(10, 7))
    ax.plot(sim_time, ratio, color='purple', linewidth=2.5, label='Symphony / Nettype Slowdown')
    
    ax.set_title("Symphony-to-Nettype Simulation Slowdown Factor", pad=15, fontweight='bold')
    ax.set_xlabel("Simulated Time (s)", labelpad=10)
    ax.set_ylabel("Slowdown Ratio (x times slower)", labelpad=10)
    ax.grid(True, linestyle='--', alpha=0.6)
    
    # Show mean and max slowdown
    mean_slowdown = ratio.mean()
    max_slowdown = ratio.max()
    min_slowdown = ratio.min()
    
    stats_text = (
        f"Slowdown Statistics:\n"
        f"• Max: {max_slowdown:.1f}x\n"
        f"• Mean: {mean_slowdown:.1f}x\n"
        f"• Min: {min_slowdown:.1f}x"
    )
    ax.text(0.05, 0.05, stats_text, transform=ax.transAxes,
            bbox=dict(boxstyle="round,pad=0.5", fc="whitesmoke", ec="gray", alpha=0.9),
            fontsize=16, va='bottom', ha='left')
    
    # Annotate end points of measure 0 and measure 9
    # Measure 0 ends at index ~224 (first half of the points)
    # Let's find the boundary point
    measure_0_idx = df[df['medida'] == 0].index[-1]
    boundary_sim_time = df.loc[measure_0_idx, 'net_tiempo_sim_s']
    boundary_ratio = df.loc[measure_0_idx, 'real_time_ratio_sym_over_net']
    
    ax.axvline(x=boundary_sim_time, color='gray', linestyle=':', alpha=0.8)
    ax.text(boundary_sim_time - 0.1, ratio.max() - 2, "Min Degradation\n(Measure 0)", 
            ha='right', fontsize=15, color='dimgray')
    ax.text(boundary_sim_time + 0.1, ratio.max() - 2, "Max Degradation\n(Measure 9)", 
            ha='left', fontsize=15, color='dimgray')
    
    plt.tight_layout()
    fig2_path = os.path.join(output_dir, "clear_slowdown_ratio.png")
    plt.savefig(fig2_path, dpi=300)
    plt.close()
    print(f"Saved: {fig2_path}")

    # -------------------------------------------------------------
    # Plot 3: Bar Chart of Total Execution Times (Log Scale & Linear Annotations)
    # -------------------------------------------------------------
    # Get total time per measure
    # Nettype and Symphony max real times for medida 0 and medida 9
    t_net_m0 = df[df['medida'] == 0]['net_tiempo_real_s'].max()
    t_sym_m0 = df[df['medida'] == 0]['sym_tiempo_real_s'].max()
    
    # For medida 9, let's check if the time starts from 0 or is cumulative.
    # In the csv: net_tiempo_real_s for medida 9 goes from 854s to 1586s.
    # The elapsed time in the csv seems to be cumulative since the beginning of the whole simulation suite.
    # But wait, let's see if the user wants the span of that specific measurement or the cumulative total.
    # If cumulative:
    # Measure 0 total: t_net_m0, t_sym_m0
    # Measure 9 total cumulative: df[df['medida'] == 9]['net_tiempo_real_s'].max(), etc.
    # Let's compute the span (duration) of each measurement:
    # Measure 0 duration: max - min (or just max since it starts near 0)
    # Measure 9 duration: max - min of medida 9? Or is it cumulative?
    # In the original bar chart (Panel 3: Real Time Spent per Measurement):
    # The bar height is ~110,000s for Symphony for both "Minimum degradation" and "Maximum degradation".
    # Since 222,000 / 2 is ~110,000, yes! Each measurement takes about 110,000s for Symphony, and ~800s for Nettype.
    # Let's calculate the spans:
    net_m0_span = df[df['medida'] == 0]['net_tiempo_real_s'].max() - df[df['medida'] == 0]['net_tiempo_real_s'].min()
    sym_m0_span = df[df['medida'] == 0]['sym_tiempo_real_s'].max() - df[df['medida'] == 0]['sym_tiempo_real_s'].min()
    
    net_m9_span = df[df['medida'] == 9]['net_tiempo_real_s'].max() - df[df['medida'] == 9]['net_tiempo_real_s'].min()
    sym_m9_span = df[df['medida'] == 9]['sym_tiempo_real_s'].max() - df[df['medida'] == 9]['sym_tiempo_real_s'].min()
    
    categories = ['Minimum Degradation\n(Measure 0)', 'Maximum Degradation\n(Measure 9)']
    net_spans = [net_m0_span, net_m9_span]
    sym_spans = [sym_m0_span, sym_m9_span]
    
    x = np.arange(len(categories))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(10, 7))
    # We use log scale because Symphony is 140x slower, making Nettype invisible on a linear scale bar chart
    ax.set_yscale('log')
    
    rects1 = ax.bar(x - width/2, net_spans, width, label='Nettype (SystemVerilog RNM)', color='tab:blue')
    rects2 = ax.bar(x + width/2, sym_spans, width, label='Symphony (Mixed-Signal)', color='tab:red')
    
    ax.set_title("Execution Real Time Comparison (Log Scale)", pad=15, fontweight='bold')
    ax.set_ylabel("Execution Time Span (s)", labelpad=10)
    ax.set_xticks(x)
    ax.set_xticklabels(categories)
    ax.grid(True, which="both", linestyle='--', alpha=0.5)
    ax.legend(loc='upper left')
    
    # Add values on top of the bars
    def autolabel(rects, is_symphony):
        for rect in rects:
            height = rect.get_height()
            if is_symphony:
                time_str = f"{height/3600:.1f} hrs\n({height:,.0f} s)"
            else:
                time_str = f"{height/60:.1f} mins\n({height:,.0f} s)"
            
            ax.annotate(time_str,
                        xy=(rect.get_x() + rect.get_width() / 2, height),
                        xytext=(0, 5),  # 5 points vertical offset
                        textcoords="offset points",
                        ha='center', va='bottom', fontsize=15, fontweight='bold')

    autolabel(rects1, False)
    autolabel(rects2, True)
    
    # Adjust y limits to make room for labels
    ax.set_ylim(10, 10**6)
    
    plt.tight_layout()
    fig3_path = os.path.join(output_dir, "clear_time_comparison_bars.png")
    plt.savefig(fig3_path, dpi=300)
    plt.close()
    print(f"Saved: {fig3_path}")

    # -------------------------------------------------------------
    # Plot 4: Combined Multi-panel Plot (All in one, but with size 14+ fonts and clear layout)
    # -------------------------------------------------------------
    fig, axs = plt.subplots(2, 2, figsize=(22, 17))
    
    # Panel A: Elapsed Real Time vs Simulated Time
    axs[0, 0].plot(sim_time, sym_real, color='tab:red', linewidth=2, label='Symphony')
    axs[0, 0].plot(sim_time, net_real, color='tab:blue', linewidth=2, label='Nettype')
    axs[0, 0].set_title("A. Simulation Elapsed Real Time vs. Simulated Time", fontweight='bold')
    axs[0, 0].set_xlabel("Simulated Time (s)")
    axs[0, 0].set_ylabel("Elapsed Real Time (s)")
    axs[0, 0].grid(True, linestyle='--', alpha=0.6)
    axs[0, 0].legend()
    # Annotate end values
    axs[0, 0].text(final_sim - 0.2, final_sym - 15000, f"Symphony: {final_sym/3600:.1f} h", 
                   color='tab:red', ha='right', fontweight='bold')
    axs[0, 0].text(final_sim - 0.2, final_net + 10000, f"Nettype: {final_net/60:.1f} m", 
                   color='tab:blue', ha='right', fontweight='bold')

    # Panel B: Slowdown Ratio
    axs[0, 1].plot(sim_time, ratio, color='purple', linewidth=2)
    axs[0, 1].set_title("B. Symphony-to-Nettype Slowdown Factor", fontweight='bold')
    axs[0, 1].set_xlabel("Simulated Time (s)")
    axs[0, 1].set_ylabel("Slowdown Ratio (x)")
    axs[0, 1].grid(True, linestyle='--', alpha=0.6)
    axs[0, 1].axvline(x=boundary_sim_time, color='gray', linestyle=':', alpha=0.8)
    axs[0, 1].text(boundary_sim_time - 0.1, ratio.min() + 2, "Min Degradation\n(Measure 0)", ha='right', fontsize=14, color='dimgray')
    axs[0, 1].text(boundary_sim_time + 0.1, ratio.min() + 2, "Max Degradation\n(Measure 9)", ha='left', fontsize=14, color='dimgray')

    # Panel C: Bar Chart of Total Execution Times (Log Scale)
    rects1_c = axs[1, 0].bar(x - width/2, net_spans, width, label='Nettype', color='tab:blue')
    rects2_c = axs[1, 0].bar(x + width/2, sym_spans, width, label='Symphony', color='tab:red')
    axs[1, 0].set_yscale('log')
    axs[1, 0].set_title("C. Execution Real Time Comparison (Log Scale)", fontweight='bold')
    axs[1, 0].set_ylabel("Execution Time Span (s)")
    axs[1, 0].set_xticks(x)
    axs[1, 0].set_xticklabels(categories)
    axs[1, 0].grid(True, which="both", linestyle='--', alpha=0.5)
    axs[1, 0].legend()
    # Labels on bars
    for rect in rects1_c:
        h = rect.get_height()
        axs[1, 0].annotate(f"{h/60:.1f} m", xy=(rect.get_x() + rect.get_width()/2, h),
                            xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontsize=14, fontweight='bold')
    for rect in rects2_c:
        h = rect.get_height()
        axs[1, 0].annotate(f"{h/3600:.1f} h", xy=(rect.get_x() + rect.get_width()/2, h),
                            xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontsize=14, fontweight='bold')
    axs[1, 0].set_ylim(10, 10**6)

    # Panel D: Text summary of speedup and efficiency
    axs[1, 1].axis('off')
    summary_html = (
        f"TIMING COMPARISON SUMMARY\n"
        f"=========================\n\n"
        f"• Total Simulation Span:\n"
        f"  - Nettype (SV RNM): {final_net/60:.1f} mins ({final_net:,.0f} s)\n"
        f"  - Symphony (Mixed-Signal): {final_sym/3600:.1f} hrs ({final_sym:,.0f} s)\n\n"
        f"• Average Speedup with Nettype:\n"
        f"  - Minimum Degradation: {ratio[df['medida'] == 0].mean():.1f}x faster\n"
        f"  - Maximum Degradation: {ratio[df['medida'] == 9].mean():.1f}x faster\n"
        f"  - Overall Mean Speedup: {mean_slowdown:.1f}x faster\n\n"
        f"• Key Observations:\n"
        f"  - Nettype completes in <30 minutes, whereas\n"
        f"    Symphony requires more than 2.5 days.\n"
        f"  - This represents a massive reduction in\n"
        f"    design verification cycle time."
    )
    axs[1, 1].text(0.02, 0.98, summary_html, va='top', ha='left', family='monospace', fontsize=18,
                   bbox=dict(boxstyle="round,pad=0.8", fc="whitesmoke", ec="lightgray", alpha=0.9))

    plt.suptitle("Detailed Timing Comparison: Nettype (SV RNM) vs. Symphony (Mixed-Signal)", y=0.98, fontweight='bold')
    plt.tight_layout(rect=[0.0, 0.0, 1.0, 0.95])
    plt.subplots_adjust(wspace=0.38, hspace=0.38)
    fig4_path = os.path.join(output_dir, "clear_timing_comparison_combined.png")
    plt.savefig(fig4_path, dpi=300)
    plt.close()
    print(f"Saved: {fig4_path}")

if __name__ == "__main__":
    main()
