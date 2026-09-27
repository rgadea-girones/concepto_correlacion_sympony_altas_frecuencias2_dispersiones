import electrical_pkg::*;
module analog_top_3p 
#(
    
parameter real R_contact1 = 500.0, // Contacto del extremo de generación
  parameter real R_contact2 = 500.0, // Contacto del extremo de shunt
  parameter real R_ext = 20000.0,   
  parameter real R_int = 1500.0,
  parameter real C_mem = 5.0e-9,
    parameter real R_shunt = 100.0
)   
(inout w_elec v_dac_val, input logic clk);


    // Nodos de la red
    w_elec node_E, node_A, node_B_C, node_B_interno, node_GND;

    assign node_GND = '{v: 0.0, i: 0.0};
    assign node_E = v_dac_val;

    // 1. Resistencia de contacto de entrada
    res_model #(.R(R_contact1)) r_cont_in (.p(node_E), .n(node_A));
    
    // 2. Bloque de Bioimpedancia (Nodo A a Nodo B_C)
    bioz_block_nettype  #(.R_INT(R_int), .R_EXT(R_ext), .C_MEM(C_mem)) bioz (.node_A(node_A), .node_B(node_B_C), .clk(clk));
    
    // 3. Resistencia de contacto del electrodo de TRABAJO (la que te faltaba)
// Esta resistencia está ENTRE el tejido y el punto donde conectas el ADC2/Shunt
    res_model #(.R(R_contact2)) r_cont_work (.p(node_B_interno), .n(node_B_C));

    // 3. Resistencia Shunt / Referencia (Nodo B_C a Tierra)
    // El ADC2 medirá aquí para obtener la corriente I = V(B_C) / R_SHUNT
    res_model #(.R(R_shunt))  r_shunt (.p(node_B_C), .n(node_GND));

    // Nota: El contacto de salida está implícito en la R_SHUNT 
    // o se sumaría internamente a la bioimpedancia.
endmodule
