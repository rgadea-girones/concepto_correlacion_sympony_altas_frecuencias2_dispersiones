module analog_top_4p_portable #(
    parameter real R_contact1 = 500.0,
    parameter real R_contact2 = 500.0,
    parameter real C_p1       = 1.0e-10,
    parameter real C_p2       = 1.0e-10,
    parameter real R_ext      = 20000.0,
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0
)(
    input  real v_dac_val,
    input  logic clk,
    input real r_cont_instant, // Ruido de contacto instantáneo, común para ambas técnicas
    input real c_contact1, // Capacitancia parásita del electrodo 1
    input real autoshunt, // Control para activar/desactivar el autoshunt en 3 puntas, se ignora en 4 puntas
    output real v_node_A, // Lado alto del tejido
    output real v_node_B, // Lado bajo del tejido
    output real v_node_C  // Shunt
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
        v_node_C = i_total * autoshunt; // Nodo C: Solo Shunt
        v_node_B = v_node_C + v_cp2;      // Nodo tras el electrodo de retorno
        v_node_A = v_node_B + v_diff_bioz; // Nodo antes del tejido
    end
endmodule