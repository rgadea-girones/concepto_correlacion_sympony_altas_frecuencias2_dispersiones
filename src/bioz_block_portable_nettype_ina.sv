import electrical_pkg::*;

module bioz_block_portable_nettype_ina #(
    parameter real DT = 8e-9,
    // --- PARÁMETROS DEL INA (Sense+ y Sense-) ---
    parameter real C_in_ina = 3.0e-12, // Capacitancia de entrada del INA
    parameter real R_in_ina = 1.0e12,  // Resistencia de entrada del INA
    // --- PARÁMETROS DEL ADC DE CORRIENTE (Red Pitaya en Shunt) ---
    parameter real C_in_adc = 10.0e-12, // Capacitancia de entrada del ADC
    parameter real R_in_adc = 1.0e6,    // Resistencia de entrada del ADC
    parameter real C_leak   = 10.0e-12, // Fugas capacitivas del cable en shunt
    parameter real Mutual_L = 2.5e-7,   // Inductancia mutua
    parameter real INA_GAIN = 1.0,      // Ganancia del INA
    // --- NUEVOS PARÁMETROS AFE MODULAR ---
    parameter real C_f      = 2.0e-12,  // Capacitancia de compensación TIA AD844 (2 pF)
    parameter real C_dc     = 10.0e-6,  // Capacitor de bloqueo DC (10 uF)
    parameter real R_in_tia_inv = 50.0  // Impedancia de entrada pin inversor AD844 (50 Ohm)
)
(
    input w_elec node_gen,   // Nodo desde DAC (E)
    output w_elec node_adc1, // Nodo hacia ADC1 (Salida del INA)
    output w_elec node_adc2, // Nodo hacia ADC2 (Salida del TIA AD844)
    output w_elec node_adc3, // Inactivo/Cero
    input real r_f1, r_f2,   // Resistencias de contacto Force
    input real r_s1, r_s2,   // Resistencias de contacto Sense
    input real c_f1, c_f2,   // Capacitancias parásitas de contacto Force
    input real c_s1, c_s2,   // Capacitancias parásitas de contacto Sense
    input real r_shunt,    
    input real rext_instant, 
    input real rint_instant, 
    input real c_mem_instant,
    input logic clk
);

    // --- SOLVER SUB-STEPPING ---
    localparam int  N_SUBSTEPS = 8;
    localparam real DT_SUB     = DT / 8.0;

    // --- VARIABLES DE ESTADO RK4 ---
    real v_cmem_s = 0.0; // Voltaje en el tejido (C_mem)
    real v_cp1_s  = 0.0; // Voltaje en Contact Force+
    real v_cp2_s  = 0.0; // Voltaje en Contact Force-
    real v_c_s    = 0.0; // Voltaje de salida del TIA V_I (AD844 Output)
    real v_cdc_s  = 0.0; // Voltaje en el capacitor de acoplamiento DC (10 uF)
    real u1_s     = 0.0; // Estado virtual para divisor capacitivo INA Input+
    real u2_s     = 0.0; // Estado virtual para divisor capacitivo INA Input-

    // --- VARIABLES DE CORRIENTE Y DERIVADAS ---
    real i_total = 0.0;
    real i_total_prev = 0.0;
    real di_tot_dt = 0.0; 
    real v_gen;

    always_comb v_gen = node_gen.v;

    // --- SISTEMA DE ECUACIONES DIFERENCIALES ---
    function automatic void f_derivs(
        input real vm, vp1, vp2, vc, vcdc, u1, u2,
        output real dvm, dvp1, dvp2, dvc, dvcdc, du1, du2
    );
        // PROTECCIONES MATEMÁTICAS (Safe Clamping)
        real safe_rint   = (rint_instant < 1.0) ? 1.0 : rint_instant;
        real safe_rext   = (rext_instant < 1.0) ? 1.0 : rext_instant;
        real safe_cmem   = (c_mem_instant < 1e-15) ? 1e-15 : c_mem_instant;
        real safe_rf1    = (r_f1 < 1.0) ? 1.0 : r_f1;
        real safe_rf2    = (r_f2 < 1.0) ? 1.0 : r_f2;
        real safe_rs1    = (r_s1 < 1.0) ? 1.0 : r_s1;
        real safe_rs2    = (r_s2 < 1.0) ? 1.0 : r_s2;
        real safe_cf1    = (c_f1 < 1e-15) ? 1e-15 : c_f1;
        real safe_cf2    = (c_f2 < 1e-15) ? 1e-15 : c_f2;
        real safe_cs1    = (c_s1 < 1e-15) ? 1e-15 : c_s1;
        real safe_cs2    = (c_s2 < 1e-15) ? 1e-15 : c_s2;
        real safe_rshunt = (r_shunt < 1.0) ? 1.0 : r_shunt;

        real safe_Cin_ina = (C_in_ina < 1e-15) ? 1e-15 : C_in_ina;
        real safe_Rin_ina = (R_in_ina < 1.0) ? 1.0 : R_in_ina;
        real safe_Cf      = (C_f < 1e-15) ? 1e-15 : C_f;
        real safe_Cdc     = (C_dc < 1e-15) ? 1e-15 : C_dc;
        real safe_Cin_adc = (C_in_adc < 1e-15) ? 1e-15 : C_in_adc;
        real safe_Cleak   = (C_leak   < 1e-15) ? 1e-15 : C_leak;
        real safe_Rin_adc = (R_in_adc < 1.0)   ? 1.0   : R_in_adc;
        // Capacitancia y resistencia efectivas en el nodo de salida del TIA
        real C_tia_eff    = safe_Cf + safe_Cin_adc + safe_Cleak;
        real R_tia_eff    = (safe_rshunt * safe_Rin_adc) / (safe_rshunt + safe_Rin_adc);

        // Dinámica del lazo de inyección principal (Force)
        real r_par = (safe_rint * safe_rext) / (safe_rint + safe_rext);
        real v_th  = vm * (safe_rext / (safe_rint + safe_rext));
        
        // I = (V_gen - V_dc_block - V_p1 - V_p2 - V_th) / (R_par + R_in_tia_inv)
        real i_tot = (v_gen - vcdc - vp1 - vp2 - v_th) / (r_par + R_in_tia_inv);
        real v_tej = v_th + (i_tot * r_par);
        
        dvm   = ((v_tej - vm) / safe_rint) / safe_cmem;
        dvp1  = (i_tot - (vp1 / safe_rf1)) / safe_cf1;
        dvp2  = (i_tot - (vp2 / safe_rf2)) / safe_cf2;
        dvcdc = i_tot / safe_Cdc;

        // Salida del TIA AD844: nodo de salida cargado por ADC (R_in_adc || C_in_adc+C_leak)
        // KCL nodo salida: C_tia_eff * dv/dt = -i_tot - v/R_tia_eff
        dvc = (-i_tot - (vc / R_tia_eff)) / C_tia_eff;

        // Dinámica de los lazos de sensado conectados a las entradas del INA
        begin
            real v_A = v_gen - vcdc - vp1; 
            real v_in_s1 = v_A + (Mutual_L * di_tot_dt); 
            real denom_s1 = safe_Cin_ina + safe_cs1;
            real v_adc1 = (u1 + safe_cs1 * v_in_s1) / denom_s1; 
            du1 = (v_in_s1 - v_adc1) / safe_rs1 - (v_adc1 / safe_Rin_ina);
        end

        begin
            real v_B = (i_tot * R_in_tia_inv) + vp2;
            real v_in_s2 = v_B - (Mutual_L * di_tot_dt); 
            real denom_s2 = safe_Cin_ina + safe_cs2;
            real v_adc2 = (u2 + safe_cs2 * v_in_s2) / denom_s2; 
            du2 = (v_in_s2 - v_adc2) / safe_rs2 - (v_adc2 / safe_Rin_ina);
        end
    endfunction

    // --- SOLVER RUNGE-KUTTA 4 CON SUB-STEPPING ---
    always @(posedge clk) begin
        real v_cmem_next ;
        real v_cp1_next  ;
        real v_cp2_next ;
        real v_c_next ;
        real v_cdc_next ;
        real u1_next    ;
        real u2_next    ;

        real mk1, mk2, mk3, mk4;
        real p1k1, p1k2, p1k3, p1k4;
        real p2k1, p2k2, p2k3, p2k4;
        real ck1, ck2, ck3, ck4;
        real cdck1, cdck2, cdck3, cdck4;
        real u1k1, u1k2, u1k3, u1k4;
        real u2k1, u2k2, u2k3, u2k4;

        v_cmem_next = v_cmem_s;
        v_cp1_next  = v_cp1_s;
        v_cp2_next  = v_cp2_s;
        v_c_next    = v_c_s;
        v_cdc_next  = v_cdc_s;
        u1_next     = u1_s;
        u2_next     = u2_s;

        for (int step = 0; step < N_SUBSTEPS; step++) begin
            f_derivs(v_cmem_next, v_cp1_next, v_cp2_next, v_c_next, v_cdc_next, u1_next, u2_next, 
                     mk1, p1k1, p2k1, ck1, cdck1, u1k1, u2k1);
            
            f_derivs(v_cmem_next + mk1*DT_SUB/2.0, v_cp1_next + p1k1*DT_SUB/2.0, v_cp2_next + p2k1*DT_SUB/2.0, v_c_next + ck1*DT_SUB/2.0, v_cdc_next + cdck1*DT_SUB/2.0, u1_next + u1k1*DT_SUB/2.0, u2_next + u2k1*DT_SUB/2.0, 
                     mk2, p1k2, p2k2, ck2, cdck2, u1k2, u2k2);
            
            f_derivs(v_cmem_next + mk2*DT_SUB/2.0, v_cp1_next + p1k2*DT_SUB/2.0, v_cp2_next + p2k2*DT_SUB/2.0, v_c_next + ck2*DT_SUB/2.0, v_cdc_next + cdck2*DT_SUB/2.0, u1_next + u1k2*DT_SUB/2.0, u2_next + u2k2*DT_SUB/2.0, 
                     mk3, p1k3, p2k3, ck3, cdck3, u1k3, u2k3);
            
            f_derivs(v_cmem_next + mk3*DT_SUB,     v_cp1_next + p1k3*DT_SUB,     v_cp2_next + p2k3*DT_SUB,     v_c_next + ck3*DT_SUB,     v_cdc_next + cdck3*DT_SUB,     u1_next + u1k3*DT_SUB,     u2_next + u2k3*DT_SUB,   
                     mk4, p1k4, p2k4, ck4, cdck4, u1k4, u2k4);

            v_cmem_next += (DT_SUB/6.0)*(mk1 + 2.0*mk2 + 2.0*mk3 + mk4);
            v_cp1_next  += (DT_SUB/6.0)*(p1k1 + 2.0*p1k2 + 2.0*p1k3 + p1k4);
            v_cp2_next  += (DT_SUB/6.0)*(p2k1 + 2.0*p2k2 + 2.0*p2k3 + p2k4);
            v_c_next    += (DT_SUB/6.0)*(ck1 + 2.0*ck2 + 2.0*ck3 + ck4);
            v_cdc_next  += (DT_SUB/6.0)*(cdck1 + 2.0*cdck2 + 2.0*cdck3 + cdck4);
            u1_next     += (DT_SUB/6.0)*(u1k1 + 2.0*u1k2 + 2.0*u1k3 + u1k4);
            u2_next     += (DT_SUB/6.0)*(u2k1 + 2.0*u2k2 + 2.0*u2k3 + u2k4);
            
v_c_next =  
    alpha * v_c_s +
    beta  * i_total;

        end

        if (_c_next != v_c_next)
            $display("vc exploded");
        if (v_cmem_next !=v_cmem_next)
            $display("v_cmem_next exploded");
        if (v_cp1_next !=v_cp1_next)
            $display("v_cp1_next exploded");
        if (v_cp2_next !=v_cp2_next)
            $display("v_cp2_next exploded");
        if (v_cdc_next !=v_cdc_next)
            $display("v_cdc_next exploded");
        if (u1_next !=  u1_next)
            $display("u1_next exploded");
        if (u2_next !=u2_next)
            $display("u2_next exploded");

        v_cmem_s = v_cmem_next;
        v_cp1_s  = v_cp1_next;
        v_cp2_s  = v_cp2_next;
        v_c_s    = v_c_next;
        v_cdc_s  = v_cdc_next;
        u1_s     = u1_next;
        u2_s     = u2_next;

        begin
            automatic real safe_rint = (rint_instant < 1.0) ? 1.0 : rint_instant;
            automatic real safe_rext = (rext_instant < 1.0) ? 1.0 : rext_instant;
            automatic real r_p = (safe_rint * safe_rext) / (safe_rint + safe_rext);
            automatic real v_t = v_cmem_s * (safe_rext / (safe_rint + safe_rext));
            
            // Consistente con f_derivs: dividir por (r_p + R_in_tia_inv)
            i_total = (v_gen - v_cdc_s - v_cp1_s - v_cp2_s - v_t) / (r_p + R_in_tia_inv);
            di_tot_dt = (i_total - i_total_prev) / DT;
            i_total_prev = i_total;
        end
    end

    // --- ASIGNACIÓN DE SALIDAS ---
    real v_A_out, v_B_out, v_in_s1_out, v_in_s2_out, v_ina_in1, v_ina_in2, v_ina_out;
    
    always_comb begin
        automatic real safe_cs1 = (c_s1 < 1e-15) ? 1e-15 : c_s1;
        automatic real safe_cs2 = (c_s2 < 1e-15) ? 1e-15 : c_s2;
        automatic real safe_Cin_ina = (C_in_ina < 1e-15) ? 1e-15 : C_in_ina;

        // Voltajes en los electrodos de sensado
        v_A_out = v_gen - v_cdc_s - v_cp1_s;
        v_in_s1_out = v_A_out + (Mutual_L * di_tot_dt);
        // Voltaje a la entrada positiva del INA
        v_ina_in1 = (u1_s + safe_cs1 * v_in_s1_out) / (safe_Cin_ina + safe_cs1); 

        v_B_out = (i_total * R_in_tia_inv) + v_cp2_s;
        v_in_s2_out = v_B_out - (Mutual_L * di_tot_dt);
        // Voltaje a la entrada negativa del INA
        v_ina_in2 = (u2_s + safe_cs2 * v_in_s2_out) / (safe_Cin_ina + safe_cs2); 

        // Restamos en analógico (salida del INA amplificada por INA_GAIN)
        v_ina_out = INA_GAIN * (v_ina_in1 - v_ina_in2);
    end

    assign node_adc1 = '{v: v_ina_out, i: 0.0}; 
    assign node_adc2 = '{v: -v_c_s,     i: -i_total}; // Salida del TIA AD844
    assign node_adc3 = '{v: 0.0,       i: 0.0};      // Inactivo en esta topología

endmodule
