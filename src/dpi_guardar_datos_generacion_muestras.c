#include <stdio.h>
#include <stdlib.h>

// Buffer para guardar una secuencia completa antes de escribir en disco
// Al tener 2 sujetos (Golden y Circuito medido), recibimos 450 puntos en total (PUNTOS_POR_MEDIDA * 2) 
// antes de cambiar de medida, dado que enviamos ambos secuencialmente para el mismo ID de medida.
#define PUNTOS_POR_MEDIDA 225
#define PUNTOS_TOTALES_POR_MEDIDA (PUNTOS_POR_MEDIDA * 2)

typedef struct {
    int sujeto;
    int clase;
    int medida;
    double frecuencia;
    double modulo;
    double fase;
    double modulo_a;
    double fase_a;
    double modulo_b;
    double fase_b;
} DatoMedida;

static DatoMedida buffer_medida[600]; // Dejamos algo de margen por si acaso (hasta 600 > 450)
static int num_puntos_buffer = 0;

static FILE *archivo_datos = NULL;
static int primera_vez = 1;
static int ultima_medida = -1;

void volcar_buffer(FILE *f) {
    if (f == NULL) return;
    
    // Sólo escribimos en el CSV si la medida recopiló todos los puntos exactos (tanto Golden como el medido).
    // OJO: Hay simuladores o testbenches que emiten primero 225 de un sujeto y luego 225 del otro. 
    // Aquí el mensaje indicaba que solo llegaban 225 de los 300 que esperaba antes. 
    if (num_puntos_buffer == 225 || num_puntos_buffer == PUNTOS_TOTALES_POR_MEDIDA) {
        for (int i = 0; i < num_puntos_buffer; i++) {
            fprintf(f, "%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                    buffer_medida[i].sujeto, buffer_medida[i].clase, buffer_medida[i].medida, 
                    buffer_medida[i].frecuencia, buffer_medida[i].modulo, 
                    buffer_medida[i].fase, buffer_medida[i].modulo_a, 
                    buffer_medida[i].fase_a, buffer_medida[i].modulo_b, 
                    buffer_medida[i].fase_b);
        }
        fflush(f); // Escribimos físicamente en disco toda la medida de golpe
        printf("\n[C] ---> Secuencia completa de medida %d guardada (%d puntos) <---\n\n", buffer_medida[0].medida, num_puntos_buffer);
        fflush(stdout);
    } else if (num_puntos_buffer > 0) {
        printf("\n[C] [Aviso] Secuencia %d ignorada por estar incompleta (%d puntos recibidos, pero se esperaban 225 o %d).\n\n", buffer_medida[0].medida, num_puntos_buffer, PUNTOS_TOTALES_POR_MEDIDA);
        fflush(stdout);
    }
    
    // Reseteamos el contador para la siguiente medida
    num_puntos_buffer = 0;
}

// Función DPI para guardar un dato
// NOTA: 'real' en SystemVerilog = 'double' en C (64 bits), no 'float' (32 bits)
void guardar_dato(int sujeto_empaquetado, int medida, double frecuencia, double modulo, double fase,
                  double modulo_a, double fase_a, double modulo_b, double fase_b) {
    
    // Desempaquetamos el primer argumento:
    // Centenas = sujeto (0 o 2), Unidades = clase (0 a 4)
    int sujeto = sujeto_empaquetado / 100;
    int clase = sujeto_empaquetado % 100;

    // Abrir el archivo la primera vez
    if (primera_vez) {
        // Comprobar si el archivo ya existe para no repetir la cabecera
        FILE *check = fopen("datos_simulacion_muestras_gru.csv", "r");
        int existe = (check != NULL);
        if (check) fclose(check);

        // CAMBIO: Abrir en modo "a" (append) para que sea incremental
        archivo_datos = fopen("datos_simulacion_muestras_gru.csv", "a");
        if (archivo_datos) {
            if (!existe) {
                // Solo escribimos la cabecera si es un archivo nuevo. 
                fprintf(archivo_datos, "sujeto,clase,medida,frecuencia,modulo,fase,modulo_a,fase_a,modulo_b,fase_b\n");
            }
            primera_vez = 0;
        } else {
            fprintf(stderr, "[Error] No se pudo abrir/crear datos_simulacion_muestras_gru.csv\n");
            return;
        }
    }
    
    // Si detectamos que la medida ha cambiado (empezamos una nueva secuencia),
    // volcamos el buffer acumulado de la medida anterior.
    // También volcamos el buffer si hemos cambiado de clase dentro de la misma medida o si superamos el máximo que deberíamos usar
    if ((ultima_medida != -1 && ultima_medida != medida) || num_puntos_buffer >= PUNTOS_TOTALES_POR_MEDIDA) {
        volcar_buffer(archivo_datos);
    }
    ultima_medida = medida;

    // Almacenamos el dato en memoria temporal (buffer) en lugar de en disco
    // Ahora dimensionado para acoger PUNTOS_TOTALES_POR_MEDIDA (450)
    if (num_puntos_buffer < 600) {
        buffer_medida[num_puntos_buffer].sujeto = sujeto;
        buffer_medida[num_puntos_buffer].clase = clase;
        buffer_medida[num_puntos_buffer].medida = medida;
        buffer_medida[num_puntos_buffer].frecuencia = frecuencia;
        buffer_medida[num_puntos_buffer].modulo = modulo;
        buffer_medida[num_puntos_buffer].fase = fase;
        buffer_medida[num_puntos_buffer].modulo_a = modulo_a;
        buffer_medida[num_puntos_buffer].fase_a = fase_a;
        buffer_medida[num_puntos_buffer].modulo_b = modulo_b;
        buffer_medida[num_puntos_buffer].fase_b = fase_b;
        num_puntos_buffer++;
    }

    // Para no saturar tanto la terminal podemos imprimir esto, o quitarlo
    // printf("[C] Capturado en buffer: sujeto=%d, medida=%d ...\n", sujeto, medida);
}

// Función DPI para cerrar el archivo al finalizar
void procesar_dataframe() {
    if (archivo_datos) {
        // Al terminar, intentamos volcar la última medida si se terminó correctamente
        volcar_buffer(archivo_datos);
        
        fclose(archivo_datos);
        printf("\n[C] Datos cerrados en datos_simulacion_muestras_gru.csv\n");
        archivo_datos = NULL;
        primera_vez = 1;

        // ESTO LANZA TU SCRIPT DE PYTHON AUTOMÁTICAMENTE
        printf("[C] Lanzando entrenamiento en Python...\n");
        fflush(stdout);
        system("start /B C:\\Users\\rgadea\\AppData\\Local\\miniconda3\\envs\\teros_hdl_best\\python.exe entrenar_gru_svm.py"); 
        printf("[C] Entrenamiento lanzado en segundo plano. La simulación puede cerrar ahora.\n");
        fflush(stdout);
    }   
}
