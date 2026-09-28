import electrical_pkg::*;

module top_bioimpedancia_circuito_medida_portable_mixed_v3 
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
    parameter real INA_GAIN   = 1.0
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

    localparam real RES_SCALE  = 1.0e3;  // Ohms to mOhms
    localparam real CAP_SCALE  = 1.0e15; // Farads to fFarads
    localparam real VOLT_SCALE = 1.0e6;  // Volts to uVolts

    integer senoide_uv;
    integer dac_load_mohm;
    integer autoshunt_mohm;
    
    integer r_f1_mohm, r_f2_mohm, r_s1_mohm, r_s2_mohm;
    integer c_f1_ff, c_f2_ff, c_s1_ff, c_s2_ff;
    
    integer rext_mohm;
    integer rint_mohm;
    integer c_mem_ff;

    always_comb begin
        senoide_uv     = $rtoi(senoide * VOLT_SCALE);
        dac_load_mohm  = $rtoi((R_contact1 + R_ext) * RES_SCALE);
        autoshunt_mohm = $rtoi(autoshunt_value * RES_SCALE);
        
        r_f1_mohm      = $rtoi(r_f1 * RES_SCALE);
        r_f2_mohm      = $rtoi(r_f2 * RES_SCALE);
        r_s1_mohm      = $rtoi(r_s1 * RES_SCALE);
        r_s2_mohm      = $rtoi(r_s2 * RES_SCALE);
        
        c_f1_ff        = $rtoi(c_f1 * CAP_SCALE);
        c_f2_ff        = $rtoi(c_f2 * CAP_SCALE);
        c_s1_ff        = $rtoi(c_s1 * CAP_SCALE);
        c_s2_ff        = $rtoi(c_s2 * CAP_SCALE);
        
        rext_mohm      = $rtoi(rext_instant * RES_SCALE);
        rint_mohm      = $rtoi(rint_instant * RES_SCALE);
        c_mem_ff       = $rtoi(c_mem_instant * CAP_SCALE);
    end

    top_bioimpedancia_ams_v3 #(
        .C_IN(C_in_adc),
        .R_IN(R_in_adc),
        .C_LEAK(C_leak),
        .MUTUAL_L(Mutual_L)
    ) analog_4p_mixed_v3 (
        .clk(clk),
        .cuantificacion(cuantificacion),
        .dac_data(dds_bus),
        .senoide_uv(senoide_uv),
        .dac_load_mohm(dac_load_mohm),
        .autoshunt_mohm(autoshunt_mohm),
        .r_f1_mohm(r_f1_mohm),
        .r_f2_mohm(r_f2_mohm),
        .r_s1_mohm(r_s1_mohm),
        .r_s2_mohm(r_s2_mohm),
        .c_f1_ff(c_f1_ff),
        .c_f2_ff(c_f2_ff),
        .c_s1_ff(c_s1_ff),
        .c_s2_ff(c_s2_ff),
        .rext_mohm(rext_mohm),
        .rint_mohm(rint_mohm),
        .c_mem_ff(c_mem_ff),
        .adc1_data(adc1_data_4p),
        .adc2_data(adc2_data_4p)
    );

    always_comb begin
        v_a_4p = 0.0;
        v_b_4p = 0.0;
    end
endmodule
