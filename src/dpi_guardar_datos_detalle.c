#include <stdio.h>
#include <stdlib.h>

// Archivo para guardar los datos
static FILE *archivo_datos = NULL;
static int primera_vez = 1;

// Función DPI para guardar un dato
// NOTA: 'real' en SystemVerilog = 'double' en C (64 bits), no 'float' (32 bits)
void guardar_dato(int sujeto, int medida, double frecuencia, double modulo, double fase,
                  double modulo_a, double fase_a, double modulo_b, double fase_b) {
    // Abrir el archivo la primera vez
    if (primera_vez) {
        archivo_datos = fopen("datos_simulacion_nuevo_nettype.csv", "w");
        if (archivo_datos) {
            fprintf(archivo_datos, "sujeto,medida,frecuencia,modulo,fase,modulo_a,fase_a,modulo_b,fase_b\n");
            primera_vez = 0;
        } else {
            fprintf(stderr, "[Error] No se pudo crear datos_simulacion_nuevo_nettype.csv\n");
            return;
        }
    }
    
    // Escribir los datos
    if (archivo_datos) {
        fprintf(archivo_datos, "%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                sujeto, medida, frecuencia, modulo, fase, modulo_a, fase_a, modulo_b, fase_b);
        //fflush(archivo_datos); // Asegurar que se escriba inmediatamente
        printf("[C] Guardado: sujeto=%d, medida=%d, modulo=%.2f, fase=%.2f, modA=%.2f, faseA=%.2f, modB=%.2f, faseB=%.2f en f=%.0f Hz\n", 
               sujeto, medida, modulo, fase, modulo_a, fase_a, modulo_b, fase_b, frecuencia);
    }
}

// Función DPI para cerrar el archivo al finalizar
void procesar_dataframe() {
    if (archivo_datos) {
        fclose(archivo_datos);
        printf("\n[C] Datos cerrados en datos_simulacion_nuevo_nettype.csv\n");
        archivo_datos = NULL;
        primera_vez = 1;

        // ESTO LANZA TU SCRIPT DE PYTHON AUTOMÁTICAMENTE
        printf("[C] Lanzando análisis en Python...\n");
        system("start /B C:\\Users\\rgadea\\AppData\\Local\\miniconda3\\envs\\teros_hdl_best\\python.exe analizar_datos_mejor_yake.py"); 
        printf("[C] Python lanzado en segundo plano. La simulación puede cerrar ahora.\n");
    }   
}
 

