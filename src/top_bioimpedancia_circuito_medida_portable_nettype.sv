import electrical_pkg::*;

module top_bioimpedancia_circuito_medida_portable_nettype 
#(
    parameter real R_contact1 = 500.0, 
    parameter real R_contact2 = 500.0, 
    parameter real C_p1       = 1.0e-10,
    parameter real C_p2       = 1.0e-10,    
    parameter real R_ext      = 20000.0, 
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0,
    // --- NUEVOS PARÁMETROS DE ALTA FRECUENCIA (ROJO) ---
    parameter real C_in       = 20.0e-12,
    parameter real R_in       = 1.0e6,
    parameter real C_leak     = 30.0e-12,
    parameter real Mutual_L   = 2.5e-6
)
(   
    input logic clk,
    input logic [13:0] dds_bus, // Bus de 14 bits para el DAC
    input logic cuantificacion, // Control para activar/desactivar la cuantificación del ADC
    input real senoide,
    input real autoshunt_value, // Valor de resistencia efectiva del autoshunt
    input real r_cont_instant,  // Ruido de contacto instantáneo
    input real c_contact1,      // Capacitancia parásita del electrodo 1
    input real rext_instant,    // Variación instantánea de R_ext (ruido)
    input real rint_instant,    // Variación instantánea de R_int (ruido)
    input real c_mem_instant,   // Variación instantánea de C_mem (ruido)
    
    output real v_a_4p, // Nodo A (con atenuación del instrumento) expuesto para testbench
    output real v_b_4p, // Nodo B (con atenuación del instrumento) expuesto para testbench
    output real v_c_4p, // Nodo C (SHUNT || C_leak) expuesto para testbench
    
    output logic [13:0] adc1_data_4p, // Nodo Sense+ digitalizado
    output logic [13:0] adc2_data_4p, // Nodo Sense- digitalizado
    output logic [13:0] adc3_data_4p  // Nodo Shunt digitalizado
);

    // --- NODOS NETTYPE (w_elec) ---
    w_elec node_dac_out;
    w_elec node_adc1;
    w_elec node_adc2;
    w_elec node_adc3;

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

    // Inyectamos el valor de voltaje final (cuantificado o puro) al nettype que va al circuito
    assign v_dac_aplicado = '{v: v_dac_4p, i: 0.0}; 

    // --- MODELO ANALÓGICO 4 PUNTAS (NETTYPE WRAPPER CON EFECTOS DE ALTA FRECUENCIA) ---
    analog_top_4p_portable_nettype #(
        .R_contact1(R_contact1),
        .R_contact2(R_contact2),
        .R_ext(R_ext),
        .R_int(R_int),
        .C_mem(C_mem),
        .R_shunt(R_shunt),
        .C_p1(C_p1),
        .C_p2(C_p2),
        .C_in(C_in),
        .R_in(R_in),
        .C_leak(C_leak),
        .Mutual_L(Mutual_L)
    ) analog_4p (
        .v_dac_val(v_dac_aplicado),
        .clk(clk),
        .autoshunt(autoshunt_value),
        .r_cont_instant(r_cont_instant),
        .c_contact1(c_contact1),
        .rext_instant(rext_instant),
        .rint_instant(rint_instant),
        .c_mem_instant(c_mem_instant),
        .node_adc1(node_adc1),
        .node_adc2(node_adc2),
        .node_adc3(node_adc3)
    );

    // --- EXTRACCION DE VARIABLES REALES PARA COMPATIBILIDAD CON BENCH ---
    assign v_a_4p = node_adc1.v;
    assign v_b_4p = node_adc2.v;
    assign v_c_4p = node_adc3.v;

    // --- CAPTURA (ADCs) CON NODOS NETTYPE ---
    rp_adc_model_nettype adc1_4p (.ana_node(node_adc1), .clk(clk), .digital_out(adc1_data_4p));
    rp_adc_model_nettype adc2_4p (.ana_node(node_adc2), .clk(clk), .digital_out(adc2_data_4p));
    rp_adc_model_nettype adc3_4p (.ana_node(node_adc3), .clk(clk), .digital_out(adc3_data_4p));

endmodule
