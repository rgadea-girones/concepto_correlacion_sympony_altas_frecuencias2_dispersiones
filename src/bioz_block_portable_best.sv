//Método Runge-Kutta de 4º Orden (RK4)
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

    // Función que describe la derivada del voltaje del condensador: dv/dt = f(v, t)
    // Basada en la resolución de malla instantánea
    function automatic real f_dvdt(input real v_cap_actual);
        real num, den, i_tot_local, v_diff_local, i_rint_local;
        
        num = v_gen * (R_INT + R_EXT) - v_cap_actual * R_EXT;
        den = r_serie * (R_INT + R_EXT) + R_EXT * R_INT;
        
        i_tot_local = num / den;
        v_diff_local = v_gen - (i_tot_local * r_serie);
        i_rint_local = (v_diff_local - v_cap_actual) / R_INT;
        
        return (i_rint_local / C_MEM); // dv/dt = I/C
    endfunction

    always @(posedge clk) begin : rk4_process
        automatic real k1, k2, k3, k4;

        // Pasos del método Runge-Kutta 4
        k1 = f_dvdt(v_cmem);
        k2 = f_dvdt(v_cmem + (k1 * DT / 2.0));
        k3 = f_dvdt(v_cmem + (k2 * DT / 2.0));
        k4 = f_dvdt(v_cmem + (k3 * DT));

        // Actualización final de v_cmem (Uso de '=' para zero-lag en simulación)
        v_cmem = v_cmem + (DT / 6.0) * (k1 + 2.0*k2 + 2.0*k3 + k4);

        // Salidas para el resto del circuito (calculadas con el nuevo estado)
        // Esto asegura que la i_total que sale está sincronizada con el paso actual
        begin
            automatic real num_out = v_gen * (R_INT + R_EXT) - v_cmem * R_EXT;
            automatic real den_out = r_serie * (R_INT + R_EXT) + R_EXT * R_INT;
            i_total = num_out / den_out;
            v_diff_bioz = v_gen - (i_total * r_serie);
        end
    end
endmodule