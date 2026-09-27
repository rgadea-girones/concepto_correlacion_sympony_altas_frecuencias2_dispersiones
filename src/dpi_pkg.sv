// Paquete con las declaraciones DPI
package dpi_pkg;
    
    // Declaración de la función para guardar datos
    // NOTA: 'real' en SystemVerilog = 'double' en C (64 bits)
    import "DPI-C" function void guardar_dato(
        input int sujeto,
        input int medida,
        input real frecuencia,
        input real modulo,
        input real fase,
        input real modulo_a,
        input real fase_a,
        input real modulo_b,
        input real fase_b
        
    );
    
    // Declaración de la función para finalizar y procesar
    import "DPI-C" function void procesar_dataframe();
    
    //golden model en C para la FFT radix-2, que se usará para comparar con la correlación en el testbench
    import "DPI-C" function void app_fft_radix2_dpi(
    input int N, input real in_re[1024], input real in_im[1024],
    output real out_re[1024], output real out_im[1024]
    );
endpackage
