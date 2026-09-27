import electrical_pkg::*;

module rp_adc_model_nettype #(
    parameter real    R_IN  = 1.0e6,   // 1 MΩ
    parameter real    C_IN  = 10.0e-12, // 10 pF
    parameter real    FS    = 125.0e6,
    parameter real    V_REF = 1.0,      // Rango ±1V (Modo LV)
    parameter real    V_CM  = 0.9       // Voltaje modo común interno
)(
    input  w_elec     ana_node,         // Conexión al nodo del nettype (solo lectura)
    input  logic      clk,
    output logic [13:0] digital_out     // Salida para tu post-procesamiento
);
    // 1. Modelado de la Carga (Impedancia de entrada)
    // El ADC consume una pequeña corriente del nodo
    real v_last = 0.0;
    real i_load;
    
    always_comb begin
        // Corriente por la R de 1M y estimación de la C
        // (Simplificado para estabilidad del solver en RNM)
        i_load = (ana_node.v / R_IN); // Solo cálculo interno, no se asigna
    end
    // El ADC no debe asignar sobre ana_node

    // 2. Etapa de Frontend (Filtro Anti-aliasing de 50MHz)
    // Usamos el modelo de pequeña señal para redondear la respuesta
    real v_filtered = 0.0;
    localparam real ALPHA = (1.0/FS) / ((1.0/(2*3.1415*50e6)) + (1.0/FS));

    always @(posedge clk) begin
        automatic real v_norm;
        // Filtrado dinámico
        v_filtered <= v_filtered + ALPHA * (ana_node.v - v_filtered);
        
        // 3. Cuantización (Conversión a bits)
        // Mapeo de ±V_REF a un entero de 14 bits (complemento a dos)
         v_norm = v_filtered / V_REF;
        if (v_norm >= 1.0)       digital_out <= 14'h1FFF;
        else if (v_norm <= -1.0) digital_out <= 14'h2000;
        else                     digital_out <= int'(v_norm * 8192.0);
    end
endmodule
