import dpi_pkg_tiempos::*;
import electrical_pkg::*;
`timescale 1ns/1ps

module tb_comparacion_3p_vs_4p_portable_python_completar_medida9;
`ifdef USE_VAMS_MIXED
    localparam string CSV_FLUJO = "symphony_mixed";
    localparam string CSV_SIMULADOR = "questa_symphony";
`else
    localparam string CSV_FLUJO = "nettype_rnm";
    localparam string CSV_SIMULADOR = "questa";
`endif
`ifdef EXPERIMENTO_SIN_AUTOSHUNT
    localparam string CSV_CONFIGURACION = "exp_k_extremos_symphony_sin_autoshunt_completar_medida9";
    localparam bit activar_autoshunt = 1'b0;
`else
    localparam string CSV_CONFIGURACION = "exp_k_extremos_symphony_completar_medida9";
    localparam bit activar_autoshunt = 1'b1;
`endif
    localparam string CSV_RUN_ID = "";

    localparam int MAGNITUD_WIDTH = 14;
    localparam int N = 1024;
    localparam real PI = 3.14159265358979;
    localparam real DT = 8e-9;
    localparam real NS_TO_S = 1e-9;
    localparam real ADC_SCALE = 8192.0;
    localparam bit ENABLE_ADC3_NOISE = 1'b1;
    localparam int NUMERO_MEDIDAS_BASE = 10;
    localparam real numero_medidas = NUMERO_MEDIDAS_BASE;
    localparam int MEDIDA_OBJETIVO = NUMERO_MEDIDAS_BASE - 1;
    localparam int NUMERO_REPETICIONES_FRECUENCIA = 225;
    localparam real ADC3_NOISE_SIGMA_LSB = 0.5;
    localparam real R_CONT_MIN = 500.0;
    localparam real R_CONT_RANGO_MEDIDA = 1500.0;
    localparam real R_CONT_AMP_BARRIDO = 120.0;
    localparam real MICRO_F1_HZ = 0.35;
    localparam real MICRO_F2_HZ = 1.10;
    localparam real R_C1_MICRO_PCT = 0.04;
    localparam real CP_MICRO_PCT = 0.06;
    localparam bit VERBOSE = 1;

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

    logic clk125;
    logic [13:0] dds_bus;
    logic [13:0] adc1_data_4p;
    logic [13:0] adc2_data_4p;
    logic [13:0] adc3_data_4p;
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
    logic [31:0] MODULO, MODULOA, MODULOB;
    logic [8:0] address_mem, address_mem2, address_mem3;
    logic [2:0] estado_pasos_cero;
    logic signed [31:0] PHASE, PHASEA, PHASEB;

    logic autoshunt;
    logic cuantificacion;

    localparam real R_ext = 20000.0;
    localparam real R_int = 1500.0;
    localparam real C_mem = 5.0e-9;
    localparam real R_shunt = 100.0;
    localparam real R_contact1 = 500.0;
    localparam real R_contact2 = 500.0;
    localparam real C_p1 = 1.0e-10;
    localparam real C_p2 = 1.0e-10;

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

    real v_im_z[N] = '{default:0};
    real v_a_4p, v_b_4p, v_c_4p;
    real adc1_v_p_4p[N], adc2_v_n_4p[N], adc3_v_sh_4p[N];
    real v_diff_4p[N], i_calc_4p[N];
    real V_fft_re_4p[N], V_fft_im_4p[N], I_fft_re_4p[N], I_fft_im_4p[N];
    real mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p;
    real den_4p;

    real modulo_4p_corr;
    real fase_4p_corr;
    real error_mag_4p_corr;
    real error_fase_4p_corr;
    real cola_frecuencias[$];

    real z_bio_re, z_bio_im, z_bio_mag, z_bio_fase;
    real omega, xc, den_bio;
    real v_shunt_effective_authosunt;
    real cola_shunt_effective_authosunt[$];

    always_comb begin
        if (autoshunt)
            case (estado_pasos_cero)
                3'b000: begin
                    v_shunt_effective_authosunt = 2000.0;
                    numero_ciclos = 10'd4;
                    numero_anchura = 10'd2;
                    numero_decimales = 4'd9;
                end
                3'b001: begin
                    v_shunt_effective_authosunt = 1000.0;
                    numero_ciclos = 10'd4;
                    numero_anchura = 10'd2;
                    numero_decimales = 4'd8;
                end
                3'b010: begin
                    v_shunt_effective_authosunt = 500.0;
                    numero_ciclos = 10'd5;
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
            numero_ciclos = 10'd5;
            v_shunt_effective_authosunt = R_shunt;
            numero_anchura = 10'd2;
            numero_decimales = 4'd4;
        end
    end

`ifdef USE_VAMS_MIXED
    top_bioimpedancia_circuito_medida_portable_mixed #(
        .R_contact1(R_contact1), .R_contact2(R_contact2), .R_ext(R_ext), .R_int(R_int), .C_mem(C_mem), .R_shunt(R_shunt), .C_p1(C_p1), .C_p2(C_p2)
    ) analog_circuit (
`else
    top_bioimpedancia_circuito_medida_portable_nettype #(
        .R_contact1(R_contact1), .R_contact2(R_contact2), .R_ext(R_ext), .R_int(R_int), .C_mem(C_mem), .R_shunt(R_shunt), .C_p1(C_p1), .C_p2(C_p2)
    ) analog_circuit (
`endif
        .clk(clk125),
        .dds_bus(dds_bus),
        .senoide(v_gen),
        .cuantificacion(cuantificacion),
        .autoshunt_value(v_shunt_effective_authosunt),
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

            noise_q16_2 = $dist_normal(seed_adc2_noise, 0, int'(ADC3_NOISE_SIGMA_LSB * 65536.0));
            noise_lsb_2 = (noise_q16_2 >= 0) ? ((noise_q16_2 + 32768) / 65536) : -(((-noise_q16_2) + 32768) / 65536);
            code_noisy_2 = code_raw_2 + noise_lsb_2;
            if (code_noisy_2 > 8191)
                code_noisy_2 = 8191;
            else if (code_noisy_2 < -8192)
                code_noisy_2 = -8192;

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

    initial begin
        int idx_k_real;

        r_cont_base_medida = R_CONT_MIN;
        r_cont_delta_barrido = 0.0;
        r_cont_instant = r_cont_base_medida;
        r_c1 = r_cont_base_medida;
        r_c2 = r_cont_base_medida;
        cp_val = 10e-12;
        r_c1_base_medida = r_c1;
        cp_base_medida = cp_val;
        rext_instant = R_ext;
        rint_instant = R_int;
        c_mem_instant = C_mem;
        t_inicio_medida_s = 0.0;
        medida = 0;
        start = 0;
        autoshunt = activar_autoshunt;
        cuantificacion = 1'b1;
        areset_n = 1'b1;
        repeat (3) @(negedge clk125);
        areset_n = 1'b0;
        repeat (3) @(negedge clk125);
        areset_n = 1'b1;
        repeat (3) @(negedge clk125);

        idx_k_real = MEDIDA_OBJETIVO;
        medida = idx_k_real;
        seed_adc3_noise = seeds_base[idx_k_real];
        seed_adc1_noise = seeds_base[idx_k_real] + 1000;
        seed_adc2_noise = seeds_base[idx_k_real] + 2000;
        r_cont_base_medida = R_CONT_MIN + $urandom_range(0, int'(R_CONT_RANGO_MEDIDA));
        r_cont_instant = r_cont_base_medida;
        k_degradacion = real'((idx_k_real + 1.0) / numero_medidas);
        r_c1_base_medida = 1000.0 + $urandom_range(0, 4000);
        cp_base_medida = 10e-12 + ($urandom_range(0, 190) * 1e-12);
        r_c1 = r_c1_base_medida;
        cp_val = cp_base_medida;
        t_inicio_medida_s = $realtime * 1e-9;
        rext_instant = R_ext * (1.0 - (0.5 * k_degradacion));
        rint_instant = R_int * (1.0 - (0.2 * k_degradacion));
        c_mem_instant = C_mem * (1.0 / (1.0 + 5.0 * k_degradacion));
        start = 1;
        @(negedge clk125);
        start = 0;
        @(posedge fin);
        #1000ns;

        $display("\nSimulacion parcial finalizada. Procesando datos en Python...");
        procesar_dataframe();
        $finish;
    end

    initial begin
        configurar_metadata_csv(CSV_FLUJO, CSV_SIMULADOR, CSV_CONFIGURACION, CSV_RUN_ID);
        inicializar_tiempos();
        clk125 = 1'b0;
        forever #((DT/2)*1s) clk125 = ~clk125;
    end

    always @(incrementado) begin
        real t_local_s;
        real micro_presion;

        f_actual = (real'(incrementado) / 4294967296.0) * 125000000.0;
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
            correr_punto(f_actual);
            cola_frecuencias.push_front(f_actual);
            guardar_dato(1, medida, f_actual, mag_z_4p, fase_z_4p, 0.0, 0.0, 0.0, 0.0, $realtime, $realtime * NS_TO_S);
            guardar_dato(2, medida, f_actual, z_bio_mag, z_bio_fase, 0.0, 0.0, 0.0, 0.0, $realtime, $realtime * NS_TO_S);
        end
    end

    always @(posedge clk125) begin
        real fases;
        real fasesa, fasesb;
        real fases_post;
        real modulo_post;
        real modulo_a, modulo_b;
        real cola_modulo[$];
        real cola_fase[$];
        real frecuencia_almacenada;
        real shunt_efectivo;

        if (VALID_M) begin
            shunt_efectivo = cola_shunt_effective_authosunt.pop_back();
            modulo_post = (real'(MODULO) * shunt_efectivo / real'(1 << numero_decimales));
            modulo_a = real'(MODULOA);
            modulo_b = real'(MODULOB);
            if (VERBOSE)
                $display("Modulos obtenidos metodo 4p correlacion: %9.2f Hz, MODULO: %9.2f, MODULOA: %9.2f, MODULOB: %9.2f", f_actual, modulo_post, modulo_a, modulo_b);
            error_mag_4p_corr = (modulo_post > z_bio_mag) ? ((modulo_post - z_bio_mag) / z_bio_mag) * 100.0 : ((z_bio_mag - modulo_post) / z_bio_mag) * 100.0;
            if (VERBOSE)
                $display("Error de magnitud metodo 4p correlacion: %5.2f%%", error_mag_4p_corr);
            cola_modulo.push_front(modulo_post);
        end

        if (VALID_P) begin
            fases = real'(PHASE) / 8.0;
            fasesa = real'(PHASEA) / 8.0;
            fasesb = real'(PHASEB) / 8.0;
            if (fases <= -90.0)
                fases_post = fases + 180.0;
            else if (fases >= 90.0)
                fases_post = fases - 180.0;
            else
                fases_post = fases;
            if (VERBOSE)
                $display("Fases obtenidas metodo 4p correlacion: %9.2f Hz, Fase: %9.2f grados, FaseA: %9.2f grados, FaseB: %9.2f grados", f_actual, fases_post, fasesa, fasesb);
            error_fase_4p_corr = (fases_post > z_bio_fase) ? (fases_post - z_bio_fase) : (z_bio_fase - fases_post);
            if (VERBOSE)
                $display("Error de fase metodo 4p correlacion: %9.2f grados", error_fase_4p_corr);
            cola_fase.push_front(fases_post);
        end

        if (cola_modulo.size() > 0 && cola_fase.size() > 0) begin
            modulo_4p_corr = cola_modulo.pop_back();
            fase_4p_corr = cola_fase.pop_back();
            frecuencia_almacenada = cola_frecuencias.pop_back();
            guardar_dato(0, medida, frecuencia_almacenada, modulo_4p_corr, fase_4p_corr, modulo_a, fasesa, modulo_b, fasesb, $realtime, $realtime * NS_TO_S);
        end
    end

    always @(posedge clk125) begin
        fase_acc += 2.0 * PI * f_actual * DT;
        if (fase_acc >= 2.0*PI)
            fase_acc -= 2.0*PI;
        v_gen = 1.0 * $sin(fase_acc);
    end

    task automatic correr_punto(real freq);
        real t_muestreo;
        begin
            t_muestreo = (3.0 / freq) / N;
            f_actual = freq;
            cola_shunt_effective_authosunt.push_front(v_shunt_effective_authosunt);
            #((2.0 / freq) * 1s);

            for (int i = 0; i < N; i++) begin
                if (cuantificacion) begin
                    adc1_v_p_4p[i] = real'(signed'(adc1_data_4p_noisy)) / ADC_SCALE;
                    adc2_v_n_4p[i] = real'(signed'(adc2_data_4p_noisy)) / ADC_SCALE;
                    adc3_v_sh_4p[i] = real'(signed'(adc3_data_4p_noisy)) / ADC_SCALE;
                end else begin
                    adc1_v_p_4p[i] = v_a_4p;
                    adc2_v_n_4p[i] = v_b_4p;
                    adc3_v_sh_4p[i] = v_c_4p;
                end
                #(t_muestreo * 1s);
            end

            for (int i = 0; i < N; i++) begin
                v_diff_4p[i] = adc1_v_p_4p[i] - adc2_v_n_4p[i];
                i_calc_4p[i] = adc3_v_sh_4p[i] / v_shunt_effective_authosunt;
            end

            app_fft_radix2_dpi(N, v_diff_4p, v_im_z, V_fft_re_4p, V_fft_im_4p);
            app_fft_radix2_dpi(N, i_calc_4p, v_im_z, I_fft_re_4p, I_fft_im_4p);
            den_4p = (I_fft_re_4p[3]**2 + I_fft_im_4p[3]**2);
            mag_z_4p = $sqrt((V_fft_re_4p[3]**2 + V_fft_im_4p[3]**2) / den_4p);
            fase_z_4p = normalizar_fase_deg((
                $atan2(V_fft_im_4p[3], V_fft_re_4p[3]) -
                $atan2(I_fft_im_4p[3], I_fft_re_4p[3])
            ) * (180.0 / PI));
            if (VERBOSE)
                $display("FFT 4P bin3 @ %9.2f Hz -> V=(%0.6f,%0.6f) I=(%0.6f,%0.6f)", freq, V_fft_re_4p[3], V_fft_im_4p[3], I_fft_re_4p[3], I_fft_im_4p[3]);

            omega = 2.0 * PI * freq;
            xc = 1.0 / (omega * c_mem_instant);
            den_bio = (rext_instant + rint_instant)**2 + xc**2;
            z_bio_re = (rext_instant * (rint_instant * (rext_instant + rint_instant) + xc**2)) / den_bio;
            z_bio_im = (rext_instant**2 * -(xc)) / den_bio;
            z_bio_mag = $sqrt(z_bio_re**2 + z_bio_im**2);
            z_bio_fase = $atan2(z_bio_im, z_bio_re) * (180.0 / PI);

            error_mag_4p = (mag_z_4p > z_bio_mag) ? ((mag_z_4p - z_bio_mag) / z_bio_mag) * 100.0 : ((z_bio_mag - mag_z_4p) / z_bio_mag) * 100.0;
            error_fase_4p = (fase_z_4p > z_bio_fase) ? (fase_z_4p - z_bio_fase) : (z_bio_fase - fase_z_4p);

            if (VERBOSE) begin
                $display("F:%9.0f Hz | R_cont:%4.0f Ohm", freq, r_cont_instant);
                $display("  Z_Golden -> Mag: %8.1f Ohm | Fase: %6.2f deg", z_bio_mag, z_bio_fase);
                $display("  Z_4P     -> Mag: %8.1f Ohm | Fase: %6.2f deg | Err_M: %5.2f%% | Err_F: %5.2f deg", mag_z_4p, fase_z_4p, error_mag_4p, error_fase_4p);
                $display("");
            end
        end
    endtask
endmodule