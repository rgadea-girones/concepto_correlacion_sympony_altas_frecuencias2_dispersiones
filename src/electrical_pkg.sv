package electrical_pkg;
    // Estructura para representar una señal eléctrica
    typedef struct {
        real v; // Voltaje en el nodo
        real i; // Corriente que entra/sale del nodo
    } electrical_t;


    // Función de resolución ideal: solo un driver permitido
    function automatic electrical_t resolve_electrical(input electrical_t drivers[]);
        if (drivers.size() == 1) begin
            return drivers[0];
        end else if (drivers.size() == 0) begin
            // Sin driver: devuelve 0
            electrical_t zero;
            zero.v = 0.0;
            zero.i = 0.0;
            return zero;
        end else begin
        $error("[resolve_electrical] Más de un driver detectado en w_elec. drivers.size()=%0d", drivers.size());
        // Opcional: imprime un backtrace para saber desde dónde se llama
        $display("Backtrace: %m");
             return drivers[0]; // Devuelve el primero para evitar crash, pero lanza error
        end
    endfunction

    // Definición del nettype para usar en los cables
    nettype electrical_t w_elec with resolve_electrical;
endpackage
