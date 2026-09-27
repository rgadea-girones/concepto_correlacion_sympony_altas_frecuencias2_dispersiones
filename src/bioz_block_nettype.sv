import electrical_pkg::*;
module bioz_block_nettype (
    inout w_elec node_A,
    inout w_elec node_B,
    input logic clk
);
    parameter real R_INT = 1000.0;
    parameter real R_EXT = 500.0;
    parameter real C_MEM = 10e-9;
    parameter real DT = 8e-9; // 125MHz

    real v_cmem = 0.0;
    real i_total;

    always @(posedge clk) begin
        automatic real v_diff = node_A.v - node_B.v;
        automatic real i_rint = v_diff / R_INT;
        automatic real i_rext_c = (v_diff - v_cmem) / R_EXT;
        
        v_cmem <= v_cmem + (i_rext_c / C_MEM) * DT;
        i_total <= i_rint + i_rext_c;
    end

    // Aportamos la corriente calculada a los nodos de la red
    assign node_A = '{v: node_A.v, i: i_total};
    assign node_B = '{v: node_B.v, i: -i_total};
endmodule
