module analog_top_3p_portable #(
    parameter real R_contact1 = 500.0,
    parameter real R_contact2 = 500.0,
    parameter real C_p1       = 1.0e-10, // Capacidad del electrodo
    parameter real C_p2       = 1.0e-10,
    parameter real R_ext      = 20000.0,
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0
)(
    input  real v_dac_val,
    input  logic clk,
    input real autoshunt, // Control para activar/desactivar el autoshunt en 3 puntas
    input real r_cont_instant, // Ruido de contacto instantáneo, común para ambas
    input real c_contact1, // Capacitancia parásita del electrodo 1
    output real v_node_A,   // ADC1
    output real v_node_BC   // ADC2 (Sobre el Shunt)
);
    real i_total, v_diff_bioz, v_cp1, v_cp2;

    bioz_block_portable #(
        .R_INT(R_int), .R_EXT(R_ext), .C_MEM(C_mem),
        .C_P1(C_p1), .C_P2(C_p2)
    ) bioz_inst (
        .v_gen(v_dac_val), .r_s1(r_cont_instant), .r_s2(r_cont_instant), .r_shunt(autoshunt),
        .c_p1(c_contact1), .c_p2(c_contact1), // Asumimos que ambos electrodos tienen la misma capacitancia parásita
        .clk(clk), .i_total(i_total), .v_diff_bioz(v_diff_bioz), .v_cp1(v_cp1), .v_cp2(v_cp2)
    );

    always_comb begin
        v_node_BC = i_total * autoshunt; // Nodo BC: Solo Shunt, con control de autoshunt
        // En 3 puntas, el nodo A es el potencial tras el primer electrodo
        v_node_A = v_node_BC + v_cp2 + v_diff_bioz;
    end
endmodule