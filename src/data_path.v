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
RFE — Jump по EPC регистру
MFC — Загрузка из Cause в регфайл
wrongInst — неверная инструкция
irq — внешнее прерывание
writeReg/writeMem – разрешение записи по clk в память
stall - остановка ковейера
flush - очистка от ложного ветвления (BEQ/BNE спекуляция) 
bypassD1/2 - выбор пришедшего байпаса в DECODE стадии
bypassE1/2 - выбор пришедшего байпаса в EXECUTE стадии
*/
module data_path(
    input clk, rst, 
    input JBEQ, J, JAL, JR, RI, LW, SHIFT, SRL, RFE, MFC,
    input writeReg, writeMem, readMem,
    input [2:0] op,
    input wrongInst,
    input irq,
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
Регистры для хранения и передачи причины/адреса прерывания/(команды с прерыванием)
*/
reg [31:0] exD, exE, exM;
reg [31:0] pcD, pcE, pcM;

/*
Cause регистр — для хранения причины прерывания
EPC регистр — для хранения адреса счетчика (команды с прерыванием)
inHandler — регистр блокирования прерываний
interr — сигнал наличия прерывания
*/
reg [31:0] cause;
reg [31:0] epc;
reg inHandler;
wire interr = (|exM || irq) && ~inHandler;

/*
FETCH стадия
*/

/*
Обработчик прерываний находится в адресах с 0 по 124 (0 — 31 по словам)
С 128 (32 по словам) идет пользовательская программа
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
// Прерывание -> в обработчик (По адресу 0x0)
// JAL -> Прыжок
// RFE -> Прыжок на адрес из EPC (возврат из обработчика прерываний)
// Иначе -> логика конвейера
assign nextaddr_F = interr ? 32'd0 : JAL ? addrJ_D : RFE ? epc : muxJJR;

// Выключаем PC если идет остановка конвейера (stall)
wire pcStall = stall || stop;
pc pc(.stall(pcStall), .clk(clk), .rst(rst), .nextaddr(nextaddr_F), .addr(addr_F));
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
// MFC -> Записываем в регистр (из rt)
wire [4:0] wa_D = MFC ? rt_D : writeReg ? regAddr_W : 5'd31;
// MFC -> Записываем значение Cause
wire [31:0] wd_D = MFC ? cause : writeReg ? data2write_W : addrAdd4_D;
// Запись в регистр и при WriteBack и при JAL (Конфликт решается остановкой)
wire writeRegPipelined = writeReg || JAL || MFC;
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



// Обновление Cause и EPC регистров (если есть причины)
always @(posedge clk) begin
    if (rst || RFE) begin // Сброс или выход из обработчика
        cause <= 32'd0;
        epc <= 32'd0;
        inHandler <= 1'd0;
    end
    else if (~inHandler && irq) begin // Внешнее (НУЖНО БЛОКИРОВАТЬ!)
        cause <= 32'd2;
        epc <= pcM;
        inHandler <= 1'd1;
    end
    else if (~inHandler && interr) begin // Есть ли вообще прерывание (НУЖНО БЛОКИРОВАТЬ!)
        cause <= exM;
        epc <= pcM;
        inHandler <= 1'd1;
    end
end

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
        // Обработка прерывания || Очистка от ошибки предсказателя || Приостановка конвейера || Работа по плану
        f2d <= interr ? 68'd0 : stall ? f2d : flush ? 68'd0 : {cmd_F, addrHigh_F, addrAdd4_F};
        // Обработка прерывания || Приостановка конвейера || Работа по плану
        d2e <= interr ? 116'd0 : stall ? 116'd0 : {rd1_D, rd2_D, shamt_D, rs_D, rdR_D, rdI_D, immd32_D};
        // Обработка прерывания || Работа по плану
        e2m <= interr ? 69'd0 : {res_E, b_pre_E, regAddr_E};
        // Обработка прерывания || Работа по плану
        m2w <= interr ? 69'd0 : {res_M, dataFromMem_M, regAddr_M}; 
    end
end

// Обновления всех регистров обработки прерываний
// Коды прерываний
// 00 — все хорошо
// 01 — неверный опкод
// 10 — внешнее прерывание
always @(posedge clk) begin
    if (rst) begin
        exD <= 32'd0;
        exE <= 32'd0;
        exM <= 32'd0;
        pcD <= 32'd0;
        pcE <= 32'd0;
        pcD <= 32'd0;
    end
    else if (stop) begin
        exD <= exD;
        exE <= exE;
        exM <= exM;
        pcD <= pcD;
        pcE <= pcE;
        pcD <= pcD;
    end
    else begin
        exD <= interr ? 32'd0 : flush ? 32'd0 : stall ? exD : 32'd0;
        exE <= interr ? 32'd0 : stall ? 32'd0 : wrongInst ? 32'd1 : 32'd0; // Если неверная инструкция — выставляем код
        exM <= interr ? 32'd0 : exE;

        pcD <= interr ? 32'd0 : flush ? 32'd0 : stall ? pcD : addr_F; // Адрес текущей команды на вход
        pcE <= interr ? 32'd0 : stall ? 32'd0 : pcD; // Передача
        pcM <= interr ? 32'd0 : pcE; // Передача
    end
end

endmodule