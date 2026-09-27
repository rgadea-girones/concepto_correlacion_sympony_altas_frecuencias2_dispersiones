import electrical_pkg::*;

module top_bioimpedancia_circuito_medida_portable_to_fpga_ina 
#(
    parameter real R_contact1 = 500.0, 
    parameter real R_contact2 = 500.0, 
    parameter real C_p1       = 1.0e-10,
    parameter real C_p2       = 1.0e-10,    
    parameter real R_ext      = 20000.0, 
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 10000.0, // Cambiado por defecto a 10 kOhm
    // --- PARÁMETROS DEL INA (Sense+ y Sense-) ---
    parameter real C_in_ina   = 3.0e-12,
    parameter real R_in_ina   = 1.0e12,
    // --- PARÁMETROS DEL ADC DE CORRIENTE (Red Pitaya) ---
    parameter real C_in_adc   = 10.0e-12,
    parameter real R_in_adc   = 1.0e6,
    parameter real C_leak     = 10.0e-12,
    parameter real Mutual_L   = 2.5e-7,
    parameter real INA_GAIN   = 1.0,
    // --- NUEVOS PARÁMETROS MODULAR AFE ---
    parameter real C_f        = 2.0e-12,
    parameter real C_dc       = 10.0e-6,
    parameter real R_in_tia_inv = 50.0
)
(   
    input logic clk,
    input logic [13:0] dds_bus, // Bus de 14 bits para el DAC
    input logic cuantificacion, // Control para cuantificación
    input real senoide,
    input real autoshunt_value, // Valor de resistencia efectiva del autoshunt
    input real r_f1, r_f2,      // Resistencias de contacto Force
    input real r_s1, r_s2,      // Resistencias de contacto Sense
    input real c_f1, c_f2,      // Capacitancias parásitas Force
    input real c_s1, c_s2,      // Capacitancias parásitas Sense
    input real rext_instant,    
    input real rint_instant,    
    input real c_mem_instant,   
    
    output real v_a_4p, // Nodo A (salida INA) expuesto para testbench
    output real v_b_4p, // Nodo B (voltaje del shunt / salida TIA) expuesto para testbench
    
    output logic [13:0] adc1_data_4p, // Tensión INA digitalizada
    output logic [13:0] adc2_data_4p  // Corriente Shunt/TIA digitalizada
);

    // --- NODOS NETTYPE (w_elec) ---
    w_elec node_dac_out;
    w_elec node_adc1;
    w_elec node_adc2;
    w_elec node_adc3; // No se usa pero se declara por si acaso

    real v_dac_4p;
    w_elec v_dac_aplicado; // Variable nettype para inyectar al circuito
    
    // --- GENERACIÓN (DAC) ---
    rp_dac_model_nettype dac4p (
        .data_i(dds_bus), 
        .clk(clk), 
        .R_ext(R_ext),
        .R_contact1(R_contact1),
        .node_out(node_dac_out) // Salida del DAC de 14 bits mapeada a w_elec
    );

    always_comb begin
        if (cuantificacion) begin
            v_dac_4p = node_dac_out.v; 
        end else begin
            v_dac_4p = senoide; 
        end
    end

    assign v_dac_aplicado = '{v: v_dac_4p, i: 0.0}; 

    // --- INSTANCIA DEL BLOQUE RK4 CON INA Y 2 ADCs ---
    bioz_block_portable_to_fpga_ina #(
        .DT(8e-9),
        .C_in_ina(C_in_ina),
        .R_in_ina(R_in_ina),
        .C_in_adc(C_in_adc),
        .R_in_adc(R_in_adc),
        .C_leak(C_leak),
        .Mutual_L(Mutual_L),
        .INA_GAIN(INA_GAIN),
        .C_f(C_f),
        .C_dc(C_dc),
        .R_in_tia_inv(R_in_tia_inv)
    ) bioz_inst (
        .node_gen(v_dac_aplicado),
        .node_adc1(node_adc1),
        .node_adc2(node_adc2),
        .node_adc3(node_adc3),
        .r_f1(r_f1),
        .r_f2(r_f2),
        .r_s1(r_s1),
        .r_s2(r_s2),
        .c_f1(c_f1),
        .c_f2(c_f2),
        .c_s1(c_s1),
        .c_s2(c_s2),
        .r_shunt(autoshunt_value),
        .rext_instant(rext_instant),
        .rint_instant(rint_instant),
        .c_mem_instant(c_mem_instant),
        .clk(clk)
    );

    // --- EXTRACCION DE VARIABLES REALES PARA COMPATIBILIDAD CON BENCH ---
    assign v_a_4p = node_adc1.v; // Voltaje de salida del INA
    assign v_b_4p = node_adc2.v; // Voltaje de salida del TIA

    // --- CAPTURA (ADCs) ---
    rp_adc_model_nettype #(
        .R_IN(R_in_adc),
        .C_IN(C_in_adc)
    ) adc1_4p (.ana_node(node_adc1), .clk(clk), .digital_out(adc1_data_4p));

    rp_adc_model_nettype #(
        .R_IN(R_in_adc),
        .C_IN(C_in_adc)
    ) adc2_4p (.ana_node(node_adc2), .clk(clk), .digital_out(adc2_data_4p));

endmodule
