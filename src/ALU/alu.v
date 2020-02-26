module alu(
    input [2:0] op,
    input [31:0] a, b,
    output reg [31:0] c,
    output zero
);

assign zero = |c;

always @(*) begin
    case (op)
        3'd0: c = a + b;
        3'd1: c = a - b;
        3'd2: c = a & b;
        3'd3: c = a | b;
        3'd4: c = a ^ b;
        default: c = a + b; 
    endcase
end

endmodule