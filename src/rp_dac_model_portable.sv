// dac_redpitaya_model.sv


module rp_dac_model_portable #(
    parameter int  BITS = 14,          // Resolución Red Pitaya 
    parameter real VREF = 1.0,         // Rango de salida (±1V típico)
    parameter real R_OUT = 50.0        // Impedancia de salida de la Red Pitaya
)(
    input  logic signed [BITS-1:0] data_i,    // Entrada digital del DDS (SIGNED)
    input  logic            clk,
    output real             node_out   // Salida eléctrica (Nettype) 
);
    logic signed [BITS-1:0] data_reg; // Registro para almacenar el valor digital
    logic [31:0] float_754; // Para conversión a formato IEEE 754 si se desea
    shortreal v_target;
    localparam real FIXED_POINT_SCALE = $pow(2, BITS-1);  // 8192 para 14 bits

    // Nodo interno para la fuente de voltaje ideal antes de la R de salida


    // Proceso de conversión: Cuantificación y escalado
    always_ff @(posedge clk) begin
        node_out <= real'(data_i / FIXED_POINT_SCALE) * VREF; // Mapeo a voltaje real   
     end
     /*
    Fixed2Float #(.FIXEDSIZE(BITS))
    converter (
        .InRadixPoint(BITS-1),
        .InFixed(data_reg),
        .OutFloat(float_754)
    );
     assign node_out = $bits2shortreal(float_754); // Salida ideal del DAC (sin modelar la caída por R_OUT)
*/
endmodule