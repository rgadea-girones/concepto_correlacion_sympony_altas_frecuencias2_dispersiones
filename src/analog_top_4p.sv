import electrical_pkg::*;
module analog_top_4p 
#(parameter real R_contact1 = 500.0, // Contacto del extremo de generación
  parameter real R_contact2 = 500.0, // Contacto del extremo de shunt
  parameter real R_ext      = 20000.0, 
  parameter real R_int      = 1500.0,
  parameter real C_mem      = 5.0e-9,
  parameter real R_shunt    = 100.0
)
(inout w_elec v_dac_val, input logic clk);


    // Nodos de la red (Cables Nettype)
    w_elec node_E, node_A, node_B, node_C, node_GND;

    // Referencia de tierra y fuente DAC
    assign node_GND = '{v: 0.0, i: 0.0};
    assign node_E = v_dac_val;

    // Componentes de tu esquema
    res_model #(.R(R_contact1)) r_contact_1 (.p(node_E), .n(node_A));
    
    bioz_block_nettype  #(.R_INT(R_int), .R_EXT(R_ext), .C_MEM(C_mem)) bioz (.node_A(node_A), .node_B(node_B), .clk(clk));
    
    res_model #(.R(R_contact2)) r_contact_2 (.p(node_B), .n(node_C));
    
    res_model #(.R(R_shunt))  r_shunt     (.p(node_C), .n(node_GND));

    // Ahora puedes observar node_A.v, node_B.v y node_C.v directamente
    // Estos valores son los que inyectarás a tus modelos de entrada (ADC stage)
endmodule
