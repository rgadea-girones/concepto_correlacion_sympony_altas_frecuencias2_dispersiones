import pandas as pd
import numpy as np
import shap
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

# 1. Cargar datos
csv_file = '/home/eda/concepto_correlacion_sympony_altas_frecuencias2_dispersiones/sim/datos_simulacion_exp_k_extremos_nettype_sin_autoshunt_20260705_134255_999.csv'
print(f"Loading data from {csv_file}...")
df = pd.read_csv(csv_file)

# Solo nos interesan las medidas 0 y 9 (k=0 y k=9), y los sujetos 0 y 1.
df = df[df['medida'].isin([0, 9])]
df = df[df['sujeto'].isin([0, 1])]

# 2. Pivotar para tener las métricas de s0 y s1 en la misma fila para cada frecuencia
features_of_interest = ['modulo_a', 'fase_a', 'modulo_b', 'fase_b']
df_pivot = df.pivot_table(index=['run_id', 'medida', 'frecuencia'], 
                          columns='sujeto', 
                          values=features_of_interest)

# Aplanar multi-index de columnas
df_pivot.columns = [f'{col[0]}_s{col[1]}' for col in df_pivot.columns]
df_pivot.reset_index(inplace=True)
df_pivot.dropna(inplace=True)

# 3. Preparar X e y
# Convertir medida a variable binaria: 0 para K=0, 1 para K=9
df_pivot['target'] = (df_pivot['medida'] == 9).astype(int)

X = df_pivot[[
    'modulo_a_s0', 'fase_a_s0', 'modulo_b_s0', 'fase_b_s0',
    'modulo_a_s1', 'fase_a_s1', 'modulo_b_s1', 'fase_b_s1',
    'frecuencia' # Añadimos frecuencia para contexto
]]
y = df_pivot['target']

# Translate column names to English
X = X.rename(columns={
    'modulo_a_s0': 'Magnitude A (Raw S0)',
    'fase_a_s0': 'Phase A (Raw S0)',
    'modulo_b_s0': 'Magnitude B (Raw S0)',
    'fase_b_s0': 'Phase B (Raw S0)',
    'modulo_a_s1': 'Magnitude A (Processed S1)',
    'fase_a_s1': 'Phase A (Processed S1)',
    'modulo_b_s1': 'Magnitude B (Processed S1)',
    'fase_b_s1': 'Phase B (Processed S1)',
    'frecuencia': 'Frequency'
})

print(f"Dataset prepared: {len(X)} samples.")
print(f"Class distribution: \n{y.value_counts()}")

# 4. Entrenar Modelo
model = RandomForestClassifier(n_estimators=100, random_state=42, max_depth=5)
model.fit(X, y)

accuracy = model.score(X, y)
print(f"Model accuracy on full set: {accuracy*100:.2f}%")

# 5. Análisis SHAP
print("Calculating SHAP values...")
explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X)

if isinstance(shap_values, list):
    shap_values_class1 = shap_values[1]
elif len(np.shape(shap_values)) == 3:
    shap_values_class1 = shap_values[:, :, 1]
else:
    shap_values_class1 = shap_values

# Imprimir importancias medias absolutas
mean_shap = np.abs(shap_values_class1).mean(axis=0)
shap_importance = pd.DataFrame({'Feature': X.columns, 'SHAP Importance': mean_shap})
shap_importance.sort_values(by='SHAP Importance', ascending=False, inplace=True)
print("\n=== Feature Importance (Mean Absolute SHAP) ===")
print(shap_importance.to_string(index=False))

# 6. Guardar Gráfico
plt.figure(figsize=(10, 6))
shap.summary_plot(shap_values_class1, X, show=False)
plt.title('SHAP Summary: Importance for discriminating K=9 vs K=0')
plt.tight_layout()
plt.savefig('/home/eda/.gemini/antigravity-ide/brain/d97fe7c4-08c5-46fa-bfdf-f56f270e68cc/shap_summary_english.png')
print("\nPlot saved in artifacts: shap_summary_english.png")
