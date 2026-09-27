import os
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import CheckButtons, Button
import seaborn as sns


class VisualizadorInteractivoYake:
    def __init__(self, archivo="datos_simulacion_nuevo.csv"):
        self.archivo = archivo
        self.df = None
        self.df_4p = None
        self.df_3p = None
        self.df_golden = None
        self.medidas_disponibles = []

        self.lines_4p_mag = {}
        self.lines_4p_fase = {}
        self.lines_4p_golden_mag = {}
        self.lines_4p_golden_fase = {}

        self.lines_3p_mag = {}
        self.lines_3p_fase = {}
        self.lines_3p_golden_mag = {}
        self.lines_3p_golden_fase = {}

        self.check_medidas = None

        self.cargar_datos()
        self.configurar_interfaz()

    @staticmethod
    def k_from_medida(medida: int) -> float:
        return (float(medida) + 1.0) / 10.0

    @staticmethod
    def color_from_k(k_deg: float):
        k_clamped = min(max(k_deg, 0.1), 1.0)
        k_norm = (k_clamped - 0.1) / 0.9
        return plt.cm.RdYlGn_r(k_norm)

    def cargar_datos(self):
        if not os.path.exists(self.archivo):
            print(f"Error: No se encontró {self.archivo}")
            return False

        self.df = pd.read_csv(self.archivo, engine="c")
        self.df_4p = self.df[self.df["sujeto"] == 0].copy()
        self.df_3p = self.df[self.df["sujeto"] == 1].copy()
        self.df_golden = self.df[self.df["sujeto"] == 2].copy()

        medidas_4p = set(self.df_4p["medida"].unique()) if not self.df_4p.empty else set()
        medidas_3p = set(self.df_3p["medida"].unique()) if not self.df_3p.empty else set()
        medidas_golden = set(self.df_golden["medida"].unique()) if not self.df_golden.empty else set()

        # Para comparación consistente, usamos medidas presentes en los tres sujetos
        medidas_comunes = sorted(list(medidas_4p & medidas_3p & medidas_golden))
        self.medidas_disponibles = medidas_comunes

        print(
            f"Datos cargados: {len(self.medidas_disponibles)} medidas comunes "
            f"(sujetos 0/1/2)"
        )
        return True

    def configurar_interfaz(self):
        sns.set_theme(style="whitegrid")

        self.fig = plt.figure(figsize=(19, 10))
        gs = self.fig.add_gridspec(
            2,
            3,
            width_ratios=[3.4, 3.4, 1.8],
            height_ratios=[1, 1],
            hspace=0.3,
            wspace=0.25,
        )

        self.ax_mag_4p = self.fig.add_subplot(gs[0, 0])
        self.ax_mag_3p = self.fig.add_subplot(gs[0, 1], sharex=self.ax_mag_4p)
        self.ax_fase_4p = self.fig.add_subplot(gs[1, 0], sharex=self.ax_mag_4p)
        self.ax_fase_3p = self.fig.add_subplot(gs[1, 1], sharex=self.ax_mag_4p)

        ax_control = self.fig.add_subplot(gs[:, 2])
        ax_control.axis("off")

        ax_check_medidas = self.fig.add_axes([0.79, 0.25, 0.18, 0.55])
        medidas_labels = [
            f"M{m} | k={self.k_from_medida(m):.1f}" for m in self.medidas_disponibles
        ]
        medidas_activas = [True] * len(self.medidas_disponibles)
        self.check_medidas = CheckButtons(ax_check_medidas, medidas_labels, medidas_activas)
        ax_check_medidas.set_title("Seleccionar medidas", fontweight="bold", loc="left")

        ax_btn_todas = self.fig.add_axes([0.79, 0.16, 0.085, 0.045])
        ax_btn_ninguna = self.fig.add_axes([0.885, 0.16, 0.085, 0.045])
        self.btn_todas = Button(ax_btn_todas, "All")
        self.btn_ninguna = Button(ax_btn_ninguna, "None")

        self.check_medidas.on_clicked(self.actualizar_graficos)
        self.btn_todas.on_clicked(self.seleccionar_todas_medidas)
        self.btn_ninguna.on_clicked(self.seleccionar_ninguna_medida)

        self.dibujar_graficos_iniciales()

    def dibujar_graficos_iniciales(self):
        for medida in self.medidas_disponibles:
            k_deg = self.k_from_medida(medida)
            color = self.color_from_k(k_deg)

            df4 = self.df_4p[self.df_4p["medida"] == medida].sort_values("frecuencia")
            df3 = self.df_3p[self.df_3p["medida"] == medida].sort_values("frecuencia")
            dfg = self.df_golden[self.df_golden["medida"] == medida].sort_values("frecuencia")

            if not df4.empty:
                l4m, = self.ax_mag_4p.plot(
                    df4["frecuencia"],
                    df4["modulo"],
                    color=color,
                    linestyle="-",
                    marker="o",
                    markersize=3.5,
                    linewidth=1.8,
                    label=f"4P k={k_deg:.1f}",
                )
                l4f, = self.ax_fase_4p.plot(
                    df4["frecuencia"],
                    df4["fase"],
                    color=color,
                    linestyle="-",
                    marker="o",
                    markersize=3.5,
                    linewidth=1.8,
                    label=f"4P k={k_deg:.1f}",
                )
                self.lines_4p_mag[medida] = l4m
                self.lines_4p_fase[medida] = l4f

            if not df3.empty:
                l3m, = self.ax_mag_3p.plot(
                    df3["frecuencia"],
                    df3["modulo"],
                    color=color,
                    linestyle="-",
                    marker="s",
                    markersize=3.5,
                    linewidth=1.8,
                    label=f"3P k={k_deg:.1f}",
                )
                l3f, = self.ax_fase_3p.plot(
                    df3["frecuencia"],
                    df3["fase"],
                    color=color,
                    linestyle="-",
                    marker="s",
                    markersize=3.5,
                    linewidth=1.8,
                    label=f"3P k={k_deg:.1f}",
                )
                self.lines_3p_mag[medida] = l3m
                self.lines_3p_fase[medida] = l3f

            if not dfg.empty:
                g4m, = self.ax_mag_4p.plot(
                    dfg["frecuencia"],
                    dfg["modulo"],
                    color=color,
                    linestyle="--",
                    linewidth=2.0,
                    alpha=0.95,
                    label=f"Golden k={k_deg:.1f}",
                )
                g4f, = self.ax_fase_4p.plot(
                    dfg["frecuencia"],
                    dfg["fase"],
                    color=color,
                    linestyle="--",
                    linewidth=2.0,
                    alpha=0.95,
                    label=f"Golden k={k_deg:.1f}",
                )
                g3m, = self.ax_mag_3p.plot(
                    dfg["frecuencia"],
                    dfg["modulo"],
                    color=color,
                    linestyle="--",
                    linewidth=2.0,
                    alpha=0.95,
                    label=f"Golden k={k_deg:.1f}",
                )
                g3f, = self.ax_fase_3p.plot(
                    dfg["frecuencia"],
                    dfg["fase"],
                    color=color,
                    linestyle="--",
                    linewidth=2.0,
                    alpha=0.95,
                    label=f"Golden k={k_deg:.1f}",
                )
                self.lines_4p_golden_mag[medida] = g4m
                self.lines_4p_golden_fase[medida] = g4f
                self.lines_3p_golden_mag[medida] = g3m
                self.lines_3p_golden_fase[medida] = g3f

        self.ax_mag_4p.set_xscale("log")
        self.ax_mag_3p.set_xscale("log")
        self.ax_fase_4p.set_xscale("log")
        self.ax_fase_3p.set_xscale("log")

        self.ax_mag_4p.set_ylabel("Magnitude (Ω)", fontweight="bold")
        self.ax_fase_4p.set_ylabel("Phase (degrees)", fontweight="bold")
        self.ax_fase_4p.set_xlabel("Frequency (Hz)", fontweight="bold")
        self.ax_fase_3p.set_xlabel("Frequency (Hz)", fontweight="bold")

        self.ax_mag_4p.set_title("4P vs Golden (k sweep)", fontweight="bold")
        self.ax_mag_3p.set_title("3P vs Golden (k sweep)", fontweight="bold")

        for ax in [self.ax_mag_4p, self.ax_mag_3p, self.ax_fase_4p, self.ax_fase_3p]:
            ax.grid(True, alpha=0.3)

        self.actualizar_leyendas()

    def actualizar_graficos(self, _label):
        estados_medidas = self.check_medidas.get_status()
        medidas_activas = [self.medidas_disponibles[i] for i, act in enumerate(estados_medidas) if act]

        for medida in self.medidas_disponibles:
            visible = medida in medidas_activas

            if medida in self.lines_4p_mag:
                self.lines_4p_mag[medida].set_visible(visible)
            if medida in self.lines_4p_fase:
                self.lines_4p_fase[medida].set_visible(visible)
            if medida in self.lines_3p_mag:
                self.lines_3p_mag[medida].set_visible(visible)
            if medida in self.lines_3p_fase:
                self.lines_3p_fase[medida].set_visible(visible)

            if medida in self.lines_4p_golden_mag:
                self.lines_4p_golden_mag[medida].set_visible(visible)
            if medida in self.lines_4p_golden_fase:
                self.lines_4p_golden_fase[medida].set_visible(visible)
            if medida in self.lines_3p_golden_mag:
                self.lines_3p_golden_mag[medida].set_visible(visible)
            if medida in self.lines_3p_golden_fase:
                self.lines_3p_golden_fase[medida].set_visible(visible)

        self.actualizar_leyendas()
        self.fig.canvas.draw_idle()

    @staticmethod
    def actualizar_leyenda_axis(ax, ncol=2):
        handles, labels = ax.get_legend_handles_labels()
        visibles = [(h, l) for h, l in zip(handles, labels) if h.get_visible()]
        if visibles:
            h_vis, l_vis = zip(*visibles)
            ax.legend(h_vis, l_vis, loc="best", fontsize=7.5, ncol=ncol)

    def actualizar_leyendas(self):
        self.actualizar_leyenda_axis(self.ax_mag_4p, ncol=2)
        self.actualizar_leyenda_axis(self.ax_mag_3p, ncol=2)
        self.actualizar_leyenda_axis(self.ax_fase_4p, ncol=2)
        self.actualizar_leyenda_axis(self.ax_fase_3p, ncol=2)

    def seleccionar_todas_medidas(self, _event):
        for i in range(len(self.medidas_disponibles)):
            if not self.check_medidas.get_status()[i]:
                self.check_medidas.set_active(i)

    def seleccionar_ninguna_medida(self, _event):
        for i in range(len(self.medidas_disponibles)):
            if self.check_medidas.get_status()[i]:
                self.check_medidas.set_active(i)

    def mostrar(self):
        plt.savefig("frequency_response_interactive_yake_kdeg.png", dpi=150, bbox_inches="tight")
        print("\n[Python] Interactive visualization generated.")
        print("  • Panel izquierdo: 4P vs Golden")
        print("  • Panel derecho: 3P vs Golden")
        print("  • Checkboxes: seleccionar medida/k_degradacion")
        plt.show()


def principal():
    archivo = "datos_simulacion_nuevo.csv"

    if not os.path.exists(archivo):
        archivos_csv = [f for f in os.listdir('.') if f.endswith('.csv')]
        if archivos_csv:
            archivo = archivos_csv[0]
            print(f"Usando archivo alternativo: {archivo}")
        else:
            print("No se encontraron archivos CSV en el directorio actual.")
            return

    visualizador = VisualizadorInteractivoYake(archivo)
    visualizador.mostrar()


if __name__ == "__main__":
    principal()
