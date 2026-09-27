module adc_14bit_model (
    input  real v_p,
    input  real v_n,
    input  logic clk,
    output logic [13:0] adc_data
);
    real v_diff;
    real v_ref = 1.0; // Rango de entrada del ADC (ej. 1V diferencial)

    always @(posedge clk) begin
        v_diff = v_p - v_n;
        // Saturación y Cuantización a 14 bits
        if (v_diff >= v_ref) 
            adc_data <= 14'h1FFF;
        else if (v_diff <= -v_ref)
            adc_data <= 14'h2000;
        else
            // Mapeo lineal a complemento a dos
            adc_data <= $realtobits(v_diff * 8192.0 / v_ref); 
    end
endmodule
