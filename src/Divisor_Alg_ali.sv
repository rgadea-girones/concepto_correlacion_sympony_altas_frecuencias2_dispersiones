module Divisor_Alg_ali #(
    parameter tamanyo = 64 ,    // 64 bits para no perder resolución de los acumuladores
    parameter n_decimales_maximo = 16  // Equivale a un <<12, mucha más precisión que el <<4
)(
    input CLK,
    input RSTa,
    input Start,
    input [tamanyo-1:0] Num,    // Módulo V
    input [tamanyo-1:0] Den,    // Módulo I
    input logic [3:0] n_decimales, // Número de bits decimales para la parte fraccional
    output logic [tamanyo-1:0] Coc,
    output logic Done
);

    typedef enum logic [1:0] {IDLE, PREPARE, DIVIDE, FINISH} state_t;
    state_t state;

    logic [tamanyo-1:0] ACCU, M, Q;
    logic [$clog2(tamanyo + n_decimales_maximo):0] CONT;
    logic [5:0] lzc_num, lzc_den, lzc_final; // Leading Zero Count

    // --- 1. Detector de ceros a la izquierda (Alineación) ---
    // Buscamos cuánto podemos desplazar el denominador hacia la izquierda
    // para que el bit más significativo (MSB) sea '1'.
// Lógica para el Numerador
always_comb begin
    lzc_num = 0;
    for (int i = tamanyo-1; i >= 0; i--) begin
        if (Num[i]) begin
            lzc_num = (tamanyo-1) - i;
            break;
        end
        if (i == 0) lzc_num = tamanyo-1;
    end
end

// Lógica para el Denominador
always_comb begin
    lzc_den = 0;
    for (int i = tamanyo-1; i >= 0; i--) begin
        if (Den[i]) begin
            lzc_den = (tamanyo-1) - i;
            break;
        end
        if (i == 0) lzc_den = tamanyo-1;
    end
end

// 2. EL SEGURO DE VIDA: Escogemos el mínimo desplazamiento posible
// Esto garantiza que NINGUNO de los dos pierda bits por la izquierda.
assign lzc_final = (lzc_num < lzc_den) ? lzc_num : lzc_den;

    always_ff @(posedge CLK or negedge RSTa) begin
        if (!RSTa) begin
            state <= IDLE;
            Done <= 0;
            CONT<='0;
            {ACCU, M, Q, Coc} <= '0;
        end else begin
            case (state)
                IDLE: begin
                    Done <= 0;
                    if (Start) begin
                        // --- 2. Alineación Dinámica ---
                        // "Normalizamos" el denominador para que use todo el rango del divisor
                        M <= Den << lzc_final;
                        // Desplazamos el numerador exactamente lo mismo para mantener la proporción
                        Q <= Num << lzc_final; 
                        
                        ACCU <= '0;
                        // El contador ahora hará los 64 pasos normales + los n_decimales
                        CONT <= tamanyo + n_decimales; 
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    if (CONT == 0) begin
                        state <= FINISH;
                    end else begin
                        // --- 3. Algoritmo de resta y desplazamiento ---
                        // Sacamos bits del cociente uno a uno. Al seguir iterando después 
                        // de tamanyo, empezamos a obtener los bits decimales.
                        if ({ACCU[tamanyo-2:0], Q[tamanyo-1]} >= M) begin
                            ACCU <= {ACCU[tamanyo-2:0], Q[tamanyo-1]} - M;
                            Q <= {Q[tamanyo-2:0], 1'b1};
                        end else begin
                            ACCU <= {ACCU[tamanyo-2:0], Q[tamanyo-1]};
                            Q <= {Q[tamanyo-2:0], 1'b0};
                        end
                        CONT <= CONT - 1;
                    end
                end

                FINISH: begin
                    Coc <= Q; // El resultado contiene la parte entera y n_decimales bits fraccionales
                    Done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule