module analog_top_4p_portable #(
    parameter real R_contact1 = 500.0, 
    parameter real R_contact2 = 500.0, 
    parameter real R_ext      = 20000.0, 
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0
)(
    input  real  v_dac_val,
    input  logic clk,
    input real r_cont_instant, // Ruido de contacto instantáneo, común para ambas técnicas
    input real autoshunt, // Control para activar/desactivar el autoshunt en 3 puntas, se ignora en 4 puntas
    output real  v_node_A,    // Conectado a ADC1
    output real  v_node_B,    // Conectado a ADC2 (Medida Kelvin)
    output real  v_node_C     // Conectado a ADC3 (Corriente en Shunt)
);

    real i_total;
    real v_diff_bioz;
    
    // La malla de corriente es idéntica a la de 3 puntas
    real r_total_serie = 2* r_cont_instant + autoshunt;

    bioz_block_portable #(
        .R_INT(R_int), 
        .R_EXT(R_ext), 
        .C_MEM(C_mem)
    ) bioz (
        .v_gen(v_dac_val),
        .r_serie(r_total_serie),
        .clk(clk),
        .i_total(i_total),
        .v_diff_bioz(v_diff_bioz)
    );

    always_comb begin
        // Nodo C: Solo Shunt
        v_node_C = i_total * autoshunt; 
        
        // Nodo B: Shunt + Resistencia de contacto 2
        // El ADC2 mide aquí en 4 puntas para dejar fuera R_contact2 del V_diff
        v_node_B = v_node_C + (i_total * r_cont_instant);
        
        // Nodo A: El potencial alto del tejido
        v_node_A = v_node_B + v_diff_bioz;
    end

endmodule
