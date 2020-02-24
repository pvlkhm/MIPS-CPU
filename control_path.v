module control_path(
    input [5:0] opcode, funct,
    input zero,
    output JBEQ, JJRJAL, JAL, JR, RI, LW, SHIFT, SRL,
    output writeReg, writeMem,
    output reg [2:0] op
);

wire BEQ = opcode == 6'b000100;
wire BNE = opcode == 6'b000101;
wire RTYPE = opcode == 6'b000000;
wire SLL = funct == 6'b000000;
wire SW = opcode == 6'b101011;
// Это R тип?
assign RI = ~(RTYPE || BEQ || BNE);
// Сдвиг left/right? Сдвиг вообще?
assign SRL = funct == 6'b000010;
assign SHIFT = (RTYPE && SRL) || (RTYPE && SLL);
// Загрузка из памяти?
assign LW = opcode == 6'b100011;
// JAL / JR?
assign JR = RTYPE && funct == 6'b001000;
// BEQ/BNE прыжок
assign JBEQ = (BEQ && zero) || (BNE && ~zero);
// JAL?
assign JAL = (opcode == 6'b000011);
// Запись в память и в регистровый файл (BEQ BNE SW J JR)
assign writeReg = ~(BEQ || BNE || SW || opcode == 6'b000010 || JR);
assign writeMem = SW;

// Выбор операции для ALU
always @(*) begin
    casex({opcode, funct})
    12'b000000_100000: op = 3'd0;
    12'b001000_xxxxxx: op = 3'd0;
    12'b000000_100010: op = 3'd1;
    12'b000100_xxxxxx: op = 3'd1;
    12'b000101_xxxxxx: op = 3'd1;
    12'b000000_100100: op = 3'd2;
    12'b001100_xxxxxx: op = 3'd2;
    12'b000000_100101: op = 3'd3;
    12'b001101_xxxxxx: op = 3'd3;
    12'b000000_100110: op = 3'd4;
    12'b001110_xxxxxx: op = 3'd4;
    default: op = 3'd0;
    endcase
end

endmodule