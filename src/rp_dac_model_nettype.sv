// dac_redpitaya_model.sv
import electrical_pkg::*;

module rp_dac_model_nettype #(
    parameter int  BITS = 14,          // Resolución Red Pitaya 
    parameter real VREF = 1.0,         // Rango de salida (±1V típico)
    parameter real R_OUT = 50.0      // Impedancia de salida de la Red Pitaya
 //   parameter real R_contact1 = 500.0, // Resistencia de contacto 1 (entrada circuito)
 //   parameter real R_ext = 20000.0     // Resistencia externa (entrada circuito)
)(
    input  logic signed [BITS-1:0] data_i,    // Entrada digital del DDS (SIGNED)
    input  logic            clk,
    input real R_ext,
    input real R_contact1,
    w_elec                  node_out   // Salida eléctrica (Nettype) 
);
    real v_target;
    localparam real FIXED_POINT_SCALE = $pow(2, BITS-1);  // 8192 para 14 bits

    // Proceso de conversión: Cuantificación y escalado
    always_ff @(posedge clk) begin
        // Convertimos el código binario signed a voltaje real (rango ±VREF)
        // data_i es signed [13:0], rango -8192 a 8191
        v_target = (real'(signed'(data_i)) / FIXED_POINT_SCALE) * VREF;
    end

    // Cálculo del divisor resistivo
    real R_LOAD;
    real v_out;
    always_comb begin
        R_LOAD = R_contact1 + R_ext;
        v_out = v_target * (R_LOAD / (R_OUT + R_LOAD));
    end

    initial $display("[rp_dac_model_nettype] Asignando node_out en instancia: %m");
    assign node_out = '{v: v_out, i: 0.0};

endmodule