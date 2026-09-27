// =============================================================================
// Banco de Pruebas: Comparación 3-Puntas vs 4-Puntas (Kelvin)
// Objetivo: Comparar la precisión de ambas técnicas bajo las mismas
//           condiciones de ruido de contacto.
// =============================================================================

import "DPI-C" function void app_fft_radix2_dpi(
    input int N, input real in_re[1024], input real in_im[1024],
    output real out_re[1024], output real out_im[1024]
);
import dpi_pkg::*; // Este es el archivo generado por PySV
`timescale 1ns/1ps
module tb_comparacion_3p_vs_4p_portable_python;
    localparam int MAGNITUD_WIDTH = 14;
    localparam int N = 1024;
    localparam real PI = 3.14159265358979;
    localparam real DT = 8e-9; // Reloj de 125 MHz
    localparam real ADC_SCALE=8192.0; // Para mapear ±1V a ±8192 (14 bits)
    localparam bit  ENABLE_ADC3_NOISE = 1'b1;
    localparam real numero_medidas = 10; // Número de medidas a simular (diferentes condiciones de contacto)
    localparam real ADC3_NOISE_SIGMA_LSB = 0.5; // sigma de ruido en LSB del ADC
    localparam real R_CONT_MIN = 500.0;
    localparam real R_CONT_RANGO_MEDIDA = 1500.0;
    localparam real R_CONT_AMP_BARRIDO = 120.0;
    localparam real MICRO_F1_HZ = 0.35;      // microvariación lenta de presión
    localparam real MICRO_F2_HZ = 1.10;      // segunda componente lenta
    localparam real R_C1_MICRO_PCT = 0.04;   // ±4% alrededor de la base por medida
    localparam real CP_MICRO_PCT  = 0.06;    // ±6% alrededor de la base por medida
    localparam bit VERBOSE = 1;
    localparam bit activar_autoshunt = 1'b1; // Control para activar/desactivar el autoshunt en 3 puntas
   
    //señales digitales
    logic clk125;
    logic [13:0] dds_bus; // Bus de datos para el DAC (ej. salida de un DDS)
    logic [13:0] adc1_data_4p; // Nodo A
    logic [13:0] adc2_data_4p; // Nodo B
    logic [13:0] adc3_data_4p;  // Nodo C
    logic signed [13:0] adc3_data_4p_noisy; // Nodo C con ruido ADC aplicado
    logic signed [13:0] adc1_data_4p_noisy; // Nodo A
    logic signed [13:0] adc2_data_4p_noisy; // Nodo B
    logic [13:0] adc1_data_3p; // Nodo A
    logic [13:0] adc2_data_3p; // Nodo B_C

    logic areset_n;
    logic start;
    int medida; // índice de medida (0..9), asociado a k_degradacion=0.1..1.0
    logic test1, test2, test3;
    logic [7:0] salto;
    logic [8:0] numero_rep;
    logic [9:0] numero_ciclos;
    logic [9:0] numero_anchura;
    logic [3:0] numero_decimales;
    logic [MAGNITUD_WIDTH-1:0] ADC_A, ADC_B;

    logic [MAGNITUD_WIDTH-1:0] DAC_A;
    logic [31:0] incrementado;  
    logic fin, fin2, VALID_M, VALID_P;
    logic [MAGNITUD_WIDTH-1:0] DAC_S_registrado;
    logic [31:0] MODULO,MODULOA,MODULOB,MODULO2;

    logic [8:0] address_mem, address_mem2, address_mem3;
    logic [2:0] estado_pasos_cero;
    logic signed [31:0] PHASE, PHASEA, PHASEB;
    logic signed [31:0] PHASE2, PHASEA2, PHASEB2;


    logic autoshunt; // Control para activar/desactivar el autoshunt en 3 puntas
    logic cuantificacion;
     // --- PARÁMETROS DEL TEJIDO (Fijo - Golden Model) ---

    // --- PARÁMETROS DEL TEJIDO (Fijo - Golden Model) ---
    localparam real R_ext   = 20000.0; 
    localparam real R_int   = 1500.0;
    localparam real C_mem   = 5.0e-9;
    localparam real R_shunt = 100.0;
    localparam real R_contact1= 500.0; // Contacto del extremo de generación
    localparam real R_contact2= 500.0; // Contacto del extremo de shunt
    localparam real C_p1     = 1.0e-10; // Capacitancia parásita del electrodo 1
    localparam real C_p2     = 1.0e-10; // Capacitancia parásita del electrodo 2



    // --- VARIABLES FÍSICAS COMUNES ---
    real r_cont_instant; // Ruido de presión, común para ambas técnicas
    real r_cont_base_medida; // Componente lenta: cambia por medida
    real r_cont_delta_barrido; // Componente rápida: cambia en el barrido de frecuencias
    real r_c1, r_c2, cp_val;  
    real r_c1_base_medida, cp_base_medida;
    real t_inicio_medida_s;
    real rext_instant, rint_instant, c_mem_instant; // Variaciones instantáneas para el modelo 3p
    real k_degradacion; // Factor de degradación (0 a 1): mayor k => mayor R_int y R_ext
    integer seed = 12345; // Semilla para generación de ruido reproducible
    integer seed_adc3_noise;// = 24680;
    integer seed_adc1_noise;// = 13579;
    integer seed_adc2_noise;// = 11223;
    integer seeds_base[10] = '{24680, 13579, 11223, 44556, 99887, 77665, 55443, 33221, 12121, 89898};
    real v_gen, f_actual, fase_acc = 0;
    real v_c_mem = 0, i_total;
    real v_tejido, i_int;
    real node_re_p, node_re_n, node_shunt_high; // Nodos físicos reales
    
    // --- BUFFERS DE CAPTURA Y PROCESADO ---
    real v_im_z[N] = '{default:0}; // Parte imaginaria para FFTs (siempre cero)

    // Para 4-Puntas
    real v_a_4p, v_b_4p, v_c_4p;
    real adc1_v_p_4p[N], adc2_v_n_4p[N], adc3_v_sh_4p[N];
    real v_diff_4p[N], i_calc_4p[N];
    real V_fft_re_4p[N], V_fft_im_4p[N], I_fft_re_4p[N], I_fft_im_4p[N];
    real mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p;

    real den_4p;
    // Para 3-Puntas
    real v_a_3p, v_bc_3p;
    real v_gen_samp_3p[N], node_sh_samp_3p[N], i_total_samp_3p[N];
    real v_diff_3p[N], i_calc_3p[N];
    real V_fft_re_3p[N], V_fft_im_3p[N], I_fft_re_3p[N], I_fft_im_3p[N];
    real mag_z_3p, fase_z_3p, error_mag_3p, error_fase_3p;
    
    real den_3p;

//solucion correlacion autoshunt
    real modulo_4p_corr;
    real fase_4p_corr;
    real error_mag_4p_corr;
    real error_fase_4p_corr;
    real modulo_3p_corr;
    real fase_3p_corr;
    real error_mag_3p_corr;
    real error_fase_3p_corr;    
    real cola_frecuencias [$];

    int filas_guardadas;
    // --- GOLDEN MODEL (Resultados teóricos) ---
    real z_bio_re, z_bio_im, z_bio_mag, z_bio_fase;
    real omega, xc, den_bio;   
    real v_shunt_effective_authosunt;
    real cola_shunt_effective_authosunt [$];


//ajuste de autoshunt
    always_comb begin
      if (autoshunt) 
        case (estado_pasos_cero)
          3'b000:begin //decada de 10 a 100 Hz
            v_shunt_effective_authosunt = 2000.0; // Shunt desconectado
            numero_ciclos = 10'd4;
            numero_anchura = 10'd2;
            numero_decimales = 4'd9; // Para la división, se puede usar una precisión fija de 4 decimales (equivale a <<12) para mantener la consistencia con el método FFT, que tiene una resolución limitada por el número de muestras y el ruido. Esto también evita complicaciones adicionales en la gestión de bits en la división, manteniendo un buen equilibrio entre precisión y complejidad.
            end
          3'b001:begin //decada de 100 a 1000 Hz
            v_shunt_effective_authosunt = 1000.0; // Solo shunt
            numero_ciclos = 10'd4;
            numero_anchura = 10'd2;
            numero_decimales = 4'd8; // Para la división, se puede usar una precisión fija de 4 decimales (equivale a <<12) para mantener la consistencia con el método FFT, que tiene una resolución limitada por el número de muestras y el ruido. Esto también evita complicaciones adicionales en la gestión de bits en la división, manteniendo un buen equilibrio entre precisión y complejidad.
            end
          3'b010: begin //decada de 1 kHz a 10 kHz
            v_shunt_effective_authosunt = 500.0; // Contacto 2 + shunt
            numero_ciclos = 10'd5 ;
            numero_anchura = 10'd2;
            numero_decimales = 4'd6; // Para la división, se puede usar una precisión fija de 4 decimales (equivale a <<12) para mantener la consistencia con el método FFT, que tiene una resolución limitada por el número de muestras y el ruido. Esto también evita complicaciones adicionales en la gestión de bits en la división, manteniendo un buen equilibrio entre precisión y complejidad.
            end
          3'b011: begin //decada de 10 kHz a 100 kHz
            v_shunt_effective_authosunt = 285.71; // Contacto 1 + contacto 2 + shunt
            numero_ciclos = 10'd5;
            numero_anchura = 10'd2;
            numero_decimales = 4'd5; // Para la división, se puede usar una precisión fija de 4 decimales (equivale a <<12) para mantener la consistencia con el método FFT, que tiene una resolución limitada por el número de muestras y el ruido. Esto también evita complicaciones adicionales en la gestión de bits en la división, manteniendo un buen equilibrio entre precisión y complejidad.
            end
          default: begin // decada de 100 kHz a 1 MHz, y cualquier otro estado, shunt desconectado
            v_shunt_effective_authosunt = 100.0; // Cualquier otro estado, shunt desconectado
            numero_ciclos = 10'd64;
            numero_anchura = 10'd2;
            numero_decimales = 4'd4;
            end
        endcase
     else begin
        numero_ciclos = 10'd5; // Si no se activa autoshunt, se hacen ciclos completos para FFT
        v_shunt_effective_authosunt = R_shunt; // Si autoshunt no está activo, el shunt es como si no existiera
        numero_anchura = 10'd2;
        numero_decimales = 4; // Para la división, se puede usar una precisión fija de 4 decimales (equivale a <<12) para mantener la consistencia con el método FFT, que tiene una resolución limitada por el número de muestras y el ruido. Esto también evita complicaciones adicionales en la gestión de bits en la división, manteniendo un buen equilibrio entre precisión y complejidad.
      end   


    end

    // =============================================================================
    // MODELO FÍSICO (�?NICO Y COMPARTIDO)
    // =============================================================================

    top_bioimpedancia_circuito_medida_portable #(.R_contact1(R_contact1), .R_contact2(R_contact2), .R_ext(R_ext), .R_int(R_int), .C_mem(C_mem), .R_shunt(R_shunt), .C_p1(C_p1), .C_p2(C_p2)) analog_circuit  (
    .clk(clk125),
    .dds_bus(dds_bus),
    .senoide(v_gen),
    .cuantificacion(cuantificacion), // Control para activar/desactivar la cuantificación del ADC 
    .autoshunt_value(v_shunt_effective_authosunt), // Controla el autoshunt en 3 puntas, se puede variar para simular diferentes condiciones de contacto
    .r_cont_instant(r_c1),
    .c_contact1(cp_val),

// Controla el autoshunt en 3 puntas, se puede variar para simular diferentes condiciones de contacto
    .v_a_4p(v_a_4p),
     .v_b_4p(v_b_4p),
      .v_c_4p(v_c_4p),
    .v_a_3p(v_a_3p),
    .v_bc_3p(v_bc_3p),
    .rext_instant(rext_instant),
    .rint_instant(rint_instant),
    .c_mem_instant(c_mem_instant),
    .adc1_data_4p(adc1_data_4p), // Solo para observar en el testbench, no afecta a la lógica digital
    .adc2_data_4p(adc2_data_4p),
    .adc3_data_4p(adc3_data_4p),
    .adc1_data_3p(adc1_data_3p),
    .adc2_data_3p(adc2_data_3p)
    );  

    // Inyección de ruido ADC por muestra (dominio digital, en LSB) para el canal shunt 4p.
    // Se aplica aguas arriba para que afecte tanto al método FFT como al método de correlación.
    always_ff @(posedge clk125) begin
        int code_raw_3;
        int noise_q16_3;
        int noise_lsb_3;
        int code_noisy_3;
        int code_raw_2;
        int noise_q16_2;
        int noise_lsb_2;
        int code_noisy_2;  
        int code_raw_1;
        int noise_q16_1;
        int noise_lsb_1;
        int code_noisy_1;
     

        code_raw_3 = signed'(adc3_data_4p);
        code_raw_2 = signed'(adc2_data_4p);
        code_raw_1 = signed'(adc1_data_4p);
        if (ENABLE_ADC3_NOISE) begin
            noise_q16_3 = $dist_normal(seed_adc3_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_3 = (noise_q16_3 >= 0) ? ((noise_q16_3 + 32768) / 65536) : -(((-noise_q16_3) + 32768) / 65536);
            code_noisy_3 = code_raw_3 + noise_lsb_3;
            if (code_noisy_3 > 8191)
                code_noisy_3 = 8191;
            else if (code_noisy_3 < -8192)
                code_noisy_3 = -8192;
            //ahora para el ADC2
            noise_q16_2 = $dist_normal(seed_adc2_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_2 = (noise_q16_2 >= 0) ? ((noise_q16_2 + 32768) / 65536) : -(((-noise_q16_2) + 32768) / 65536);
            code_noisy_2 = code_raw_2 + noise_lsb_2;
            if (code_noisy_2 > 8191)
                code_noisy_2 = 8191;
            else if (code_noisy_2 < -8192)                
                code_noisy_2 = -8192;
            //ahora para el ADC1

            noise_q16_1 = $dist_normal(seed_adc1_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_1 = (noise_q16_1 >= 0) ? ((noise_q16_1 + 32768) / 65536) : -(((-noise_q16_1) + 32768) / 65536);
            code_noisy_1 = code_raw_1 + noise_lsb_1;
            if (code_noisy_1 > 8191)
                code_noisy_1 = 8191;
            else if (code_noisy_1 < -8192)
                code_noisy_1 = -8192;

            adc3_data_4p_noisy <= code_noisy_3[13:0];
            adc1_data_4p_noisy <= code_noisy_1[13:0]; // Para simular ruido en ambos canales, se podría aplicar el mismo proceso a adc1_data_4p y adc2_data_4p
            adc2_data_4p_noisy <= code_noisy_2[13:0];
        end else begin
            adc3_data_4p_noisy <= adc3_data_4p;
            adc1_data_4p_noisy <= adc1_data_4p;
            adc2_data_4p_noisy <= adc2_data_4p;
        end
    end



    // =============================================================================
    // TAREA DE SIMULACI�?N extracción de impedancias por FFT y cálculo de errores
    // =============================================================================
    task automatic correr_punto(real freq);
        real t_muestreo = (3.0 / freq) / N;
        f_actual = freq;
        cola_shunt_effective_authosunt.push_front(v_shunt_effective_authosunt);        
       // r_cont_instant =  500.0 + $urandom_range(0, 1500); 
        //#500us; // Estabilización
        #((2.0 / freq)*1s); // Espera un par de ciclos para asegurar fase estable

        // --- FASE DE MUESTREO (Simultánea para ambas técnicas) ---
        for (int i=0; i<N; i++) begin
            if(cuantificacion) begin
                // Captura para 4-Puntas (mide nodos internos)
                adc1_v_p_4p[i]  = real'(signed'(adc1_data_4p_noisy)) / ADC_SCALE;
                adc2_v_n_4p[i]  = real'(signed'(adc2_data_4p_noisy)) / ADC_SCALE;
                adc3_v_sh_4p[i] = real'(signed'(adc3_data_4p_noisy)) / ADC_SCALE;

                // Captura para 3-Puntas (mide en los extremos del lazo de corriente)
                v_gen_samp_3p[i]   = real'(signed'(adc1_data_3p)) / ADC_SCALE; // Voltaje de generación (Nodo E)
                node_sh_samp_3p[i] = real'(signed'(adc2_data_3p)) / ADC_SCALE;
                i_total_samp_3p[i] = real'(signed'(adc2_data_3p)) / (ADC_SCALE *v_shunt_effective_authosunt ); // Para la derivación del modelo 3p
            end else begin
                // Si no se quiere cuantificación, se pueden usar las señales reales directamente
                adc1_v_p_4p[i]  = v_a_4p;
                adc2_v_n_4p[i]  = v_b_4p;
                adc3_v_sh_4p[i] = v_c_4p;

                v_gen_samp_3p[i]   = v_a_3p;
                node_sh_samp_3p[i] = v_bc_3p;
                i_total_samp_3p[i] = v_bc_3p / v_shunt_effective_authosunt; // Para la derivación del modelo 3p
            end

            #(t_muestreo * 1s);
        end
     
        // --- PROCESADO DIGITAL (FPGA) ---
        // Para 4-Puntas
        for (int i=0; i<N; i++) begin
            v_diff_4p[i] = adc1_v_p_4p[i] - adc2_v_n_4p[i];
            i_calc_4p[i] = adc3_v_sh_4p[i] / v_shunt_effective_authosunt;
        end
        app_fft_radix2_dpi(N, v_diff_4p, v_im_z, V_fft_re_4p, V_fft_im_4p);
        app_fft_radix2_dpi(N, i_calc_4p, v_im_z, I_fft_re_4p, I_fft_im_4p);
        // Para 4-Puntas
        den_4p = (I_fft_re_4p[3]**2 + I_fft_im_4p[3]**2);
        mag_z_4p = $sqrt((V_fft_re_4p[3]**2 + V_fft_im_4p[3]**2) / den_4p);
        fase_z_4p = $atan2((V_fft_im_4p[3]*I_fft_re_4p[3] - V_fft_re_4p[3]*I_fft_im_4p[3]), 
                           (V_fft_re_4p[3]*I_fft_re_4p[3] + V_fft_im_4p[3]*I_fft_im_4p[3])) * (180.0/PI);

       /* 
        // Para 3-Puntas (simula la medida con error de contacto)
        // V_medido = V(extremo_gen) - V(extremo_shunt)
        // V(extremo_gen) = v_gen - i_total * r_cont_instant
        // V(extremo_shunt) = node_shunt_high
        for (int i=0; i<N; i++) begin
             v_diff_3p[i] = (v_gen_samp_3p[i] - i_total_samp_3p[i] * r_cont_instant) - node_sh_samp_3p[i];
             i_calc_3p[i] = node_sh_samp_3p[i] / v_shunt_effective_authosunt;
        end

        // --- FFTs ---
        app_fft_radix2_dpi(N, v_diff_3p, v_im_z, V_fft_re_3p, V_fft_im_3p);
        app_fft_radix2_dpi(N, i_calc_3p, v_im_z, I_fft_re_3p, I_fft_im_3p);

        // --- CÁLCULO DE IMPEDANCIA ---
        // Para 3-Puntas
        den_3p = (I_fft_re_3p[3]**2 + I_fft_im_3p[3]**2);
        mag_z_3p = $sqrt((V_fft_re_3p[3]**2 + V_fft_im_3p[3]**2) / den_3p);
        fase_z_3p = $atan2((V_fft_im_3p[3]*I_fft_re_3p[3] - V_fft_re_3p[3]*I_fft_im_3p[3]), 
                           (V_fft_re_3p[3]*I_fft_re_3p[3] + V_fft_im_3p[3]*I_fft_im_3p[3])) * (180.0/PI);
*/
        // --- GOLDEN MODEL (Común para ambos) ---

        omega = 2.0 * PI * freq;
        xc = 1.0 / (omega * c_mem_instant);
        den_bio = (rext_instant + rint_instant)**2 + xc**2;
        z_bio_re = (rext_instant * (rint_instant*(rext_instant + rint_instant) + xc**2)) / den_bio;
        z_bio_im = (rext_instant**2 * -(xc)) / den_bio;
        z_bio_mag  = $sqrt(z_bio_re**2 + z_bio_im**2);
        z_bio_fase = $atan2(z_bio_im, z_bio_re) * (180.0 / PI);

        // --- CÁLCULO DE ERRORES ---

        error_mag_4p  = (mag_z_4p > z_bio_mag) ? ((mag_z_4p - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - mag_z_4p)/z_bio_mag)*100.0;
        error_fase_4p = (fase_z_4p > z_bio_fase) ? (fase_z_4p - z_bio_fase) : (z_bio_fase - fase_z_4p);
/*
        error_mag_3p  = (mag_z_3p > z_bio_mag) ? ((mag_z_3p - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - mag_z_3p)/z_bio_mag)*100.0;
        error_fase_3p = (fase_z_3p > z_bio_fase) ? (fase_z_3p - z_bio_fase) : (z_bio_fase - fase_z_3p);
*/
        // --- DISPLAY ---
          if (VERBOSE) begin
          $display("F:%9.0f Hz | R_cont:%4.0f Ohm", freq, r_cont_instant);
          $display("  Z_Golden -> Mag: %8.1f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
          $display("  Z_4P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p);
     //   $display("  Z_3P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_3p, fase_z_3p, error_mag_3p, error_fase_3p);
        $display("");
          end
    endtask

    task automatic guardar_dato_ram(int sujeto_id, int medida_id, real frecuencia, real modulo, real fase);
        int frecuencia_milli;
        int modulo_milli;
        int fase_milli;
        frecuencia_milli = $rtoi(frecuencia * 1000.0);
        modulo_milli = $rtoi(modulo * 1000.0);
        fase_milli = $rtoi(fase * 1000.0);
    endtask

//intanciacion generado DDs y calculador impedancias por correlacion
    Control_path_best_rafa_mejora_correlacion_autoshunt_4p_mejorado #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(9),
        .MAGNITUD_WIDTH(MAGNITUD_WIDTH),
        .pancho_detector(2),
        .pciclos(4),
        .FICHERO_INICIAL("freq_log_ideal.dat"),
        .shunt(1000)
    )
     control_path_4p_inst (
        .clk125(clk125),
        .clk65(clk65),
        .areset_n(areset_n),
        .start(start),
        .test1(1'b0),
        .test2(1'b0),
        .test3(1'b1),
        .salto(salto),
        .numero_rep(9'd225),
        .num_ciclos(numero_ciclos),
        .numero_anchura(numero_anchura),
        .n_decimales(numero_decimales),
        .ADC_A(adc1_data_4p_noisy),
        .ADC_B(adc2_data_4p_noisy),
        .ADC_C(adc3_data_4p_noisy),
        .wren_sys(),
        .address_wr_sys(),
        .data_write_sys(),
        .data_read_sys(),
        .fin(fin),
        .fin2(fin2),
        .VALID_M(VALID_M),
        .VALID_P(VALID_P),
        .incrementado(incrementado),
        .DAC_S_registrado(dds_bus),
        .MODULO(MODULO),
        .address_mem(address_mem),
        .address_mem2(address_mem2),
        .address_mem3(address_mem3),
        .estado_pasos_cero(estado_pasos_cero),
        .MODULOA(MODULOA),
        .MODULOB(MODULOB),
        .PHASE(PHASE),
        .PHASEA(PHASEA),
        .PHASEB(PHASEB)

    );
    /*
    Control_path_best_rafa_mejora_correlacion_autoshunt #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(9),
        .MAGNITUD_WIDTH(MAGNITUD_WIDTH),
        .pancho_detector(10),
        .pciclos(4),
        .FICHERO_INICIAL("freq_log_ideal.dat"),
        .shunt(1000)
    )
     control_path_3p_inst (
        .clk125(clk125),
        .clk65(clk65),
        .areset_n(areset_n),
        .start(start),
        .test1(1'b0),
        .test2(1'b0),
        .test3(1'b1),
        .salto(salto),
        .numero_rep(9'd225),
        .num_ciclos(4'd6),
        .numero_anchura(numero_anchura),
        .ADC_A(adc1_data_3p_noisy),
        .ADC_B(adc2_data_3p_noisy),
        .wren_sys(),
        .address_wr_sys(),
        .data_write_sys(),
        .data_read_sys(),
        .fin(),
        .fin2(),
        .VALID_M(VALID_M2),
        .VALID_P(VALID_P2),
        .incrementado(),
        .DAC_S_registrado(),
        .MODULO(MODULO2),
        .address_mem(),
        .address_mem2(),
        .address_mem3(),
        .estado_pasos_cero(),
        .PHASE(PHASE2),
        .PHASEA(PHASEA2),
        .PHASEB(PHASEB2)

    );
*/
    // =============================================================================
    // SECUENCIA PRINCIPAL
    // =============================================================================
    initial 
    
    begin

        
        r_cont_base_medida = R_CONT_MIN;
        r_cont_delta_barrido = 0.0;
        r_cont_instant = r_cont_base_medida;
        r_c1=r_cont_base_medida;
        r_c2=r_cont_base_medida;
        cp_val = 10e-12;
        r_c1_base_medida = r_c1;
        cp_base_medida = cp_val;
        rext_instant = R_ext ; 
        rint_instant = R_int ;
        c_mem_instant = C_mem ;
        t_inicio_medida_s = 0.0;
        medida = 0;
        start = 0;
        autoshunt = activar_autoshunt; // Activamos el autoshunt para simular la técnica de 3 puntas
        cuantificacion = 1'b1 ; // Activamos la cuantificación para simular el efecto del ADC
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);
        areset_n = 1'b0;
        repeat(3) @(negedge clk125);
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);
        // Espera adicional para asegurar que todo se ha reseteado correctamente

        for (int idx_k = 0; idx_k < numero_medidas; idx_k++) begin
            medida = idx_k;
            seed_adc3_noise = seeds_base[idx_k]; // Cambiamos la semilla para cada medida para simular diferentes condiciones de ruido
            seed_adc1_noise= seeds_base[idx_k] + 1000; // Semilla diferente para cada canal, pero relacionada para simular condiciones similares
            seed_adc2_noise= seeds_base[idx_k] + 2000;
            r_cont_base_medida = R_CONT_MIN + $urandom_range(0, int'(R_CONT_RANGO_MEDIDA));
            r_cont_instant = r_cont_base_medida;
            // Barrido de degradación: 0.1, 0.2, ..., 1.0
            k_degradacion = real'((idx_k + 1) / numero_medidas);
            r_c1_base_medida   = 1000.0 + $urandom_range(0, 4000); // 1k a 5k
            cp_base_medida = 10e-12  + ($urandom_range(0, 190) * 1e-12); // 10p a 200p
            r_c1 = r_c1_base_medida;
            cp_val = cp_base_medida;
            t_inicio_medida_s = $realtime * 1e-9;
            // --- MODELO REFINADO DE ÁCIDO LÁCTICO Y RUPTURA CELULAR ---
            // 1. Aumento de conductividad extracelular (lactato/protones)
            rext_instant  = R_ext * (1.0 - (0.5 * k_degradacion)); 

            // 2. Ruptura del equilibrio osmótico interno
             rint_instant  = R_int * (1.0 - (0.2 * k_degradacion));

            // 3. CAÍDA NO LINEAL: Colapso de la membrana (Dieléctrico dañado)
            // Al final del sweep (k=1.0), la membrana casi desaparece eléctricamente
            c_mem_instant = C_mem * (1.0 / (1.0 + 5.0 * k_degradacion));
            //deshidratacion la comento porque no es tan relevante en este caso y complica mucho el modelo, pero se podría simular con un aumento de R_int y R_ext (menos agua -> más resistencia) 
            //rext_instant = R_ext  * (1.0 + (0.4 * k_degradacion)); // 20k a 28k
            //rint_instant = R_int * (1.0 + (0.3 * k_degradacion)); // 1.5k a 1.95k
            //c_mem_instant = C_mem * (1.0 - (0.2 * k_degradacion)); // 5n a 4n
            start = 1;
            @(negedge clk125);
                start = 0;
            @(posedge fin);

            #1000ns; // Espera para asegurar que todo se ha estabilizado antes de terminar la simulación
        end
        $display("\nSimulación finalizada. Procesando datos en Python...");
        procesar_dataframe();
            $finish;
    end
//GENERADOR DE RELOJ    
initial begin
     clk125 = 1'b0;
     forever #((DT/2)*1s) clk125 = ~clk125;
end
always@( incrementado) //para cálculo de las FFTs en función de la frecuencia actual del DDS
begin
    real t_local_s;
    real micro_presion;

    f_actual = (real'(incrementado) / 4294967296.0) * 125000000.0; // Cálculo de frecuencia actual basada en el incremento
    if (f_actual > 1.0) begin
    t_local_s = ($realtime * 1e-9) - t_inicio_medida_s;
    micro_presion = 0.65*$sin(2.0*PI*MICRO_F1_HZ*t_local_s) + 0.35*$sin(2.0*PI*MICRO_F2_HZ*t_local_s + 0.7);

    // Base inter-medidas + microvariación intra-medida (presión)
    // Más presión -> baja R de contacto y sube C de contacto
    r_c1 = r_c1_base_medida * (1.0 - R_C1_MICRO_PCT*micro_presion);
    cp_val = cp_base_medida * (1.0 + CP_MICRO_PCT*micro_presion);
    if (r_c1 < 1.0)
        r_c1 = 1.0;
    if (cp_val < 1e-13)
        cp_val = 1e-13;

    r_cont_delta_barrido = R_CONT_AMP_BARRIDO * $sin(2.0 * PI * ($ln(f_actual + 1.0) / $ln(10.0)));
    r_cont_instant = r_c1;
    if (r_cont_instant < 1.0)
        r_cont_instant = 1.0;
    correr_punto(f_actual);
    cola_frecuencias.push_front(f_actual);
    guardar_dato(1,medida,f_actual,mag_z_4p,fase_z_4p, 0.0, 0.0, 0.0, 0.0); // Guardamos golden para el método de 4 puntas de esta medida
    guardar_dato(2,medida,f_actual,z_bio_mag ,z_bio_fase, 0.0, 0.0, 0.0, 0.0); // Guardamos golden para el k_degradacion de esta medida
    end
       
end

always @(posedge clk125) begin
    real fases,fases2;
    real fasesa,fasesb;
    real fases_post,fases2_post;
    real modulo_post,modulo2_post;
    real modulo_a, modulo_b;
    real cola_modulo [$]; // Para almacenar los últimos valores de módulo y fase y evitar fluctuaciones extremas en la visualización
    real cola_fase [$];
    real cola_modulo2 [$];
    real cola_fase2 [$];
    real frecuencia_almacenada;
    real shunt_efectivo;

    if (VALID_M) begin
        shunt_efectivo = cola_shunt_effective_authosunt.pop_back(); // Obtenemos el valor de shunt efectivo correspondiente a esta medida
        modulo_post=(real'(MODULO)*shunt_efectivo/real'(1<<numero_decimales));//esto debe ser congruente con el desplazamiento del divisor final
        modulo_a=(real'(MODULOA));
        modulo_b=(real'(MODULOB));
//        modulo2_post=(real'(MODULO2)*shunt_efectivo/16.0);
        if (VERBOSE)
            $display("Modulos obtenidos metodo 4p correlacion: %9.2f Hz, MODULO: %9.2f, MODULOA: %9.2f, MODULOB: %9.2f", f_actual, modulo_post, modulo_a, modulo_b);
        error_mag_4p_corr  = (modulo_post > z_bio_mag) ? ((modulo_post - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_post)/z_bio_mag)*100.0;
        if (VERBOSE)
            $display("Error de magnitud metodo 4p correlacion: %5.2f%%", error_mag_4p_corr);
        cola_modulo.push_front(modulo_post);


    end   
    /*
        if (VALID_M2) begin
        modulo2_post=(real'(MODULO2)*shunt_efectivo/16.0);
        if (VERBOSE)
            $display("Frecuencia actual del DDS 3p correlacion: %9.2f Hz,  MODULO: %9.2f", f_actual, modulo2_post);
        error_mag_3p_corr  = (modulo2_post > z_bio_mag) ? ((modulo2_post - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo2_post)/z_bio_mag)*100.0;
        if (VERBOSE)
            $display("Error de magnitud metodo 3p correlacion: %5.2f%%", error_mag_3p_corr);
        cola_modulo2.push_front(modulo2_post);
     
    end 
        */
    if (VALID_P) begin
        fases=real'(PHASE)/8.0;
        fasesa=real'(PHASEA)/8.0;
        fasesb=real'(PHASEB)/8.0;
        if (fases<=-90.0)
            fases_post=fases+180.0;
        else if (fases>=90.0)
            fases_post=fases-180.0;
        else
            fases_post=fases;
        if (VERBOSE)
            $display("Fases obtenidas metodo 4p correlacion: %9.2f Hz, Fase: %9.2f grados, FaseA: %9.2f grados, FaseB: %9.2f grados", f_actual, fases_post, fasesa, fasesb);
        error_fase_4p_corr = (fases_post > z_bio_fase) ? (fases_post - z_bio_fase) : (z_bio_fase - fases_post);
        if (VERBOSE)
            $display("Error de fase metodo 4p correlacion: %9.2f grados", error_fase_4p_corr);
        cola_fase.push_front(fases_post);
    end
    /*
    if (VALID_P2) begin
        fases2=-real'(PHASE2)/8.0;
        if (fases2<=-90.0)
            fases2_post=fases2+180.0;
        else if (fases2>=90.0)
            fases2_post=fases2-180.0;
        else
            fases2_post=fases2;           
        if (VERBOSE)
            $display("Frecuencia actual del DDS 3p correlacion: %9.2f Hz, Fase: %9.2f grados", f_actual, fases2_post);
        error_fase_3p_corr = (fases2_post > z_bio_fase) ? (fases2_post - z_bio_fase) : (z_bio_fase - fases2_post);
        if (VERBOSE)
            $display("Error de fase metodo 3p correlacion: %9.2f grados", error_fase_3p_corr);
        cola_fase2.push_front(fases2_post);
    end
        */
    //modulo_4p_corr=modulo_post;
    //fase_4p_corr=fases_post;
    //modulo_3p_corr=modulo2_post;
    //fase_3p_corr=fases2_post;  
    if (cola_modulo.size() > 0 && cola_fase.size()>0)
        begin 
            modulo_4p_corr= cola_modulo.pop_back(); // Mantener solo los últimos 5 valores para suavizar la visualización
            fase_4p_corr= cola_fase.pop_back();
            frecuencia_almacenada=cola_frecuencias.pop_back();
            guardar_dato(0,medida,frecuencia_almacenada,modulo_4p_corr,fase_4p_corr, modulo_a, fasesa, modulo_b, fasesb);
        
        end 
        /*
    if (cola_modulo2.size() > 0 && cola_fase2.size()>0)
        begin 
            modulo_3p_corr= cola_modulo2.pop_back(); // Mantener solo los últimos 5 valores para suavizar la visualización
            fase_3p_corr= cola_fase2.pop_back();
            guardar_dato(1,medida,frecuencia_almacenada,modulo_3p_corr,fase_3p_corr);
        end 
        */    
        
    end
        


    always @(posedge clk125) begin
        fase_acc += 2.0 * PI * f_actual * DT;
        if (fase_acc >= 2.0*PI) fase_acc -= 2.0*PI;
        v_gen = 1.0 * $sin(fase_acc);


    end
endmodule
