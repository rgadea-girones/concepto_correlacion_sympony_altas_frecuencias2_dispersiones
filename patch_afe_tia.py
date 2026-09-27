import os

def patch_bioz_block():
    filepath = 'src/bioz_block_portable_nettype_ina.sv'
    print(f'Parcheando {filepath}...')
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Añadir el parámetro C_f
    old_params = '''    // --- PARÁMETROS DEL ADC DE CORRIENTE (Red Pitaya en Shunt) ---
    parameter real C_in_adc = 10.0e-12, // Capacitancia de entrada del ADC
    parameter real R_in_adc = 1.0e6,    // Resistencia de entrada del ADC
    parameter real C_leak   = 10.0e-12, // Fugas capacitivas del cable en shunt
    parameter real Mutual_L = 2.5e-7,   // Inductancia mutua
    parameter real INA_GAIN = 1.0      // Ganancia del INA'''
    
    new_params = '''    // --- PARÁMETROS DEL ADC DE CORRIENTE (Red Pitaya en Shunt) ---
    parameter real C_in_adc = 10.0e-12, // Capacitancia de entrada del ADC
    parameter real R_in_adc = 1.0e6,    // Resistencia de entrada del ADC
    parameter real C_leak   = 10.0e-12, // Fugas capacitivas del cable en shunt
    parameter real Mutual_L = 2.5e-7,   // Inductancia mutua
    parameter real INA_GAIN = 1.0,      // Ganancia del INA
    parameter real C_f      = 2.0e-12   // Capacitancia de compensación del TIA'''

    # 2. Modificar f_derivs para la tierra virtual del TIA
    old_f_derivs = '''        // Dinámica del lazo de inyección principal (Force)
        real r_par = (safe_rint * safe_rext) / (safe_rint + safe_rext);
        real v_th  = vm * (safe_rext / (safe_rint + safe_rext));
        
        real i_tot = (v_gen - vp1 - vp2 - v_th - vc) / r_par;
        real v_tej = v_th + (i_tot * r_par);
        
        dvm  = ((v_tej - vm) / safe_rint) / safe_cmem;
        dvp1 = (i_tot - (vp1 / safe_rs1)) / safe_cp1;
        dvp2 = (i_tot - (vp2 / safe_rs2)) / safe_cp2;

        // El Shunt está en paralelo con R_in_adc y la capacitancia equivalente total C_leak + C_in_adc
        begin
            real r_sh_eq = (safe_rshunt * safe_Rin_adc) / (safe_rshunt + safe_Rin_adc);
            real c_sh_eq = safe_cleak + safe_Cin_adc;
            dvc  = (i_tot - (vc / r_sh_eq)) / c_sh_eq;
        end'''

    new_f_derivs = '''        // Dinámica del lazo de inyección principal (Force)
        // Force- es tierra virtual (0V), por lo que vc (salida del TIA) no se resta del lazo de inyección
        real r_par = (safe_rint * safe_rext) / (safe_rint + safe_rext);
        real v_th  = vm * (safe_rext / (safe_rint + safe_rext));
        
        real i_tot = (v_gen - vp1 - vp2 - v_th) / r_par;
        real v_tej = v_th + (i_tot * r_par);
        
        dvm  = ((v_tej - vm) / safe_rint) / safe_cmem;
        dvp1 = (i_tot - (vp1 / safe_rs1)) / safe_cp1;
        dvp2 = (i_tot - (vp2 / safe_rs2)) / safe_cp2;

        // El TIA activo (AD844) convierte la corriente i_tot a voltaje inversamente (Zf = Rshunt || Cf)
        begin
            real safe_Cf = (C_f < 1e-15) ? 1e-15 : C_f;
            dvc  = (-i_tot - (vc / safe_rshunt)) / safe_Cf;
        end'''

    # 3. Modificar la asignación de salidas para Sense- (Force- es 0V)
    old_output_comb = '''        v_B_out = v_c_s + v_cp2_s;
        v_in_s2_out = v_B_out - (Mutual_L * di_tot_dt);
        // Voltaje a la entrada negativa del INA
        v_ina_in2 = (u2_s + safe_cp2 * v_in_s2_out) / (safe_Cin_ina + safe_cp2); 

        // Restamos en analógico (salida del INA amplificada por INA_GAIN)
        v_ina_out = INA_GAIN * (v_ina_in1 - v_ina_in2);
    end

    assign node_adc1 = '{v: v_ina_out, i: 0.0}; 
    assign node_adc2 = '{v: v_c_s,     i: -i_total}; // El shunt, de donde medimos corriente'''

    new_output_comb = '''        v_B_out = 0.0 + v_cp2_s; // Force- es tierra virtual (0V)
        v_in_s2_out = v_B_out - (Mutual_L * di_tot_dt);
        // Voltaje a la entrada negativa del INA
        v_ina_in2 = (u2_s + safe_cp2 * v_in_s2_out) / (safe_Cin_ina + safe_cp2); 

        // Restamos en analógico (salida del INA amplificada por INA_GAIN)
        v_ina_out = INA_GAIN * (v_ina_in1 - v_ina_in2);
    end

    assign node_adc1 = '{v: v_ina_out, i: 0.0}; 
    assign node_adc2 = '{v: v_c_s,     i: 0.0}; // Salida activa del TIA (impedancia de salida de 0 ohmios)'''

    content = content.replace(old_params, new_params)
    content = content.replace(old_f_derivs, new_f_derivs)
    content = content.replace(old_output_comb, new_output_comb)

    with open(filepath, 'w') as f:
        f.write(content)
    print(f'{filepath} parcheado.\n')


def patch_top_level():
    filepath = 'src/top_bioimpedancia_circuito_medida_portable_nettype_ina.sv'
    print(f'Parcheando {filepath}...')
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Cambiar parámetros por defecto y añadir C_f
    old_params = '''    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0,
    // --- PARÁMETROS DEL INA (Sense+ y Sense-) ---'''
    
    new_params = '''    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 10000.0, // 10 kOhm por defecto para el TIA
    // --- PARÁMETROS DEL TIA ACTIVO ---
    parameter real C_f        = 2.0e-12, // 2 pF de compensación
    // --- PARÁMETROS DEL INA (Sense+ y Sense-) ---'''

    # 2. Propagar C_f a la instancia bioz_inst
    old_instance = '''    bioz_block_portable_nettype_ina #(
        .DT(8e-9),
        .C_in_ina(C_in_ina),
        .R_in_ina(R_in_ina),
        .C_in_adc(C_in_adc),
        .R_in_adc(R_in_adc),
        .C_leak(C_leak),
        .Mutual_L(Mutual_L),
        .INA_GAIN(INA_GAIN)
    ) bioz_inst ('''

    new_instance = '''    bioz_block_portable_nettype_ina #(
        .DT(8e-9),
        .C_in_ina(C_in_ina),
        .R_in_ina(R_in_ina),
        .C_in_adc(C_in_adc),
        .R_in_adc(R_in_adc),
        .C_leak(C_leak),
        .Mutual_L(Mutual_L),
        .INA_GAIN(INA_GAIN),
        .C_f(C_f)
    ) bioz_inst ('''

    content = content.replace(old_params, new_params)
    content = content.replace(old_instance, new_instance)

    with open(filepath, 'w') as f:
        f.write(content)
    print(f'{filepath} parcheado.\n')


def patch_testbench():
    filepath = 'src/tb_correlacion_ina_2adcs.sv'
    print(f'Parcheando {filepath}...')
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Añadir parámetro C_f y cambiar R_shunt
    old_phys_params = '''    localparam real PHYS_R_IN = 1.0e6;      // Resistencia interna Red Pitaya real
    localparam real PHYS_C_IN = 10.0e-12;   // Capacitancia pura del ADC real
    localparam real PHYS_C_LEAK = 10.0e-12; // Fugas a tierra de los cables reales'''

    new_phys_params = '''    localparam real PHYS_R_IN = 1.0e6;      // Resistencia interna Red Pitaya real
    localparam real PHYS_C_IN = 10.0e-12;   // Capacitancia pura del ADC real
    localparam real PHYS_C_LEAK = 10.0e-12; // Fugas a tierra de los cables reales
    localparam real PHYS_C_F = 2.0e-12;     // Capacitancia de compensación del TIA'''

    old_inv_params = '''    localparam real INV_R_IN_EQ     = PHYS_R_IN;     // Impedancia del ADC (Red Pitaya)
    localparam real INV_C_IN_EQ     = PHYS_C_IN;     
    localparam real INV_C_LEAK_EQ   = PHYS_C_LEAK;   
    localparam real INV_R_INA       = 1.0e12;        // Impedancia de entrada del INA
    localparam real INV_C_INA       = 3.0e-12;// Ej. con error: 40.0e-12;'''

    new_inv_params = '''    localparam real INV_R_IN_EQ     = PHYS_R_IN;     // Impedancia del ADC (Red Pitaya)
    localparam real INV_C_IN_EQ     = PHYS_C_IN;     
    localparam real INV_C_LEAK_EQ   = PHYS_C_LEAK;   
    localparam real INV_R_INA       = 1.0e12;        // Impedancia de entrada del INA
    localparam real INV_C_INA       = 3.0e-12;// Ej. con error: 40.0e-12;
    localparam real INV_C_F         = PHYS_C_F;'''

    # 2. Modificar la inicialización de variables para usar R_shunt = 10k en el bucle
    old_init_shunt = '''            v_shunt_effective_authosunt = 2000.0; // Valor inicial del shunt para el experimento'''
    new_init_shunt = '''            v_shunt_effective_authosunt = 10000.0; // 10 kOhm fijo para el TIA'''

    old_case_shunt = '''        case (estado_pasos_cero)
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
        endcase'''

    new_case_shunt = '''        // Para el TIA, la resistencia de realimentación es fija de 10 kOhm en todos los estados
        case (estado_pasos_cero)
          3'b000:begin 
            v_shunt_effective_authosunt = 10000.0; 
            numero_ciclos = 10'd0;
            numero_anchura = 10'd1;
            numero_decimales = 4'd9; 
            end
          3'b001:begin 
            v_shunt_effective_authosunt = 10000.0; 
            numero_ciclos = 10'd1;
            numero_anchura = 10'd1;
            numero_decimales = 4'd8; 
            end
          3'b010: begin 
            v_shunt_effective_authosunt = 10000.0; 
            numero_ciclos = 10'd4 ;
            numero_anchura = 10'd2;
            numero_decimales = 4'd6; 
            end
          3'b011: begin 
            v_shunt_effective_authosunt = 10000.0; 
            numero_ciclos = 10'd5;
            numero_anchura = 10'd2;
            numero_decimales = 4'd5; 
            end
          default: begin 
            v_shunt_effective_authosunt = 10000.0; 
            numero_ciclos = 10'd64;
            numero_anchura = 10'd2;
            numero_decimales = 4'd4; 
            end
        endcase'''

    # 3. Modificar la instancia del DUT analog_circuit para pasar el parámetro C_f
    old_dut_instance = '''    top_bioimpedancia_circuito_medida_portable_nettype_ina #(
      .C_in_ina(INV_C_INA),
      .R_in_ina(INV_R_INA),
      .C_in_adc(PHYS_C_IN),
      .R_in_adc(PHYS_R_IN),
      .C_leak(PHYS_C_LEAK),
      .Mutual_L(PHYS_MUTUAL_L),
      .INA_GAIN(1.0)
    ) analog_circuit ('''

    new_dut_instance = '''    top_bioimpedancia_circuito_medida_portable_nettype_ina #(
      .C_in_ina(INV_C_INA),
      .R_in_ina(INV_R_INA),
      .C_in_adc(PHYS_C_IN),
      .R_in_adc(PHYS_R_IN),
      .C_leak(PHYS_C_LEAK),
      .Mutual_L(PHYS_MUTUAL_L),
      .INA_GAIN(1.0),
      .C_f(INV_C_F)
    ) analog_circuit ('''

    # 4. Inversión de fase del TIA: Añadir señal inv y conectar en el Control Path
    old_control_path = '''        .ADC_A(adc1_data_4p_noisy),
        .ADC_B(14'sd0),
        .ADC_C(adc2_data_4p_noisy),'''

    new_control_path = '''        .ADC_A(adc1_data_4p_noisy),
        .ADC_B(14'sd0),
        .ADC_C(adc2_data_4p_noisy_inv),'''

    # Insertar la declaración de la señal invertida justo antes de instanciar Control_path
    old_instantiation_block = '''    // --- INSTANCIACIÓN DE LA ELECTRÓNICA DIGITAL (CORRELADORES + DDS) ---
    Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p_mejorado_quiza_final control_path_4p_inst ('''

    new_instantiation_block = '''    // Invertir el voltaje del TIA para compensar la ganancia negativa del amplificador operacional
    wire signed [13:0] adc2_data_4p_noisy_inv = -signed'(adc2_data_4p_noisy);

    // --- INSTANCIACIÓN DE LA ELECTRÓNICA DIGITAL (CORRELADORES + DDS) ---
    Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p_mejorado_quiza_final control_path_4p_inst ('''

    # 5. Ecuaciones matemáticas del testbench
    old_math_inversion = '''                // 2.3 Impedancia en el Nodo Shunt
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
                
                // den_z = DenC_re * DenC_re + DenC_im * DenC_im;
                // Fc_re = (NumC_re * DenC_re + NumC_im * DenC_im) / den_z;
                // Fc_im = (NumC_im * DenC_re - NumC_re * DenC_im) / den_z;
                Fc_re = 1.0;
                Fc_im = 0.0;

                // 2.5b Multiplicador de Derivación del Shunt (Ksh)
                Ksh_re = 1.0 + (shunt_efectivo / INV_R_IN_EQ);
                Ksh_im = w * shunt_efectivo * C_sh_eq;'''

    new_math_inversion = '''                // 2.3 Compensación del lazo de realimentación del TIA: Zf = R_shunt || C_f
                // Fi_real = R_shunt / Zf = 1 + j * w * R_shunt * C_f
                Fi_re = 1.0;
                Fi_im = w * shunt_efectivo * INV_C_F;

                // 2.4 Factor de Corrección de Voltaje (Fv)
                den_z = Zin_re * Zin_re + Zin_im * Zin_im;
                Zs_over_Zin_re = (Zs_re * Zin_re + Zs_im * Zin_im) / den_z;
                Zs_over_Zin_im = (Zs_im * Zin_re - Zs_re * Zin_im) / den_z;
                Fv_re = 1.0 + Zs_over_Zin_re;
                Fv_im = Zs_over_Zin_im;

                // 2.5 Factor de Corrección de Corriente (Fc)
                // Se anula porque el voltímetro está desacoplado del lazo de inyección principal
                Fc_re = 1.0;
                Fc_im = 0.0;

                // 2.5b Multiplicador de Derivación del Shunt (Ksh)
                // Se anula porque el ADC2 lee la salida del TIA activo de baja impedancia
                Ksh_re = 1.0;
                Ksh_im = 0.0;'''

    content = content.replace(old_phys_params, new_phys_params)
    content = content.replace(old_inv_params, new_inv_params)
    content = content.replace(old_init_shunt, new_init_shunt)
    content = content.replace(old_case_shunt, new_case_shunt)
    content = content.replace(old_dut_instance, new_dut_instance)
    content = content.replace(old_control_path, new_control_path)
    content = content.replace(old_instantiation_block, new_instantiation_block)
    content = content.replace(old_math_inversion, new_math_inversion)

    with open(filepath, 'w') as f:
        f.write(content)
    print(f'{filepath} parcheado.\n')

# Ejecutar los parches
patch_bioz_block()
patch_top_level()
patch_testbench()
print('¡Todos los archivos del nuevo AFE con TIA han sido actualizados!')
