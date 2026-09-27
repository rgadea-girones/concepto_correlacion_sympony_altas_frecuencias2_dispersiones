import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC
from sklearn.metrics import accuracy_score, classification_report
import tensorflow as tf
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.layers import GRU, Dense, Input

# 1. Cargar y preparar los datos
archivo_csv = 'datos_simulacion_muestras_gru.csv'
print(f"Cargando datos desde {archivo_csv}...")
df = pd.read_csv(archivo_csv)

# Agrupar por medida para formar las secuencias
# Filtramos Sujeto 2, que corresponde al "Golden Model" (resultados ideales teóricos),
# para que la red neuronal solo se entrene con los datos ruidosos medidos por el circuito (Sujeto 0).
df_circuito = df[df['sujeto'] != 2]

num_medidas = df_circuito['medida'].nunique()
frecuencias_por_medida = 225
num_features = 4  # modulo, fase, modulo_a (o fase_a), modulo_b (o fase_b), ajusta según tu CSV real

X_list = []
y_list = []

# Extraer secuencias y targets (usando SOLO los datos del circuito medido)
for medida_id, group in df_circuito.groupby('medida'):
    # Asegurar que los datos estén ordenados por frecuencia
    group = group.sort_values('frecuencia')
    
    # Extraer las características: MODULO, FASE, Fase A, Fase B
    # Ajusta los nombres de las columnas según cómo las guardó systemverilog/pysv
    features = group[['modulo', 'fase', 'modulo_a', 'fase_a', 'modulo_b', 'fase_b']].values
    
    # En la petición se mencionan 4 features, seleccionamos las 4 pedidas:
    # modulo, fase, fase_a, fase_b
    # Si las columnas se llaman ligeramente distinto, ajusta aquí:
    features = group[['modulo', 'fase', 'fase_a', 'fase_b']].values
    
    X_list.append(features)
    
    # La degradación viene en 'clase' de manera directa (0, 1, 2, 3, o 4)
    target = int(group['clase'].iloc[0])
    y_list.append(target)

X = np.array(X_list)  # Forma esperada: (200, 225, 4)
y = np.array(y_list)  # Forma esperada: (200,)

print(f"Forma de X: {X.shape}")
print(f"Forma de y: {y.shape}")

# Normalización de los datos (Flatten -> Scale -> Reshape)
# Es importante normalizar las características para la GRU
X_reshaped = X.reshape(-1, num_features)
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X_reshaped)
X = X_scaled.reshape(-1, frecuencias_por_medida, num_features)

# Dividir en entrenamiento y prueba (80% / 20%)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# 2. Construir y entrenar la GRU
# Para poder entrenar la GRU y luego usar el SVM, primero entrenamos la GRU 
# junto con una capa densa para que aprenda a extraer buenas características.

input_seq = Input(shape=(frecuencias_por_medida, num_features))
gru_out = GRU(8, return_sequences=False, name="gru_layer")(input_seq)
output_class = Dense(5, activation='softmax', name="classifier")(gru_out) # 5 clases de degradación

model = Model(inputs=input_seq, outputs=output_class)
model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

print("Entrenando la GRU (Feature Extractor)...")
# Usamos few epochs dado que los datos son pocos y puede sobreajustar rápido
history = model.fit(X_train, y_train, epochs=30, batch_size=16, validation_data=(X_test, y_test), verbose=1)

# 3. Extraer características de la GRU (8 neuronas)
# Creamos un submodelo que llega hasta la salida de la GRU
feature_extractor = Model(inputs=model.input, outputs=model.get_layer("gru_layer").output)

X_train_gru_features = feature_extractor.predict(X_train)
X_test_gru_features = feature_extractor.predict(X_test)

print(f"Forma de características de la GRU: {X_train_gru_features.shape}")

# 4. Entrenar el SVM utilizando las características extraídas por la GRU
print("Entrenando clasificador SVM...")
svm_clf = SVC(kernel='rbf', C=1.0, gamma='scale')
svm_clf.fit(X_train_gru_features, y_train)

# 5. Evaluar todo el pipeline
y_pred = svm_clf.predict(X_test_gru_features)
acc = accuracy_score(y_test, y_pred)
print(f"\nResultados SVM sobre características GRU:")
print(f"Accuracy del SVM: {acc * 100:.2f}%")
print("\nReporte de clasificación:")
print(classification_report(y_test, y_pred, target_names=["0.0", "0.2", "0.4", "0.6", "0.8"]))
