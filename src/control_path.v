/*
Устройство управления (конвейерное)
Располагается в стадии DECODE и испускает сигналы далее
Суффиксы сигналов-стадий:
_D - DECODE, _E - EXECUTE, _M - MEMORY, _W - WRITEBACK
*/
module control_path(
    input clk, rst,
    input [5:0] opcode, funct,
    input zero,
    output JBEQ, J, JAL, JR, RI, LW, SHIFT, SRL,
    output writeReg, writeMem,
    output [2:0] op,
    /* Значения на выход в Управление Конфликтами (Hazard Manager) и вход*/
    input stall,
    output wriSigEXEC, wriSigMEMO, wriSigWRIT,
    output wriMemorySigEXEC, wriMemorySigMEMO,
    output wriRegFromMemEXEC, wriRegFromMemMEMO
);

/* Стартовая выработка команд DECODE стадии */
wire BEQ_D = opcode == 6'b000100;
wire BNE_D = opcode == 6'b000101;
wire RTYPE_D = opcode == 6'b000000;
wire SW_D = opcode == 6'b101011;
// Это J инструкция?
wire J_D = opcode == 6'b000010;
// Это I тип?
wire RI_D = ~(RTYPE_D || BEQ_D || BNE_D);
// Сдвиг left/right? Сдвиг вообще?
wire SLL_D = funct == 6'b000000;
wire SRL_D = funct == 6'b000010;
wire SHIFT_D = (RTYPE_D && SRL_D) || (RTYPE_D && SLL_D);
// Загрузка из памяти?
wire LW_D = opcode == 6'b100011;
// JAL / JR?
wire JR_D = RTYPE_D && funct == 6'b001000;
// BEQ/BNE прыжок
wire JBEQ_D = (BEQ_D && zero) || (BNE_D && ~zero);
// JAL?
wire JAL_D = opcode == 6'b000011;
// Запись в память и в регистровый файл НЕ: (BEQ BNE SW J JR "JAL")
wire writeMem_D = SW_D;
wire writeReg_D = ~(BEQ_D || BNE_D || SW_D || J_D || JR_D || JAL_D);
// Выбор операции для ALU
reg [2:0] op_D;
always @(*) begin
    casex({opcode, funct})
    12'b000000_100000: op_D = 3'd0;
    12'b001000_xxxxxx: op_D = 3'd0;
    12'b000000_100010: op_D = 3'd1;
    12'b000100_xxxxxx: op_D = 3'd1;
    12'b000101_xxxxxx: op_D = 3'd1;
    12'b000000_100100: op_D = 3'd2;
    12'b001100_xxxxxx: op_D = 3'd2;
    12'b000000_100101: op_D = 3'd3;
    12'b001101_xxxxxx: op_D = 3'd3;
    12'b000000_100110: op_D = 3'd4;
    12'b001110_xxxxxx: op_D = 3'd4;
    default: op_D = 3'd0;
    endcase
end

/*
Выдача значений из стадий либо пересылка в следующую
*/

// Выдача из DECODE стадии
assign JBEQ = JBEQ_D;
assign J = J_D;
assign JR = JR_D;
assign JAL = JAL_D;

/*
Decode -> Execute
*/
// Регистр-задержка
reg [8:0] d2e;
// Дальше по конвейеру
assign writeReg_E = d2e[8];
assign LW_E = d2e[7];
assign writeMem_E = d2e[6];
// Выдача из EXECUTE стадии
assign SHIFT = d2e[5];
assign op = d2e[4:2];
assign SRL = d2e[1];
assign RI = d2e[0];
assign wriSigEXEC = writeReg_E;
assign wriRegFromMemEXEC = LW_E;


/*
Execute -> Memory
*/
// Регистр-задержка
reg [2:0] e2m;
// Дальше по конвейеру
assign writeReg_M = e2m[2];
assign LW_M = e2m[1];
// Выдача из MEMORY стадии
assign writeMem = e2m[0];
assign wriSigMEMO = writeReg_M;
assign wriRegFromMemMEMO = LW_M;

/*
Memory -> WriteBack
*/
// Регистр-задержка
reg [1:0] m2w;
// Выдача из WRITEBACK стадии
assign writeReg = m2w[1];
assign LW = m2w[0];
assign wriSigWRIT = writeReg;

/*
Обновление регистров (Пересылка данных в следующую стадию) по такту
*/
always @(posedge clk) begin
    if (rst) begin
        d2e <= 9'd0;
        e2m <= 3'd0;
        m2w <= 2'd0;
    end else begin
        // Если остановка конвейера -> пускание "пузыря"
        d2e <= stall ? 9'd0 : {writeReg_D, LW_D, writeMem_D, SHIFT_D, op_D, SRL_D, RI_D};
        e2m <= {writeReg_E, LW_E, writeMem_E};
        m2w <= {writeReg_M, LW_M};
    end
end

endmodule