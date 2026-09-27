import electrical_pkg::*;

module bioz_block_portable_nettype #(
    parameter real DT = 8e-9,
    // --- NUEVOS PARÁMETROS DE ALTA FRECUENCIA (ROJO) ---
    parameter real C_in     = 50.0e-12, // Capacitancia de entrada del instrumento (Red Pitaya) 20 pF es lo normal
    parameter real R_in     = 1.0e6,    // Resistencia de entrada del instrumento
    parameter real C_leak   = 100.0e-12, // Fugas capacitivas en los cables 30pf he puesto
    parameter real Mutual_L = 2.5e-6    // Inductancia mutua entre cables Force y Sense
)
(
    input w_elec node_gen,   // Nodo desde DAC (E)
    output w_elec node_adc1, // Nodo hacia ADC1 (Sense+ con efectos de carga)
    output w_elec node_adc2, // Nodo hacia ADC2 (Sense- con efectos de carga)
    output w_elec node_adc3, // Nodo C (SHUNT + Cleak)
    input real r_s1, r_s2,   // Resistencias de contacto
    input real c_p1, c_p2,   // Capacitancias parásitas de contacto
    input real r_shunt,    
    input real rext_instant, 
    input real rint_instant, 
    input real c_mem_instant,
    input logic clk
);

    // --- SOLVER SUB-STEPPING ---
    // Dividimos el DT en 20 micropasos para garantizar la estabilidad de los "stiff poles" (nodos muy rápidos)
    localparam int  N_SUBSTEPS = 20;
    localparam real DT_SUB     = DT / 20.0;

    // --- VARIABLES DE ESTADO RK4 AMPLIADAS ---
    real v_cmem_s = 0.0; // Voltaje en el tejido (C_mem)
    real v_cp1_s  = 0.0; // Voltaje en Contact Force+
    real v_cp2_s  = 0.0; // Voltaje en Contact Force-
    real v_c_s    = 0.0; // Voltaje en Nodo C (Shunt || C_leak)
    real u1_s     = 0.0; // Estado virtual para divisor capacitivo Sense+
    real u2_s     = 0.0; // Estado virtual para divisor capacitivo Sense-

    // --- VARIABLES DE CORRIENTE Y DERIVADAS ---
    real i_total = 0.0;
    real i_total_prev = 0.0;
    real di_tot_dt = 0.0; 
    real v_gen;

    always_comb v_gen = node_gen.v;

    // --- SISTEMA DE ECUACIONES DIFERENCIALES ---
    function automatic void f_derivs(
        input real vm, vp1, vp2, vc, u1, u2,
        output real dvm, dvp1, dvp2, dvc, du1, du2
    );
        // PROTECCIONES MATEMÁTICAS (Safe Clamping) para evitar divisiones por cero o valores físicamente imposibles
        real safe_rint   = (rint_instant < 1.0) ? 1.0 : rint_instant;
        real safe_rext   = (rext_instant < 1.0) ? 1.0 : rext_instant;
        real safe_cmem   = (c_mem_instant < 1e-15) ? 1e-15 : c_mem_instant;
        real safe_rs1    = (r_s1 < 1.0) ? 1.0 : r_s1;
        real safe_rs2    = (r_s2 < 1.0) ? 1.0 : r_s2;
        real safe_cp1    = (c_p1 < 1e-15) ? 1e-15 : c_p1;
        real safe_cp2    = (c_p2 < 1e-15) ? 1e-15 : c_p2;
        real safe_rshunt = (r_shunt < 1.0) ? 1.0 : r_shunt;
        real safe_cleak  = (C_leak < 1e-15) ? 1e-15 : C_leak;
        real safe_Cin    = (C_in < 1e-15) ? 1e-15 : C_in;
        real safe_Rin    = (R_in < 1.0) ? 1.0 : R_in;

        // Dinámica del lazo de inyección principal (Force)
        real r_par = (safe_rint * safe_rext) / (safe_rint + safe_rext);
        real v_th  = vm * (safe_rext / (safe_rint + safe_rext));
        
        real i_tot = (v_gen - vp1 - vp2 - v_th - vc) / r_par;
        real v_tej = v_th + (i_tot * r_par);
        
        dvm  = ((v_tej - vm) / safe_rint) / safe_cmem;
        dvp1 = (i_tot - (vp1 / safe_rs1)) / safe_cp1;
        dvp2 = (i_tot - (vp2 / safe_rs2)) / safe_cp2;
        dvc  = (i_tot - (vc / safe_rshunt)) / safe_cleak; 

        // Dinámica de los lazos de sensado (SENSE+ y SENSE-)
        begin
            real v_A = v_gen - vp1; 
            real v_in_s1 = v_A + (Mutual_L * di_tot_dt); 
            real denom_s1 = safe_Cin + safe_cp1;
            real v_adc1 = (u1 + safe_cp1 * v_in_s1) / denom_s1; 
            du1 = (v_in_s1 - v_adc1) / safe_rs1 - (v_adc1 / safe_Rin);
        end

        begin
            real v_B = vc + vp2;
            real v_in_s2 = v_B - (Mutual_L * di_tot_dt); 
            real denom_s2 = safe_Cin + safe_cp2;
            real v_adc2 = (u2 + safe_cp2 * v_in_s2) / denom_s2; 
            du2 = (v_in_s2 - v_adc2) / safe_rs2 - (v_adc2 / safe_Rin);
        end
    endfunction

    // --- SOLVER RUNGE-KUTTA 4 CON SUB-STEPPING ---
    always @(posedge clk) begin
        real v_cmem_next ;
        real v_cp1_next  ;
        real v_cp2_next ;
        real v_c_next ;
        real u1_next    ;
        real u2_next    ;

        real mk1, mk2, mk3, mk4;
        real p1k1, p1k2, p1k3, p1k4;
        real p2k1, p2k2, p2k3, p2k4;
        real ck1, ck2, ck3, ck4;
        real u1k1, u1k2, u1k3, u1k4;
        real u2k1, u2k2, u2k3, u2k4;

        v_cmem_next = v_cmem_s;
        v_cp1_next  = v_cp1_s;
        v_cp2_next  = v_cp2_s;
        v_c_next    = v_c_s;
        u1_next     = u1_s;
        u2_next     = u2_s;
        // Ejecutamos varios micropasos por cada ciclo de reloj
        for (int step = 0; step < N_SUBSTEPS; step++) begin
            f_derivs(v_cmem_next, v_cp1_next, v_cp2_next, v_c_next, u1_next, u2_next, 
                     mk1, p1k1, p2k1, ck1, u1k1, u2k1);
            
            f_derivs(v_cmem_next + mk1*DT_SUB/2.0, v_cp1_next + p1k1*DT_SUB/2.0, v_cp2_next + p2k1*DT_SUB/2.0, v_c_next + ck1*DT_SUB/2.0, u1_next + u1k1*DT_SUB/2.0, u2_next + u2k1*DT_SUB/2.0, 
                     mk2, p1k2, p2k2, ck2, u1k2, u2k2);
            
            f_derivs(v_cmem_next + mk2*DT_SUB/2.0, v_cp1_next + p1k2*DT_SUB/2.0, v_cp2_next + p2k2*DT_SUB/2.0, v_c_next + ck2*DT_SUB/2.0, u1_next + u1k2*DT_SUB/2.0, u2_next + u2k2*DT_SUB/2.0, 
                     mk3, p1k3, p2k3, ck3, u1k3, u2k3);
            
            f_derivs(v_cmem_next + mk3*DT_SUB,     v_cp1_next + p1k3*DT_SUB,     v_cp2_next + p2k3*DT_SUB,     v_c_next + ck3*DT_SUB,     u1_next + u1k3*DT_SUB,     u2_next + u2k3*DT_SUB,   
                     mk4, p1k4, p2k4, ck4, u1k4, u2k4);

            v_cmem_next += (DT_SUB/6.0)*(mk1 + 2.0*mk2 + 2.0*mk3 + mk4);
            v_cp1_next  += (DT_SUB/6.0)*(p1k1 + 2.0*p1k2 + 2.0*p1k3 + p1k4);
            v_cp2_next  += (DT_SUB/6.0)*(p2k1 + 2.0*p2k2 + 2.0*p2k3 + p2k4);
            v_c_next    += (DT_SUB/6.0)*(ck1 + 2.0*ck2 + 2.0*ck3 + ck4);
            u1_next     += (DT_SUB/6.0)*(u1k1 + 2.0*u1k2 + 2.0*u1k3 + u1k4);
            u2_next     += (DT_SUB/6.0)*(u2k1 + 2.0*u2k2 + 2.0*u2k3 + u2k4);
        end

        // Actualizamos los estados globales
        v_cmem_s = v_cmem_next;
        v_cp1_s  = v_cp1_next;
        v_cp2_s  = v_cp2_next;
        v_c_s    = v_c_next;
        u1_s     = u1_next;
        u2_s     = u2_next;

        // Actualización final de la corriente y su derivada para el siguiente ciclo
        begin
            automatic real safe_rint = (rint_instant < 1.0) ? 1.0 : rint_instant;
            automatic real safe_rext = (rext_instant < 1.0) ? 1.0 : rext_instant;
            automatic real r_p = (safe_rint * safe_rext) / (safe_rint + safe_rext);
            automatic real v_t = v_cmem_s * (safe_rext / (safe_rint + safe_rext));
            
            i_total = (v_gen - v_cp1_s - v_cp2_s - v_t - v_c_s) / r_p;
            di_tot_dt = (i_total - i_total_prev) / DT;
            i_total_prev = i_total;
        end
    end

    // --- ASIGNACIÓN DE SALIDAS (NODOS NETTYPE) ---
    real v_A_out, v_B_out, v_in_s1_out, v_in_s2_out, v_adc1_out, v_adc2_out;
    
    always_comb begin
        // Protecciones idénticas para la combinacional de salida
        automatic real safe_cp1 = (c_p1 < 1e-15) ? 1e-15 : c_p1;
        automatic real safe_cp2 = (c_p2 < 1e-15) ? 1e-15 : c_p2;
        automatic real safe_Cin = (C_in < 1e-15) ? 1e-15 : C_in;

        v_A_out = v_gen - v_cp1_s;
        v_in_s1_out = v_A_out + (Mutual_L * di_tot_dt);
        v_adc1_out = (u1_s + safe_cp1 * v_in_s1_out) / (safe_Cin + safe_cp1); 

        v_B_out = v_c_s + v_cp2_s;
        v_in_s2_out = v_B_out - (Mutual_L * di_tot_dt);
        v_adc2_out = (u2_s + safe_cp2 * v_in_s2_out) / (safe_Cin + safe_cp2); 
    end

    // Proyectamos i: 0.0 porque el módulo ADC de destino es puramente observacional.
    assign node_adc1 = '{v: v_adc1_out, i: 0.0}; 
    assign node_adc2 = '{v: v_adc2_out, i: 0.0}; 
    assign node_adc3 = '{v: v_c_s,      i: -i_total};

endmodule