#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <time.h>
#endif

static FILE *archivo_datos = NULL;
static int primera_vez = 1;
static int temporizador_inicializado = 0;

#ifdef _WIN32
static LARGE_INTEGER qpc_inicio;
static LARGE_INTEGER qpc_freq;
#else
static struct timespec ts_inicio;
#endif

static char csv_flujo[64] = "nettype_rnm";
static char csv_simulador[64] = "questa";
static char csv_configuracion[128] = "qrun_live_rafa_nettype";
static char csv_run_id[64] = "";
static char csv_nombre_archivo[256] = "datos_simulacion_nuevo_tiempos.csv";

static void copiar_cadena_segura(char *dst, size_t dst_size, const char *src);

static void sanitizar_segmento_csv(char *cadena) {
    size_t i;

    if (!cadena) {
        return;
    }

    for (i = 0; cadena[i] != '\0'; ++i) {
        char ch = cadena[i];
        if (!((ch >= 'a' && ch <= 'z') ||
              (ch >= 'A' && ch <= 'Z') ||
              (ch >= '0' && ch <= '9') ||
              ch == '_' || ch == '-')) {
            cadena[i] = '_';
        }
    }
}

static void actualizar_nombre_csv() {
    char config_sanitizada[128];
    char run_id_sanitizado[64];

    copiar_cadena_segura(config_sanitizada, sizeof(config_sanitizada), csv_configuracion);
    copiar_cadena_segura(run_id_sanitizado, sizeof(run_id_sanitizado), csv_run_id);
    sanitizar_segmento_csv(config_sanitizada);
    sanitizar_segmento_csv(run_id_sanitizado);

    if (run_id_sanitizado[0] == '\0') {
        snprintf(
            csv_nombre_archivo,
            sizeof(csv_nombre_archivo),
            "datos_simulacion_%s.csv",
            config_sanitizada[0] ? config_sanitizada : "run"
        );
    } else {
        snprintf(
            csv_nombre_archivo,
            sizeof(csv_nombre_archivo),
            "datos_simulacion_%s_%s.csv",
            config_sanitizada[0] ? config_sanitizada : "run",
            run_id_sanitizado
        );
    }

    csv_nombre_archivo[sizeof(csv_nombre_archivo) - 1] = '\0';
}

static void copiar_cadena_segura(char *dst, size_t dst_size, const char *src) {
    if (!dst || dst_size == 0) {
        return;
    }
    if (!src) {
        dst[0] = '\0';
        return;
    }
    strncpy(dst, src, dst_size - 1);
    dst[dst_size - 1] = '\0';
}

static void generar_run_id_por_defecto() {
#ifdef _WIN32
    SYSTEMTIME st;
    GetLocalTime(&st);
    _snprintf(
        csv_run_id,
        sizeof(csv_run_id),
        "%04d%02d%02d_%02d%02d%02d_%03d",
        st.wYear,
        st.wMonth,
        st.wDay,
        st.wHour,
        st.wMinute,
        st.wSecond,
        st.wMilliseconds
    );
#else
    struct timespec ts_actual;
    struct tm tm_actual;

    clock_gettime(CLOCK_REALTIME, &ts_actual);
    localtime_r(&ts_actual.tv_sec, &tm_actual);
    snprintf(
        csv_run_id,
        sizeof(csv_run_id),
        "%04d%02d%02d_%02d%02d%02d_%03ld",
        tm_actual.tm_year + 1900,
        tm_actual.tm_mon + 1,
        tm_actual.tm_mday,
        tm_actual.tm_hour,
        tm_actual.tm_min,
        tm_actual.tm_sec,
        ts_actual.tv_nsec / 1000000L
    );
#endif
    csv_run_id[sizeof(csv_run_id) - 1] = '\0';
}

void configurar_metadata_csv(
    const char *flujo,
    const char *simulador,
    const char *configuracion,
    const char *run_id
) {
    copiar_cadena_segura(csv_flujo, sizeof(csv_flujo), flujo);
    copiar_cadena_segura(csv_simulador, sizeof(csv_simulador), simulador);
    copiar_cadena_segura(csv_configuracion, sizeof(csv_configuracion), configuracion);

    if (run_id && run_id[0] != '\0') {
        copiar_cadena_segura(csv_run_id, sizeof(csv_run_id), run_id);
    } else {
        csv_run_id[0] = '\0';
    }

    actualizar_nombre_csv();
}

void inicializar_tiempos() {
    if (!temporizador_inicializado) {
#ifdef _WIN32
        QueryPerformanceFrequency(&qpc_freq);
        QueryPerformanceCounter(&qpc_inicio);
#else
        clock_gettime(CLOCK_MONOTONIC, &ts_inicio);
#endif
        temporizador_inicializado = 1;
    }
}

static double tiempo_pc_desde_inicio_s() {
#ifdef _WIN32
    LARGE_INTEGER qpc_actual;
#else
    struct timespec ts_actual;
#endif

    if (!temporizador_inicializado) {
        inicializar_tiempos();
    }

#ifdef _WIN32
    QueryPerformanceCounter(&qpc_actual);
    return (double)(qpc_actual.QuadPart - qpc_inicio.QuadPart) / (double)qpc_freq.QuadPart;
#else
    clock_gettime(CLOCK_MONOTONIC, &ts_actual);
    return (double)(ts_actual.tv_sec - ts_inicio.tv_sec) +
           (double)(ts_actual.tv_nsec - ts_inicio.tv_nsec) / 1.0e9;
#endif
}
double get_cpu_time_s() {
#ifdef _WIN32
    LARGE_INTEGER qpc_actual;
#else
    struct timespec ts_actual;
#endif

    if (!temporizador_inicializado) {
        inicializar_tiempos();
    }

#ifdef _WIN32
    QueryPerformanceCounter(&qpc_actual);
    return (double)(qpc_actual.QuadPart - qpc_inicio.QuadPart) / (double)qpc_freq.QuadPart;
#else
    clock_gettime(CLOCK_MONOTONIC, &ts_actual);
    return (double)(ts_actual.tv_sec - ts_inicio.tv_sec) +
           (double)(ts_actual.tv_nsec - ts_inicio.tv_nsec) / 1.0e9;
#endif
}

void guardar_dato(
    int sujeto,
    int medida,
    double frecuencia,
    double modulo,
    double fase,
    double modulo_a,
    double fase_a,
    double modulo_b,
    double fase_b,
    double tiempo_pc_s,
    double tiempo_hardware_s
) {
    if (primera_vez) {
        archivo_datos = fopen(csv_nombre_archivo, "w");
        if (archivo_datos) {
            fprintf(
                archivo_datos,
                "flujo,simulador,configuracion,run_id,sujeto,medida,frecuencia,modulo,fase,modulo_a,fase_a,modulo_b,fase_b,tiempo_pc_s,tiempo_hardware_s\n"
            );
            primera_vez = 0;
        } else {
            fprintf(stderr, "[Error] No se pudo crear %s\n", csv_nombre_archivo);
            return;
        }
    }

    if (archivo_datos) {
        fprintf(
            archivo_datos,
            "%s,%s,%s,%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.3f,%.12f\n",
            csv_flujo,
            csv_simulador,
            csv_configuracion,
            csv_run_id,
            sujeto,
            medida,
            frecuencia,
            modulo,
            fase,
            modulo_a,
            fase_a,
            modulo_b,
            fase_b,
            tiempo_pc_s,
            tiempo_hardware_s
        );
        printf(
            "[C tiempos] Guardado: sujeto=%d medida=%d f=%.0f Hz t_sim=%.3f t_real=%.9f s\n",
            sujeto,
            medida,
            frecuencia,
            tiempo_pc_s,
            tiempo_hardware_s
        );
    }
}

void procesar_dataframe() {
    if (archivo_datos) {
        fclose(archivo_datos);
        printf("\n[C tiempos] Datos cerrados en %s\n", csv_nombre_archivo);
        archivo_datos = NULL;
        primera_vez = 1;
        temporizador_inicializado = 0;
        csv_run_id[0] = '\0';

        printf("[C tiempos] Lanzando análisis detallado en Python...\n");
#ifdef _WIN32
        {
            char comando[1024];
            snprintf(
                comando,
                sizeof(comando),
                "start /B C:\\Users\\rgadea\\AppData\\Local\\miniconda3\\envs\\teros_hdl_best\\python.exe comparar_correlacion_vs_fft_detalle.py --archivo %s --out-prefix comparacion_correlacion_vs_fft_tiempos_%s",
                csv_nombre_archivo,
                csv_configuracion
            );
            system(comando);
        }
#else
        {
            char comando[1024];
            char config_sanitizada[128];

            copiar_cadena_segura(config_sanitizada, sizeof(config_sanitizada), csv_configuracion);
            sanitizar_segmento_csv(config_sanitizada);
            snprintf(
                comando,
                sizeof(comando),
                "python3 comparar_correlacion_vs_fft_detalle.py --archivo '%s' --out-prefix comparacion_correlacion_vs_fft_tiempos_%s >/dev/null 2>&1 &",
                csv_nombre_archivo,
                config_sanitizada[0] ? config_sanitizada : "run"
            );
            system(comando);
        }
#endif
        printf("[C tiempos] Python lanzado en segundo plano. La simulacion puede cerrar ahora.\n");
    }
}