module top_bioimpedancia_circuito_medida_portable_mixed
#(
    parameter real R_contact1 = 500.0,
    parameter real R_contact2 = 500.0,
    parameter real C_p1       = 1.0e-10,
    parameter real C_p2       = 1.0e-10,
    parameter real R_ext      = 20000.0,
    parameter real R_int      = 1500.0,
    parameter real C_mem      = 5.0e-9,
    parameter real R_shunt    = 100.0,
    // --- NUEVOS PARÁMETROS DE ALTA FRECUENCIA PARA AMS ---
    parameter real C_in       = 20.0e-12,
    parameter real R_in       = 1.0e6,
    parameter real C_leak     = 30.0e-12,
    parameter real Mutual_L   = 2.5e-6
)
(
    input logic clk,
    input logic [13:0] dds_bus,
    input logic cuantificacion,
    input real senoide,
    input real autoshunt_value,
    input real r_cont_instant,
    input real c_contact1,
    input real rext_instant,
    input real rint_instant,
    input real c_mem_instant,

    output real v_a_4p,
    output real v_b_4p,
    output real v_c_4p,

    output logic [13:0] adc1_data_4p,
    output logic [13:0] adc2_data_4p,
    output logic [13:0] adc3_data_4p
);

    localparam real RES_SCALE = 1.0e3;
    localparam real CAP_SCALE = 1.0e15;
    localparam real VOLT_SCALE = 1.0e6;

    integer senoide_uv;
    integer dac_load_mohm;
    integer autoshunt_mohm;
    integer r_cont_mohm;
    integer c_contact_ff;
    integer rext_mohm;
    integer rint_mohm;
    integer c_mem_ff;

    always_comb begin
        senoide_uv = $rtoi(senoide * VOLT_SCALE);
        dac_load_mohm = $rtoi((R_contact1 + R_ext) * RES_SCALE);
        autoshunt_mohm = $rtoi(autoshunt_value * RES_SCALE);
        r_cont_mohm = $rtoi(r_cont_instant * RES_SCALE);
        c_contact_ff = $rtoi(c_contact1 * CAP_SCALE);
        rext_mohm = $rtoi(rext_instant * RES_SCALE);
        rint_mohm = $rtoi(rint_instant * RES_SCALE);
        c_mem_ff = $rtoi(c_mem_instant * CAP_SCALE);
    end

    top_bioimpedancia_ams #(
        .C_IN(C_in),
        .R_IN(R_in),
        .C_LEAK(C_leak),
        .MUTUAL_L(Mutual_L)
    ) analog_4p_mixed (
        .clk(clk),
        .cuantificacion(cuantificacion),
        .dac_data(dds_bus),
        .senoide_uv(senoide_uv),
        .dac_load_mohm(dac_load_mohm),
        .autoshunt_mohm(autoshunt_mohm),
        .r_cont_mohm(r_cont_mohm),
        .c_contact_ff(c_contact_ff),
        .rext_mohm(rext_mohm),
        .rint_mohm(rint_mohm),
        .c_mem_ff(c_mem_ff),
        .adc1_data(adc1_data_4p),
        .adc2_data(adc2_data_4p),
        .adc3_data(adc3_data_4p)
    );

    always_comb begin
        v_a_4p = 0.0;
        v_b_4p = 0.0;
        v_c_4p = 0.0;
    end
endmodule