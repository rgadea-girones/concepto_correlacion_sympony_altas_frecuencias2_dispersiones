// =============================================================================
// Banco de Pruebas: Correlación, Golden Model e INVERSIÓN MATEMÁTICA EXACTA
// Archivo: tb_correlacion_inversion_exacta_10cm.sv
// Optimizaciones: Cables a 10cm, Protección NaN, RK4 Mismatch Corregido
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
        // =============================================================================
    // 1. MUNDO FÍSICO (LA REALIDAD DEL HARDWARE RK4)
    // Estos valores definen el comportamiento analógico real de la Red Pitaya y los cables.
    // =============================================================================
    localparam real PHYS_R_IN = 1.0e6;      // Resistencia interna Red Pitaya real
    localparam real PHYS_C_IN = 10.0e-12;   // Capacitancia pura del ADC real
    localparam real PHYS_C_LEAK = 10.0e-12; // Fugas a tierra de los cables reales
    localparam real PHYS_C_EQ = PHYS_C_IN + PHYS_C_LEAK; // Capacitancia equivalente total
    localparam real PHYS_MUTUAL_L = 2.5e-7; // Inductancia magnética real

    // =============================================================================
    // 2. MUNDO MATEMÁTICO (LO QUE CREE EL PYTHON)
    // Vinculados por defecto a la física para una INVERSIÓN IDEAL.
    // Para probar errores de estimación, comenta el vínculo y pon un valor manual.
    // =============================================================================
    localparam real INV_R_IN_EQ     = PHYS_R_IN;     // Impedancia del ADC (Red Pitaya)
    localparam real INV_C_IN_EQ     = PHYS_C_IN;     
    localparam real INV_C_LEAK_EQ   = PHYS_C_LEAK;   
    localparam real INV_R_INA       = 1.0e12;        // Impedancia de entrada del INA
    localparam real INV_C_INA       = 3.0e-12;// Ej. con error: 40.0e-12;
    localparam real INV_C_EQ        = PHYS_C_EQ;      // Ej. con error: 55.0e-12;
    localparam real INV_MUTUAL_L_EQ = PHYS_MUTUAL_L; // Ej. con error: 3.0e-6;



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
    logic [13:0] dds_bus; 
    logic [13:0] adc1_data_4p; 
    logic [13:0] adc2_data_4p; 
    logic [13:0] adc3_data_4p = 14'd0;  
    logic signed [13:0] adc3_data_4p_noisy; 
    logic signed [13:0] adc1_data_4p_noisy; 
    logic signed [13:0] adc2_data_4p_noisy; 
    logic [13:0] adc1_data_3p; 
    logic [13:0] adc2_data_3p; 

    logic areset_n;
    logic start;
    int medida; 
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

    logic autoshunt; 
    logic cuantificacion;

    // --- PARÁMETROS DEL TEJIDO (Fijo - Golden Model) ---
    localparam real R_ext   = 20000.0; 
    localparam real R_int   = 1500.0;
    localparam real C_mem   = 5.0e-9;
    localparam real R_shunt = 1000.0;
    localparam real R_contactos = 1500000.0;
    localparam real R_contact1= R_contactos; 
    localparam real R_contact2= R_contactos; 
    localparam real C_contactos= 1.0e-12;
    localparam real C_p1     = C_contactos; 
    localparam real C_p2     = C_contactos; 

    localparam real shunt_unico = 2000;

    // --- VARIABLES FÍSICAS COMUNES ---
    real r_cont_instant; 
    real r_cont_base_medida; 
    real r_cont_delta_barrido; 
    real r_c1, r_c2, cp_val;  
    real r_c1_base_medida, cp_base_medida;
    real t_inicio_medida_s;
    real rext_instant, rint_instant, c_mem_instant; 
    real k_degradacion; 
    integer seed = 12345; 
    integer seed_adc3_noise;
    integer seed_adc1_noise;
    integer seed_adc2_noise;
    integer seeds_base[10] = '{24680, 13579, 11223, 44556, 99887, 77665, 55443, 33221, 12121, 89898};
    real v_gen, f_actual, fase_acc = 0;
    real v_c_mem = 0, i_total;
    real v_tejido, i_int;
    real node_re_p, node_re_n, node_shunt_high; 
    
    // --- VARIABLES DE TIEMPO ---
    real tiempo_hardware_s;
    real tiempo_pc_s;

    // --- COLAS PARA INVERSIÓN FLASH ---
    real cola_frecuencias [$];
    real cola_r_cont [$];
    real cola_cp_val [$];
    real cola_shunt_effective_authosunt [$];

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
          3'b000:begin 
            v_shunt_effective_authosunt = 2000.0; 
            numero_ciclos = 10'd0;
            numero_anchura = 10'd1;
            numero_decimales = 4'd9; 
            end
          3'b001:begin 
            v_shunt_effective_authosunt = 2000.0; 
            numero_ciclos = 10'd1;
            numero_anchura = 10'd1;
            numero_decimales = 4'd8; 
            end
          3'b010: begin 
            v_shunt_effective_authosunt =2000.0; 
            numero_ciclos = 10'd4 ;
            numero_anchura = 10'd2;
            numero_decimales = 4'd6; 
            end
          3'b011: begin 
            v_shunt_effective_authosunt = 2000.0; 
            numero_ciclos = 10'd5;
            numero_anchura = 10'd2;
            numero_decimales = 4'd5; 
            end
          default: begin 
            v_shunt_effective_authosunt = 2000.0; 
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

    top_bioimpedancia_circuito_medida_portable_nettype_ina #(
      .C_in_ina(INV_C_INA),
      .R_in_ina(INV_R_INA),
      .C_in_adc(PHYS_C_IN),
      .R_in_adc(PHYS_R_IN),
      .C_leak(PHYS_C_LEAK),
      .Mutual_L(PHYS_MUTUAL_L),
      .INA_GAIN(1.0)
    ) analog_circuit (
    .clk(clk125),
    .dds_bus(dds_bus),
    .senoide(v_gen),
    .cuantificacion(cuantificacion), 
    .autoshunt_value(v_shunt_effective_authosunt), 
    .r_cont_instant(r_c1),
    .c_contact1(cp_val),
    .v_a_4p(v_a_4p),
    .v_b_4p(v_b_4p),
    .rext_instant(rext_instant),
    .rint_instant(rint_instant),
    .c_mem_instant(c_mem_instant),
    .adc1_data_4p(adc1_data_4p), 
    .adc2_data_4p(adc2_data_4p)
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
        .ADC_B(14'sd0),
        .ADC_C(adc2_data_4p_noisy),
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
            r_c1_base_medida   = R_contactos + $urandom_range(0, 500000); 
            cp_base_medida = C_contactos + ($urandom_range(0, 500) * 1e-15); 
            //atencion: estos son los valores que efectivamente son introducidos a la bioimpedancia y los que deben de ser utilizados
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

            #1000ns; // Espera para asegurar estabilización
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

        f_actual = (real'(incrementado) / 4294967296.0) * 125000000.0; 
        if (f_actual > 1.0) begin
            t_local_s = ($realtime * 1e-9) - t_inicio_medida_s;
            micro_presion = 0.65*$sin(2.0*PI*MICRO_F1_HZ*t_local_s) + 0.35*$sin(2.0*PI*MICRO_F2_HZ*t_local_s + 0.7);

            r_c1 = r_c1_base_medida * (1.0 - R_C1_MICRO_PCT*micro_presion);
            cp_val = cp_base_medida * (1.0 + CP_MICRO_PCT*micro_presion);
            if (r_c1 < 1.0) r_c1 = 1.0;
            if (cp_val < 1e-13) cp_val = 1e-13;

            r_cont_delta_barrido = R_CONT_AMP_BARRIDO * $sin(2.0 * PI * ($ln(f_actual + 1.0) / $ln(10.0)));
            r_cont_instant = r_c1;
            if (r_cont_instant < 1.0) r_cont_instant = 1.0;
            
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
            tiempo_hardware_s = $realtime / 1s;
            tiempo_pc_s = get_cpu_time_s(); 

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
        
        // --- COLAS DE SINCRONIZACIÓN ---
        real cola_modulo [$]; 
        real cola_fase [$];
        real cola_modulo_a [$];
        real cola_modulo_b [$];
        real cola_fase_a [$];
        real cola_fase_b [$];
        
        real frecuencia_almacenada;
        real shunt_efectivo;
        real r_cont_almacenada, cp_almacenada;
        
        // --- Variables Inversión Flash Analítica Completa ---
        real w, wRC, den_z;
        real Zs_re, Zs_im;
        real Zin_re, Zin_im;
        real Zsh_re, Zsh_im;
        real R_sh_eq, C_sh_eq;
        real Zs_over_Zin_re, Zs_over_Zin_im;
        real Fv_re, Fv_im;
        real Fi_re, Fi_im;
        real Ksh_re, Ksh_im;
        real NumC_re, NumC_im, DenC_re, DenC_im;
        real Fc_re, Fc_im;
        real Ftot_re, Ftot_im;
        
        // Variables para el Sujeto 0
        real mag_V_raw, fase_V_raw;
        real mag_I_raw, fase_I_raw;
        
        // Variables para el Sujeto 1 (Invertidas separadamente)
        real mag_V_corr, fase_V_corr;
        real mag_I_corr, fase_I_corr;
        real v_med_re, v_med_im, v_corr_re, v_corr_im;
        real i_med_re, i_med_im, i_corr_re, i_corr_im;

        real z_med_re, z_med_im, z_corr_re, z_corr_im;
        real z_final_re, z_final_im;

        if (VALID_M) begin
            shunt_efectivo = cola_shunt_effective_authosunt.pop_back(); 
            modulo_post = (real'(MODULO)*shunt_efectivo/real'(1<<numero_decimales));
            modulo_a = real'(MODULOA)/(numero_ciclos + 1 );
            modulo_b = (real'(MODULOB)/(shunt_efectivo* (numero_ciclos+1)));
            
            cola_modulo.push_front(modulo_post);
            cola_modulo_a.push_front(modulo_a);
            cola_modulo_b.push_front(modulo_b);
        end   
        
        if (VALID_P) begin
            fases=real'(PHASE)/8.0;
            fasesa=real'(PHASEA)/8.0;
            fasesb=real'(PHASEB)/8.0;
            
            fases_post=fases; 
            cola_fase.push_front(fases_post);
            cola_fase_a.push_front(fasesa);
            cola_fase_b.push_front(fasesb);
        end
        
        if (cola_modulo.size() > 0 && cola_fase.size()>0 && 
            cola_modulo_a.size() > 0 && cola_fase_a.size()>0 &&
            cola_modulo_b.size() > 0 && cola_fase_b.size()>0)
            begin 
                // Sacamos datos sincronizados
                modulo_4p_corr = cola_modulo.pop_back(); 
                fase_4p_corr = cola_fase.pop_back();
                mag_V_raw = cola_modulo_a.pop_back();
                fase_V_raw = cola_fase_a.pop_back();
                mag_I_raw = cola_modulo_b.pop_back();
                fase_I_raw = cola_fase_b.pop_back();
                
                frecuencia_almacenada = cola_frecuencias.pop_back();
                r_cont_almacenada = cola_r_cont.pop_back();
                cp_almacenada = cola_cp_val.pop_back();

                // ---------------------------------------------------------
                // 1. EXTRACCIÓN DINÁMICA DE R_CONTACT (TÉCNICA FLASH)
                // ---------------------------------------------------------
                if (frecuencia_almacenada < 100.0) begin

                                        
                    // A baja frecuencia (ej. 40 Hz), C_p y C_in son circuitos abiertos (> Gigaochmios).
                    // Podemos presuponer con total seguridad que Z_contact ≈ R_contact.
                    // En la realidad, Python medirá la corriente total (I_shunt) a través del ADC3.
                    // Emulamos esa lectura de corriente física (I = V / R_total):
                    automatic real v_gen_amp = 0.5; // Amplitud inyectada por el DAC
                    automatic real i_shunt_amp = v_gen_amp / (2.0 * r_cont_almacenada + z_bio_mag + shunt_efectivo);
                    
                    // Python calcula la Impedancia Total del Bucle:
                    automatic real z_bucle_total = v_gen_amp / i_shunt_amp;
                    
                    // Extraemos la R_contact dinámicamente restando el tejido (ya medido en 4P) y el shunt:
                    // Asumimos simetría: R_contact_F+ ≈ R_contact_F-
                    r_contact_flash = (z_bucle_total - modulo_4p_corr - shunt_efectivo) / 2.0;

                    if (VERBOSE) begin
                        $display("\n  [FLASH EXTRACTION] Freq: %5.1f Hz", frecuencia_almacenada);
                        $display("    -> Z Bucle Total Medida: %9.0f Ohm", z_bucle_total);
                        $display("    -> R_contact Dinámica Extraída: %9.0f Ohm (Valor real oculto: %9.0f)", r_contact_flash, r_cont_almacenada);
                    end
                    
                    // Extraída implícitamente por el flujo del array dinámico
                    //lo comento para que utilice la extraida
                 //   r_contact_flash = r_cont_almacenada;
                end

                // ---------------------------------------------------------
                // 2. APLICACIÓN DE LA INVERSIÓN MATEMÁTICA EXACTA
                // ---------------------------------------------------------
                w = 2.0 * PI * frecuencia_almacenada;

                // 2.1 Impedancia del Contacto (Aguja): Zs = R_contact || Cp
                wRC = w * r_contact_flash * cp_almacenada;
                den_z = 1.0 + wRC * wRC;
                Zs_re = r_contact_flash / den_z;
                Zs_im = -(w * r_contact_flash * r_contact_flash * cp_almacenada) / den_z;

                // 2.2 Impedancia de Entrada del INA: Zin = R_ina || C_ina
                wRC = w * INV_R_INA * INV_C_INA; 
                den_z = 1.0 + wRC * wRC;
                Zin_re = INV_R_INA / den_z;
                Zin_im = -(w * INV_R_INA * INV_R_INA * INV_C_INA) / den_z; 

                // 2.3 Impedancia en el Nodo Shunt
                // El RK4 pone C_leak + C_in en el nodo del ADC3
                R_sh_eq = (shunt_efectivo * INV_R_IN_EQ) / (shunt_efectivo + INV_R_IN_EQ);
                C_sh_eq = INV_C_LEAK_EQ + INV_C_IN_EQ; 
                wRC = w * R_sh_eq * C_sh_eq;
                den_z = 1.0 + wRC * wRC;
                Zsh_re = R_sh_eq / den_z;
                Zsh_im = -(w * R_sh_eq * R_sh_eq * C_sh_eq) / den_z;

                // 2.4 Factor de Corrección de Voltaje (Fv)
                den_z = Zin_re * Zin_re + Zin_im * Zin_im;
                Zs_over_Zin_re = (Zs_re * Zin_re + Zs_im * Zin_im) / den_z;
                Zs_over_Zin_im = (Zs_im * Zin_re - Zs_re * Zin_im) / den_z;
                Fv_re = 1.0 + Zs_over_Zin_re;
                Fv_im = Zs_over_Zin_im;

                // 2.5 Factor de Corrección de Corriente (Fc)
                NumC_re = 2.0 * Zs_re + Zsh_re + Zin_re;
                NumC_im = 2.0 * Zs_im + Zsh_im + Zin_im;
                DenC_re = Zs_re + Zin_re;
                DenC_im = Zs_im + Zin_im;
                
                den_z = DenC_re * DenC_re + DenC_im * DenC_im;
                Fc_re = (NumC_re * DenC_re + NumC_im * DenC_im) / den_z;
                Fc_im = (NumC_im * DenC_re - NumC_re * DenC_im) / den_z;

                // 2.5b Multiplicador de Derivación del Shunt (Ksh)
                Ksh_re = 1.0 + (shunt_efectivo / INV_R_IN_EQ);
                Ksh_im = w * shunt_efectivo * C_sh_eq;
                
                // Factor Real de Corriente (Fi_real) = Fc * Ksh
                Fi_re = (Fc_re * Ksh_re) - (Fc_im * Ksh_im);
                Fi_im = (Fc_re * Ksh_im) + (Fc_im * Ksh_re);

                // 2.6 Factor Total para Z: Ftot = Fv / Fi_real
                den_z = Fi_re * Fi_re + Fi_im * Fi_im;
                Ftot_re = (Fv_re * Fi_re + Fv_im * Fi_im) / den_z; 
                Ftot_im = (Fv_im * Fi_re - Fv_re * Fi_im) / den_z;
                
                // ---------------------------------------------------------
                // 2.7 APLICAR CORRECCIÓN INDIVIDUAL PARA V e I (Sujeto 1)
                // ---------------------------------------------------------
                
                // A) Corregir Voltaje (Módulo A) con Factor Fv
                v_med_re = mag_V_raw * $cos(fase_V_raw * PI / 180.0);
                v_med_im = mag_V_raw * $sin(fase_V_raw * PI / 180.0);
                
                v_corr_re = (v_med_re * Fv_re) - (v_med_im * Fv_im);
                v_corr_im = (v_med_re * Fv_im) + (v_med_im * Fv_re);
                
                mag_V_corr = $sqrt(v_corr_re**2 + v_corr_im**2);
                
                // <<< CORRECCIÓN ANTI-NAN: Evitar atan2(0,0)
                fase_V_corr = (mag_V_corr < 1e-12) ? 0.0 : normalizar_fase_deg($atan2(v_corr_im, v_corr_re) * 180.0 / PI);

                // B) Corregir Corriente (Módulo B) con Factor Fc
                i_med_re = mag_I_raw * $cos(fase_I_raw * PI / 180.0);
                i_med_im = mag_I_raw * $sin(fase_I_raw * PI / 180.0);
                
                i_corr_re = (i_med_re * Fi_re) - (i_med_im * Fi_im);
                i_corr_im = (i_med_re * Fi_im) + (i_med_im * Fi_re);
                
                mag_I_corr = $sqrt(i_corr_re**2 + i_corr_im**2);
                fase_I_corr = (mag_I_corr < 1e-12) ? 0.0 : normalizar_fase_deg($atan2(i_corr_im, i_corr_re) * 180.0 / PI);
                
                // C) Corregir Z_Total (Módulo 4P) con Factor Ftot
                z_med_re = modulo_4p_corr * $cos(fase_4p_corr * PI / 180.0);
                z_med_im = modulo_4p_corr * $sin(fase_4p_corr * PI / 180.0);
                
                z_corr_re = (z_med_re * Ftot_re) - (z_med_im * Ftot_im);
                z_corr_im = (z_med_re * Ftot_im) + (z_med_im * Ftot_re);
                
                // Restar inductancia mutua
                // <<< CORRECCIÓN INDUCTANCIA: El RK4 usa +M y -M (Total 2M de diferencial)
                z_final_re = z_corr_re;
                z_final_im = z_corr_im - (2.0 * w * INV_MUTUAL_L_EQ);
                
                modulo_4p_inv = $sqrt(z_final_re**2 + z_final_im**2);
                fase_4p_inv = (modulo_4p_inv < 1e-12) ? 0.0 : normalizar_fase_deg($atan2(z_final_im, z_final_re) * 180.0 / PI);   
                
                // ---------------------------------------------------------
                // CÁLCULO DE ERRORES Y GUARDADO
                // ---------------------------------------------------------
                error_mag_4p_corr = (modulo_4p_corr > z_bio_mag) ? ((modulo_4p_corr - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_corr)/z_bio_mag)*100.0;
                error_fase_4p_corr = (fase_4p_corr > z_bio_fase) ? (fase_4p_corr - z_bio_fase) : (z_bio_fase - fase_4p_corr);
                
                error_mag_4p_inv = (modulo_4p_inv > z_bio_mag) ? ((modulo_4p_inv - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_inv)/z_bio_mag)*100.0;
                error_fase_4p_inv = (fase_4p_inv > z_bio_fase) ? (fase_4p_inv - z_bio_fase) : (z_bio_fase - fase_4p_inv);

                if (VERBOSE) begin
                    $display("=== FREQ: %9.2f Hz ===", frecuencia_almacenada);
                    $display("  [SUJETO 0: PRE-INV]  Mag: %8.2f Ohm | Fase: %6.2f deg", modulo_4p_corr, fase_4p_corr);
                    $display("  [SUJETO 1: POST-INV] Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", modulo_4p_inv, fase_4p_inv, error_mag_4p_inv, error_fase_4p_inv);
                    $display("  [SUJETO 2: GOLDEN]   Mag: %8.2f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
                end

                tiempo_hardware_s = $realtime / 1s;
                tiempo_pc_s = get_cpu_time_s(); 

                guardar_dato(0, medida, frecuencia_almacenada, modulo_4p_corr, fase_4p_corr, mag_V_raw, fase_V_raw, mag_I_raw, fase_I_raw, tiempo_pc_s, tiempo_hardware_s);
                guardar_dato(1, medida, frecuencia_almacenada, modulo_4p_inv, fase_4p_inv, mag_V_corr, fase_V_corr, mag_I_corr, fase_I_corr, tiempo_pc_s, tiempo_hardware_s);
            end 
    end
        
    always @(posedge clk125) begin
        fase_acc += 2.0 * PI * f_actual * DT;
        if (fase_acc >= 2.0*PI) fase_acc -= 2.0*PI;
        v_gen = 0.5 * $sin(fase_acc);
    end

endmodule