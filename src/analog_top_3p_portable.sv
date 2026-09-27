
module analog_top_3p_portable #(
    parameter real R_contact1 = 500.0, 
    parameter real R_contact2 = 500.0, 
    parameter real R_ext      = 20000.0, 
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0
)(
    input  real  v_dac_val,
    input  logic clk,
    input real autoshunt  , // Control para activar/desactivar el autoshunt en 3 puntas
    input real r_cont_instant, // Ruido de contacto instantáneo, común para ambas técnicas
    output real  v_node_A,    // Conectado a ADC1
    output real  v_node_BC    // Conectado a ADC2
);

    real i_total;
    real v_diff_bioz;
    real v_shunt_effective;

    
    // En 3 puntas, la corriente atraviesa todo: R_cont1, Bioz, R_cont2 y Shunt
    real r_total_serie ;

    always_comb begin
      v_shunt_effective= autoshunt ;
      r_total_serie = 2* r_cont_instant + v_shunt_effective;
    end
    // Instancia del bloque con la nueva lógica de resolución de malla
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
        // El nodo BC es la caída solo en el Shunt (referencia de corriente)
        v_node_BC = i_total * v_shunt_effective; 
        
        // El nodo A es el voltaje tras la pérdida en la primera resistencia de contacto
        v_node_A = v_dac_val - (i_total * r_cont_instant);
    end

endmodule
