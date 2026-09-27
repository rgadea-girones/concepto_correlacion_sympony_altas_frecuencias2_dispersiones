#include <stdint.h>
#include <math.h>
#include "svdpi.h"

#define PI_F 3.14159265358979323846f

// Función hardware emulada
float SENO_COSENO_HARD(int mode, float angle) {
    return (mode == 0) ? cosf(angle) : sinf(angle);
}

// Implementación Mariposa Radix-2 adaptada para DPI-C
void app_fft_radix2_dpi(int N, const double* in_re, const double* in_im, double* out_re, double* out_im) {
    // Buffers temporales para floats (precisión hardware)
    static float xr[4096], xi[4096]; 

    for(int i=0; i<N; i++) {
        xr[i] = (float)in_re[i];
        xi[i] = (float)in_im[i];
    }

    // 1. Bit-reversal Permutation
    int j = 0;
    for (int i = 0; i < N; ++i) {
        if (i < j) {
            float tr = xr[j], ti = xi[j];
            xr[j] = xr[i];  xi[j] = xi[i];
            xr[i] = tr;     xi[i] = ti;
        }
        int m = N >> 1;
        while (m >= 1 && j >= m) { j -= m; m >>= 1; }
        j += m;
    }

    // 2. FFT Mariposa
    for (int m = 2; m <= N; m <<= 1) {
        float theta_base = -2.0f * PI_F / (float)m;
        for (int k = 0; k < m/2; ++k) {
            float angle = theta_base * (float)k;
            float wr = SENO_COSENO_HARD(0, angle);
            float wi = SENO_COSENO_HARD(1, angle);
            for (int j = k; j < N; j += m) {
                int t = j + m/2;
                float tr = wr * xr[t] - wi * xi[t];
                float ti = wr * xi[t] + wi * xr[t];
                float ur = xr[j], ui = xi[j];
                xr[j] = ur + tr;  xi[j] = ui + ti;
                xr[t] = ur - tr;  xi[t] = ui - ti;
            }
        }
    }

    // 3. Devolución de resultados
    for(int i=0; i<N; i++) {
        out_re[i] = (double)xr[i];
        out_im[i] = (double)xi[i];
    }
}