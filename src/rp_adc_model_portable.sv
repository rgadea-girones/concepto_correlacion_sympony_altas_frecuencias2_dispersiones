

module rp_adc_model_portable
#(
    parameter real    R_IN  = 1.0e6,   // 1 MΩ
    parameter real    C_IN  = 10.0e-12, // 10 pF
    parameter real    FS    = 125.0e6,
    parameter real    V_REF = 1.0,      // Rango ±1V (Modo LV)
    parameter real    V_CM  = 0.9       // Voltaje modo común interno
) 
(
    input real     ana_node,         // Conexión al nodo del nettype
    input  logic      clk,
    output logic signed [13:0] digital_out     // Salida para tu post-procesamiento
);
 always_ff @(posedge clk) begin
        digital_out <= int'(ana_node * 8192.0); // Mapeo a digital [cite: 100]
    end
endmodule
