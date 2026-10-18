import dpi_pkg_tiempos::*;
import electrical_pkg::*;
`timescale 1ns/1ps
module tb_correlacion_portable_python_to_fpga_configurable;
`ifdef EXPERIMENTO_CONTACTO_150K
    localparam string STR_CONTACTO = "150K";
`elsif EXPERIMENTO_CONTACTO_50K
    localparam string STR_CONTACTO = "50K";
`elsif EXPERIMENTO_CONTACTO_5K
    localparam string STR_CONTACTO = "5K";
`else
    localparam string STR_CONTACTO = "1.5MK";
`endif

`ifdef EXPERIMENTO_SIN_AUTOSHUNT
    localparam string STR_AUTOSHUNT = "sin_autoshunt";
`else
    localparam string STR_AUTOSHUNT = "con_autoshunt";
`endif

`ifdef USE_VAMS_MIXED
    localparam string STR_SYMPHONY = "symphony";
    localparam string CSV_FLUJO = "symphony_mixed";
    localparam string CSV_SIMULADOR = "questa_symphony";
`else
    localparam string STR_SYMPHONY = "nettype";
    localparam string CSV_FLUJO = "nettype_rnm";
    localparam string CSV_SIMULADOR = "questa";
`endif

`ifdef EXPERIMENTO_K_MIN
    localparam string STR_K = "k_min";
`elsif EXPERIMENTO_K_MAX
    localparam string STR_K = "k_max";
`elsif EXPERIMENTO_K_EXTREMOS
    localparam string STR_K = "k_extremos";
`else
    localparam string STR_K = "todos_k";
`endif

    localparam string CSV_CONFIGURACION = {STR_CONTACTO, "_", STR_AUTOSHUNT, "_", STR_SYMPHONY, "_", STR_K};
    localparam string CSV_RUN_ID = "";

    import "DPI-C" function real get_cpu_time_s();

    localparam int MAGNITUD_WIDTH = 14;
    localparam real PI = 3.14159265358979;
    localparam real DT = 8e-9;
    localparam real NS_TO_S = 1e-9;
    localparam real ADC_SCALE=8192.0;
    localparam bit  ENABLE_ADC3_NOISE = 1'b1;
    localparam int NUMERO_MEDIDAS_BASE = 5;
`ifdef EXPERIMENTO_K_MIN
    localparam int NUMERO_MEDIDAS_EJECUCION = 1;
`elsif EXPERIMENTO_K_MAX
    localparam int NUMERO_MEDIDAS_EJECUCION = 1;
`elsif EXPERIMENTO_K_EXTREMOS
    localparam int NUMERO_MEDIDAS_EJECUCION = 2;
`else
    localparam int NUMERO_MEDIDAS_EJECUCION = NUMERO_MEDIDAS_BASE;
`endif
    localparam real numero_medidas = NUMERO_MEDIDAS_BASE;
    localparam real ADC3_NOISE_SIGMA_LSB = 0.5;
    localparam real R_CONT_MIN = 450000.0;
    localparam real R_CONT_RANGO_MEDIDA = 100000.0;
    localparam real R_CONT_AMP_BARRIDO = 120.0;
    localparam real MICRO_F1_HZ = 0.35;
    localparam real MICRO_F2_HZ = 1.10;
    localparam real R_C1_MICRO_PCT = 0.04;
    localparam real CP_MICRO_PCT  = 0.06;
    localparam bit VERBOSE = 1;
`ifdef EXPERIMENTO_SIN_AUTOSHUNT
    localparam bit activar_autoshunt = 1'b0;
`else
    localparam bit activar_autoshunt = 1'b1;
`endif

`ifdef DISPERSION_CONTACTOS
    localparam bit ACTIVA_DISPERSION = 1'b1;
`else
    localparam bit ACTIVA_DISPERSION = 1'b0;
`endif

    localparam real PHYS_R_IN = 1.0e6;
    localparam real PHYS_C_IN = 10.0e-12;
    localparam real PHYS_C_LEAK = 1.0e-12;
    localparam real PHYS_C_EQ = PHYS_C_IN + PHYS_C_LEAK;
    localparam real PHYS_MUTUAL_L = 2.5e-7;

    localparam real INV_R_IN_EQ     = PHYS_R_IN;
    localparam real INV_C_IN_EQ     = PHYS_C_IN;
    localparam real INV_C_LEAK_EQ   = PHYS_C_LEAK;
    localparam real INV_R_INA       = 1.0e12;
    localparam real INV_R_BIAS_INA  = 100.0e6;
    localparam real INV_C_INA       = 3.0e-12;
    localparam real INV_C_EQ        = PHYS_C_EQ;
    localparam real INV_MUTUAL_L_EQ = PHYS_MUTUAL_L;
    localparam real INV_C_F         = 2.0e-12;
    localparam real INV_R_SW_ON     = 4.5;
    localparam real INV_C_SW        = 10.0e-12;
    localparam real R_CAL_PATRON    = 10000.0;

// -----------------------------------------------------------------------------
// CONTROL DUAL / TRIPLE DE CALIBRACIÓN Y COMPENSACIÓN (OPCIÓN 3 ACUMULADA)
// METODO_SUJETO1:
//   0 = Método 1: Inversión Analítica Pura (Ecuaciones exactas INA + TIA + Shunt Real)
//   1 = Método 2: Calibración por LUT Pura (Resistencia Patrón R_cal)
//   2 = Método 3: Híbrido Acumulado (LUT Instrumental + De-embedding de contactos Fv)
// -----------------------------------------------------------------------------
`ifdef METODO_CALIB_HIBRIDO
    parameter int METODO_SUJETO1 = 2;
    parameter bit SIMULAR_FASE_CALIB_PREVIA = 1'b1;
`elsif METODO_CALIB_LUT_PURA
    parameter int METODO_SUJETO1 = 1;
    parameter bit SIMULAR_FASE_CALIB_PREVIA = 1'b1;
`elsif METODO_CALIB_ANALITICA
    parameter int METODO_SUJETO1 = 0;
    parameter bit SIMULAR_FASE_CALIB_PREVIA = 1'b0;
`else
`ifdef SIMULAR_CALIB_PREVIA
    parameter int METODO_SUJETO1 = 2; // Por defecto si se calibra previamente: Híbrido Acumulado
    parameter bit SIMULAR_FASE_CALIB_PREVIA = 1'b1;
`else
    parameter int METODO_SUJETO1 = 0; // Por defecto: Inversión Analítica Directa
    parameter bit SIMULAR_FASE_CALIB_PREVIA = 1'b0;
`endif
`endif

    function automatic real calcular_shunt_real(input [3:0] sw_val);
        real g_tot;
        g_tot = 1.0 / INV_R_IN_EQ;
        if (sw_val[0]) g_tot += 1.0 / (2000.0 + INV_R_SW_ON);
        if (sw_val[1]) g_tot += 1.0 / (1000.0 + INV_R_SW_ON);
        if (sw_val[2]) g_tot += 1.0 / (500.0  + INV_R_SW_ON);
        if (sw_val[3]) g_tot += 1.0 / (200.0  + INV_R_SW_ON);
        return (g_tot > 0.0) ? (1.0 / g_tot) : 2000.0;
    endfunction
    
    localparam bit  HF_PHASE_COMP_EN      = 1'b0;
    localparam real HF_PHASE_COMP_MAX_DEG = 46.0;
    localparam real HF_PHASE_COMP_F0_HZ   = 2.2e5;

`ifndef F_MIN_VAL
    `define F_MIN_VAL 40.0
`endif
`ifndef F_MAX_VAL
    `define F_MAX_VAL 1000000.0
`endif
    parameter real F_MIN = `F_MIN_VAL;
    parameter real F_MAX = `F_MAX_VAL;
`ifndef PTS_POR_DECADA_VAL
    `define PTS_POR_DECADA_VAL 10
`endif
    parameter int  PTS_POR_DECADA = `PTS_POR_DECADA_VAL;

    function automatic int calcular_num_puntos(real fmin, real fmax, int pts_dec);
        real ratio;
        real decades;
        ratio = fmax / fmin;
        decades = $ln(ratio) / $ln(10.0);
        return int'(decades * pts_dec) + 1;
    endfunction

    localparam int NUM_PUNTOS = calcular_num_puntos(F_MIN, F_MAX, PTS_POR_DECADA);

    function automatic bit generar_fichero_freqs(real fmin, real fmax, int pts_dec);
        int fd;
        int num_pts;
        real f_actual;
        logic [31:0] inc;
        
        num_pts = calcular_num_puntos(fmin, fmax, pts_dec);
        fd = $fopen("freq_log_ideal.dat", "w");
        if (fd == 0) return 1'b0;
        
        for (int i = 0; i < num_pts; i++) begin
            f_actual = fmin * $pow(10.0, real'(i) / real'(pts_dec));
            if (f_actual > fmax) f_actual = fmax;
            inc = int'((f_actual / 125000000.0) * 4294967296.0);
            $fwrite(fd, "@%x\n%08h\n", i, inc);
        end
        
        $fclose(fd);
        return 1'b1;
    endfunction

    bit dummy_init = generar_fichero_freqs(F_MIN, F_MAX, PTS_POR_DECADA);

    function automatic real normalizar_fase_deg(input real fase_deg);
        real fase_norm;
        begin
            fase_norm = fase_deg;
            while (fase_norm > 180.0) fase_norm -= 360.0;
            while (fase_norm <= -180.0) fase_norm += 360.0;
            normalizar_fase_deg = fase_norm;
        end
    endfunction

    function automatic real hf_phase_comp_deg(input real freq_hz);
        real x;
        begin
            if (!HF_PHASE_COMP_EN || freq_hz <= 0.0) begin
                hf_phase_comp_deg = 0.0;
            end else begin
                x = freq_hz / HF_PHASE_COMP_F0_HZ;
                hf_phase_comp_deg = HF_PHASE_COMP_MAX_DEG * (x * x) / (1.0 + x * x);
            end
        end
    endfunction
   
    logic clk125;
    logic [13:0] dds_bus; 
    logic [13:0] adc1_data_4p; 
    logic [13:0] adc2_data_4p; 
    logic [13:0] adc3_data_4p = 14'd0;  
    logic signed [13:0] adc3_data_4p_noisy; 
    logic signed [13:0] adc1_data_4p_noisy; 
    logic signed [13:0] adc2_data_4p_noisy; 

    logic areset_n;
    logic start;
    int medida; 
    logic [7:0] salto;
    logic [9:0] numero_ciclos;
    logic [9:0] numero_anchura;
    logic [3:0] numero_decimales;

    logic [31:0] incrementado;  
    logic fin, fin2, VALID_M, VALID_P;
    logic [31:0] MODULO,MODULOA,MODULOB;

    logic [8:0] address_mem, address_mem2, address_mem3;
    logic [2:0] estado_pasos_cero;
    logic signed [31:0] PHASE, PHASEA, PHASEB;

    logic autoshunt; 
    logic cuantificacion;
    longint contador_ciclos;
    logic [3:0] sw_autoshunt_val;

    localparam real R_ext   = 20000.0; 
    localparam real R_int   = 1500.0;
    localparam real C_mem   = 5.0e-9;
    localparam real R_shunt = 1000.0;
`ifdef EXPERIMENTO_CONTACTO_150K
    localparam real R_contactos = 150000.0;
`else
    localparam real R_contactos = 1500000.0;
`endif
    localparam real R_contact1= R_contactos; 
    localparam real R_contact2= R_contactos; 
    localparam real C_contactos= 1.0e-12;

    real r_cont_instant, r_cont_base_medida, r_cont_delta_barrido; 
    real r_c1, r_c2, r_s1, r_s2, cp_v1, cp_v2, cs_v1, cs_v2, cp_val;  
    real r_c1_base_medida, cp_base_medida;

    real r_f1_base_medida, r_f2_base_medida;
    real r_s1_base_medida, r_s2_base_medida;
    real cp_f1_base_medida, cp_f2_base_medida;
    real cp_s1_base_medida, cp_s2_base_medida;
    real r_f1, r_f2;
    real c_f1, c_f2, c_s1, c_s2;
    real t_inicio_medida_s;
    real rext_instant, rint_instant, c_mem_instant; 
    real k_degradacion; 
    integer seed_adc3_noise, seed_adc1_noise, seed_adc2_noise;
    integer seeds_base[10] = '{24680, 13579, 11223, 44556, 99887, 77665, 55443, 33221, 12121, 89898};
    real v_gen, f_actual, fase_acc = 0;
    
    real tiempo_hardware_s, tiempo_pc_s;

    real cola_frecuencias [$];
    real cola_r_cont [$];
    real cola_cp_val [$];
    real cola_shunt_effective_authosunt [$];
    real cola_shunt_real [$];
    logic [3:0] cola_sw_autoshunt [$];
    real cola_ciclos_acum [$];

    real v_a_4p, v_b_4p;
    real modulo_4p_corr, fase_4p_corr, error_mag_4p_corr, error_fase_4p_corr;
    
    bit modo_calibracion = 1'b0;
    real tabla_fase_calib [int];
    real tabla_modulo_calib [int];

    real modulo_4p_inv, fase_4p_inv, error_mag_4p_inv, error_fase_4p_inv, r_contact_flash;
    real modulo_inv_analitica, fase_inv_analitica;
    real modulo_calib_lut, fase_calib_lut;
    real modulo_hibrido_acum, fase_hibrido_acum;
    string nombre_metodo_sujeto1;
    real z_bio_re, z_bio_im, z_bio_mag, z_bio_fase, omega, xc, den_bio;   
    real v_shunt_effective_authosunt = 2000.0;
    real v_shunt_real = 2000.49;

`ifdef USE_VAMS_MIXED
    top_bioimpedancia_circuito_medida_portable_mixed_v4 #(
`else
    top_bioimpedancia_circuito_medida_portable_to_fpga_ina_v4 #(
`endif
      .C_in_ina(INV_C_INA),
      .R_in_ina(INV_R_INA),
      .R_bias_ina(INV_R_BIAS_INA),
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
        .sw_autoshunt(sw_autoshunt_val),
        .autoshunt_value(v_shunt_effective_authosunt), 
        .r_f1(r_f1),
        .r_f2(r_f2),
        .r_s1(r_s1),
        .r_s2(r_s2),
        .c_f1(c_f1),
        .c_f2(c_f2),
        .c_s1(c_s1),
        .c_s2(c_s2),
        .v_a_4p(v_a_4p),
        .v_b_4p(v_b_4p),
        .rext_instant(rext_instant),
        .rint_instant(rint_instant),
        .c_mem_instant(c_mem_instant),
        .adc1_data_4p(adc1_data_4p), 
        .adc2_data_4p(adc2_data_4p)
    );  

    always_ff @(posedge clk125) begin
        int code_raw_3, noise_q16_3, noise_lsb_3, code_noisy_3;
        int code_raw_2, noise_q16_2, noise_lsb_2, code_noisy_2;  
        int code_raw_1, noise_q16_1, noise_lsb_1, code_noisy_1;
     
        code_raw_3 = signed'(adc3_data_4p);
        code_raw_2 = signed'(adc2_data_4p);
        code_raw_1 = signed'(adc1_data_4p);
        if (ENABLE_ADC3_NOISE) begin
            noise_q16_3 = $dist_normal(seed_adc3_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_3 = (noise_q16_3 >= 0) ? ((noise_q16_3 + 32768) / 65536) : -(((-noise_q16_3) + 32768) / 65536);
            code_noisy_3 = code_raw_3 + noise_lsb_3;
            if (code_noisy_3 > 8191) code_noisy_3 = 8191;
            else if (code_noisy_3 < -8192) code_noisy_3 = -8192;
            
            noise_q16_2 = $dist_normal(seed_adc2_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_2 = (noise_q16_2 >= 0) ? ((noise_q16_2 + 32768) / 65536) : -(((-noise_q16_2) + 32768) / 65536);
            code_noisy_2 = code_raw_2 + noise_lsb_2;
            if (code_noisy_2 > 8191) code_noisy_2 = 8191;
            else if (code_noisy_2 < -8192) code_noisy_2 = -8192;
            
            noise_q16_1 = $dist_normal(seed_adc1_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_1 = (noise_q16_1 >= 0) ? ((noise_q16_1 + 32768) / 65536) : -(((-noise_q16_1) + 32768) / 65536);
            code_noisy_1 = code_raw_1 + noise_lsb_1;
            if (code_noisy_1 > 8191) code_noisy_1 = 8191;
            else if (code_noisy_1 < -8192) code_noisy_1 = -8192;

            adc3_data_4p_noisy <= code_noisy_3[13:0];
            adc1_data_4p_noisy <= code_noisy_1[13:0]; 
            adc2_data_4p_noisy <= code_noisy_2[13:0];
        end else begin
            adc3_data_4p_noisy <= adc3_data_4p;
            adc1_data_4p_noisy <= adc1_data_4p;
            adc2_data_4p_noisy <= adc2_data_4p;
        end
    end

    Control_path_best_rafa_mejora_correlacion_autoshunt_4p_mejorado #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(9),
        .MAGNITUD_WIDTH(MAGNITUD_WIDTH),
        .pancho_detector(2),
        .pciclos(4),
        .FICHERO_INICIAL("freq_log_ideal.dat"),
        .shunt(1000)
    ) control_path_4p_inst (
        .clk125(clk125),
        .clk65(clk65),
        .areset_n(areset_n),
        .start(start),
        .test1(1'b0),
        .test2(1'b0),
        .test3(1'b1),
        .salto(salto),
        .numero_rep(NUM_PUNTOS),
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

    initial begin
        contador_ciclos=0;
        r_cont_base_medida = R_CONT_MIN;
        r_cont_delta_barrido = 0.0;
        r_cont_instant = r_cont_base_medida;
        r_c1=r_cont_base_medida;
        r_c2=r_cont_base_medida;
        cp_val = 10e-12;
        r_c1_base_medida = r_c1;
        cp_base_medida = cp_val;
        
        r_f1_base_medida = r_cont_base_medida;
        r_f2_base_medida = r_cont_base_medida;
        r_s1_base_medida = r_cont_base_medida;
        r_s2_base_medida = r_cont_base_medida;
        cp_f1_base_medida = cp_val;
        cp_f2_base_medida = cp_val;
        cp_s1_base_medida = cp_val;
        cp_s2_base_medida = cp_val;

        rext_instant = R_ext ; 
        rint_instant = R_int ;
        c_mem_instant = C_mem ;
        t_inicio_medida_s = 0.0;
        medida = 0;
        start = 0;
        
        configurar_metadata_csv(CSV_FLUJO, CSV_SIMULADOR, CSV_CONFIGURACION, CSV_RUN_ID);
        autoshunt = activar_autoshunt; 
        cuantificacion = 1'b1 ; 
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);
        areset_n = 1'b0;
        repeat(3) @(negedge clk125);
        areset_n = 1'b1;
        repeat(3) @(negedge clk125);

        modo_calibracion = 1'b0;
        $display("\n=================================================================");
        $display("   [V4 - OPCION 3 MAGNITUD] INICIANDO ENTORNO DUAL (ANALITICA + LUT)");
        $display("   Modo Calibracion Previa: %s | Metodo Sujeto 1: %0d (%s)", 
                 SIMULAR_FASE_CALIB_PREVIA ? "HABILITADO" : "DESHABILITADO",
                 METODO_SUJETO1,
                 (METODO_SUJETO1 == 2) ? "HIBRIDO ACUMULADO (LUT + Fv)" :
                 (METODO_SUJETO1 == 1) ? "CALIBRACION LUT PURA" : "INVERSION ANALITICA DIRECTA");
        $display("=================================================================\n");

        if (SIMULAR_FASE_CALIB_PREVIA) begin
            $display("\n=================================================================");
            $display("   [FASE 0: CALIBRACION VIRTUAL] Barrido con R_cal patron pura (%.1f Ohm)...", R_CAL_PATRON);
            $display("   Conectando terminales a 4 hilos ideales (Rc = 0.01 Ohm, Cp = 0)...");
            $display("=================================================================\n");

            modo_calibracion = 1'b1;
            rext_instant  = R_CAL_PATRON;
            rint_instant  = 1.0e9;
            c_mem_instant = 1.0e-18;
            r_f1 = 0.01;
            r_f2 = 0.01;
            r_s1 = 0.01;
            r_s2 = 0.01;
            c_f1 = 1.0e-15;
            c_f2 = 1.0e-15;
            c_s1 = 1.0e-15;
            c_s2 = 1.0e-15;
            r_c1 = 0.01;
            cp_val = 1.0e-15;

            t_inicio_medida_s = $realtime * 1e-9;
            start = 1;
            @(negedge clk125);
            start = 0;
            @(posedge fin);
            #1000ns;

            $display("\n=================================================================");
            $display("   [FASE 0 COMPLETADA] %0d puntos calibrados y guardados en LUT.", tabla_modulo_calib.num());
            $display("   Pasando a FASE 1: Medida del tejido biológico con dispersion de contactos...");
            $display("=================================================================\n");

            modo_calibracion = 1'b0;
        end

        for (int idx_loop = 0; idx_loop < NUMERO_MEDIDAS_EJECUCION; idx_loop++) begin
            int idx_k_real;
`ifdef EXPERIMENTO_K_MIN
            idx_k_real = 0;
`elsif EXPERIMENTO_K_MAX
            idx_k_real = NUMERO_MEDIDAS_BASE - 1;
`elsif EXPERIMENTO_K_EXTREMOS
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
            
            k_degradacion = real'((idx_k_real + 1.0) / numero_medidas);
`ifdef EXPERIMENTO_CONTACTO_150K
            r_c1_base_medida   = 150000.0 + $urandom_range(0, 20000);
`elsif EXPERIMENTO_CONTACTO_50K
            r_c1_base_medida   = 50000.0 + $urandom_range(0, 7000); 
`elsif EXPERIMENTO_CONTACTO_5K
            r_c1_base_medida   = 5000.0 + $urandom_range(0, 1000);             
`else
            r_c1_base_medida   = 1500000.0 + $urandom_range(0, 500000); 
`endif
            cp_base_medida = C_contactos + ($urandom_range(0, 500) * 1e-15); 
            
            if (ACTIVA_DISPERSION) begin
                r_f1_base_medida = r_c1_base_medida * (0.8 + 0.4 * ($urandom_range(0, 1000) / 1000.0));
                r_f2_base_medida = r_c1_base_medida * (0.8 + 0.4 * ($urandom_range(0, 1000) / 1000.0));
                r_s1_base_medida = r_c1_base_medida * (0.8 + 0.4 * ($urandom_range(0, 1000) / 1000.0));
                r_s2_base_medida = r_c1_base_medida * (0.8 + 0.4 * ($urandom_range(0, 1000) / 1000.0));
            end else begin
                r_f1_base_medida = r_c1_base_medida;
                r_f2_base_medida = r_c1_base_medida;
                r_s1_base_medida = r_c1_base_medida;
                r_s2_base_medida = r_c1_base_medida;
            end

            cp_f1_base_medida = cp_base_medida;
            cp_f2_base_medida = cp_base_medida;
            cp_s1_base_medida = cp_base_medida;
            cp_s2_base_medida = cp_base_medida;

            r_f1 = r_f1_base_medida;
            r_f2 = r_f2_base_medida;
            r_s1 = r_s1_base_medida;
            r_s2 = r_s2_base_medida;
            c_f1 = cp_f1_base_medida;
            c_f2 = cp_f2_base_medida;
            c_s1 = cp_s1_base_medida;
            c_s2 = cp_s2_base_medida;
            
            r_c1 = r_s1_base_medida;
            cp_val = cp_base_medida;
            t_inicio_medida_s = $realtime * 1e-9;
            
            rext_instant  = R_ext * (1.0 - (0.5 * k_degradacion)); 
            rint_instant  = R_int * (1.0 - (0.2 * k_degradacion));
            c_mem_instant = C_mem * (1.0 / (1.0 + 5.0 * k_degradacion));
            
            start = 1;
            @(negedge clk125);
                start = 0;
            @(posedge fin);

            #1000ns;
        end
        $display("\nSimulación finalizada. Procesando datos en Python...");
        procesar_dataframe();
        $finish;
    end

    initial begin
        configurar_metadata_csv(CSV_FLUJO, CSV_SIMULADOR, CSV_CONFIGURACION, CSV_RUN_ID);
        inicializar_tiempos();
        clk125 = 1'b0;
        forever #((DT/2)*1s) clk125 = ~clk125;
    end

    always@(incrementado) begin
        real t_local_s;
        real micro_presion;

        f_actual = (real'(incrementado) / 4294967296.0) * 125000000.0;
        if (autoshunt) begin
            if (f_actual < 1000.0) begin 
                v_shunt_effective_authosunt = 2000.0; 
                sw_autoshunt_val = 4'b0001;
                if (f_actual < 100.0) begin 
                    numero_ciclos = 10'd0; numero_anchura = 10'd1; numero_decimales = 4'd9;  
                end else begin
                    numero_ciclos = 10'd1; numero_anchura = 10'd1; numero_decimales = 4'd8; 
                end
            end else if (f_actual < 10000.0) begin 
                v_shunt_effective_authosunt = 666.67;
                sw_autoshunt_val = 4'b0011;
                numero_ciclos = 10'd16; //antes era 4
                numero_anchura = 10'd2; 
                numero_decimales = 4'd6;  
            end else if (f_actual < 100000.0) begin 
                v_shunt_effective_authosunt = 333.33;
                sw_autoshunt_val = 4'b0110;
                numero_ciclos = 10'd32; //antes era 5
                numero_anchura = 10'd2; 
                numero_decimales = 4'd5; 
            end else begin 
                v_shunt_effective_authosunt = 125.0;
                sw_autoshunt_val = 4'b1110;
                numero_ciclos = 10'd128; numero_anchura = 10'd2; numero_decimales = 4'd4; 
            end
        end else begin
            v_shunt_effective_authosunt = 2000.0;  
            sw_autoshunt_val = 4'b0001;
            if (f_actual < 100.0) begin 
                numero_ciclos = 10'd0; numero_anchura = 10'd1; numero_decimales = 4'd9;  
            end else if (f_actual < 1000.0) begin 
                numero_ciclos = 10'd1; numero_anchura = 10'd1; numero_decimales = 4'd8; 
            end else if (f_actual < 10000.0) begin  
                numero_ciclos = 10'd4; numero_anchura = 10'd2; numero_decimales = 4'd6;  
            end else if (f_actual < 100000.0) begin 
                numero_ciclos = 10'd5; numero_anchura = 10'd2; numero_decimales = 4'd5; 
            end else begin 
                numero_ciclos = 10'd64; numero_anchura = 10'd2; numero_decimales = 4'd4; 
            end
        end   

        if (f_actual > 1.0) begin
            t_local_s = ($realtime * 1e-9) - t_inicio_medida_s;
            micro_presion = 0.65*$sin(2.0*PI*MICRO_F1_HZ*t_local_s) + 0.35*$sin(2.0*PI*MICRO_F2_HZ*t_local_s + 0.7);

            r_f1 = r_f1_base_medida * (1.0 - R_C1_MICRO_PCT*micro_presion);
            r_f2 = r_f2_base_medida * (1.0 - R_C1_MICRO_PCT*micro_presion);
            r_s1 = r_s1_base_medida * (1.0 - R_C1_MICRO_PCT*micro_presion);
            r_s2 = r_s2_base_medida * (1.0 - R_C1_MICRO_PCT*micro_presion);

            cp_base_medida = 1.0e-12; 
            c_f1 = cp_base_medida * (1.0 + CP_MICRO_PCT*micro_presion);
            c_f2 = cp_base_medida * (1.0 + CP_MICRO_PCT*micro_presion);
            c_s1 = cp_base_medida * (1.0 + CP_MICRO_PCT*micro_presion);
            c_s2 = cp_base_medida * (1.0 + CP_MICRO_PCT*micro_presion);

            if (r_f1 < 1.0) r_f1 = 1.0;
            if (r_f2 < 1.0) r_f2 = 1.0;
            if (r_s1 < 1.0) r_s1 = 1.0;
            if (r_s2 < 1.0) r_s2 = 1.0;
            if (c_f1 < 1e-13) c_f1 = 1e-13;
            if (c_f2 < 1e-13) c_f2 = 1e-13;
            if (c_s1 < 1e-13) c_s1 = 1e-13;
            if (c_s2 < 1e-13) c_s2 = 1e-13;

            r_c1 = r_s1;
            cp_v1 = c_s1;

            r_cont_delta_barrido = R_CONT_AMP_BARRIDO * $sin(2.0 * PI * ($ln(f_actual + 1.0) / $ln(10.0)));
            r_cont_instant = r_s1;
            if (r_cont_instant < 1.0) r_cont_instant = 1.0;
            
            omega = 2.0 * PI * f_actual;
            xc = 1.0 / (omega * c_mem_instant);
            den_bio = (rext_instant + rint_instant)**2 + xc**2;
            z_bio_re = (rext_instant * (rint_instant*(rext_instant + rint_instant) + xc**2)) / den_bio;
            z_bio_im = (rext_instant**2 * -(xc)) / den_bio;
            z_bio_mag  = $sqrt(z_bio_re**2 + z_bio_im**2);
            z_bio_fase = $atan2(z_bio_im, z_bio_re) * (180.0 / PI);

            v_shunt_real = calcular_shunt_real(sw_autoshunt_val);
            cola_frecuencias.push_front(f_actual);
            cola_shunt_effective_authosunt.push_front(v_shunt_effective_authosunt);
            cola_shunt_real.push_front(v_shunt_real);
            cola_sw_autoshunt.push_front(sw_autoshunt_val);
            cola_r_cont.push_front(r_cont_instant);
            cola_cp_val.push_front(cp_v1);
            cola_ciclos_acum.push_front(((numero_ciclos + 2 - numero_anchura) > 0) ? real'(numero_ciclos + 2 - numero_anchura) : 1.0);
            
            tiempo_hardware_s = $realtime / 1s;
            tiempo_pc_s = get_cpu_time_s(); 

            if (!modo_calibracion) begin
                guardar_dato(2,medida,f_actual,z_bio_mag ,z_bio_fase, 0.0, 0.0, 0.0, 0.0, tiempo_pc_s, tiempo_hardware_s);
            end 
        end
    end

    always @(posedge clk125) begin
        real fases,fasesa,fasesb;
        real fases_post;
        real modulo_post, modulo_a, modulo_b, n_ciclos_acum;
        
        real cola_modulo [$]; 
        real cola_fase [$];
        real cola_modulo_a [$];
        real cola_modulo_b [$];
        real cola_fase_a [$];
        real cola_fase_b [$];
        
        real frecuencia_almacenada;
        real shunt_efectivo;
        real shunt_real;
        logic [3:0] sw_val_act;
        real r_cont_almacenada, cp_almacenada;
        
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
        real inv_alpha;
        
        real mag_V_raw, fase_V_raw;
        real mag_I_raw, fase_I_raw;
        
        real mag_V_corr, fase_V_corr;
        real mag_I_corr, fase_I_corr;
        real v_med_re, v_med_im, v_corr_re, v_corr_im;
        real i_med_re, i_med_im, i_corr_re, i_corr_im;

        real z_med_re, z_med_im, z_corr_re, z_corr_im;
        real z_final_re, z_final_im;
        real hf_phase_comp;

        contador_ciclos = contador_ciclos + 1;

        if (VALID_M) begin
            shunt_efectivo = (cola_shunt_effective_authosunt.size() > 0) ? cola_shunt_effective_authosunt.pop_back() : v_shunt_effective_authosunt; 
            shunt_real     = (cola_shunt_real.size() > 0) ? cola_shunt_real.pop_back() : v_shunt_real;
            sw_val_act     = (cola_sw_autoshunt.size() > 0) ? cola_sw_autoshunt.pop_back() : sw_autoshunt_val;
            n_ciclos_acum  = (cola_ciclos_acum.size() > 0) ? cola_ciclos_acum.pop_back() : (((numero_ciclos + 2 - numero_anchura) > 0) ? real'(numero_ciclos + 2 - numero_anchura) : 1.0);
            modulo_post    = (real'(MODULO)*shunt_efectivo/real'(1<<numero_decimales));
            modulo_a       = real'(MODULOA) / n_ciclos_acum;
            modulo_b       = (real'(MODULOB) / (shunt_efectivo * n_ciclos_acum));
            
            cola_modulo.push_front(modulo_post);
            cola_modulo_a.push_front(modulo_a);
            cola_modulo_b.push_front(modulo_b);
        end   
        
        if (VALID_P) begin
            fases=real'(PHASE)/8.0;
            fasesa=real'(PHASEA)/8.0;
            fasesb=real'(PHASEB)/8.0;
            
            fases_post = fases; 
            cola_fase.push_front(fases_post);
            cola_fase_a.push_front(fasesa);
            cola_fase_b.push_front(fasesb);
        end
        
        if (cola_modulo.size() > 0 && cola_fase.size()>0 && 
            cola_modulo_a.size() > 0 && cola_fase_a.size()>0 &&
            cola_modulo_b.size() > 0 && cola_fase_b.size()>0)
            begin 
                modulo_4p_corr = cola_modulo.pop_back(); 
                fase_4p_corr = cola_fase.pop_back();
                mag_V_raw = cola_modulo_a.pop_back();
                fase_V_raw = cola_fase_a.pop_back();
                mag_I_raw = cola_modulo_b.pop_back();
                fase_I_raw = cola_fase_b.pop_back();
                
                frecuencia_almacenada = cola_frecuencias.pop_back();
                r_cont_almacenada = cola_r_cont.pop_back();
                cp_almacenada = cola_cp_val.pop_back();

                hf_phase_comp = hf_phase_comp_deg(frecuencia_almacenada);

                if (frecuencia_almacenada < 80.0) begin
                    automatic real v_gen_amp = 0.5; 
                    automatic real K_ADC = 5.234e-10 * frecuencia_almacenada;
                    automatic real i_shunt_amp_real = mag_I_raw * K_ADC;
                    automatic real z_bucle_total = v_gen_amp / i_shunt_amp_real;
                    
                    r_contact_flash = (z_bucle_total - modulo_4p_corr - 50.0) / 2.0;

                    if (VERBOSE) begin
                        $display("\n  [FLASH EXTRACTION] Freq: %5.1f Hz", frecuencia_almacenada);
                        $display("    -> Z Bucle Total Medida: %9.0f Ohm", z_bucle_total);
                        $display("    -> R_contact Dinámica Extraída: %9.0f Ohm", r_contact_flash);
                        $display("    -> R_contact_Force real (promedio): %9.0f Ohm (rf1: %0.0f, rf2: %0.0f)", (r_f1 + r_f2)/2.0, r_f1, r_f2);
                        $display("    -> R_contact_Sense real (oculto rs1): %9.0f Ohm", r_s1);
                    end
                end

                w = 2.0 * PI * frecuencia_almacenada;

                wRC = w * r_contact_flash * cp_almacenada;
                den_z = 1.0 + wRC * wRC;
                Zs_re = r_contact_flash / den_z;
                Zs_im = -(w * r_contact_flash * r_contact_flash * cp_almacenada) / den_z;

                begin
                    automatic real R_ina_eff = (INV_R_INA * INV_R_BIAS_INA) / (INV_R_INA + INV_R_BIAS_INA);
                    automatic real C_ina_eq  = INV_C_INA;
                    wRC = w * R_ina_eff * C_ina_eq; 
                    den_z = 1.0 + wRC * wRC;
                    Zin_re = R_ina_eff / den_z;
                    Zin_im = -(w * R_ina_eff * R_ina_eff * C_ina_eq) / den_z;
                end 

                R_sh_eq = (shunt_efectivo * INV_R_IN_EQ) / (shunt_efectivo + INV_R_IN_EQ);
                C_sh_eq = INV_C_LEAK_EQ + INV_C_IN_EQ; 
                wRC = w * R_sh_eq * C_sh_eq;
                den_z = 1.0 + wRC * wRC;
                Zsh_re = R_sh_eq / den_z;
                Zsh_im = -(w * R_sh_eq * R_sh_eq * C_sh_eq) / den_z;

                den_z = Zin_re * Zin_re + Zin_im * Zin_im;
                Zs_over_Zin_re = (Zs_re * Zin_re + Zs_im * Zin_im) / den_z;
                Zs_over_Zin_im = (Zs_im * Zin_re - Zs_re * Zin_im) / den_z;
                Fv_re = 1.0 + Zs_over_Zin_re;
                Fv_im = Zs_over_Zin_im;

                Fc_re = 1.0;
                Fc_im = 0.0;
                Ksh_re = 1.0;
                Ksh_im = 0.0;

                begin
                    automatic real n_sw_on = (sw_val_act[0]?1.0:0.0) + (sw_val_act[1]?1.0:0.0) + (sw_val_act[2]?1.0:0.0) + (sw_val_act[3]?1.0:0.0);
                    automatic real C_eff = INV_C_F + INV_C_IN_EQ + INV_C_LEAK_EQ + (n_sw_on * INV_C_SW);
                    Fi_re = 1.0 + (shunt_real / INV_R_IN_EQ);
                    Fi_im = w * shunt_real * C_eff;
                end

                inv_alpha = 1.0;
                Fv_re = 1.0 + inv_alpha * (Fv_re - 1.0);
                Fv_im = inv_alpha * Fv_im;
                Fi_re = 1.0 + inv_alpha * (Fi_re - 1.0);
                Fi_im = inv_alpha * Fi_im;

                den_z = Fi_re * Fi_re + Fi_im * Fi_im;
                Ftot_re = (Fv_re * Fi_re + Fv_im * Fi_im) / den_z; 
                Ftot_im = (Fv_im * Fi_re - Fv_re * Fi_im) / den_z;
                
                begin
                    automatic real f_v_inv = normalizar_fase_deg(fase_V_raw - hf_phase_comp);
                    automatic real f_i_inv = normalizar_fase_deg(fase_I_raw - hf_phase_comp);
                    automatic real f_z_inv = normalizar_fase_deg(fase_4p_corr - hf_phase_comp);

                    v_med_re = mag_V_raw * $cos(f_v_inv * PI / 180.0);
                    v_med_im = mag_V_raw * $sin(f_v_inv * PI / 180.0);
                    
                    v_corr_re = (v_med_re * Fv_re) - (v_med_im * Fv_im);
                    v_corr_im = (v_med_re * Fv_im) + (v_med_im * Fv_re);
                    
                    mag_V_corr = $sqrt(v_corr_re**2 + v_corr_im**2);
                    fase_V_corr = (mag_V_corr < 1e-12) ? 0.0 : normalizar_fase_deg($atan2(v_corr_im, v_corr_re) * 180.0 / PI);

                    i_med_re = mag_I_raw * $cos(f_i_inv * PI / 180.0);
                    i_med_im = mag_I_raw * $sin(f_i_inv * PI / 180.0);
                    
                    i_corr_re = (i_med_re * Fi_re) - (i_med_im * Fi_im);
                    i_corr_im = (i_med_re * Fi_im) + (i_med_im * Fi_re);
                    
                    mag_I_corr = $sqrt(i_corr_re**2 + i_corr_im**2);
                    fase_I_corr = (mag_I_corr < 1e-12) ? 0.0 : normalizar_fase_deg($atan2(i_corr_im, i_corr_re) * 180.0 / PI);

                    z_med_re = modulo_4p_corr * $cos(f_z_inv * PI / 180.0);
                    z_med_im = modulo_4p_corr * $sin(f_z_inv * PI / 180.0);
                end
                
                if (modo_calibracion) begin
                    automatic int f_key = int'(frecuencia_almacenada + 0.5);
                    tabla_fase_calib[f_key]   = fase_4p_corr;
                    tabla_modulo_calib[f_key] = (modulo_4p_corr > 1e-6) ? (R_CAL_PATRON / modulo_4p_corr) : 1.0;
                    if (VERBOSE) begin
                        $display("  [CALIB HW] Freq: %9.2f Hz | Desfase HW: %6.2f deg | K_gain: %8.4f", 
                                 frecuencia_almacenada, fase_4p_corr, tabla_modulo_calib[f_key]);
                    end
                end else begin
                    automatic int f_key = int'(frecuencia_almacenada + 0.5);
                    automatic real n_sw_on = (sw_val_act[0]?1.0:0.0) + (sw_val_act[1]?1.0:0.0) + (sw_val_act[2]?1.0:0.0) + (sw_val_act[3]?1.0:0.0);
                    automatic real C_tia_comp = INV_C_F + INV_C_IN_EQ + INV_C_LEAK_EQ + (n_sw_on * INV_C_SW);
                    automatic real theta_tia_deg = $atan(w * shunt_real * C_tia_comp) * (180.0 / PI);
                    
                    automatic real C_ina_comp = INV_C_INA + cp_almacenada;
                    automatic real theta_ina_deg = $atan(w * r_contact_flash * C_ina_comp) * (180.0 / PI);
                    
                    automatic real delay_comp_deg = 360.0 * frecuencia_almacenada * 8.0e-9;
                    
                    // =========================================================================
                    // V4 - OPCIÓN 3: COMPARADOR DE 3 MÉTODOS DE COMPENSACIÓN
                    // =========================================================================
                    automatic real mag_ina_factor = $sqrt(Fv_re**2 + Fv_im**2);
                    automatic real theta_ina_calc_deg = $atan2(Fv_im, Fv_re) * (180.0 / PI);
                    
                    // 1. MÉTODO 1: INVERSIÓN ANALÍTICA PURA (Modelo matemático de Shunt Real + TIA + INA)
                    fase_inv_analitica = normalizar_fase_deg(fase_4p_corr + theta_ina_deg - theta_tia_deg + delay_comp_deg);
                    begin
                        automatic real k_shunt_corr = shunt_real / shunt_efectivo;
                        if (mag_I_corr > 1e-15) begin
                            modulo_inv_analitica = (mag_V_corr / mag_I_corr) * k_shunt_corr;
                        end else begin
                            modulo_inv_analitica = modulo_4p_corr * k_shunt_corr;
                        end
                    end

                    // 2. MÉTODO 2: CALIBRACIÓN POR LUT PURA (Absorbe 100% de errores internos del instrumento en R_cal)
                    if (tabla_modulo_calib.exists(f_key)) begin
                        modulo_calib_lut = modulo_4p_corr * tabla_modulo_calib[f_key];
                        fase_calib_lut   = normalizar_fase_deg(fase_4p_corr - tabla_fase_calib[f_key]);
                    end else begin
                        modulo_calib_lut = modulo_inv_analitica;
                        fase_calib_lut   = fase_inv_analitica;
                    end

                    // 3. MÉTODO 3: HÍBRIDO ACUMULADO (LUT del Instrumento + De-embedding de contactos de piel Fv)
                    // La LUT ya absorbió el TIA, multiplexor y delay. Se acumula la corrección del divisor de contacto:
                    if (tabla_modulo_calib.exists(f_key)) begin
                        modulo_hibrido_acum = modulo_calib_lut * mag_ina_factor;
                        fase_hibrido_acum   = normalizar_fase_deg(fase_calib_lut + theta_ina_calc_deg);
                    end else begin
                        modulo_hibrido_acum = modulo_inv_analitica;
                        fase_hibrido_acum   = fase_inv_analitica;
                    end

                    // Selección del método activo asignado a Sujeto 1
                    if (METODO_SUJETO1 == 2 && tabla_modulo_calib.exists(f_key)) begin
                        modulo_4p_inv = modulo_hibrido_acum;
                        fase_4p_inv   = fase_hibrido_acum;
                        nombre_metodo_sujeto1 = "HIBRIDO ACUMULADO (LUT + Fv)";
                    end else if (METODO_SUJETO1 == 1 && tabla_modulo_calib.exists(f_key)) begin
                        modulo_4p_inv = modulo_calib_lut;
                        fase_4p_inv   = fase_calib_lut;
                        nombre_metodo_sujeto1 = "CALIBRACION LUT PURA";
                    end else begin
                        modulo_4p_inv = modulo_inv_analitica;
                        fase_4p_inv   = fase_inv_analitica;
                        nombre_metodo_sujeto1 = "INVERSION ANALITICA";
                    end
                    
                    error_mag_4p_corr = (modulo_4p_corr > z_bio_mag) ? ((modulo_4p_corr - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_corr)/z_bio_mag)*100.0;
                    error_fase_4p_corr = (fase_4p_corr > z_bio_fase) ? (fase_4p_corr - z_bio_fase) : (z_bio_fase - fase_4p_corr);
                    
                    error_mag_4p_inv = (modulo_4p_inv > z_bio_mag) ? ((modulo_4p_inv - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_inv)/z_bio_mag)*100.0;
                    error_fase_4p_inv = (fase_4p_inv > z_bio_fase) ? (fase_4p_inv - z_bio_fase) : (z_bio_fase - fase_4p_inv);

                    begin
                        automatic real err_m_raw = (modulo_4p_corr > z_bio_mag) ? ((modulo_4p_corr - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_4p_corr)/z_bio_mag)*100.0;
                        automatic real err_f_raw = (fase_4p_corr > z_bio_fase) ? (fase_4p_corr - z_bio_fase) : (z_bio_fase - fase_4p_corr);

                        automatic real err_m_analit = (modulo_inv_analitica > z_bio_mag) ? ((modulo_inv_analitica - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_inv_analitica)/z_bio_mag)*100.0;
                        automatic real err_f_analit = (fase_inv_analitica > z_bio_fase) ? (fase_inv_analitica - z_bio_fase) : (z_bio_fase - fase_inv_analitica);

                        automatic real err_m_lut = (modulo_calib_lut > z_bio_mag) ? ((modulo_calib_lut - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_calib_lut)/z_bio_mag)*100.0;
                        automatic real err_f_lut = (fase_calib_lut > z_bio_fase) ? (fase_calib_lut - z_bio_fase) : (z_bio_fase - fase_calib_lut);

                        automatic real err_m_hib = (modulo_hibrido_acum > z_bio_mag) ? ((modulo_hibrido_acum - z_bio_mag)/z_bio_mag)*100.0 : ((z_bio_mag - modulo_hibrido_acum)/z_bio_mag)*100.0;
                        automatic real err_f_hib = (fase_hibrido_acum > z_bio_fase) ? (fase_hibrido_acum - z_bio_fase) : (z_bio_fase - fase_hibrido_acum);

                        if (VERBOSE) begin
                            $display("=== FREQ: %9.2f Hz ===", frecuencia_almacenada);
                            $display("  [SUJETO 0: RAW]         Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", 
                                     modulo_4p_corr, fase_4p_corr, err_m_raw, err_f_raw);
                            $display("  [SUJETO 1: APLICADO]    Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg (%s)", 
                                     modulo_4p_inv, fase_4p_inv, error_mag_4p_inv, error_fase_4p_inv, nombre_metodo_sujeto1);
                            $display("    -> [M1] Invers. Analit: Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", 
                                     modulo_inv_analitica, fase_inv_analitica, err_m_analit, err_f_analit);
                            if (tabla_modulo_calib.exists(f_key)) begin
                                $display("    -> [M2] LUT Pura:       Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", 
                                         modulo_calib_lut, fase_calib_lut, err_m_lut, err_f_lut);
                                $display("    -> [M3] Hibrido Acum:   Mag: %8.2f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", 
                                         modulo_hibrido_acum, fase_hibrido_acum, err_m_hib, err_f_hib);
                            end
                            $display("  [SUJETO 2: GOLDEN]      Mag: %8.2f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
                        end
                    end

                    tiempo_hardware_s = real'(contador_ciclos) * 8.0e-9;
                    tiempo_pc_s = get_cpu_time_s(); 

                    guardar_dato(0, medida, frecuencia_almacenada, modulo_4p_corr, fase_4p_corr, mag_V_raw, fase_V_raw, mag_I_raw, fase_I_raw, tiempo_pc_s, tiempo_hardware_s);
                    guardar_dato(1, medida, frecuencia_almacenada, modulo_4p_inv, fase_4p_inv, mag_V_corr, fase_V_corr, mag_I_corr, fase_I_corr, tiempo_pc_s, tiempo_hardware_s);
                end
            end 
    end
        
    always @(posedge clk125) begin
        fase_acc += 2.0 * PI * f_actual * DT;
        if (fase_acc >= 2.0*PI) fase_acc -= 2.0*PI;
        v_gen = 0.5 * $sin(fase_acc);
    end

endmodule
