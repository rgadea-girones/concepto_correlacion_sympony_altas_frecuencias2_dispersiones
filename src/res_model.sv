import electrical_pkg::*;

module res_model #(parameter real R = 1000.0)
(
    inout w_elec p, // Terminal positivo
    inout w_elec n  // Terminal negativo
);
    // Ley de Ohm: i = (v_p - v_n) / R
    // Para nettypes, debes asignar la estructura completa, no campos individuales
    assign p = '{v: p.v, i: (p.v - n.v) / R};
    assign n = '{v: n.v, i: (n.v - p.v) / R};
endmodule