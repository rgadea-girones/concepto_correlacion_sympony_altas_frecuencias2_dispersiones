import matplotlib.pyplot as plt
import numpy as np

# Configure larger font sizes
plt.rcParams.update({
    'font.size': 16,
    'axes.titlesize': 18,
    'axes.labelsize': 16,
    'xtick.labelsize': 14,
    'ytick.labelsize': 14,
    'legend.fontsize': 14,
})

def main():
    categories = ["Peak Frequency", "Peak Phase", "Maximum Magnitude"]
    importance_4point = [0.36, 0.36, 0.28]
    importance_3point = [0.43, 0.22, 0.34]

    x = np.arange(len(categories))
    width = 0.35  # width of the bars

    fig, ax = plt.subplots(figsize=(12, 7))

    # Using similar colors to the original plot:
    # 4-Point: Muted green (#5cb85c or similar)
    # 3-Point: Muted red (#d9534f or similar)
    rects1 = ax.bar(x - width/2, importance_4point, width, label='4-Point', color='#5cb85c')
    rects2 = ax.bar(x + width/2, importance_3point, width, label='3-Point', color='#d9534f')

    # Add text labels, titles and custom x-axis tick labels, etc.
    ax.set_ylabel('Relative Importance')
    ax.set_title('Feature Importance Comparison: 4-Point vs 3-Point')
    ax.set_xticks(x)
    ax.set_xticklabels(categories)
    ax.set_ylim(0, 0.47)  # Give some headroom for labels
    ax.legend(loc='upper right')

    # Attach a text label above each bar in rects1 and rects2, displaying its height.
    # Using a slightly smaller font size for the bar labels to keep them clean
    ax.bar_label(rects1, padding=5, fmt='%.2f', fontsize=14)
    ax.bar_label(rects2, padding=5, fmt='%.2f', fontsize=14)

    fig.tight_layout()

    output_path = "fig8_feature_importance.png"
    plt.savefig(output_path, dpi=150)
    print(f"[OK] Grafica guardada en: {output_path}")

if __name__ == "__main__":
    main()
