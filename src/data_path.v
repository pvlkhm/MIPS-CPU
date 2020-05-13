/*
Конвейер
JBEQ — Jump относительный (После beq/bne)
J — Jump по псевдопрямому адресу
JAL — Выбор регистра $ra для записи при jal
JR – Выбор адреса для jump'а из регистра
RI – R или I инструкция
LW – Инструкция lw
SHIFT – Инструкиця сдвига
SRL – Выбор сдвига вправо (srl)
writeReg/writeMem – разрешение записи по clk в память
stall - остановка ковейера
flush - очистка от ложного ветвления (BEQ/BNE спекуляция) 
bypassD1/2 - выбор пришедшего байпаса в DECODE стадии
bypassE1/2 - выбор пришедшего байпаса в EXECUTE стадии
*/
module data_path(
    input clk, rst, 
    input JBEQ, J, JAL, JR, RI, LW, SHIFT, SRL,
    input writeReg, writeMem, readMem,
    input [2:0] op,
    output [5:0] opcode, funct,
    output zero,
    output stopCPU,
    /* Сигналы управления от/в Управления Конфликтами */
    input stall, stop, flush,
    input bypassD1, bypassD2,
    input [1:0] bypassE1, bypassE2,
    output [4:0] rsDECO, rtDECO,
    output [4:0] rsEXEC, rtEXEC,
    output [4:0] wriRegEXEC, wriRegMEMO, wriRegWRIT
);

/*
Регистры-задержки между стадиями
Суффиксы сигналов-стадий:
_D - DECODE, _E - EXECUTE, _M - MEMORY, _W - WRITEBACK
*/
// FETCH -> DECODE (адрес:32 + частьАдреса:4 + следАдрес:32)
reg [67:0] f2d;
// DECODE -> EXECUTE (рег1:32 + рег2:32 + shamt:5 + регSАдрес:5 + регTАдрес:5 + регDАдрес:5 + immd:32)
reg [115:0] d2e;
// EXECUTE -> MEMORY (результат:32 + адрес:32 + регАдрес:5)
reg [68:0] e2m;
// MEMORY -> WRITEBACK (результат:32 + изПамяти:32 + регАдрес:5)
reg [68:0] m2w;


/*
FETCH стадия
*/

// PC + CMDMEM wires
wire [31:0] nextaddr_F, addr_F, cmd_F;
wire [31:0] addrJBEQ_D, addrJR_D, addrJ_D;
// PC + 4 (Классический шаг)
wire [31:0] addrAdd4_F = addr_F + 4;
// Выбор следующей команды для PC
wire [31:0] muxJBEQ = JBEQ ? addrJBEQ_D : addrAdd4_F;
wire [31:0] muxJR = JR ? addrJR_D : addrJ_D; 
wire [31:0] muxJJR = J || JR ? muxJR : muxJBEQ;
assign nextaddr_F = JAL ? addrJ_D : muxJJR;

// Выключаем PC если идет остановка конвейера (stall)
pc pc(.stall(stall), .clk(clk), .rst(rst), .nextaddr(nextaddr_F), .addr(addr_F));
cmdmem cmdmem(.addr(addr_F), .cmd(cmd_F));

wire [3:0] addrHigh_F = addr_F[31:28];


/*
DECODE стадия
*/

wire [31:0] cmd_D = f2d[67:36];
wire [3:0] addrHigh_D = f2d[35:32];
wire [31:0] addrAdd4_D = f2d[31:0];

// Выбор частей из шины команды
wire [5:0] opcode_D, funct_D;
wire [4:0] rs_D, rt_D, rdR_D, shamt_D, rdI_D;
wire [15:0] immd_D;
wire [25:0] jaddr_D;
assign  opcode_D = cmd_D[31:26],
        rs_D = cmd_D[25:21],
        rt_D = cmd_D[20:16],
        rdR_D = cmd_D[15:11],
        shamt_D = cmd_D[10:6],
        funct_D = cmd_D[5:0],
        rdI_D = cmd_D[20:16],
        immd_D = cmd_D[15:0],
        jaddr_D = cmd_D[25:0];

// REGFILE wires
wire [31:0] rd1_D, rd2_D;
wire [4:0] wa_D = writeReg ? regAddr_W : 5'd31;
wire [31:0] wd_D = writeReg ? data2write_W : addrAdd4_D;
// Запись в регистр и при WriteBack и при JAL (Конфликт решается остановкой)
wire writeRegPipelined = writeReg || JAL;
regfile regfile(.clk(clk), .rst(rst), .writeReg(writeRegPipelined),
                .ra1(rs_D), .ra2(rt_D), .wa(wa_D), .wd(wd_D),
                .rd1(rd1_D), .rd2(rd2_D));

// Расширение со знаком immd 16->32
wire [31:0] immd32_D = {{16{immd_D[15]}}, immd_D};

// Сборка адресов для прыжков (В prefetch стадию)
assign addrJBEQ_D = (immd32_D << 2) + addrAdd4_D;
assign addrJ_D = {addrHigh_D, jaddr_D, 2'b00};
assign addrJR_D = rd1_D;

// Output значения из DECODE стадии (res_M - это выход из ALU)
assign zero = (bypassD1 ? res_M : rd1_D) == (bypassD2 ? res_M : rd2_D);
assign opcode = opcode_D;
assign funct = funct_D;
// Выдача в Управление Конфликтами
assign rsDECO = rs_D;
assign rtDECO = rt_D;


/*
EXECUTE стадия
*/

wire [31:0] rd1_E = d2e[115:84];
wire [31:0] rd2_E = d2e[83:52];
wire [4:0] shamt_E = d2e[51:47];
wire [4:0] rs_E = d2e[46:42];
wire [4:0] rdR_E = d2e[41:37];
wire [4:0] rdI_E = d2e[36:32];
wire [31:0] immd32_E = d2e[31:0];

// ALU + выбор значения в ALU и после
reg [31:0] a_E, b_pre_E;
wire [31:0] b_E, c_E;
wire [31:0] shiftRt_E;
always @(*) begin
    case (bypassE1)
    2'b00: a_E = rd1_E;
    2'b01: a_E = data2write_W;
    2'b10: a_E = res_M;
    2'b11: a_E = rd1_E;
    endcase
    case (bypassE2)
    2'b00: b_pre_E = rd2_E;
    2'b01: b_pre_E = data2write_W;
    2'b10: b_pre_E = res_M;
    2'b11: b_pre_E = rd2_E;
    endcase
end
assign b_E = RI ? immd32_E : b_pre_E;
// Сдвинутое значение (SLL/SRL команда)
assign shiftRt_E = SRL ? b_pre_E >> shamt_E : b_pre_E << shamt_E;

alu alu(.op(op), .a(a_E), .b(b_E), .c(c_E));

// Выбор адреса для Data Memory и WriteBack стадии
wire [31:0] res_E = SHIFT ? shiftRt_E : c_E;
wire [4:0] regAddr_E = RI ? rdI_E : rdR_E;

// Выдача в Управление Конфликтами
assign rsEXEC = rs_E;
assign rtEXEC = rdI_E; // (Он же считается rt_E)
assign wriRegEXEC = regAddr_E;


/*
MEMORY стадия
*/

wire [31:0] res_M = e2m[68:37];
wire [31:0] wd_M = e2m[36:5];
wire [4:0] regAddr_M = e2m[4:0];

wire [31:0] dataFromMem_M;

cache cache(
    .clk(clk), .rst(rst), .address(res_M), .writeData(wd_M),
    .writeMem(writeMem), .readMem(readMem), .stopCPU(stopCPU),
    .data(dataFromMem_M)
);

// Выдача в Управление Конфликтами
assign wriRegMEMO = regAddr_M;


/*
WRITEBACK стадия
*/

wire [31:0] res_W = m2w[68:37];
wire [31:0] dataFromMem_W = m2w[36:5];
wire [4:0] regAddr_W = m2w[4:0];

wire [31:0] data2write_W = LW ? dataFromMem_W : res_W;

// Выдача в Управление Конфликтами
assign wriRegWRIT = regAddr_W;


// Обновление всех регистров (Проход данных с задержкой)
always @(posedge clk) begin
    // Сброс — все регистры обнуляются
    if (rst) begin
        f2d <= 68'd0;
        d2e <= 116'd0;
        e2m <= 69'd0;
        m2w <= 69'd0;
    end
    else if (stop) begin
        f2d <= f2d;
        d2e <= d2e;
        e2m <= e2m;
        m2w <= m2w;
    end 
    else begin
        // Отчистка от ошибки предсказателя || Приостановка конвейера || Работа по плану
        f2d <= flush ? 68'd0 : stall ? f2d : {cmd_F, addrHigh_F, addrAdd4_F};
        // Приостановка конвейера || Работа по плану
        d2e <= stall ? 116'd0 : {rd1_D, rd2_D, shamt_D, rs_D, rdR_D, rdI_D, immd32_D};
        e2m <= {res_E, b_pre_E, regAddr_E};
        m2w <= {res_M, dataFromMem_M, regAddr_M}; 
    end
end

endmodule