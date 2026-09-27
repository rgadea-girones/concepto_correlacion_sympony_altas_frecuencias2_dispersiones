module arctan8better

#(parameter tamanyo=32)

			  


(input CLK,
input RSTa,
input Start,
input [tamanyo-1:0] Num,
input [tamanyo-1:0] Den,

output [tamanyo-1:0] Coc,
output logic [31:0] Arctan2,
output Done);
localparam size_cont=$clog2(tamanyo-1);
enum  logic [2:0] {D0, D1,D2,D3,D4} state1;
logic [tamanyo-1:0] ACCU, M,Q;
logic [size_cont-1 :0] CONT;
logic fin;
logic [tamanyo-1:0] magnitud_num,magnitud_den;
logic signo;
logic [9:0] tabla;
logic [tamanyo-1:0] magnitud_arctan2;

// Extraer bits de signo (MSB)
logic sign_I = Num[tamanyo-1]; 
logic sign_Q = Den[tamanyo-1];

assign magnitud_num=sign_I?~(Num<<6)+1:(Num<<6);
assign magnitud_den=sign_Q?~(Den)+1:Den; 
always_ff @(posedge CLK or negedge RSTa) 

begin
    if(!RSTa)
    begin

      state1<=D0;
      ACCU<='0;
      CONT<='0;
      Q<='0;
      M<='0;
      fin<=1'b0;
	end
else
	case(state1)
	D0: begin
          state1<=D0;
          ACCU<='0;
          CONT<='0;
          Q<='0;
          M<='0;
          fin<=1'b0;
            if (Start) 
              begin
                 ACCU<='0;
                 CONT<=tamanyo-1;
                 Q<=magnitud_num;
                 M<=magnitud_den;
                 state1 <= D1;
              end
    end
	D1: begin	
            {ACCU,Q}<={ACCU[tamanyo-2:0],Q,1'b0};
            state1 <= D2;
    end
    D2: begin
            CONT<=CONT-1;
            if (ACCU>=M)
            begin
               Q<=Q+1;
               ACCU<=ACCU-M;
            end
            if (CONT=='0) 
            begin
                fin<=1'b1;
                state1 <= D3;
            end
            else 
                state1<=D1;
    end
	D3: begin 

            fin<=1'b0;
            if (!Start) 
                state1 <= D0;

    end

	endcase

end

        //    assign Res=ACCU;
            
assign magnitud_arctan2=(Coc[tamanyo-1:14]=='0)?{22'h000000,tabla}:32'd720;

always_comb begin
    if (sign_I == 1'b0 && sign_Q == 1'b0) begin
        // Cuadrante 1: I(+), Q(+) -> Fase normal positiva
        Arctan2 = magnitud_arctan2; 
        
    end else if (sign_I == 1'b0 && sign_Q == 1'b1) begin
        // Cuadrante 4: I(+), Q(-) -> Bioimpedancia Normal (0 a -90)
        Arctan2 = -magnitud_arctan2; 
        
    end else if (sign_I == 1'b1 && sign_Q == 1'b1) begin
        // Cuadrante 3: I(-), Q(-) -> El Peligro (Cruce por debajo de -90)
        // Ejemplo: Si base es 5°, el real es -180 + 5 = -175°
        Arctan2 = -180.0 + magnitud_arctan2; 
        
    end else begin
        // Cuadrante 2: I(-), Q(+) -> Cruce por encima de +90
        Arctan2 = 180.0 - magnitud_arctan2; 
    end
end


        
memoria_single_port_mejorado #(.DATA_WIDTH(10),.ADDR_WIDTH(14),
.punto_entrada(6),.punto_salida(3))  arco_tangente1
(.clk(CLK),
.addr(Coc[13:0]), 
.q(tabla));

logic aux_shifter;
always_ff @(posedge CLK or negedge RSTa) 
    if(!RSTa)
        aux_shifter<='0;
    else 
        aux_shifter<=fin;

assign Done=aux_shifter;
assign Coc=Q;        
        

endmodule