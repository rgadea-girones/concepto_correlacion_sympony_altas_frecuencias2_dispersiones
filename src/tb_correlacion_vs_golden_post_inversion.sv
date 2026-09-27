// =============================================================================
// Banco de Pruebas: Correlación, Golden Model e INVERSIÓN FLASH
// Objetivo: Testbench ultrarrápido con corrección de artefactos en tiempo real
// =============================================================================

import dpi_pkg_tiempos::*; // importacion de funciones DPI para guardar datos y FFT
import electrical_pkg::*; // importacion del paquete de nettypes eléctricos
`timescale 1ns/1ps
module tb_correlacion_portable_python_nettype;
`ifdef EXPERIMENTO_K_EXTREMOS
`ifdef USE_VAMS_MIXED
    localparam string CSV_FLUJO = "symphony_mixed";
    localparam string CSV_SIMULADOR = "questa_symphony";
`ifdef EXPERIMENTO_SIN_AUTOSHUNT
    localparam string CSV_CONFIGURACION = "exp_k_extremos_symphony_sin_autoshunt";
`else
    localparam string CSV_CONFIGURACION = "exp_k_extremos_symphony";
`endif
`else
    localparam string CSV_FLUJO = "nettype_rnm";
    localparam string CSV_SIMULADOR = "questa";
`ifdef EXPERIMENTO_SIN_AUTOSHUNT
    localparam string CSV_CONFIGURACION = "exp_k_extremos_nettype_sin_autoshunt";
`else
    localparam string CSV_CONFIGURACION = "exp_k_extremos_nettype";
`endif
`endif
`else
    localparam string CSV_FLUJO = "nettype_rnm";
    localparam string CSV_SIMULADOR = "questa";
    localparam string CSV_CONFIGURACION = "qrun_live_rafa_nettype";
`endif
    localparam string CSV_RUN_ID = "";

    // IMPORTACIÓN DE LA FUNCIÓN DPI-C PARA EL TIEMPO DEL PC
    import "DPI-C" function real get_cpu_time_s();

    localparam int MAGNITUD_WIDTH = 14;
    localparam real PI = 3.14159265358979;
    localparam real DT = 8e-9; // Reloj de 125 MHz
    localparam real NS_TO_S = 1e-9;
    localparam real ADC_SCALE=8192.0; // Para mapear ±1V a ±8192 (14 bits)
    localparam bit  ENABLE_ADC3_NOISE = 1'b1;
    localparam int NUMERO_MEDIDAS_BASE = 10;
`ifdef EXPERIMENTO_K_EXTREMOS
    localparam int NUMERO_MEDIDAS_EJECUCION = 2;
`else
    localparam int NUMERO_MEDIDAS_EJECUCION = NUMERO_MEDIDAS_BASE;
`endif
    localparam real numero_medidas = NUMERO_MEDIDAS_BASE; // Número de medidas del barrido de degradación original
    localparam real ADC3_NOISE_SIGMA_LSB = 0.5; // sigma de ruido en LSB del ADC
    localparam real R_CONT_MIN = 450000.0; //mi valor inicial era 500.0
    localparam real R_CONT_RANGO_MEDIDA = 100000.0;
    localparam real R_CONT_AMP_BARRIDO = 120.0;
    localparam real MICRO_F1_HZ = 0.35;      // microvariación lenta de presión
    localparam real MICRO_F2_HZ = 1.10;      // segunda componente lenta
    localparam real R_C1_MICRO_PCT = 0.04;   // ±4% alrededor de la base por medida
    localparam real CP_MICRO_PCT  = 0.06;    // ±6% alrededor de la base por medida
    localparam bit VERBOSE = 1;
`ifdef EXPERIMENTO_SIN_AUTOSHUNT
    localparam bit activar_autoshunt = 1'b0; // Variante de experimento con autoshunt desactivado
`else
    localparam bit activar_autoshunt = 1'b1; // Control para activar/desactivar el autoshunt en 3 puntas
`endif

    // --- PARÁMETROS PARA LA INVERSIÓN MATEMÁTICA (DE-EMBEDDING) ---
    // Deben coincidir con los de tu Analog Front-End (top_bioimpedancia_circuito_medida_portable_nettype)
    localparam real INV_C_IN_EQ = 20.0e-12; // C_in 
    localparam real INV_C_LEAK_EQ = 30.0e-12; // Fugas capacitivas en los cables
    localparam real INV_C_EQ = 50.0e-12;    //C_in (20pF) + C_leak (30pF)
    localparam real INV_R_IN_EQ = 1.0e6;    // R_in del ADC
    localparam real INV_MUTUAL_L_EQ = 2.5e-6;   // Inductancia mutua en Henrios

    function automatic real normalizar_fase_deg(input real fase_deg);
        real fase_norm;
        begin
            fase_norm = fase_deg;
            while (fase_norm > 180.0)
                fase_norm -= 360.0;
            while (fase_norm <= -180.0)
                fase_norm += 360.0;
            normalizar_fase_deg = fase_norm;
        end
    endfunction
   
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
    //--ATENCION , ESTOS PARAMETROS SON SUSTITUIDOS POR INPUTS PARA PODER SER MODIFICADOS DINÁMICAMENTE EN LA SIMULACION
    localparam real R_ext   = 20000.0; 
    localparam real R_int   = 1500.0;
    localparam real C_mem   = 5.0e-9;
    localparam real R_shunt = 1000.0;
    localparam real R_contact1= 1500000.0; // Contacto del extremo de generación
    localparam real R_contact2= 1500000.0; // Contacto del extremo de shunt
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
    
    // --- VARIABLES DE TIEMPO ---
    real tiempo_hardware_s;
    real tiempo_pc_s;

    // --- COLAS PARA INVERSIÓN FLASH ---
    real cola_frecuencias [$];
    real cola_r_cont [$];
    real cola_cp_val [$];
    real cola_shunt_effective_authosunt [$];
    real cola_modulo [$];
    real cola_fase [$];

    // Para 4-Puntas
    real v_a_4p, v_b_4p, v_c_4p;
    real error_mag_4p, error_fase_4p;

    // Variables de correlacion
    real modulo_4p_corr;
    real fase_4p_corr;
    real error_mag_4p_corr;
    real error_fase_4p_corr;
    
    // --- VARIABLES DE INVERSIÓN FLASH ---
    real modulo_4p_inv;
    real fase_4p_inv;
    real error_mag_4p_inv;
    real error_fase_4p_inv;
    real r_total_medida;
    real r_contact_medida;
    real r_contact_flash;
    
    // ATENCIÓN: Si el cálculo de la R_total por pantalla te da mal, ajusta este factor 
    // según los bits que gane o pierda la magnitud MODULOB dentro de tu correlador FPGA.
    real ESCALA_CORRELADOR = 1.0; 
    

    int filas_guardadas;

    // --- GOLDEN MODEL (Resultados teóricos) ---
    real z_bio_re, z_bio_im, z_bio_mag, z_bio_fase;
    real omega, xc, den_bio;   
    real v_shunt_effective_authosunt;


    // =============================================================================
    // autoshunt
    // =============================================================================

    always_comb begin
      if (autoshunt) 
        case (estado_pasos_cero)
          3'b000:begin 
            v_shunt_effective_authosunt = 2000.0; 
            numero_ciclos = 10'd4;
            numero_anchura = 10'd2;
            numero_decimales = 4'd9; 
            end
          3'b001:begin 
            v_shunt_effective_authosunt = 1000.0; 
            numero_ciclos = 10'd4;
            numero_anchura = 10'd2;
            numero_decimales = 4'd8; 
            end
          3'b010: begin 
            v_shunt_effective_authosunt = 500.0; 
            numero_ciclos = 10'd5 ;
            numero_anchura = 10'd2;
            numero_decimales = 4'd6; 
            end
          3'b011: begin 
            v_shunt_effective_authosunt = 285.71; 
            numero_ciclos = 10'd5;
            numero_anchura = 10'd2;
            numero_decimales = 4'd5; 
            end
          default: begin 
            v_shunt_effective_authosunt = 100.0; 
            numero_ciclos = 10'd64;
            numero_anchura = 10'd2;
            numero_decimales = 4'd4;
            end
        endcase
     else begin
         
        case (estado_pasos_cero)
          3'b000:begin //decada de 10 a 100 Hz
            v_shunt_effective_authosunt = 1000.0; 
            numero_ciclos = 10'd0;
            numero_anchura = 10'd1;
            numero_decimales = 4'd9; 
            end
          3'b001:begin //decada de 100 a 1000 Hz
            v_shunt_effective_authosunt = 1000.0; 
            numero_ciclos = 10'd1;
            numero_anchura = 10'd1;
            numero_decimales = 4'd8; 
            end
          3'b010: begin //decada de 1 kHz a 10 kHz
            v_shunt_effective_authosunt =1000.0; 
            numero_ciclos = 10'd4 ;
            numero_anchura = 10'd2;
            numero_decimales = 4'd6; 
            end
          3'b011: begin //decada de 10 kHz a 100 kHz
            v_shunt_effective_authosunt = 1000.0; 
            numero_ciclos = 10'd5;
            numero_anchura = 10'd2;
            numero_decimales = 4'd5; 
            end
          default: begin 
            v_shunt_effective_authosunt = 1000.0; 
            numero_ciclos = 10'd64;
            numero_anchura = 10'd2;
            numero_decimales = 4'd4;
            end
        endcase
      end   
    end

    // =============================================================================
    // MODELO FÍSICO
    // =============================================================================

`ifdef USE_VAMS_MIXED
    top_bioimpedancia_circuito_medida_portable_mixed #(  .C_in(INV_C_IN_EQ),.R_in(INV_R_IN_EQ),.C_leak(INV_C_LEAK_EQ),.Mutual_L(INV_MUTUAL_L_EQ)) analog_circuit  (
`else
  top_bioimpedancia_circuito_medida_portable_nettype #(  .C_in(INV_C_IN_EQ),.R_in(INV_R_IN_EQ),.C_leak(INV_C_LEAK_EQ),.Mutual_L(INV_MUTUAL_L_EQ)) analog_circuit  (
`endif
    .clk(clk125),
    .dds_bus(dds_bus),
    .senoide(v_gen),
    .cuantificacion(cuantificacion), // Control para activar/desactivar la cuantificación del ADC 
    .autoshunt_value(v_shunt_effective_authosunt), // Controla el autoshunt en 3 puntas, se puede variar para simular diferentes condiciones de contacto
    .r_cont_instant(r_c1),
    .c_contact1(cp_val),
    .v_a_4p(v_a_4p),
    .v_b_4p(v_b_4p),
    .v_c_4p(v_c_4p),
    .rext_instant(rext_instant),
    .rint_instant(rint_instant),
    .c_mem_instant(c_mem_instant),
    .adc1_data_4p(adc1_data_4p), 
    .adc2_data_4p(adc2_data_4p),
    .adc3_data_4p(adc3_data_4p)
    );  

    
    // =============================================================================
    // INYECCIÓN DE RUIDO ADC
    // =============================================================================

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
            adc1_data_4p_noisy <= code_noisy_1[13:0]; 
            adc2_data_4p_noisy <= code_noisy_2[13:0];
        end else begin
            adc3_data_4p_noisy <= adc3_data_4p;
            adc1_data_4p_noisy <= adc1_data_4p;
            adc2_data_4p_noisy <= adc2_data_4p;
        end
    end

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

    // =============================================================================
    // SECUENCIA PRINCIPAL
    // =============================================================================
    initial begin
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
        
        // Inicializamos el valor seguro de la Inversión Flash al valor base
        r_contact_flash = R_contact1; 
        
        autoshunt = activar_autoshunt; 
        cuantificacion = 1'b1 ; 
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);
        areset_n = 1'b0;
        repeat(3) @(negedge clk125);
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);

        for (int idx_loop = 0; idx_loop < NUMERO_MEDIDAS_EJECUCION; idx_loop++) begin
            int idx_k_real;
`ifdef EXPERIMENTO_K_EXTREMOS
            idx_k_real = (idx_loop == 0) ? 0 : (NUMERO_MEDIDAS_BASE - 1);
`else
            idx_k_real = idx_loop;
`endif
            medida = idx_k_real;
            seed_adc3_noise = seeds_base[idx_k_real]; 
            seed_adc1_noise= seeds_base[idx_k_real] + 1000; 
            seed_adc2_noise= seeds_base[idx_k_real] + 2000;
            r_cont_base_medida = R_CONT_MIN + $urandom_range(0, int'(R_CONT_RANGO_MEDIDA));
            r_cont_instant = r_cont_base_medida;
            // Barrido de degradación: 0.1, 0.2, ..., 1.0
            k_degradacion = real'((idx_k_real + 1.0) / numero_medidas);
            r_c1_base_medida   = R_contact1 + $urandom_range(0, 100000); // 4.5M a 5.5M
            cp_base_medida = 1.0e-12 + ($urandom_range(0, 500) * 1e-15); // 1.0pF a 1.5pF

            r_c1 = r_c1_base_medida;
            
            cp_val = cp_base_medida;
            t_inicio_medida_s = $realtime * 1e-9;
            // --- MODELO REFINADO DE ÁCIDO LÁCTICO Y RUPTURA CELULAR ---
            rext_instant  = R_ext * (1.0 - (0.5 * k_degradacion)); 
             rint_instant  = R_int * (1.0 - (0.2 * k_degradacion));
            c_mem_instant = C_mem * (1.0 / (1.0 + 5.0 * k_degradacion));
            
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
        configurar_metadata_csv(CSV_FLUJO, CSV_SIMULADOR, CSV_CONFIGURACION, CSV_RUN_ID);
        inicializar_tiempos();
         clk125 = 1'b0;
         forever #((DT/2)*1s) clk125 = ~clk125;
    end

    // =============================================================================
    // modelizacion de variaciones de impedancias y cálculo de Golden Model
    // =============================================================================
    always@( incrementado) 
    begin
        real t_local_s;
        real micro_presion;

        f_actual = (real'(incrementado) / 4294967296.0) * 125000000.0; // Cálculo de frecuencia actual basada en el incremento
        if (f_actual > 1.0) begin
            t_local_s = ($realtime * 1e-9) - t_inicio_medida_s;
            micro_presion = 0.65*$sin(2.0*PI*MICRO_F1_HZ*t_local_s) + 0.35*$sin(2.0*PI*MICRO_F2_HZ*t_local_s + 0.7);

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
            
            // --- GOLDEN MODEL (Cálculo directo sin FFT) ---
            omega = 2.0 * PI * f_actual;
            xc = 1.0 / (omega * c_mem_instant);
            den_bio = (rext_instant + rint_instant)**2 + xc**2;
            z_bio_re = (rext_instant * (rint_instant*(rext_instant + rint_instant) + xc**2)) / den_bio;
            z_bio_im = (rext_instant**2 * -(xc)) / den_bio;
            z_bio_mag  = $sqrt(z_bio_re**2 + z_bio_im**2);
            z_bio_fase = $atan2(z_bio_im, z_bio_re) * (180.0 / PI);

            cola_frecuencias.push_front(f_actual);
            cola_shunt_effective_authosunt.push_front(v_shunt_effective_authosunt);
            cola_r_cont.push_front(r_cont_instant);
            cola_cp_val.push_front(cp_val);
            
            // --- ASIGNACIÓN DE TIEMPOS ---
            tiempo_hardware_s = $realtime * NS_TO_S;
            tiempo_pc_s = get_cpu_time_s(); // Extrae el tiempo consumido de la CPU

            // Guardamos golden para el k_degradacion de esta medida (ID 2)
            guardar_dato(2,medida,f_actual,z_bio_mag ,z_bio_fase, 0.0, 0.0, 0.0, 0.0, tiempo_pc_s, tiempo_hardware_s); 
        end
    end

    // =============================================================================
    // PROCESADO DE RESULTADOS CORRELACION Y CÁLCULO DE ERRORES E INVERSIÓN MATEMÁTICA
    // =============================================================================
    always @(posedge clk125) begin
        real fases,fasesa,fasesb;
        real fases_post;
        real modulo_post, modulo_a, modulo_b;
        real cola_modulo [$]; 
        real cola_fase [$];
        real frecuencia_almacenada;
        real shunt_efectivo;
        real r_cont_almacenada, cp_almacenada;
        
        // --- Variables Inversión Flash ---
        real omega_inv, factor_re, factor_im;
        real z_med_re, z_med_im, z_corr_re, z_corr_im;
        real z_final_re, z_final_im;
        real N_r, N_i, D_r, D_i, den_D;
        real modulo_4p_inv, fase_4p_inv;
        real error_mag_4p_inv, error_fase_4p_inv;

        if (VALID_M) begin
            shunt_efectivo = cola_shunt_effective_authosunt.pop_back(); 
            modulo_post=(real'(MODULO)*shunt_efectivo/real'(1<<numero_decimales));
            modulo_a=(real'(MODULOA));
            modulo_b=(real'(MODULOB));
            
            cola_modulo.push_front(modulo_post);
        end   
        
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
            
            fases_post=fases; 
            cola_fase.push_front(fases_post);
        end
        
        if (cola_modulo.size() > 0 && cola_fase.size()>0)
            begin 
                modulo_4p_corr= cola_modulo.pop_back(); 
                fase_4p_corr= cola_fase.pop_back();
                frecuencia_almacenada=cola_frecuencias.pop_back();
                r_cont_almacenada = cola_r_cont.pop_back();
                cp_almacenada = cola_cp_val.pop_back();

                // ---------------------------------------------------------
                // 1. EXTRACCIÓN DINÁMICA DE R_CONTACT (TÉCNICA FLASH)
                // ---------------------------------------------------------
                if (frecuencia_almacenada < 100.0) begin
                    r_contact_flash = r_cont_almacenada;
                    if (VERBOSE) begin
                        $display("\n  [FLASH EXTRACTION] Freq: %5.1f Hz | R_contact real congelada: %9.0f Ohm", 
                                 frecuencia_almacenada, r_contact_flash);
                    end
                end

                // ---------------------------------------------------------
                // 2. APLICACIÓN DE LA INVERSIÓN MATEMÁTICA (DE-EMBEDDING)
                // ---------------------------------------------------------
                omega_inv = 2.0 * PI * frecuencia_almacenada;
                
                // Función de Transferencia Inversa (A^-1) con Divisor Complejo:
                // Numerador (N) = 1 + (R_s/R_in) + j*w*R_s*(C_in + C_p)
                N_r = 1.0 + (r_contact_flash / INV_R_IN_EQ);
                N_i = omega_inv * r_contact_flash * (INV_C_EQ + cp_almacenada);
                
                // Denominador (D) = 1 + j*w*R_s*C_p
                D_r = 1.0;
                D_i = omega_inv * r_contact_flash * cp_almacenada;
                
                // División compleja (N/D)
                den_D = D_r**2 + D_i**2;
                factor_re = (N_r * D_r + N_i * D_i) / den_D;
                factor_im = (N_i * D_r - N_r * D_i) / den_D;
                
                // Pasar a rectangular, multiplicar por Factor_Inverso
                z_med_re = modulo_4p_corr * $cos(fase_4p_corr * PI / 180.0);
                z_med_im = modulo_4p_corr * $sin(fase_4p_corr * PI / 180.0);
                
                z_corr_re = (z_med_re * factor_re) - (z_med_im * factor_im);
                z_corr_im = (z_med_re * factor_im) + (z_med_im * factor_re);
                
                // Restar inductancia mutua
                z_final_re = z_corr_re;
                z_final_im = z_corr_im - (omega_inv * INV_MUTUAL_L_EQ);
                
                // Volver a Polar
                modulo_4p_inv = $sqrt(z_final_re**2 + z_final_im**2);
                fase_4p_inv = normalizar_fase_deg($atan2(z_final_im, z_final_re) * 180.0 / PI);
                
                // ---------------------------------------------------------
                // CÁLCULO DE ERRORES Y GUARDADO
                // ---------------------------------------------------------
                error_mag_4p_corr = (modulo_4p_corr > z_bio_mag) ? ((modulo_4p_corr - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_corr)/z_bio_mag)*100.0;
                error_fase_4p_corr = (fase_4p_corr > z_bio_fase) ? (fase_4p_corr - z_bio_fase) : (z_bio_fase - fase_4p_corr);
                
                error_mag_4p_inv = (modulo_4p_inv > z_bio_mag) ? ((modulo_4p_inv - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_inv)/z_bio_mag)*100.0;
                error_fase_4p_inv = (fase_4p_inv > z_bio_fase) ? (fase_4p_inv - z_bio_fase) : (z_bio_fase - fase_4p_inv);

                if (VERBOSE) begin
                    $display("=== FREQ: %9.2f Hz ===", frecuencia_almacenada);
                    $display("  [SUJETO 0: PRE-INV]  Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", modulo_4p_corr, fase_4p_corr, error_mag_4p_corr, error_fase_4p_corr);
                    $display("  [SUJETO 1: POST-INV] Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", modulo_4p_inv, fase_4p_inv, error_mag_4p_inv, error_fase_4p_inv);
                    $display("  [SUJETO 2: GOLDEN]   Mag: %8.2f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
                end

                tiempo_hardware_s = $realtime * NS_TO_S;
                tiempo_pc_s = get_cpu_time_s(); 

                guardar_dato(0,medida,frecuencia_almacenada,modulo_4p_corr,fase_4p_corr, modulo_a, fasesa, modulo_b, fasesb, tiempo_pc_s, tiempo_hardware_s);
                guardar_dato(1,medida,frecuencia_almacenada,modulo_4p_inv,fase_4p_inv, 0.0, 0.0, 0.0, 0.0, tiempo_pc_s, tiempo_hardware_s);
            end 
    end
        
    always @(posedge clk125) begin
        fase_acc += 2.0 * PI * f_actual * DT;
        if (fase_acc >= 2.0*PI) fase_acc -= 2.0*PI;
        v_gen = 0.5 * $sin(fase_acc); // Mantenido a 0.5V tal como indicaste
    end

endmodule