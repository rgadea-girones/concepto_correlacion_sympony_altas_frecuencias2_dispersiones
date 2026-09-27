package dpi_pkg_tiempos;

    import "DPI-C" function void configurar_metadata_csv(
        input string flujo,
        input string simulador,
        input string configuracion,
        input string run_id
    );

    import "DPI-C" function void inicializar_tiempos();

    import "DPI-C" function void guardar_dato(
        input int sujeto,
        input int medida,
        input real frecuencia,
        input real modulo,
        input real fase,
        input real modulo_a,
        input real fase_a,
        input real modulo_b,
        input real fase_b,
        input real tiempo_simulacion,
        input real tiempo_transcurrido_real
    );

    import "DPI-C" function void procesar_dataframe();

    import "DPI-C" function void app_fft_radix2_dpi(
        input int N, input real in_re[1024], input real in_im[1024],
        output real out_re[1024], output real out_im[1024]
    );

        // NUEVA FUNCIÓN: Obtener el tiempo de CPU (Procesador) en segundos
    import "DPI-C" function real get_cpu_time_s();
endpackage