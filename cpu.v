module cpu(
    input clk, rst,
    input irq // внешнее прерывание
);

// Hazard Manager wires
wire [4:0] rsDECO, rtDECO;
wire [4:0] rsEXEC, rtEXEC;
wire [4:0] wriRegEXEC, wriRegMEMO, wriRegWRIT;
wire bypassD1, bypassD2;
wire [1:0] bypassE1, bypassE2;
wire flush;
wire wriRegFromMemEXEC, wriRegFromMemMEMO;
wire stall;
wire stopCPU;

// Control+Data wires
wire JBEQ, J, JAL, JR, RI, LW, SHIFT, SRL;
wire writeReg, writeMem;
wire [2:0] op;
wire [5:0] opcode, funct;
wire zero;

hazard_mngr hazard_mngr(.rsDECO(rsDECO), .rtDECO(rtDECO),
                        .rsEXEC(rsEXEC), .rtEXEC(rtEXEC),
                        .wriRegEXEC(wriRegEXEC), .wriRegMEMO(wriRegMEMO), .wriRegWRIT(wriRegWRIT),
                        .wriSigEXEC(wriSigEXEC), .wriSigMEMO(wriSigMEMO), .wriSigWRIT(wriSigWRIT),
                        .bypassD1(bypassD1), .bypassD2(bypassD2),
                        .bypassE1(bypassE1), .bypassE2(bypassE2),
                        .JBEQ(JBEQ), .BEQBNE(BEQBNE),
                        .flush(flush),
                        .stopCPU(stopCPU),
                        .JAL(JAL), .J(J), .JR(JR), .RFE(RFE),
                        .wriRegFromMemEXEC(wriRegFromMemEXEC), .wriRegFromMemMEMO(wriRegFromMemMEMO),
                        .stall(stall), .stop(stop));  

data_path data_path(.clk(clk), .rst(rst),
                    .JBEQ(JBEQ), .J(J), .JAL(JAL), .JR(JR), .RI(RI), .LW(LW), .SHIFT(SHIFT), .SRL(SRL), .RFE(RFE), .MFC(MFC),
                    .writeReg(writeReg), .writeMem(writeMem), .readMem(readMem), .op(op), .wrongInst(wrongInst), .irq(irq),
                    .opcode(opcode), .funct(funct), .zero(zero),
                    .stall(stall), .stop(stop), .flush(flush), .stopCPU(stopCPU),
                    .bypassD1(bypassD1), .bypassD2(bypassD2),
                    .bypassE1(bypassE1), .bypassE2(bypassE2),
                    .rsDECO(rsDECO), .rtDECO(rtDECO),
                    .rsEXEC(rsEXEC), .rtEXEC(rtEXEC),
                    .wriRegEXEC(wriRegEXEC), .wriRegMEMO(wriRegMEMO), .wriRegWRIT(wriRegWRIT));

control_path control_path(  .clk(clk), .rst(rst),
                            .opcode(opcode), .funct(funct),
                            .zero(zero),
                            .BEQBNE(BEQBNE), .JBEQ(JBEQ), .J(J), .JAL(JAL), .JR(JR), .RI(RI), .LW(LW), .SHIFT(SHIFT), .SRL(SRL), .RFE(RFE), .MFC(MFC),
                            .writeReg(writeReg), .writeMem(writeMem), .readMem(readMem),
                            .op(op), .wrongInst(wrongInst),
                            .stall(stall), .stop(stop),
                            .wriSigEXEC(wriSigEXEC), .wriSigMEMO(wriSigMEMO), .wriSigWRIT(wriSigWRIT),
                            .wriMemorySigEXEC(wriMemorySigEXEC), .wriMemorySigMEMO(wriMemorySigMEMO),
                            .wriRegFromMemEXEC(wriRegFromMemEXEC), .wriRegFromMemMEMO(wriRegFromMemMEMO));

endmodule
