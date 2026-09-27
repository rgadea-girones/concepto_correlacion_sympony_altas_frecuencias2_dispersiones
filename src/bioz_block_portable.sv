//método de Euler para resolver la malla completa sin retardos de ciclo (método explícito)
module bioz_block_portable (
    input  real v_gen,      // Voltaje del DAC
    input  real r_serie,    // R_cont1 + R_cont2 + R_shunt
    input  logic clk,
    output real i_total,
    output real v_diff_bioz 
);
    parameter real R_INT = 1500.0;
    parameter real R_EXT = 20000.0;
    parameter real C_MEM = 5.0e-9;
    parameter real DT    = 8e-9;

    real v_cmem = 0.0;

    always @(posedge clk) begin
        // Resolvemos la malla completa considerando V_cmem como una fuente:
        // La fórmula despejada para evitar retardos de ciclo es:
        automatic real i_rint;
        automatic real numerador = v_gen * (R_INT + R_EXT) - v_cmem * R_EXT;
        automatic real denominador = r_serie * (R_INT + R_EXT) + R_EXT * R_INT;
        
        i_total = numerador / denominador;

        // Ahora el voltaje diferencial es el que queda para el tejido
        v_diff_bioz = v_gen - (i_total * r_serie);

        // Calculamos la corriente que entra al condensador (Rama interna)
        // i_rint = (v_diff_bioz - v_cmem) / R_INT
        i_rint = (v_diff_bioz - v_cmem) / R_INT; 
        
        // Actualizamos v_cmem para el siguiente paso
        v_cmem = v_cmem + (i_rint / C_MEM) * DT; 
    end
endmodule