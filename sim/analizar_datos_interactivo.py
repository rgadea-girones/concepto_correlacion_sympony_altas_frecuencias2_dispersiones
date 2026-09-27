import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import CheckButtons, Button
import seaborn as sns
import os
import numpy as np

class VisualizadorInteractivo:
    def __init__(self, archivo="datos_simulacion_nuevo.csv"):
        self.archivo = archivo
        self.df = None
        self.df_golden_pares = None
        self.df_golden_impares = None
        self.df_test = None
        self.medidas_disponibles = []
        self.sujetos_disponibles = []
        self.lines_mag = {}
        self.lines_fase = {}
        self.golden_mag_par = None
        self.golden_mag_impar = None
        self.golden_fase_par = None
        self.golden_fase_impar = None
        self.check_medidas = None
        self.check_sujetos = None
        
        # Cargar datos
        self.cargar_datos()
        
        # Configurar la interfaz
        self.configurar_interfaz()
    
    def cargar_datos(self):
        """Carga el archivo CSV y prepara los datos"""
        if not os.path.exists(self.archivo):
            print(f"Error: No se encontró {self.archivo}")
            return False
        
        self.df = pd.read_csv(self.archivo, engine='c')
        
        # Separar golden model (sujeto 2) por facetas:
        # medidas pares -> sin YAKE, medidas impares -> con YAKE
        df_golden_total = self.df[self.df['sujeto'] == 2]
        self.df_golden_pares = (
            df_golden_total[df_golden_total['medida'] % 2 == 0]
            .drop_duplicates(subset=['frecuencia'])
            .sort_values('frecuencia')
        )
        self.df_golden_impares = (
            df_golden_total[df_golden_total['medida'] % 2 == 1]
            .drop_duplicates(subset=['frecuencia'])
            .sort_values('frecuencia')
        )
        self.df_test = self.df[self.df['sujeto'] != 2].copy()
        
        # Obtener medidas y sujetos únicos
        self.medidas_disponibles = sorted(self.df_test['medida'].unique())
        self.sujetos_disponibles = sorted(self.df_test['sujeto'].unique())
        
        print(f"Datos cargados: {len(self.medidas_disponibles)} medidas, "
              f"{len(self.sujetos_disponibles)} sujetos (test)")
        return True
    
    def configurar_interfaz(self):
        """Configura la interfaz gráfica con widgets"""
        sns.set_theme(style="whitegrid")
        
        # Crear figura con espacio para los controles a la derecha
        self.fig = plt.figure(figsize=(16, 10))
        
        # Layouts: gráficos (70%) + controles (30%)
        gs = self.fig.add_gridspec(2, 2, width_ratios=[7, 3], 
                                   height_ratios=[1, 1], hspace=0.3, wspace=0.3)
        
        # Subplots principales
        self.ax_mag = self.fig.add_subplot(gs[0, 0])
        self.ax_fase = self.fig.add_subplot(gs[1, 0], sharex=self.ax_mag)
        
        # Áreas para controles
        ax_control_sujetos = self.fig.add_subplot(gs[0, 1])
        ax_control_medidas = self.fig.add_subplot(gs[1, 1])
        
        # --- Configurar CheckButtons para SUJETOS ---
        ax_control_sujetos.axis('off')
        ax_check_sujetos = self.fig.add_axes([0.73, 0.6, 0.23, 0.25])
        
        sujetos_labels = [f"Subject {s} ({'4P' if s == 0 else '3P'})" 
                          for s in self.sujetos_disponibles]
        sujetos_activos = [True] * len(self.sujetos_disponibles)
        
        self.check_sujetos = CheckButtons(ax_check_sujetos, sujetos_labels, sujetos_activos)
        ax_check_sujetos.set_title("Select Subjects", fontweight='bold', loc='left')
        
        # --- Configurar CheckButtons para MEDIDAS ---
        ax_control_medidas.axis('off')
        ax_check_medidas = self.fig.add_axes([0.73, 0.15, 0.23, 0.35])
        
        medidas_labels = [f"Measurement {m}" for m in self.medidas_disponibles]
        medidas_activas = [True] * len(self.medidas_disponibles)
        
        self.check_medidas = CheckButtons(ax_check_medidas, medidas_labels, medidas_activas)
        ax_check_medidas.set_title("Select Measurements", fontweight='bold', loc='left')
        
        # --- Botones de acción para medidas ---
        ax_btn_todas = self.fig.add_axes([0.73, 0.08, 0.10, 0.04])
        ax_btn_ninguna = self.fig.add_axes([0.86, 0.08, 0.10, 0.04])
        
        self.btn_todas = Button(ax_btn_todas, 'All')
        self.btn_ninguna = Button(ax_btn_ninguna, 'None')
        
        # Conectar eventos
        self.check_medidas.on_clicked(self.actualizar_graficos)
        self.check_sujetos.on_clicked(self.actualizar_graficos)
        self.btn_todas.on_clicked(self.seleccionar_todas_medidas)
        self.btn_ninguna.on_clicked(self.seleccionar_ninguna_medida)
        
        # Dibujar gráficos iniciales
        self.dibujar_graficos_iniciales()
        
    def dibujar_graficos_iniciales(self):
        """Dibuja todos los datos por primera vez"""
        colores = plt.cm.tab10(np.linspace(0, 1, max(len(self.medidas_disponibles), 10)))
        
        # --- MAGNITUD ---
        # Dibujar golden model por facetas
        if not self.df_golden_pares.empty:
            self.golden_mag_par, = self.ax_mag.plot(
                self.df_golden_pares['frecuencia'],
                self.df_golden_pares['modulo'],
                color='black', linestyle='--', linewidth=3,
                label='GOLDEN (sin YAKE)', zorder=100
            )
        if not self.df_golden_impares.empty:
            self.golden_mag_impar, = self.ax_mag.plot(
                self.df_golden_impares['frecuencia'],
                self.df_golden_impares['modulo'],
                color='dimgray', linestyle='--', linewidth=3,
                label='GOLDEN (con YAKE)', zorder=100
            )
        
        # Dibujar datos de test por medida y sujeto
        for idx_med, medida in enumerate(self.medidas_disponibles):
            for idx_suj, sujeto in enumerate(self.sujetos_disponibles):
                df_subset = self.df_test[(self.df_test['medida'] == medida) & 
                                         (self.df_test['sujeto'] == sujeto)]
                
                if not df_subset.empty:
                    estilo = '-o' if sujeto == 0 else '-s'
                    alpha = 0.7
                    label = f"M{medida} S{sujeto}"
                    
                    line, = self.ax_mag.plot(df_subset['frecuencia'], df_subset['modulo'],
                                            estilo, color=colores[idx_med], alpha=alpha,
                                            label=label, markersize=4)
                    
                    self.lines_mag[(medida, sujeto)] = line
        
        self.ax_mag.set_xscale('log')
        self.ax_mag.set_ylabel('Magnitude (Ω)', fontweight='bold')
        self.ax_mag.set_title('Frequency Response: Magnitude', fontweight='bold')
        self.ax_mag.legend(loc='best', fontsize=8, ncol=2)
        self.ax_mag.grid(True, alpha=0.3)
        
        # --- FASE ---
        # Dibujar golden model por facetas
        if not self.df_golden_pares.empty:
            self.golden_fase_par, = self.ax_fase.plot(
                self.df_golden_pares['frecuencia'],
                self.df_golden_pares['fase'],
                color='black', linestyle='--', linewidth=3,
                label='GOLDEN (sin YAKE)', zorder=100
            )
        if not self.df_golden_impares.empty:
            self.golden_fase_impar, = self.ax_fase.plot(
                self.df_golden_impares['frecuencia'],
                self.df_golden_impares['fase'],
                color='dimgray', linestyle='--', linewidth=3,
                label='GOLDEN (con YAKE)', zorder=100
            )
        
        # Dibujar datos de test
        for idx_med, medida in enumerate(self.medidas_disponibles):
            for idx_suj, sujeto in enumerate(self.sujetos_disponibles):
                df_subset = self.df_test[(self.df_test['medida'] == medida) & 
                                         (self.df_test['sujeto'] == sujeto)]
                
                if not df_subset.empty:
                    estilo = '-o' if sujeto == 0 else '-s'
                    alpha = 0.7
                    
                    line, = self.ax_fase.plot(df_subset['frecuencia'], df_subset['fase'],
                                             estilo, color=colores[idx_med], alpha=alpha,
                                             markersize=4)
                    
                    self.lines_fase[(medida, sujeto)] = line
        
        self.ax_fase.set_xscale('log')
        self.ax_fase.set_ylabel('Phase (degrees)', fontweight='bold')
        self.ax_fase.set_xlabel('Frequency (Hz)', fontweight='bold')
        self.ax_fase.grid(True, alpha=0.3)
    
    def actualizar_graficos(self, label):
        """Actualiza la visibilidad de las líneas según los checkboxes"""
        # Obtener estados de checkboxes
        estados_medidas = self.check_medidas.get_status()
        estados_sujetos = self.check_sujetos.get_status()
        
        # Mapear estados
        medidas_activas = [self.medidas_disponibles[i] for i, act in enumerate(estados_medidas) if act]
        sujetos_activos = [self.sujetos_disponibles[i] for i, act in enumerate(estados_sujetos) if act]
        
        # Actualizar visibilidad de todas las líneas
        for (medida, sujeto), line_mag in self.lines_mag.items():
            visible = (medida in medidas_activas) and (sujeto in sujetos_activos)
            line_mag.set_visible(visible)
            
            if (medida, sujeto) in self.lines_fase:
                self.lines_fase[(medida, sujeto)].set_visible(visible)

        # Mostrar/ocultar cada golden según la paridad de medidas activas
        hay_pares_activos = any((m % 2 == 0) for m in medidas_activas)
        hay_impares_activos = any((m % 2 == 1) for m in medidas_activas)

        if self.golden_mag_par is not None:
            self.golden_mag_par.set_visible(hay_pares_activos)
        if self.golden_mag_impar is not None:
            self.golden_mag_impar.set_visible(hay_impares_activos)
        if self.golden_fase_par is not None:
            self.golden_fase_par.set_visible(hay_pares_activos)
        if self.golden_fase_impar is not None:
            self.golden_fase_impar.set_visible(hay_impares_activos)
        
        # Actualizar leyenda (solo mostrar elementos visibles)
        self.actualizar_leyenda()
        
        self.fig.canvas.draw_idle()
    
    def actualizar_leyenda(self):
        """Actualiza la leyenda para mostrar solo elementos visibles"""
        handles, labels = self.ax_mag.get_legend_handles_labels()
        
        # Filtrar solo elementos visibles
        visible_handles = []
        visible_labels = []
        
        for h, l in zip(handles, labels):
            if h.get_visible():
                visible_handles.append(h)
                visible_labels.append(l)
        
        if visible_handles:
            self.ax_mag.legend(visible_handles, visible_labels, 
                              loc='best', fontsize=8, ncol=2)
    
    def seleccionar_todas_medidas(self, event):
        """Activa todas las medidas"""
        for i in range(len(self.medidas_disponibles)):
            if not self.check_medidas.get_status()[i]:
                # Simular click en el checkbox
                self.check_medidas.set_active(i)
    
    def seleccionar_ninguna_medida(self, event):
        """Desactiva todas las medidas"""
        for i in range(len(self.medidas_disponibles)):
            if self.check_medidas.get_status()[i]:
                # Simular click en el checkbox
                self.check_medidas.set_active(i)
    
    def mostrar(self):
        """Muestra la interfaz"""
        plt.savefig("frequency_response_interactive.png", dpi=150, bbox_inches='tight')
        print("\n[Python] Interactive visualization generated.")
        print("  • Use checkboxes to select measurements and subjects")
        print("  • 'All'/'None' buttons control all measurements")
        print("  • Subject 0 = 4-point (circles), Subject 1 = 3-point (squares)")
        plt.show()


def principal():
    """Función principal"""
    archivo = "datos_simulacion_nuevo.csv"
    
    # Buscar el archivo CSV más reciente si el predeterminado no existe
    if not os.path.exists(archivo):
        archivos_csv = [f for f in os.listdir('.') if f.endswith('.csv')]
        if archivos_csv:
            archivo = archivos_csv[0]
            print(f"Usando archivo alternativo: {archivo}")
        else:
            print("No se encontraron archivos CSV en el directorio actual.")
            return
    
    visualizador = VisualizadorInteractivo(archivo)
    visualizador.mostrar()


if __name__ == "__main__":
    principal()
