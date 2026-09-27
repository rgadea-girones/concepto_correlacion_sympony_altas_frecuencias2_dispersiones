import pysv
import pandas as pd
import numpy as np

# Lista global para recolectar datos durante la simulación
data_recolectada = []

@pysv.sv(sujeto=int, medida=int, frecuencia=np.float64, modulo=np.float64, fase=np.float64)
def guardar_dato(sujeto, medida, frecuencia, modulo, fase):
    global data_recolectada
    data_recolectada.append({
        "sujeto": sujeto,
        "medida": medida,
        "frecuencia": frecuencia,
        "modulo": modulo,
        "fase": fase
    })
    print(f"[Python] Sujeto {sujeto}: medida={medida}, modulo={modulo:.2f}, fase={fase:.2f} en f={frecuencia:.0f}")
    
@pysv.sv()
def procesar_dataframe():
    df = pd.DataFrame(data_recolectada)
    print("\n--- DataFrame Final ---")
    print(df.head())
    print(f"\nTotal de registros: {len(df)}")
    print(f"Sujetos únicos: {df['sujeto'].unique()}")
    df.to_csv("datos_simulacion.csv", index=False)
    print("✓ Guardado en datos_simulacion.csv")