import electrical_pkg::*;

module analog_top_4p_portable_nettype #(
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
)(
    input w_elec v_dac_val, // Voltage from DAC
    input  logic clk,
    input real r_cont_instant, // Ruido de contacto instantáneo, común para ambas técnicas
    input real c_contact1, // Capacitancia parásita del electrodo 1
    input real autoshunt, // Control para activar/desactivar el autoshunt
    input real rext_instant, // Variación instantánea de R_ext (ruido)
    input real rint_instant, // Variación instantánea de R_int (ruido)
    input real c_mem_instant, // Variación instantánea de C_mem (ruido)
    
    // Nodos expuestos a la red (Nettypes)
    output w_elec node_adc1, // Lado A -> Sense+ -> Instrumento
    output w_elec node_adc2, // Lado B -> Sense- -> Instrumento
    output w_elec node_adc3  // Lado C (Shunt + C_leak)
);

    // Instancia del bloque principal que resuelve el circuito usando RK4
    bioz_block_portable_nettype #(
        .DT(8e-9),
        .C_in(C_in),
        .R_in(R_in),
        .C_leak(C_leak),
        .Mutual_L(Mutual_L)
    ) bioz_inst_nettype (
        .node_gen(v_dac_val),
        .node_adc1(node_adc1),
        .node_adc2(node_adc2),
        .node_adc3(node_adc3),
        .r_s1(r_cont_instant),
        .r_s2(r_cont_instant),
        .c_p1(c_contact1),
        .c_p2(c_contact1),
        .r_shunt(autoshunt),
        .rext_instant(rext_instant),
        .rint_instant(rint_instant),
        .c_mem_instant(c_mem_instant),
        .clk(clk)
    );

endmodule