
module top_bioimpedancia_circuito_medida_portable
#(
        parameter real R_contact1 = 500.0, 
    parameter real R_contact2 = 500.0, 
    parameter real C_p1       = 1.0e-10,
    parameter real C_p2       = 1.0e-10,    
    parameter real R_ext      = 20000.0, 
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0
)
(input logic clk,
input logic [13:0] dds_bus,
input logic cuantificacion, // Control para activar/desactivar la cuantificación del ADC
input real senoide,
input real autoshunt_value, // Valor de resistencia efectiva del autoshunt, se puede ajustar para simular diferentes condiciones
input real r_cont_instant, // Ruido de contacto instantáneo, común para ambas técnicas
input real c_contact1, // Capacitancia parásita del electrodo 1
input real rext_instant, // Variación instantánea de R_ext (ruido)
input real rint_instant, // Variación instantánea de R_int (ruido
input real c_mem_instant, // Variación instantánea de C_mem (ruido)
output real v_a_4p, // Nodo A 4 puntas
output real v_b_4p, // Nodo B 4 puntas  
output real v_c_4p, // Nodo C 4 puntas
output real v_a_3p, // Nodo A 3 puntas  
output real v_bc_3p, // Nodo B_C 3 puntas
output logic [13:0] adc1_data_4p, // Nodo A
output logic [13:0] adc2_data_4p, // Nodo B
output logic [13:0] adc3_data_4p,  // Nodo C
output logic [13:0] adc1_data_3p, // Nodo A
output logic [13:0] adc2_data_3p // Nodo B_C



);
 

// Señales de interconexión en formato REAL (Compatibles con cualquier licencia)
    real v_dac_4p, v_dac_3p;
    real v_dac_4p_quant, v_dac_3p_quant; // Versiones cuantificadas de las señales DAC para simular el efecto del ADC
   // real v_a_4p, v_b_4p, v_c_4p;
   // real v_a_3p, v_bc_3p;

    // --- GENERACIÓN (DACs) ---
    rp_dac_model_portable dac4p (.data_i(dds_bus), .clk(clk), .node_out(v_dac_4p_quant));
    rp_dac_model_portable dac3p (.data_i(dds_bus), .clk(clk), .node_out(v_dac_3p_quant));

    always_comb begin
        // Si la cuantificación está activada, redondeamos el valor analógico al nivel más cercano representable por el ADC de 14 bits
        if (cuantificacion) begin
            v_dac_4p = v_dac_4p_quant;// Simula un DAC de 14 bits con rango de 0 a 16V
            v_dac_3p = v_dac_3p_quant;//$rtoi((v_dac_3p_quant / 16.0) * 16383.0) * (16.0 / 16383.0);
        end else begin
            v_dac_4p = senoide; // Si no hay cuantificación, usamos directamente la señal de entrada para simular un DAC ideal
            v_dac_3p = senoide;
        end
    end
    // --- MODELOS ANALÓGICOS (PORTABLES) ---
    analog_top_4p_portable  #(.R_contact1(R_contact1), .R_contact2(R_contact2), .R_ext(R_ext), .R_int(R_int), .C_mem(C_mem), .R_shunt(R_shunt),.C_p1(C_p1), .C_p2(C_p2)) analog_4p (
        .v_dac_val(v_dac_4p), .clk(clk), .autoshunt(autoshunt_value), .r_cont_instant(r_cont_instant),.c_contact1(c_contact1),
        .rext_instant(rext_instant), .rint_instant(rint_instant), .c_mem_instant(c_mem_instant),
        .v_node_A(v_a_4p), .v_node_B(v_b_4p), .v_node_C(v_c_4p)
    );

    analog_top_3p_portable #(.R_contact1(R_contact1), .R_contact2(R_contact2), .R_ext(R_ext), .R_int(R_int), .C_mem(C_mem), .R_shunt(R_shunt), .C_p1(C_p1), .C_p2(C_p2)) analog_3p (
        .v_dac_val(v_dac_3p), .clk(clk), .autoshunt(autoshunt_value), .r_cont_instant(r_cont_instant), .c_contact1(c_contact1),
        .rext_instant(rext_instant), .rint_instant(rint_instant), .c_mem_instant(c_mem_instant),
        .v_node_A(v_a_3p), .v_node_BC(v_bc_3p)
    );

    // --- CAPTURA (ADCs) ---
    // 4 Puntas
    rp_adc_model_portable adc1_4p (.ana_node(v_a_4p), .clk(clk), .digital_out(adc1_data_4p));
    rp_adc_model_portable adc2_4p (.ana_node(v_b_4p), .clk(clk), .digital_out(adc2_data_4p));
    rp_adc_model_portable adc3_4p (.ana_node(v_c_4p), .clk(clk), .digital_out(adc3_data_4p));

    // 3 Puntas
    rp_adc_model_portable adc1_3p (.ana_node(v_a_3p), .clk(clk), .digital_out(adc1_data_3p));
    rp_adc_model_portable adc2_3p (.ana_node(v_bc_3p), .clk(clk), .digital_out(adc2_data_3p));

endmodule
