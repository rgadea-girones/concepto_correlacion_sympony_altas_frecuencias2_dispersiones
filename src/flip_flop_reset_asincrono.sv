module ff_reset_asincrono(
    input  logic clk,
    input  logic rst,
    input  logic [13:0] d,
    output logic [13:0] q
);

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            q <= 14'b0;
        end else begin
            q <= d;
        end
    end
endmodule