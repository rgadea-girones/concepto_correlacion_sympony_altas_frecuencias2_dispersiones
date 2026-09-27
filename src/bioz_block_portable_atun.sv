// bioz_block_atun.sv - Modelo RK4 con Capacidad de Interfaz
module bioz_block_portable (
    input  real v_gen,      
    input  real r_s1, r_s2, // Resistencias de contacto variables
    input  real c_p1, c_p2, // Capacidades parásitas de los electrodos
    input  real r_shunt,    
    input  logic clk,
    output real i_total,
    output real v_diff_bioz, // Tensión pura en el tejido
    output real v_cp1, v_cp2 // Caídas en las interfaces de electrodo
);
    parameter real R_INT = 1500.0;
    parameter real R_EXT = 20000.0;
    parameter real C_MEM = 5.0e-9;
    parameter real C_P1  = 1.0e-10; // Capacidad parásita (Hielo)
    parameter real C_P2  = 1.0e-10; 
    parameter real DT    = 8e-9;

    real v_cmem_s = 0.0;
    real v_cp1_s  = 0.0;
    real v_cp2_s  = 0.0;

    // Función de derivadas para RK4 (Resuelve la malla completa)
    function automatic void f_derivs(
        input real vm, vp1, vp2,
        output real dvm, dvp1, dvp2
    );
        real r_par = (R_INT * R_EXT) / (R_INT + R_EXT);
        real v_th  = vm * (R_EXT / (R_INT + R_EXT));
        real i_tot = (v_gen - vp1 - vp2 - v_th) / (r_shunt + r_par);
        real v_tej = v_th + (i_tot * r_par);
        
        dvm  = ((v_tej - vm) / R_INT) / C_MEM;
        dvp1 = (i_tot - (vp1 / r_s1)) / c_p1;
        dvp2 = (i_tot - (vp2 / r_s2)) / c_p2;
    endfunction

    always @(posedge clk) begin
        real mk1, mk2, mk3, mk4, p1k1, p1k2, p1k3, p1k4, p2k1, p2k2, p2k3, p2k4;

        f_derivs(v_cmem_s, v_cp1_s, v_cp2_s, mk1, p1k1, p2k1);
        f_derivs(v_cmem_s + mk1*DT/2, v_cp1_s + p1k1*DT/2, v_cp2_s + p2k1*DT/2, mk2, p1k2, p2k2);
        f_derivs(v_cmem_s + mk2*DT/2, v_cp1_s + p1k2*DT/2, v_cp2_s + p2k2*DT/2, mk3, p1k3, p2k3);
        f_derivs(v_cmem_s + mk3*DT,   v_cp1_s + p1k3*DT,   v_cp2_s + p2k3*DT,   mk4, p1k4, p2k4);

        v_cmem_s = v_cmem_s + (DT/6.0)*(mk1 + 2*mk2 + 2*mk3 + mk4);
        v_cp1_s  = v_cp1_s  + (DT/6.0)*(p1k1 + 2*p1k2 + 2*p1k3 + p1k4);
        v_cp2_s  = v_cp2_s  + (DT/6.0)*(p2k1 + 2*p2k2 + 2*p2k3 + p2k4);

        // Actualización de salidas síncronas
        begin
            automatic real r_p = (R_INT * R_EXT) / (R_INT + R_EXT);
            automatic real v_t = v_cmem_s * (R_EXT / (R_INT + R_EXT));
            i_total = (v_gen - v_cp1_s - v_cp2_s - v_t) / (r_shunt + r_p);
            v_diff_bioz = v_t + (i_total * r_p);
            v_cp1 = v_cp1_s;
            v_cp2 = v_cp2_s;
        end
    end
endmodule