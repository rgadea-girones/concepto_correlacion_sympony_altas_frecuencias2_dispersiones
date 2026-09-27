    import electrical_pkg::*;
module top_bioimpedancia_circuito_medida
(input logic clk,
input logic [13:0] dds_bus, // Bus de datos para el DAC (ej. salida de un DDS)
output logic [13:0] adc1_data_4p, // Nodo A
output logic [13:0] adc2_data_4p, // Nodo B
output logic [13:0] adc3_data_4p,  // Nodo C
output logic [13:0] adc1_data_3p, // Nodo A
output logic [13:0] adc2_data_3p // Nodo B_C


);
 

    
    
    // Buses digitales que van a tu lógica de post-procesamiento
    logic [13:0] adc1_data, adc2_data, adc3_data;
    //==============================================================================
    //  modelo 4 puntas
    //============================================================================== 
    w_elec v_dac_val_4p, v_dac_val_3p;
    // 1. Instancia del Top Analógico con nettypes
    // (Este contiene node_A, node_B, node_C internos)
    analog_top_4p analog_circuit1 (
        .v_dac_val(v_dac_val_4p),
        .clk(clk)
    );

    // 2. Instancia de los 3 ADCs (Entradas de la Red Pitaya)
    // ADC1 mide el Nodo A (antes de la bioimpedancia)
    rp_adc_model_nettype adc_1 (
        .ana_node(analog_circuit1.node_A), 
        .clk(clk), 
        .digital_out(adc1_data_4p)
    );

    // ADC2 mide el Nodo B (después de la bioimpedancia)
    rp_adc_model_nettype adc_2 (
        .ana_node(analog_circuit1.node_B), 
        .clk(clk), 
        .digital_out(adc2_data_4p)
    );

    // ADC3 mide el Nodo C (sobre la resistencia SHUNT)
    rp_adc_model_nettype adc_3 (
        .ana_node(analog_circuit1.node_C), 
        .clk(clk), 
        .digital_out(adc3_data_4p)
    );
    
    rp_dac_model_nettype dac_model1 (
        .data_i(dds_bus), 
        .clk(clk), 
        .node_out(v_dac_val_4p) // Conecta directamente al nodo E del circuito analógico
    );

   //==============================================================================
    //  modelo 3 puntas
    //==============================================================================

    // 1. Instancia del Top Analógico con nettypes
    // (Este contiene node_A, node_B_C internos)
    analog_top_3p analog_circuit2 (
        .v_dac_val(v_dac_val_3p ),
        .clk(clk)
    );

    // 2. Instancia de los 2 ADCs (Entradas de la Red Pitaya)
    // ADC1 mide el Nodo A (antes de la bioimpedancia)
    rp_adc_model_nettype adc_1_3p (
        .ana_node(analog_circuit2.node_A), 
        .clk(clk), 
        .digital_out(adc1_data_3p)
    );

    // ADC2 mide el Nodo B_C (después de la bioimpedancia y contacto)
    rp_adc_model_nettype adc_2_3p (
        .ana_node(analog_circuit2.node_B_C), 
        .clk(clk), 
        .digital_out(adc2_data_3p)
    );

   rp_dac_model_nettype dac_model2 (
        .data_i(dds_bus), 
        .clk(clk), 
        .node_out(v_dac_val_3p) // Conecta directamente al nodo E del circuito analógico
    );


endmodule
