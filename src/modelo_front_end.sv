// Modelo de Pequeña Señal: Frontend Red Pitaya
module rp_frontend_ss_model #(
    parameter real FS = 125.0e6,      // Frecuencia de muestreo (Hz)
    parameter real FC = 50.0e6,       // Frecuencia de corte (-3dB) en Hz
    parameter real VCM = 0.9,         // Voltaje de modo común del ADC
    parameter real GAIN_LV = 1.0      // Ganancia en modo Low Voltage
)(
    input  real vin,                  // Entrada analógica (pequeña señal)
    input  logic clk,                 // Reloj de muestreo
    output real v_pos,                // Salida diferencial positiva
    output real v_neg                 // Salida diferencial negativa
);

    // Cálculos de constante de tiempo
    // RC = 1 / (2 * pi * FC)
    localparam real RC = 1.0 / (2.0 * 3.14159265 * FC);
    localparam real DT = 1.0 / FS;
    
    // Coeficiente de filtrado (Discretización)
    // y[n] = y[n-1] + (DT/(RC+DT)) * (x[n] - y[n-1])
    localparam real ALPHA = DT / (RC + DT);

    real v_out_filtered = 0.0;

    always @(posedge clk) begin
        // 1. Respuesta dinámica (Polo dominante del Driver + Filtro RC)
        v_out_filtered <= v_out_filtered + ALPHA * (vin - v_out_filtered);
    end

    // 2. Generación de señales diferenciales (Modelo de pequeña señal)
    // La señal se divide y se monta sobre el voltaje de modo común
    assign v_pos = VCM + (v_out_filtered * GAIN_LV / 2.0);
    assign v_neg = VCM - (v_out_filtered * GAIN_LV / 2.0);

endmodule

