import electrical_pkg::*;

module top_bioimpedancia_circuito_medida_portable_to_fpga_ina_v3 
#(
    parameter real R_contact1 = 500.0, 
    parameter real R_contact2 = 500.0, 
    parameter real C_p1       = 1.0e-10,
    parameter real C_p2       = 1.0e-10,    
    parameter real R_ext      = 20000.0, 
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 10000.0,
    parameter real C_in_ina   = 3.0e-12,
    parameter real R_in_ina   = 1.0e12,
    parameter real R_bias_ina = 100.0e6,
    parameter real C_in_adc   = 10.0e-12,
    parameter real R_in_adc   = 1.0e6,
    parameter real C_leak     = 10.0e-12,
    parameter real Mutual_L   = 2.5e-7,
    parameter real INA_GAIN   = 1.0,
    parameter real C_f        = 2.0e-12,
    parameter real C_dc       = 10.0e-6,
    parameter real R_dc       = 100.0e3,
    parameter real R_in_tia_inv = 50.0
)
(   
    input logic clk,
    input logic [13:0] dds_bus,
    input logic cuantificacion,
    input real senoide,
    input real autoshunt_value,
    input real r_f1, r_f2,
    input real r_s1, r_s2,
    input real c_f1, c_f2,
    input real c_s1, c_s2,
    input real rext_instant,    
    input real rint_instant,    
    input real c_mem_instant,   
    
    output real v_a_4p,
    output real v_b_4p,
    
    output logic [13:0] adc1_data_4p,
    output logic [13:0] adc2_data_4p
);

    w_elec node_dac_p;
    w_elec node_dac_n;
    w_elec node_adc1;
    w_elec node_adc2;
    w_elec node_adc3;

    real v_dac_p_val, v_dac_n_val;
    w_elec v_dac_p_aplicado, v_dac_n_aplicado;
    
    logic signed [13:0] dds_bus_p;
    logic signed [13:0] dds_bus_n;

    always_comb begin
        dds_bus_p = signed'(dds_bus);
        dds_bus_n = -signed'(dds_bus);
    end

    rp_dac_model_nettype dac_p (
        .data_i(dds_bus_p), 
        .clk(clk), 
        .R_ext(R_ext),
        .R_contact1(R_contact1),
        .node_out(node_dac_p)
    );

    rp_dac_model_nettype dac_n (
        .data_i(dds_bus_n), 
        .clk(clk), 
        .R_ext(R_ext),
        .R_contact1(R_contact2),
        .node_out(node_dac_n)
    );

    always_comb begin
        if (cuantificacion) begin
            v_dac_p_val = node_dac_p.v * 0.5; 
            v_dac_n_val = node_dac_n.v * 0.5; 
        end else begin
            v_dac_p_val = senoide * 0.5; 
            v_dac_n_val = -senoide * 0.5; 
        end
    end

    assign v_dac_p_aplicado = '{v: v_dac_p_val, i: 0.0}; 
    assign v_dac_n_aplicado = '{v: v_dac_n_val, i: 0.0}; 

    bioz_block_portable_to_fpga_ina_v3 #(
        .DT(8e-9),
        .C_in_ina(C_in_ina),
        .R_in_ina(R_in_ina),
        .R_bias_ina(R_bias_ina),
        .C_in_adc(C_in_adc),
        .R_in_adc(R_in_adc),
        .C_leak(C_leak),
        .Mutual_L(Mutual_L),
        .INA_GAIN(INA_GAIN),
        .C_f(C_f),
        .C_dc(C_dc),
        .R_dc(R_dc),
        .R_in_tia_inv(R_in_tia_inv)
    ) bioz_inst (
        .node_gen_p(v_dac_p_aplicado),
        .node_gen_n(v_dac_n_aplicado),
        .node_adc1(node_adc1),
        .node_adc2(node_adc2),
        .node_adc3(node_adc3),
        .r_f1(r_f1),
        .r_f2(r_f2),
        .r_s1(r_s1),
        .r_s2(r_s2),
        .c_f1(c_f1),
        .c_f2(c_f2),
        .c_s1(c_s1),
        .c_s2(c_s2),
        .r_shunt(autoshunt_value),
        .rext_instant(rext_instant),
        .rint_instant(rint_instant),
        .c_mem_instant(c_mem_instant),
        .clk(clk)
    );

    assign v_a_4p = node_adc1.v;
    assign v_b_4p = node_adc2.v;

    rp_adc_model_nettype #(
        .R_IN(R_in_adc),
        .C_IN(C_in_adc)
    ) adc1_4p (.ana_node(node_adc1), .clk(clk), .digital_out(adc1_data_4p));

    rp_adc_model_nettype #(
        .R_IN(R_in_adc),
        .C_IN(C_in_adc)
    ) adc2_4p (.ana_node(node_adc2), .clk(clk), .digital_out(adc2_data_4p));

endmodule
