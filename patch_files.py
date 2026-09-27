import os

def patch_tb():
    with open('/home/eda/concepto_correlacion_sympony_altas_frecuencias2_ungravity/src/tb_correlacion_ina_2adcs.sv', 'r') as f:
        content = f.read()

    # chunk 1
    content = content.replace(
    """    localparam real INV_R_IN_EQ     = PHYS_R_IN;     // Ej. con error: 1.2e6;
    localparam real INV_C_IN_EQ     = PHYS_C_IN;     // Ej. con error: 12e-12;
    localparam real INV_C_LEAK_EQ   = PHYS_C_LEAK;   """,
    """    localparam real INV_R_IN_EQ     = PHYS_R_IN;     // Impedancia del ADC (Red Pitaya)
    localparam real INV_C_IN_EQ     = PHYS_C_IN;     
    localparam real INV_C_LEAK_EQ   = PHYS_C_LEAK;   
    localparam real INV_R_INA       = 1.0e12;        // Impedancia de entrada del INA
    localparam real INV_C_INA       = 3.0e-12;""")

    # chunk 2
    content = content.replace(
    """    logic [13:0] adc3_data_4p;  """,
    """    logic [13:0] adc3_data_4p = 14'd0;  """)

    # chunk 3
    content = content.replace(
    """`ifdef USE_VAMS_MIXED
    top_bioimpedancia_circuito_medida_portable_mixed #(  .C_in(PHYS_C_IN),.R_in(PHYS_R_IN),.C_leak(PHYS_C_LEAK),.Mutual_L(PHYS_MUTUAL_L)) analog_circuit  (
`else
  top_bioimpedancia_circuito_medida_portable_nettype #(  .C_in(PHYS_C_IN),.R_in(PHYS_R_IN),.C_leak(PHYS_C_LEAK),.Mutual_L(PHYS_MUTUAL_L)) analog_circuit  (
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
    );  """,
    """    top_bioimpedancia_circuito_medida_portable_nettype_ina #(
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
    );  """)

    # chunk 4
    content = content.replace(
    """        .ADC_A(adc1_data_4p_noisy),
        .ADC_B(adc2_data_4p_noisy),
        .ADC_C(adc3_data_4p_noisy),""",
    """        .ADC_A(adc1_data_4p_noisy),
        .ADC_B(14'sd0),
        .ADC_C(adc2_data_4p_noisy),""")

    # chunk 5
    content = content.replace(
    """                // 2.2 Impedancia de Entrada del ADC: Zin = R_in || C_in
                // <<< CORRECCIÓN FÍSICA: En el nodo Sense, el RK4 SÓLO usa INV_C_IN_EQ (10pF), 
                // no el C_leak del cable.
                wRC = w * INV_R_IN_EQ * INV_C_IN_EQ; 
                den_z = 1.0 + wRC * wRC;
                Zin_re = INV_R_IN_EQ / den_z;
                Zin_im = -(w * INV_R_IN_EQ * INV_R_IN_EQ * INV_C_IN_EQ) / den_z; """,
    """                // 2.2 Impedancia de Entrada del INA: Zin = R_ina || C_ina
                wRC = w * INV_R_INA * INV_C_INA; 
                den_z = 1.0 + wRC * wRC;
                Zin_re = INV_R_INA / den_z;
                Zin_im = -(w * INV_R_INA * INV_R_INA * INV_C_INA) / den_z; """)

    with open('/home/eda/concepto_correlacion_sympony_altas_frecuencias2_ungravity/src/tb_correlacion_ina_2adcs.sv', 'w') as f:
        f.write(content)
    print("Testbench patched successfully!")

def patch_compilation():
    with open('/home/eda/concepto_correlacion_sympony_altas_frecuencias2_ungravity/sim/qrun_experimento_ina_2adcs.f', 'r') as f:
        f_content = f.read()

    f_content = f_content.replace('top_bioimpedancia_circuito_medida_portable_nettype.sv', 'top_bioimpedancia_circuito_medida_portable_nettype_ina.sv')
    f_content = f_content.replace('bioz_block_portable_nettype.sv', 'bioz_block_portable_nettype_ina.sv')
    f_content = f_content.replace('tb_correlacion_vs_calibrado_vs_golden.sv', 'tb_correlacion_ina_2adcs.sv')

    with open('/home/eda/concepto_correlacion_sympony_altas_frecuencias2_ungravity/sim/qrun_experimento_ina_2adcs.f', 'w') as f:
        f.write(f_content)

    print("Compilation file patched successfully!")

if __name__ == '__main__':
    patch_tb()
    patch_compilation()
