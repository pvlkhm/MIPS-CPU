/*
Устройство управления конфликтами в конвейере
Управляет:
1. Байпасами из MEMORY/WRITEBACK в EXECUTE
2. Остановкой конвейера
3. Отчисткой FETCH->DECODE стадии (При BEQ/BNE переходе)
*/
module hazard_mngr(
    /* Управление Bypass'ами */
    input [4:0] rsDECO, rtDECO,
    input [4:0] rsEXEC, rtEXEC,
    input [4:0] wriRegEXEC, wriRegMEMO, wriRegWRIT,
    input wriSigEXEC, wriSigMEMO, wriSigWRIT,
    input stopCPU,
    output bypassD1, bypassD2,
    output reg [1:0] bypassE1, bypassE2,
    /* Управление предсказателем */
    input JBEQ,
    output flush,
    /* Управление остановкой конвейера */
    input J, JR, JAL,
    input wriRegFromMemEXEC, wriRegFromMemMEMO,
    output stall, stop
);

/* Bypass управление */

// В EXECUTE стадию
// ВАЖНО: не bypass-ить $0 регистр, так как он аппаратно не будет в регистр записываться в конце(!)
// Если участвующий в E операции регистр находится на M или W в очереди записи -> доставляем прямиком в E
always @(*) begin
    if (rsEXEC != 5'd0 && (rsEXEC == wriRegMEMO && wriSigMEMO)) bypassE1 = 2'b10;
    else if (rsEXEC != 5'd0 && (rsEXEC == wriRegWRIT && wriSigWRIT)) bypassE1 = 2'b01;
    else bypassE1 = 2'b00;

    if (rtEXEC != 5'd0 && (rtEXEC == wriRegMEMO && wriSigMEMO)) bypassE2 = 2'b10;
    else if (rtEXEC != 5'd0 && (rtEXEC == wriRegWRIT && wriSigWRIT)) bypassE2 = 2'b01;
    else bypassE2 = 2'b00;
end
// В DECODE стадию
assign bypassD1 = (rsDECO != 5'd0 && (rsDECO == wriRegMEMO && wriSigMEMO));
assign bypassD2 = (rtDECO != 5'd0 && (rtDECO == wriRegMEMO && wriSigMEMO));


/* Управление предсказателем */

// Если предсказатель ошибся — затереть предыдущую команду из очереди выполнения
// Т.к. она лишняя (Если произошло ветвление — BEQBNE сработал)
// А также безусловно затирать при прыжках (J JAL JR) — т.к. успевает пртолкнуть одну инструкцию после
// Если JAL — особенное внимание — нужно затирать только при выполнении JAL (А не пока оно стоит)
assign flush = JBEQ || J || JR || (JAL && ~wriSigWRIT);


/* Управление остановкой конвейера */

// Если команду невозможно bypass-ить в DECODE из EXECUTE (Например lw) — нужно остановить
// Если для вычисления BEQ/BNE нужны регистры, которые в E (ариф) или M (lw) – остановка
// Если на одном такте JAL и Любая команда записи сошлись в DECODE стадии — остановка до \
// выполнения всех мешающих JAL команд, а после и сам JAL

// wriRegFromMemEXEC – признак команды читающий из MEMORY (А значит долгой) (lw)
wire stallLW = (rsDECO == rtEXEC || rtDECO == rtEXEC) && wriRegFromMemEXEC;

// Если JBEQ и 1. В EXECUTE арифметика с записью в регистр 2. В MEMORY LW с записью
wire stallJBEQ_WITH_E = JBEQ && (rsDECO == wriRegEXEC || rtDECO == wriRegEXEC) && wriSigEXEC;
wire stallJBEQ_WITH_M = JBEQ && (rsDECO == wriRegMEMO || rtDECO == wriRegMEMO) && wriRegFromMemMEMO;
wire stallJBEQ = stallJBEQ_WITH_E || stallJBEQ_WITH_M;

// Остановка конвейера при записи из WRITEBACK
wire stallJAL = JAL && wriSigWRIT;


assign stall = stallLW || stallJBEQ || stallJAL;
assign stop = stopCPU;

endmodule