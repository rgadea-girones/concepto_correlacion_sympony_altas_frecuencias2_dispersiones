//metodo de integración numérica para resolver la malla completa sin retardos de ciclo  (método trapezoidal)
module bioz_block_portable (
    input  real v_gen,      
    input  real r_serie,    
    input  logic clk,
    output real i_total,
    output real v_diff_bioz 
);
    parameter real R_INT = 1500.0;
    parameter real R_EXT = 20000.0;
    parameter real C_MEM = 5.0e-9;
    parameter real DT    = 8e-9;

    real v_cmem = 0.0;
    real i_rint_old = 0.0; // Memoria para la integración trapezoidal

    always @(posedge clk) begin : resolucion_trapezoidal
        // Variables automáticas para cálculo instantáneo
        automatic real i_rint_now;
        automatic real num, den;

        // 1. Resolución de malla (Identica a la anterior para i_total)
        num = v_gen * (R_INT + R_EXT) - v_cmem * R_EXT;
        den = r_serie * (R_INT + R_EXT) + R_EXT * R_INT;
        i_total = num / den; 

        v_diff_bioz = v_gen - (i_total * r_serie);

        // 2. Cálculo de corriente actual en la rama del condensador
        i_rint_now = (v_diff_bioz - v_cmem) / R_INT;

        // 3. INTEGRACIÓN TRAPEZOIDAL (Método de Tustin)
        // En lugar de: v_cmem = v_cmem + (i_now/C)*DT
        // Usamos: v_cmem = v_cmem + ((i_now + i_old)/2 / C) * DT
        v_cmem = v_cmem + ((i_rint_now + i_rint_old) * 0.5 / C_MEM) * DT;

        // Guardamos la corriente para el próximo ciclo
        i_rint_old = i_rint_now;
    end
endmodule