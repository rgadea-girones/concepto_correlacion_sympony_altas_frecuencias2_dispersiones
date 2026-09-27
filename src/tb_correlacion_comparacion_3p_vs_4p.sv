// =============================================================================
// Banco de Pruebas: Comparación 3-Puntas vs 4-Puntas (Kelvin)
// Objetivo: Comparar la precisión de ambas técnicas bajo las mismas
//           condiciones de ruido de contacto.
// =============================================================================

import "DPI-C" function void app_fft_radix2_dpi(
    input int N, input real in_re[1024], input real in_im[1024],
    output real out_re[1024], output real out_im[1024]
);
import electrical_pkg::*;
module top_sim;
    localparam int MAGNITUD_WIDTH = 14;
    localparam int N = 1024;
    localparam real PI = 3.14159265358979;
    localparam real DT = 8e-9; // Reloj de 125 MHz
   
    //señales digitales
    logic clk125;

    logic areset_n;
    logic start;
    logic test1, test2, test3;
    logic salto;
    logic [7:0] numero_rep;
    logic [7:0] numero_ciclos;
    logic [7:0] numero_anchura;
    logic [MAGNITUD_WIDTH-1:0] ADC_A, ADC_B;

    logic [MAGNITUD_WIDTH-1:0] DAC_A;
    logic fin, fin2, VALID_M, VALID_P, incrementado;
    logic [MAGNITUD_WIDTH-1:0] DAC_S_registrado;
    logic [7:0] MODULO;
    logic [8:0] address_mem, address_mem2, address_mem3;
    logic [3:0] estado_pasos_cero;
    logic [7:0] PHASE, PHASEA, PHASEB;



    // Nodos de la red (Cables Nettype)
    w_elec node_E, node_A, node_B, node_C, node_GND;

    // --- PARÁMETROS DEL TEJIDO (Fijo - Golden Model) ---
    localparam real R_ext   = 20000.0; 
    localparam real R_int   = 1500.0;
    localparam real C_mem   = 5.0e-9;
    localparam real R_shunt = 100.0;
    localparam real R_contact1= 500.0; // Contacto del extremo de generación
    localparam real R_contact2= 500.0; // Contacto del extremo de shunt



    // --- VARIABLES FÍSICAS COMUNES ---
    real r_cont_instant; // Ruido de presión, común para ambas técnicas
    real v_gen, f_actual, fase_acc = 0;
    real v_c_mem = 0, i_total;
    real v_tejido, i_int;
    real node_re_p, node_re_n, node_shunt_high; // Nodos físicos reales
    
    // --- BUFFERS DE CAPTURA Y PROCESADO ---
    real v_im_z[N] = '{default:0}; // Parte imaginaria para FFTs (siempre cero)

    // Para 4-Puntas
    real adc1_v_p_4p[N], adc2_v_n_4p[N], adc3_v_sh_4p[N];
    real v_diff_4p[N], i_calc_4p[N];
    real V_fft_re_4p[N], V_fft_im_4p[N], I_fft_re_4p[N], I_fft_im_4p[N];
    real mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p;

    real den_4p;
    // Para 3-Puntas
    real v_gen_samp_3p[N], node_sh_samp_3p[N], i_total_samp_3p[N];
    real v_diff_3p[N], i_calc_3p[N];
    real V_fft_re_3p[N], V_fft_im_3p[N], I_fft_re_3p[N], I_fft_im_3p[N];
    real mag_z_3p, fase_z_3p, error_mag_3p, error_fase_3p;
    
    real den_3p;


    // --- GOLDEN MODEL (Resultados teóricos) ---
    real z_bio_re, z_bio_im, z_bio_mag, z_bio_fase;
    real omega, xc, den_bio;   
    // =============================================================================
    // MODELO FÍSICO (ÚNICO Y COMPARTIDO)
    // =============================================================================

    top_bioimpedancia_circuito_medida analog_circuit (
    .clk(clk125),
    .adc1_data_4p(adc1_v_p_4p), // Solo para observar en el testbench, no afecta a la lógica digital
    .adc2_data_4p(adc2_v_n_4p),
    .adc3_data_4p(adc3_v_sh_4p),
    .adc1_data_3p(v_gen_samp_3p),
    .adc2_data_3p(node_sh_samp_3p)
    );  



    // =============================================================================
    // TAREA DE SIMULACIÓN extracción de impedancias por FFT y cálculo de errores
    // =============================================================================
    task automatic correr_punto(real freq);
        real t_muestreo = (3.0 / freq) / N;
        f_actual = freq;
        
        r_cont_instant = 500.0 + $urandom_range(0, 1500); 
        #500us; // Estabilización

        // --- FASE DE MUESTREO (Simultánea para ambas técnicas) ---
        for (int i=0; i<N; i++) begin
            // Captura para 4-Puntas (mide nodos internos)
            adc1_v_p_4p[i]  = node_re_p;
            adc2_v_n_4p[i]  = node_re_n;
            adc3_v_sh_4p[i] = node_shunt_high;

            // Captura para 3-Puntas (mide en los extremos del lazo de corriente)
            v_gen_samp_3p[i]   = v_gen;
            node_sh_samp_3p[i] = node_shunt_high;
            i_total_samp_3p[i] = i_total; // Para la derivación del modelo 3p

            #(t_muestreo * 1s);
        end

        // --- PROCESADO DIGITAL (FPGA) ---
        // Para 4-Puntas
        for (int i=0; i<N; i++) begin
            v_diff_4p[i] = adc1_v_p_4p[i] - adc2_v_n_4p[i];
            i_calc_4p[i] = adc3_v_sh_4p[i] / R_shunt;
        end
        
        // Para 3-Puntas (simula la medida con error de contacto)
        // V_medido = V(extremo_gen) - V(extremo_shunt)
        // V(extremo_gen) = v_gen - i_total * r_cont_instant
        // V(extremo_shunt) = node_shunt_high
        for (int i=0; i<N; i++) begin
             v_diff_3p[i] = (v_gen_samp_3p[i] - i_total_samp_3p[i] * r_cont_instant) - node_sh_samp_3p[i];
             i_calc_3p[i] = node_sh_samp_3p[i] / R_shunt;
        end

        // --- FFTs ---
        app_fft_radix2_dpi(N, v_diff_4p, v_im_z, V_fft_re_4p, V_fft_im_4p);
        app_fft_radix2_dpi(N, i_calc_4p, v_im_z, I_fft_re_4p, I_fft_im_4p);
        app_fft_radix2_dpi(N, v_diff_3p, v_im_z, V_fft_re_3p, V_fft_im_3p);
        app_fft_radix2_dpi(N, i_calc_3p, v_im_z, I_fft_re_3p, I_fft_im_3p);

        // --- CÁLCULO DE IMPEDANCIA ---
       // Para 4-Puntas
        den_4p = (I_fft_re_4p[3]**2 + I_fft_im_4p[3]**2);
        mag_z_4p = $sqrt((V_fft_re_4p[3]**2 + V_fft_im_4p[3]**2) / den_4p);
        fase_z_4p = $atan2((V_fft_im_4p[3]*I_fft_re_4p[3] - V_fft_re_4p[3]*I_fft_im_4p[3]), 
                           (V_fft_re_4p[3]*I_fft_re_4p[3] + V_fft_im_4p[3]*I_fft_im_4p[3])) * (180.0/PI);
        // Para 3-Puntas
        den_3p = (I_fft_re_3p[3]**2 + I_fft_im_3p[3]**2);
        mag_z_3p = $sqrt((V_fft_re_3p[3]**2 + V_fft_im_3p[3]**2) / den_3p);
        fase_z_3p = $atan2((V_fft_im_3p[3]*I_fft_re_3p[3] - V_fft_re_3p[3]*I_fft_im_3p[3]), 
                           (V_fft_re_3p[3]*I_fft_re_3p[3] + V_fft_im_3p[3]*I_fft_im_3p[3])) * (180.0/PI);

        // --- GOLDEN MODEL (Común para ambos) ---

        omega = 2.0 * PI * freq;
        xc = 1.0 / (omega * C_mem);
        den_bio = (R_ext + R_int)**2 + xc**2;
        z_bio_re = (R_ext * (R_int*(R_ext + R_int) + xc**2)) / den_bio;
        z_bio_im = (R_ext**2 * -(xc)) / den_bio;
        z_bio_mag  = $sqrt(z_bio_re**2 + z_bio_im**2);
        z_bio_fase = $atan2(z_bio_im, z_bio_re) * (180.0 / PI);

        // --- CÁLCULO DE ERRORES ---
        error_mag_4p  = (mag_z_4p > z_bio_mag) ? ((mag_z_4p - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - mag_z_4p)/z_bio_mag)*100.0;
        error_fase_4p = (fase_z_4p > z_bio_fase) ? (fase_z_4p - z_bio_fase) : (z_bio_fase - fase_z_4p);
        error_mag_3p  = (mag_z_3p > z_bio_mag) ? ((mag_z_3p - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - mag_z_3p)/z_bio_mag)*100.0;
        error_fase_3p = (fase_z_3p > z_bio_fase) ? (fase_z_3p - z_bio_fase) : (z_bio_fase - fase_z_3p);

        // --- DISPLAY ---
        $display("F:%9.0f Hz | R_cont:%4.0f Ω", freq, r_cont_instant);
        $display("  Z_Golden -> Mag: %8.1f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
        $display("  Z_4P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p);
        $display("  Z_3P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_3p, fase_z_3p, error_mag_3p, error_fase_3p);
        $display("");
    endtask

//intanciacion generado DDs y calculador impedancias por correlacion
    Control_path_best_rafa_mejora_correlacion_autoshunt #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(9),
        .MAGNITUD_WIDTH(MAGNITUD_WIDTH),
        .pancho_detector(10),
        .pciclos(4),
        .FICHERO_INICIAL("freq_log.dat"),
        .shunt(1000)
    )
     control_path_inst (
        .clk125(clk125),
        .clk65(clk65),
        .areset_n(areset_n),
        .start(start),
        .test1(test1),
        .test2(test2),
        .test3(test3),
        .salto(salto),
        .numero_rep(numero_rep),
        .numero_ciclos(numero_ciclos),
        .numero_anchura(numero_anchura),
        .ADC_A(ADC_A),
        .ADC_B(ADC_B),
        .wren_sys(),
        .address_wr_sys(),
        .data_write_sys(),
        .data_read_sys(),
        .fin(fin),
        .fin2(fin2),
        .VALID_M(VALID_M),
        .VALID_P(VALID_P),
        .incrementado(incrementado),
        .DAC_S_registrado(DAC_S_registrado()),
        .MODULO(MODULO),
        .address_mem(address_mem),
        .address_mem2(address_mem2),
        .address_mem3(address_mem3),
        .estado_pasos_cero(estado_pasos_cero),
        .PHASE(PHASE),
        .PHASEA(PHASEA),
        .PHASEB(PHASEB)

    );

    // =============================================================================
    // SECUENCIA PRINCIPAL
    // =============================================================================
    initial begin
        f_actual = 10;
        while (f_actual <= 1e6) begin
            if (f_actual >=40)
                correr_punto(f_actual);
            f_actual *= $pow(10.0, 1.0/50.0);
        end
        $stop;
    end
//GENERADOR DE RELOJ    
initial begin
     clk125 = 1'b0;
     forever #(DT*1s) clk125 = ~clk125;
end
endmodule
