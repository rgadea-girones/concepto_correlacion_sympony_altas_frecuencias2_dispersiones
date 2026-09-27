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
    localparam real R_CONT_MIN = 500.0;
    localparam real R_CONT_RANGO_MEDIDA = 1500.0;
    localparam real R_CONT_AMP_BARRIDO = 120.0;
   
    //señales digitales
    logic clk125;
    logic [13:0] dds_bus; // Bus de datos para el DAC (ej. salida de un DDS)
    logic [13:0] adc1_data_4p; // Nodo A
    logic [13:0] adc2_data_4p; // Nodo B
    logic [13:0] adc3_data_4p;  // Nodo C
    logic [13:0] adc1_data_3p; // Nodo A
    logic [13:0] adc2_data_3p; // Nodo B_C

    logic areset_n;
    logic start;
    int medida; //par congelado impar descongelado
    int congelacion; // 0 para 4p, 1 para 3p
    logic test1, test2, test3;
    logic [7:0] salto;
    logic [8:0] numero_rep;
    logic [3:0] numero_ciclos;
    logic [15:0] numero_anchura;
    logic [MAGNITUD_WIDTH-1:0] ADC_A, ADC_B;

    logic [MAGNITUD_WIDTH-1:0] DAC_A;
    logic [31:0] incrementado;  
    logic fin, fin2, VALID_M, VALID_P;
    logic [MAGNITUD_WIDTH-1:0] DAC_S_registrado;
    logic [31:0] MODULO,MODULO2;
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
    // --- GOLDEN MODEL (Resultados teóricos) ---
    real z_bio_re, z_bio_im, z_bio_mag, z_bio_fase;
    real omega, xc, den_bio;   
    real v_shunt_effective_authosunt;


//ajuste de autoshunt
    always_comb begin
      if (autoshunt) begin
        case (estado_pasos_cero)
          3'b000: v_shunt_effective_authosunt = 2000.0; // Shunt desconectado
          3'b001: v_shunt_effective_authosunt = 1000.0; // Solo shunt
          3'b010: v_shunt_effective_authosunt = 500.0; // Contacto 2 + shunt
          3'b011: v_shunt_effective_authosunt = 285.71; // Contacto 1 + contacto 2 + shunt
          default: v_shunt_effective_authosunt = 100.0; // Cualquier otro estado, shunt desconectado
        endcase
      end else begin
        v_shunt_effective_authosunt = R_shunt; // Si autoshunt no está activo, el shunt es como si no existiera
      end   

    end

    // =============================================================================
    // MODELO FÍSICO (ÚNICO Y COMPARTIDO)
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
    .adc1_data_4p(adc1_data_4p), // Solo para observar en el testbench, no afecta a la lógica digital
    .adc2_data_4p(adc2_data_4p),
    .adc3_data_4p(adc3_data_4p),
    .adc1_data_3p(adc1_data_3p),
    .adc2_data_3p(adc2_data_3p)
    );  



    // =============================================================================
    // TAREA DE SIMULACIÓN extracción de impedancias por FFT y cálculo de errores
    // =============================================================================
    task automatic correr_punto(real freq);
        real t_muestreo = (3.0 / freq) / N;
        f_actual = freq;
        
       // r_cont_instant =  500.0 + $urandom_range(0, 1500); 
        //#500us; // Estabilización
        #((2.0 / freq)*1s); // Espera un par de ciclos para asegurar fase estable

        // --- FASE DE MUESTREO (Simultánea para ambas técnicas) ---
        for (int i=0; i<N; i++) begin
            if(cuantificacion) begin
                // Captura para 4-Puntas (mide nodos internos)
                adc1_v_p_4p[i]  = real'(signed'(adc1_data_4p)) / ADC_SCALE;
                adc2_v_n_4p[i]  = real'(signed'(adc2_data_4p)) / ADC_SCALE;
                adc3_v_sh_4p[i] = real'(signed'(adc3_data_4p)) / ADC_SCALE;

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
     /*
        // --- PROCESADO DIGITAL (FPGA) ---
        // Para 4-Puntas
        for (int i=0; i<N; i++) begin
            v_diff_4p[i] = adc1_v_p_4p[i] - adc2_v_n_4p[i];
            i_calc_4p[i] = adc3_v_sh_4p[i] / v_shunt_effective_authosunt;
        end
        
        // Para 3-Puntas (simula la medida con error de contacto)
        // V_medido = V(extremo_gen) - V(extremo_shunt)
        // V(extremo_gen) = v_gen - i_total * r_cont_instant
        // V(extremo_shunt) = node_shunt_high
        for (int i=0; i<N; i++) begin
             v_diff_3p[i] = (v_gen_samp_3p[i] - i_total_samp_3p[i] * r_cont_instant) - node_sh_samp_3p[i];
             i_calc_3p[i] = node_sh_samp_3p[i] / v_shunt_effective_authosunt;
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
*/
        // --- GOLDEN MODEL (Común para ambos) ---

        omega = 2.0 * PI * freq;
        xc = 1.0 / (omega * C_mem);
        den_bio = (R_ext + R_int)**2 + xc**2;
        z_bio_re = (R_ext * (R_int*(R_ext + R_int) + xc**2)) / den_bio;
        z_bio_im = (R_ext**2 * -(xc)) / den_bio;
        z_bio_mag  = $sqrt(z_bio_re**2 + z_bio_im**2);
        z_bio_fase = $atan2(z_bio_im, z_bio_re) * (180.0 / PI);

        // --- CÁLCULO DE ERRORES ---
/*
        error_mag_4p  = (mag_z_4p > z_bio_mag) ? ((mag_z_4p - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - mag_z_4p)/z_bio_mag)*100.0;
        error_fase_4p = (fase_z_4p > z_bio_fase) ? (fase_z_4p - z_bio_fase) : (z_bio_fase - fase_z_4p);
        error_mag_3p  = (mag_z_3p > z_bio_mag) ? ((mag_z_3p - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - mag_z_3p)/z_bio_mag)*100.0;
        error_fase_3p = (fase_z_3p > z_bio_fase) ? (fase_z_3p - z_bio_fase) : (z_bio_fase - fase_z_3p);
*/
        // --- DISPLAY ---
        $display("F:%9.0f Hz | R_cont:%4.0f Ohm", freq, r_cont_instant);
        $display("  Z_Golden -> Mag: %8.1f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
     //   $display("  Z_4P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p);
     //   $display("  Z_3P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_3p, fase_z_3p, error_mag_3p, error_fase_3p);
        $display("");
    endtask

//intanciacion generado DDs y calculador impedancias por correlacion
    Control_path_best_rafa_mejora_correlacion_autoshunt_4p #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(9),
        .MAGNITUD_WIDTH(MAGNITUD_WIDTH),
        .pancho_detector(10),
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
        .num_ciclos(4'd6),
        .numero_anchura(numero_anchura),
        .ADC_A(adc1_data_4p),
        .ADC_B(adc2_data_4p),
        .ADC_C(adc3_data_4p),
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
        .PHASE(PHASE),
        .PHASEA(PHASEA),
        .PHASEB(PHASEB)

    );
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
        .ADC_A(adc1_data_3p),
        .ADC_B(adc2_data_3p),
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
        medida = 0;
        congelacion=0;
        start = 0;
        autoshunt = 1'b0; // Activamos el autoshunt para simular la técnica de 3 puntas
        cuantificacion = 1'b1 ; // Activamos la cuantificación para simular el efecto del ADC
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);
        areset_n = 1'b0;
        repeat(3) @(negedge clk125);
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);
        // Espera adicional para asegurar que todo se ha reseteado correctamente

        repeat(3)
        begin
            r_cont_base_medida = R_CONT_MIN + $urandom_range(0, int'(R_CONT_RANGO_MEDIDA));
            r_cont_instant = r_cont_base_medida;
            congelacion=0;
             //
            //atun congelado
            r_c1   = 1000.0 + $urandom_range(0, 4000); // 1k a 5k
            cp_val = 10e-12  + ($urandom_range(0, 190) * 1e-12); // 10p a 200p
            start = 1;
            @(negedge clk125);
                start = 0;
            @(posedge fin);

            #1000ns; // Espera para asegurar que todo se ha estabilizado antes de terminar la simulación
            medida=medida+1;
        end
        medida=0;
        repeat(3)
        begin
            r_cont_base_medida = R_CONT_MIN + $urandom_range(0, int'(R_CONT_RANGO_MEDIDA));
            r_cont_instant = r_cont_base_medida;
            congelacion=1;
             //
            // atun descongelado
            r_c1   = 200.0  + $urandom_range(0, 400);  // 200 a 600
            cp_val = 1e-9    + ($urandom_range(0, 9) * 1e-9);   // 1n a 10n             
            start = 1;
            @(negedge clk125);
                start = 0;
            @(posedge fin);

            #1000ns; // Espera para asegurar que todo se ha estabilizado antes de terminar la simulación
            medida=medida+1;
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
    f_actual = (real'(incrementado) / 4294967296.0) * 125000000.0; // Cálculo de frecuencia actual basada en el incremento
    if (f_actual > 1.0) begin
    r_cont_delta_barrido = R_CONT_AMP_BARRIDO * $sin(2.0 * PI * ($ln(f_actual + 1.0) / $ln(10.0)));
    r_cont_instant = r_cont_base_medida + r_cont_delta_barrido;
    if (r_cont_instant < 1.0)
        r_cont_instant = 1.0;
    correr_punto(f_actual);
    cola_frecuencias.push_front(f_actual);
    guardar_dato(2,2*medida+congelacion,f_actual,z_bio_mag ,z_bio_fase, 0.0, 0.0, 0.0, 0.0); // Guardamos un punto inicial con frecuencia y errores a cero para referencia
    end
       
end

always @(posedge clk125) begin
    real fases,fases2;
    real fases_post,fases2_post;
    real modulo_post,modulo2_post;
    real cola_modulo [$]; // Para almacenar los últimos valores de módulo y fase y evitar fluctuaciones extremas en la visualización
    real cola_fase [$];
    real cola_modulo2 [$];
    real cola_fase2 [$];
    real frecuencia_almacenada;

    if (VALID_M) begin
        modulo_post=(real'(MODULO)*v_shunt_effective_authosunt/16.0);
//        modulo2_post=(real'(MODULO2)*v_shunt_effective_authosunt/16.0);
        $display("Frecuencia actual del DDS 4p correlacion: %9.2f Hz, MODULO: %9.2f", f_actual, modulo_post);
        error_mag_4p_corr  = (modulo_post > z_bio_mag) ? ((modulo_post - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_post)/z_bio_mag)*100.0;
        $display("Error de magnitud metodo 4p correlacion: %5.2f%%", error_mag_4p_corr);
        cola_modulo.push_front(modulo_post);


    end   
        if (VALID_M2) begin
        modulo2_post=(real'(MODULO2)*v_shunt_effective_authosunt/16.0);
        $display("Frecuencia actual del DDS 3p correlacion: %9.2f Hz,  MODULO: %9.2f", f_actual, modulo2_post);
        error_mag_3p_corr  = (modulo2_post > z_bio_mag) ? ((modulo2_post - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo2_post)/z_bio_mag)*100.0;
        $display("Error de magnitud metodo 3p correlacion: %5.2f%%", error_mag_3p_corr);
        cola_modulo2.push_front(modulo2_post);
     
    end 
    if (VALID_P) begin
        fases=-real'(PHASE)/4.0;
        if (fases<=-90.0)
            fases_post=fases+180.0;
        else if (fases>=90.0)
            fases_post=fases-180.0;
        else
            fases_post=fases;
        $display("Frecuencia actual del DDS 4p correlacion: %9.2f Hz, Fase: %9.2f grados", f_actual, fases_post);
        error_fase_4p_corr = (fases_post > z_bio_fase) ? (fases_post - z_bio_fase) : (z_bio_fase - fases_post);
        $display("Error de fase metodo 4p correlacion: %9.2f grados", error_fase_4p_corr);
        cola_fase.push_front(fases_post);
    end
    if (VALID_P2) begin
        fases2=-real'(PHASE2)/4.0;
        if (fases2<=-90.0)
            fases2_post=fases2+180.0;
        else if (fases2>=90.0)
            fases2_post=fases2-180.0;
        else
            fases2_post=fases2;           
        $display("Frecuencia actual del DDS 3p correlacion: %9.2f Hz, Fase: %9.2f grados", f_actual, fases2_post);
        error_fase_3p_corr = (fases2_post > z_bio_fase) ? (fases2_post - z_bio_fase) : (z_bio_fase - fases2_post);
        $display("Error de fase metodo 3p correlacion: %9.2f grados", error_fase_3p_corr);
        cola_fase2.push_front(fases2_post);
    end
    //modulo_4p_corr=modulo_post;
    //fase_4p_corr=fases_post;
    //modulo_3p_corr=modulo2_post;
    //fase_3p_corr=fases2_post;  
    if (cola_modulo.size() > 0 && cola_fase.size()>0)
        begin 
            modulo_4p_corr= cola_modulo.pop_back(); // Mantener solo los últimos 5 valores para suavizar la visualización
            fase_4p_corr= cola_fase.pop_back();
            frecuencia_almacenada=cola_frecuencias.pop_back();
            guardar_dato(0,2*medida+congelacion,frecuencia_almacenada,modulo_4p_corr,fase_4p_corr, 0.0, 0.0, 0.0, 0.0);
        
        end 
    if (cola_modulo2.size() > 0 && cola_fase2.size()>0)
        begin 
            modulo_3p_corr= cola_modulo2.pop_back(); // Mantener solo los últimos 5 valores para suavizar la visualización
            fase_3p_corr= cola_fase2.pop_back();
            guardar_dato(1,2*medida+congelacion,frecuencia_almacenada,modulo_3p_corr,fase_3p_corr, 0.0, 0.0, 0.0, 0.0);
        end         
    end


    always @(posedge clk125) begin
        fase_acc += 2.0 * PI * f_actual * DT;
        if (fase_acc >= 2.0*PI) fase_acc -= 2.0*PI;
        v_gen = 1.0 * $sin(fase_acc);


    end
endmodule
