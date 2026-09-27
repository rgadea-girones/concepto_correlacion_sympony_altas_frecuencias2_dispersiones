# gen_pysv.py
import os
import sys
import shutil

# Forzar UTF-8 para evitar errores de codificación
os.environ['PYTHONIOENCODING'] = 'utf-8'
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from mi_modelo import guardar_dato, procesar_dataframe
import pysv

# Limpiar build anterior si existe
if os.path.exists("build"):
    try:
        shutil.rmtree("build")
        print("Directorio build limpiado")
    except:
        pass

try:
    # 1. Compila las funciones de Python a una librería compartida (.so o .dll)
    lib_path = pysv.compile_lib([guardar_dato, procesar_dataframe], cwd="build")
    print(f"Libreria generada en: {lib_path}")
except UnicodeEncodeError as e:
    print(f"ERROR de codificación: {e}")
    print("Intentando generar solo el binding SV...")

# 2. Genera el paquete de SystemVerilog (pysv_pkg.sv)
pysv.generate_sv_binding([guardar_dato, procesar_dataframe], filename="pysv_pkg.sv")
print("Binding SV generado: pysv_pkg.sv")